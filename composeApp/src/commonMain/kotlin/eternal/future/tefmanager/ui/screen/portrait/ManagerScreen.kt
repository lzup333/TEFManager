package eternal.future.tefmanager.ui.screen.portrait

import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
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
import eternal.future.tefmanager.ConfigurationState
import eternal.future.tefmanager.Platform
import eternal.future.tefmanager.strings.StringsResource.Strings
import eternal.future.tefmanager.ui.component.TefLoaderCard
import eternal.future.tefmanager.ui.component.TefModCard
import eternal.future.tefmanager.ui.dialogs.AddonInstallOrUpdateDialog
import eternal.future.tefmanager.utils.addon.AddonManager
import eternal.future.tefmanager.utils.addon.ModLoaderManager
import eternal.future.tefmanager.utils.addon.ModuleManager
import eternal.future.tefmanager.utils.addon.PluginManager
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
 * TEFManager - ManagerScreen
 *
 * 复刻旧版 Loader 页外观：单一列表，无标签栏。
 *  - TEFKernel / ModLoader / 内核插件 使用 Loader 卡片
 *  - 内核模块 使用 Mod 卡片
 *******************************************************************************/

object ManagerScreen : Screen, MainScreen.TitledScreen {

    @Composable
    override fun Content() {
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
                showInstallDialog.value = false
            }
        }

        LaunchedEffect(ModLoaderManager.packs.toList()) {
            AddonManager.refreshModManager(ModLoaderManager.packs)
        }

        Box(modifier = Modifier.fillMaxSize()) {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(vertical = 8.dp)
            ) {
                // TEFKernel —— 视为 Loader
                item(key = "tefkernel") {
                    TefLoaderCard(
                        name = "TEFKernel",
                        version = ConfigurationState.kernelVersion,
                        description = Strings.settings.about.kernelVersion,
                        enabled = true,
                        showToggle = false,
                        onEnableChange = {}
                    )
                }

                // ModLoader —— Loader
                items(ModLoaderManager.packs, key = { "loader_${it.pkgId}" }) { loader ->
                    var enabled by remember(loader.pkgId) {
                        mutableStateOf(ModLoaderManager.isEnabled(loader.pkgId))
                    }

                    TefLoaderCard(
                        name = loader.name,
                        author = loader.author,
                        version = loader.version,
                        description = loader.brieflyDescribe.ifBlank { loader.description },
                        iconPath = Platform.getData("modloader") / "icons" / "${loader.pkgId}.icon",
                        enabled = enabled,
                        onEnableChange = { enable ->
                            // 立刻更新 UI + 立刻写盘
                            enabled = enable
                            if (enable) {
                                ModLoaderManager.enable(loader.pkgId)
                                AddonManager.getOrCreateModManager(loader.pkgId, true)
                            } else {
                                ModLoaderManager.disable(loader.pkgId)
                                AddonManager.closeModManager(loader.pkgId)
                            }
                        },
                        onDelete = {
                            runBlocking { ModLoaderManager.delete(loader.pkgId) }
                        }
                    )
                }

                // 内核插件 —— Loader
                items(PluginManager.packs, key = { "plugin_${it.pkgId}" }) { plugin ->
                    TefLoaderCard(
                        name = plugin.name,
                        author = plugin.author,
                        version = plugin.version,
                        description = plugin.description,
                        iconPath = PluginManager.getIconFilePath(plugin.pkgId),
                        enabled = true,
                        onEnableChange = {},
                        onDelete = {
                            runBlocking { PluginManager.delete(plugin.pkgId) }
                        }
                    )
                }

                // 内核模块
                items(ModuleManager.packs, key = { "module_${it.pkgId}" }) { module ->
                    var enabled by remember(module.pkgId) {
                        mutableStateOf(ModuleManager.isEnabled(module.pkgId))
                    }

                    TefLoaderCard(
                        name = module.name,
                        author = module.author,
                        version = module.version,
                        description = module.brieflyDescribe.ifBlank { module.description },
                        iconPath = ModuleManager.getIconFilePath(module.pkgId),
                        enabled = enabled,
                        onEnableChange = { enable ->
                            enabled = enable
                            if (enable) ModuleManager.enable(module.pkgId)
                            else ModuleManager.disable(module.pkgId)
                        },
                        onDelete = {
                            runBlocking { ModuleManager.delete(module.pkgId) }
                        }
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
                    contentDescription = Strings.manager.add,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = Strings.manager.add,
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Medium
                )
            }
        }
    }

    override val title: String
        get() = Strings.manager.title
}
