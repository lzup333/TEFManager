package eternal.future.tefmanager.ui.screen.portrait

import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import cafe.adriel.voyager.core.screen.Screen
import cafe.adriel.voyager.navigator.LocalNavigator
import eternal.future.tefmanager.Platform
import eternal.future.tefmanager.strings.StringsResource.Strings
import eternal.future.tefmanager.ui.component.TefModCard
import eternal.future.tefmanager.ui.dialogs.AddonInstallOrUpdateDialog
import eternal.future.tefmanager.utils.addon.AddonManager
import eternal.future.tefmanager.utils.addon.ModLoaderManager
import eternal.future.tefmanager.utils.addon.ModuleManager
import eternal.future.tefmanager.utils.openUrl
import io.github.vinceglb.filekit.dialogs.FileKitMode
import io.github.vinceglb.filekit.dialogs.compose.rememberFilePickerLauncher
import io.github.vinceglb.filekit.nameWithoutExtension
import io.github.vinceglb.filekit.size
import io.github.vinceglb.filekit.source
import kotlinx.coroutines.runBlocking
import kotlinx.io.buffered
import kotlinx.io.files.SystemFileSystem
import okio.FileSystem
import okio.Path
import okio.Path.Companion.toPath
import okio.SYSTEM
import kotlin.math.roundToInt

/*******************************************************************************
 * TEFManager - ModScreen
 *
 * 外观复刻自 TEFModLoader 的“EFMod”页面：单一扁平卡片列表 + 可拖动 FAB。
 * 资源加载由内核模块负责，因此这些资源加载器（内核模块）以 Mod 卡片展示，
 * 点击进入各自独立的资源管理页面。
 *******************************************************************************/

object ModScreen : Screen, MainScreen.TitledScreen {

    private data class ResourcePseudoMod(
        val pkgId: String,
        val title: String,
        val hint: String,
        val screen: Screen
    )

