package eternal.future.tefmanager.ui.screen.portrait

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Image
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import cafe.adriel.voyager.core.screen.Screen
import eternal.future.tefmanager.Platform
import eternal.future.tefmanager.model.ResourcesPackItem
import eternal.future.tefmanager.strings.StringsResource.Strings
import eternal.future.tefmanager.ui.dialogs.ResourcePackInstallDialog
import eternal.future.tefmanager.utils.resourcepack.AudioManager
import eternal.future.tefmanager.utils.resourcepack.BasePackManager
import eternal.future.tefmanager.utils.resourcepack.FontPackManager
import eternal.future.tefmanager.utils.resourcepack.LanguagePackManager
import eternal.future.tefmanager.utils.resourcepack.TexturePackManager
import eternal.future.tefmanager.utils.toFileUrlString
import io.github.vinceglb.filekit.dialogs.FileKitMode
import io.github.vinceglb.filekit.dialogs.compose.rememberFilePickerLauncher
import io.github.vinceglb.filekit.nameWithoutExtension
import io.github.vinceglb.filekit.size
import io.github.vinceglb.filekit.source
import io.kamel.image.KamelImage
import io.kamel.image.asyncPainterResource
import kotlinx.coroutines.runBlocking
import kotlinx.io.buffered
import kotlinx.io.files.SystemFileSystem
import okio.FileSystem
import okio.Path
import okio.Path.Companion.toPath
import okio.SYSTEM
import kotlin.math.roundToInt

/*******************************************************************************
 * TEFManager - ResourcePackManagerScreen
 *
 * 全新的资源包管理界面（不复用旧的 ResourcePackScreen）。
 * 通过 [ResourcePackAdapter] 适配语言/材质/字体/音频包管理器。
 *******************************************************************************/

interface ResourcePackAdapter {
    val title: String
    val packs: List<ResourcesPackItem>
    fun initialize() {}
    fun isEnabled(fileName: String): Boolean
    fun setEnabled(fileName: String, enabled: Boolean)
    fun moveUp(fileName: String)
    fun moveDown(fileName: String)
    suspend fun delete(fileName: String)
}

class BasePackAdapter(
    override val title: String,
    private val manager: BasePackManager
) : ResourcePackAdapter {
    override val packs: List<ResourcesPackItem> get() = manager.packs
    override fun initialize() = manager.initialize()
    override fun isEnabled(fileName: String) = manager.isPackEnabled(fileName)
    override fun setEnabled(fileName: String, enabled: Boolean) = manager.setPackEnabled(fileName, enabled)
    override fun moveUp(fileName: String) = manager.movePackPriority(fileName, moveUp = true)
    override fun moveDown(fileName: String) = manager.movePackPriority(fileName, moveUp = false)
    override suspend fun delete(fileName: String) {
        manager.deletePack(fileName)
    }
}

class LanguagePackAdapter(override val title: String) : ResourcePackAdapter {
    override val packs: List<ResourcesPackItem> get() = LanguagePackManager.languagePacks
    override fun initialize() = LanguagePackManager.initialize()
    override fun isEnabled(fileName: String) = LanguagePackManager.isPackEnabled(fileName)
    override fun setEnabled(fileName: String, enabled: Boolean) {
        LanguagePackManager.setPackEnabled(fileName, enabled)
    }
    override fun moveUp(fileName: String) = LanguagePackManager.movePackPriority(fileName, moveUp = true)
    override fun moveDown(fileName: String) = LanguagePackManager.movePackPriority(fileName, moveUp = false)
    override suspend fun delete(fileName: String) {
        LanguagePackManager.deleteLanguagePack(fileName)
    }
}

class FontPackAdapter(override val title: String) : ResourcePackAdapter {
    override val packs: List<ResourcesPackItem> get() = FontPackManager.fontPacks
    override fun initialize() = FontPackManager.initialize()
    override fun isEnabled(fileName: String) = FontPackManager.isFontPackSelected(fileName)
    override fun setEnabled(fileName: String, enabled: Boolean) {
        if (enabled) {
            FontPackManager.selectFontPack(fileName)
        } else if (FontPackManager.isFontPackSelected(fileName)) {
            FontPackManager.deselectFontPack()
        }
    }
    override fun moveUp(fileName: String) {}
    override fun moveDown(fileName: String) {}
    override suspend fun delete(fileName: String) {
        FontPackManager.deleteFontPack(fileName)
    }
}

class ResourcePackManagerScreen(
    private val categoryId: String
) : Screen, MainScreen.TitledScreen {

    @Composable
    override fun Content() {
        val adapter = resourcePackAdapterFor(categoryId)

        LaunchedEffect(Unit) {
            adapter.initialize()
        }

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
            ResourcePackInstallDialog(
                filePaths = installFiles,
                onDismiss = {
                    FileSystem.SYSTEM.deleteRecursively(Platform.getDirectory("tmp") / "install_tmp")
                    installFiles.clear()
                    showInstallDialog.value = false
                }
            )
        }

        Box(modifier = Modifier.fillMaxSize()) {
            val packs = adapter.packs

            if (packs.isEmpty()) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(32.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Text(
                        text = Strings.resource.empty(adapter.title),
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = Strings.resource.emptyAction(adapter.title),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(vertical = 8.dp)
                ) {
                    items(packs) { pack ->
                        var enabled by remember(pack.fileName) {
                            mutableStateOf(adapter.isEnabled(pack.fileName))
                        }

                        ResourcePackCard(
                            pack = pack,
                            enabled = enabled,
                            onEnableChange = { value ->
                                enabled = value
                                adapter.setEnabled(pack.fileName, value)
                            },
                            onMoveUp = { adapter.moveUp(pack.fileName) },
                            onMoveDown = { adapter.moveDown(pack.fileName) },
                            onDelete = {
                                runBlocking { adapter.delete(pack.fileName) }
                            }
                        )
                    }

                    item { Spacer(modifier = Modifier.height(96.dp)) }
                }
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
                    contentDescription = null,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = Strings.resource.add(adapter.title),
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.Medium
                )
            }
        }
    }

    override val title: String
        get() = resourcePackTitle(categoryId)
}

private fun resourcePackTitle(categoryId: String): String = when (categoryId) {
    "language" -> Strings.resource.language.title
    "texture" -> Strings.resource.texture
    "font" -> Strings.resource.font.title
    "audio" -> Strings.resource.audio.title
    else -> Strings.resource.language.title
}

/**
 * 按类别 id 解析资源包适配器。
 * 注意：屏幕本身只保存可序列化的 [categoryId]，不可序列化的适配器/管理器在组合时解析，
 * 否则 Voyager 保存导航栈时会因不可序列化而崩溃。
 */
fun resourcePackAdapterFor(categoryId: String): ResourcePackAdapter = when (categoryId) {
    "language" -> LanguagePackAdapter(resourcePackTitle(categoryId))
    "texture" -> BasePackAdapter(resourcePackTitle(categoryId), TexturePackManager)
    "font" -> FontPackAdapter(resourcePackTitle(categoryId))
    "audio" -> BasePackAdapter(resourcePackTitle(categoryId), AudioManager)
    else -> LanguagePackAdapter(resourcePackTitle(categoryId))
}

@Composable
private fun ResourcePackCard(
    pack: ResourcesPackItem,
    enabled: Boolean,
    onEnableChange: (Boolean) -> Unit,
    onMoveUp: () -> Unit,
    onMoveDown: () -> Unit,
    onDelete: () -> Unit
) {
    var expanded by remember { mutableStateOf(false) }

    ElevatedCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clickable { expanded = !expanded },
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                val iconPath = pack.iconPath.takeIf { it.isNotBlank() }
                if (iconPath != null && FileSystem.SYSTEM.exists(iconPath.toPath())) {
                    KamelImage(
                        resource = { asyncPainterResource(data = iconPath.toPath().toFileUrlString()) },
                        contentDescription = null,
                        modifier = Modifier
                            .size(48.dp)
                            .clip(RoundedCornerShape(8.dp))
                    )
                } else {
                    Icon(
                        imageVector = Icons.Rounded.Image,
                        contentDescription = null,
                        modifier = Modifier.size(48.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                Spacer(modifier = Modifier.width(16.dp))

                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = pack.name,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Text(
                        text = "by ${pack.author}",
                        fontSize = 14.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.padding(top = 4.dp)
                    )
                    Text(
                        text = "v${pack.version}",
                        fontSize = 14.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                Switch(checked = enabled, onCheckedChange = onEnableChange)
            }

            AnimatedVisibility(
                visible = expanded,
                enter = expandVertically(animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy)),
                exit = shrinkVertically(animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy))
            ) {
                Column(modifier = Modifier.padding(top = 16.dp)) {
                    HorizontalDivider()
                    Spacer(modifier = Modifier.height(8.dp))

                    Row(
                        horizontalArrangement = Arrangement.SpaceBetween,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row {
                            IconButton(onClick = onMoveUp) {
                                Icon(Icons.Default.KeyboardArrowUp, contentDescription = "Up")
                            }
                            IconButton(onClick = onMoveDown) {
                                Icon(Icons.Default.KeyboardArrowDown, contentDescription = "Down")
                            }
                        }
                        IconButton(onClick = onDelete) {
                            Icon(
                                Icons.Default.Delete,
                                contentDescription = "Delete",
                                tint = MaterialTheme.colorScheme.error
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    Text(
                        text = pack.description,
                        fontSize = 14.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}