    @Composable
    override fun Content() {
        val navigator = LocalNavigator.current

        val showInstallDialog = remember { mutableStateOf(false) }
        val installFiles = remember { mutableListOf<Path>() }

        val filePickerLauncher = rememberFilePickerLauncher(
            mode = FileKitMode.Multiple(maxItems = 10)
        ) { files ->
            installFiles.clear()
            files?.forEach { file ->
                val tmp = kotlinx.io.files.Path(
                    (Platform.getDirectory("tmp") / "install_tmp" / file.nameWithoutExtension).toString()
                )
                tmp.parent?.let { SystemFileSystem.createDirectories(it) }
                SystemFileSystem.sink(tmp).buffered().use { sink ->
                    sink.write(file.source(), file.size())
                    sink.flush()
                    installFiles.add(tmp.toString().toPath())
                }
                showInstallDialog.value = true
            }
        }

        if (showInstallDialog.value) {
            AddonInstallOrUpdateDialog(installFiles) {
                FileSystem.SYSTEM.deleteRecursively(Platform.getDirectory("tmp") / "install_tmp")
                AddonManager.refreshModManager(ModLoaderManager.packs)
                showInstallDialog.value = false
            }
        }

        val enabledLoaders = remember { mutableStateMapOf<String, Boolean>() }

        LaunchedEffect(ModLoaderManager.packs) {
            AddonManager.refreshModManager(ModLoaderManager.packs)
            ModLoaderManager.packs.forEach {
                enabledLoaders[it.pkgId] = ModLoaderManager.isEnabled(it.pkgId)
            }
        }

        // 资源加载器（内核模块）—— 视为 Mod，点击进入全新的资源管理界面
        val resourceMods = buildList {
            add(
                ResourcePseudoMod(
                    pkgId = "eternal.future.languagepackextension",
                    title = Strings.resource.language.title,
                    hint = Strings.manager.mod.resourceHint,
                    screen = ResourcePackManagerScreen("language")
                )
            )
            if (Platform.isAndroid) {
                add(
                    ResourcePseudoMod(
                        pkgId = "eternal.future.texturepackextension",
                        title = Strings.resource.texture,
                        hint = Strings.manager.mod.resourceHint,
                        screen = ResourcePackManagerScreen("texture")
                    )
                )
                add(
                    ResourcePseudoMod(
                        pkgId = "eternal.future.fontpackextension",
                        title = Strings.resource.font.title,
                        hint = Strings.manager.mod.resourceHint,
                        screen = ResourcePackManagerScreen("font")
                    )
                )
                add(
                    ResourcePseudoMod(
                        pkgId = "eternal.future.audiopackextension",
                        title = Strings.resource.audio.title,
                        hint = Strings.manager.mod.resourceHint,
                        screen = ResourcePackManagerScreen("audio")
                    )
                )
            }
        }

        // 所有已启用 Loader 的 Mod（自动匹配）
        // 直接读取快照状态（不缓存），这样新增/删除 Mod、启用/禁用 Loader 都会即时刷新。
        val modGroups = ModLoaderManager.packs
            .filter { enabledLoaders[it.pkgId] == true }
            .flatMap { loader ->
                val manager = AddonManager.modManagersList[loader.pkgId]
                manager?.packs?.map { mod -> loader.pkgId to mod } ?: emptyList()
            }

        Box(modifier = Modifier.fillMaxSize()) {
            LazyColumn(modifier = Modifier.fillMaxSize()) {
                items(resourceMods, key = { "res_${it.pkgId}" }) { pseudo ->
                    val module = ModuleManager.getPackItem(pseudo.pkgId)
                    TefModCard(
                        name = pseudo.title,
                        author = module?.author,
                        version = module?.version,
                        description = pseudo.hint,
                        iconPath = ModuleManager.getIconFilePath(pseudo.pkgId),
                        showToggle = false,
                        onOpen = { navigator?.push(pseudo.screen) }
                    )
                }

                items(modGroups, key = { (loaderId, mod) -> "${loaderId}_${mod.pkgId}" }) { (loaderId, mod) ->
                    val manager = AddonManager.getOrCreateModManager(loaderId)
                    var enabled by remember(mod.pkgId) {
                        mutableStateOf(manager?.isEnabled(mod.pkgId) ?: false)
                    }
                    val detailsUrl = mod.detailsURL

                    TefModCard(
                        name = mod.name,
                        author = mod.author,
                        version = mod.version,
                        description = mod.brieflyDescribe.ifBlank { mod.description },
                        iconPath = manager?.getIconFilePath(mod.pkgId),
                        enabled = enabled,
                        onEnableChange = { enable ->
                            enabled = enable
                            if (enable) manager?.enable(mod.pkgId) else manager?.disable(mod.pkgId)
                        },
                        onDelete = {
                            runBlocking { manager?.delete(mod.pkgId) }
                        },
                        onSettings = if (mod.settings.isNotEmpty()) {
                            { navigator?.push(ModSettingsScreen(loaderId, mod.pkgId)) }
                        } else null,
                        onInfo = if (detailsUrl.isNotBlank()) {
                            {
                                openUrl(detailsUrl)
                                Unit
                            }
                        } else null
                    )
                }

                item { Spacer(modifier = Modifier.height(96.dp)) }
            }

            var offsetX by remember { mutableFloatStateOf(0f) }
            var offsetY by remember { mutableFloatStateOf(0f) }

            ExtendedFloatingActionButton(
                onClick = { filePickerLauncher.launch() },
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(16.dp)
                    .offset { IntOffset(offsetX.roundToInt(), offsetY.roundToInt()) }
                    .pointerInput(Unit) {
                        detectDragGestures { _, dragAmount ->
                            offsetX += dragAmount.x
                            offsetY += dragAmount.y
                        }
                    },
                containerColor = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary,
                shape = RoundedCornerShape(16.dp)
            ) {
                Icon(
                    imageVector = Icons.Rounded.Add,
                    contentDescription = Strings.manager.mod.add,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = Strings.manager.mod.add,
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Medium
                )
            }
        }
    }

    override val title: String
        get() = Strings.manager.mod.title
}
