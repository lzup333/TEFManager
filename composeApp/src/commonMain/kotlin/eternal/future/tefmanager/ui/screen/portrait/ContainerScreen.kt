package eternal.future.tefmanager.ui.screen.portrait

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DeleteSweep
import androidx.compose.material.icons.filled.FileDownload
import androidx.compose.material.icons.filled.FileUpload
import androidx.compose.material.icons.filled.Image
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import cafe.adriel.voyager.core.screen.Screen
import cafe.adriel.voyager.navigator.LocalNavigator
import eternal.future.tefmanager.ConfigurationState
import eternal.future.tefmanager.Platform
import eternal.future.tefmanager.strings.StringsResource.Strings
import eternal.future.tefmanager.ui.component.TefActionButton
import eternal.future.tefmanager.ui.component.TefModernCheckBox
import eternal.future.tefmanager.ui.component.TefModCard
import eternal.future.tefmanager.utils.exitApplication
import eternal.future.tefmanager.utils.modpack.ModPackBackup
import eternal.future.tefmanager.utils.modpack.ModPackManager
import eternal.future.tefmanager.utils.modpack.ModPackStore
import io.github.vinceglb.filekit.dialogs.FileKitDialogSettings
import io.github.vinceglb.filekit.dialogs.FileKitMode
import io.github.vinceglb.filekit.dialogs.compose.rememberFilePickerLauncher
import io.github.vinceglb.filekit.dialogs.compose.rememberFileSaverLauncher
import io.github.vinceglb.filekit.name
import io.github.vinceglb.filekit.size
import io.github.vinceglb.filekit.sink
import io.github.vinceglb.filekit.source
import kotlinx.coroutines.launch
import kotlinx.io.buffered
import kotlinx.io.files.SystemFileSystem
import okio.Path
import okio.Path.Companion.toPath

/*******************************************************************************
 * TEFManager - ContainerScreen
 *
 * 底部「容器」栏目：整合包 = 存储容器/快照。
 *  - 列出初始容器与已导入容器
 *  - 导入/导出容器
 *  - 应用（切换存储）/ 删除（连同容器内 Mod/Loader 一起卸载）
 *******************************************************************************/

object ContainerScreen : Screen, MainScreen.TitledScreen {

    @Composable
    override fun Content() {
        LaunchedEffect(Unit) {
            ModPackStore.refresh()
            ModPackStore.ensureInitialContainer()
        }

        val navigator = LocalNavigator.current
        val scope = rememberCoroutineScope()

        var showExportDialog by remember { mutableStateOf(false) }
        var exportName by remember { mutableStateOf("") }
        var exportIconName by remember { mutableStateOf<String?>(null) }
        var exportIconPath by remember { mutableStateOf<Path?>(null) }

        var busy by remember { mutableStateOf(false) }
        var busyText by remember { mutableStateOf("") }
        var message by remember { mutableStateOf<String?>(null) }
        var needsRestart by remember { mutableStateOf(false) }
        var pendingDeleteId by remember { mutableStateOf<String?>(null) }
        var showClearBackupsConfirm by remember { mutableStateOf(false) }
        var pendingExportZip by remember { mutableStateOf<Path?>(null) }

        val iconPicker = rememberFilePickerLauncher(mode = FileKitMode.Single) { file ->
            if (file != null) {
                try {
                    val tmp = kotlinx.io.files.Path(
                        (Platform.getDirectory("tmp") / "modpack_icon_${file.name}").toString()
                    )
                    tmp.parent?.let { SystemFileSystem.createDirectories(it) }
                    SystemFileSystem.sink(tmp).buffered().use { sink ->
                        sink.write(file.source(), file.size())
                        sink.flush()
                    }
                    exportIconPath = tmp.toString().toPath()
                    exportIconName = file.name
                } catch (e: Exception) {
                    message = Strings.manager.modpack.failed(e.message ?: "UNKNOWN")
                }
            }
        }

        val saver = rememberFileSaverLauncher(FileKitDialogSettings.createDefault()) { target ->
            if (target != null) {
                val src = pendingExportZip
                if (src != null) {
                    try {
                        val source = kotlinx.io.files.Path(src.toString())
                        target.sink().use { output ->
                            SystemFileSystem.source(source).buffered().use { input ->
                                output.buffered().use { out -> input.transferTo(out) }
                            }
                        }
                        message = Strings.manager.modpack.exportSuccess
                    } catch (e: Exception) {
                        message = Strings.manager.modpack.failed(e.message ?: "UNKNOWN")
                    }
                }
            }
            pendingExportZip = null
        }

        val importPicker = rememberFilePickerLauncher(mode = FileKitMode.Single) { file ->
            if (file != null) {
                try {
                    val tmp = kotlinx.io.files.Path(
                        (Platform.getDirectory("tmp") / "modpack_import_${file.name}").toString()
                    )
                    tmp.parent?.let { SystemFileSystem.createDirectories(it) }
                    SystemFileSystem.sink(tmp).buffered().use { sink ->
                        sink.write(file.source(), file.size())
                        sink.flush()
                    }
                    val zipPath = tmp.toString().toPath()

                    scope.launch {
                        busy = true
                        busyText = Strings.manager.modpack.importing
                        val result = ModPackManager.import(zipPath) { name ->
                            busyText = "${Strings.manager.modpack.importing} $name"
                        }
                        busy = false
                        ModPackStore.refresh()
                        result.fold(
                            onSuccess = {
                                message = Strings.manager.modpack.applySuccess
                                needsRestart = true
                            },
                            onFailure = { e -> message = Strings.manager.modpack.failed(e.message ?: "UNKNOWN") }
                        )
                        runCatching { SystemFileSystem.delete(tmp) }
                    }
                } catch (e: Exception) {
                    message = Strings.manager.modpack.failed(e.message ?: "UNKNOWN")
                }
            }
        }

        Box(modifier = Modifier.fillMaxSize()) {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(8.dp)
            ) {
                item {
                    Text(
                        text = Strings.manager.modpack.hint,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                    )

                    TefActionButton(
                        icon = Icons.Default.FileDownload,
                        title = Strings.manager.modpack.export,
                        onClick = {
                            exportName = Strings.manager.modpack.defaultName
                            showExportDialog = true
                        }
                    )

                    TefActionButton(
                        icon = Icons.Default.FileUpload,
                        title = Strings.manager.modpack.import,
                        onClick = { importPicker.launch() }
                    )

                    TefModernCheckBox(
                        title = Strings.manager.modpack.autoBackup,
                        contentDescription = Strings.manager.modpack.autoBackupHint,
                        isChecked = ConfigurationState.modPackAutoBackup,
                        onCheckedChange = { ConfigurationState.modPackAutoBackup = it },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 6.dp)
                    )

                    TefActionButton(
                        icon = Icons.Default.DeleteSweep,
                        title = Strings.manager.modpack.clearBackups,
                        description = Strings.manager.modpack.clearBackupsHint,
                        onClick = { showClearBackupsConfirm = true }
                    )
                }

                items(ModPackStore.packs, key = { it.id }) { pack ->
                    TefModCard(
                        name = pack.manifest.name,
                        version = pack.manifest.version,
                        description = Strings.manager.modpack.contents(pack.manifest.entries.size),
                        iconPath = pack.iconPath,
                        showToggle = false,
                        onOpen = { navigator?.push(ModPackDetailScreen(pack.id)) },
                        onDelete = if (pack.initial) null else ({ pendingDeleteId = pack.id })
                    )
                }
            }
        }

        if (showExportDialog) {
            AlertDialog(
                onDismissRequest = { if (!busy) showExportDialog = false },
                title = { Text(Strings.manager.modpack.export) },
                text = {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        OutlinedTextField(
                            value = exportName,
                            onValueChange = { exportName = it },
                            label = { Text(Strings.manager.modpack.name) },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth()
                        )

                        Surface(
                            onClick = { iconPicker.launch() },
                            shape = RoundedCornerShape(8.dp),
                            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.1f),
                            contentColor = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Image,
                                    contentDescription = null,
                                    modifier = Modifier.size(22.dp)
                                )
                                Spacer(modifier = Modifier.width(12.dp))
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = Strings.manager.modpack.icon,
                                        style = MaterialTheme.typography.titleSmall
                                    )
                                    Text(
                                        text = exportIconName ?: Strings.manager.modpack.chooseIcon,
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        }
                    }
                },
                confirmButton = {
                    TextButton(
                        enabled = !busy,
                        onClick = {
                            val name = exportName.ifBlank { Strings.manager.modpack.defaultName }
                            showExportDialog = false
                            scope.launch {
                                busy = true
                                busyText = Strings.manager.modpack.exporting
                                val out = Platform.getDirectory("tmp") / "modpack_export.zip"
                                val result = ModPackManager.export(
                                    destZip = out,
                                    name = name,
                                    iconSource = exportIconPath,
                                    onProgress = { n -> busyText = "${Strings.manager.modpack.exporting} $n" }
                                )
                                busy = false
                                result.fold(
                                    onSuccess = {
                                        pendingExportZip = out
                                        saver.launch(name, "zip")
                                    },
                                    onFailure = { e ->
                                        message = if (e.message == "EMPTY") {
                                            Strings.manager.modpack.empty
                                        } else {
                                            Strings.manager.modpack.failed(e.message ?: "UNKNOWN")
                                        }
                                    }
                                )
                            }
                        }
                    ) {
                        Text(Strings.confirm)
                    }
                },
                dismissButton = {
                    TextButton(onClick = { showExportDialog = false }, enabled = !busy) {
                        Text(Strings.cancel)
                    }
                }
            )
        }

        pendingDeleteId?.let { id ->
            AlertDialog(
                onDismissRequest = { pendingDeleteId = null },
                title = { Text(Strings.manager.modpack.delete) },
                text = { Text(Strings.manager.modpack.deleteConfirm) },
                confirmButton = {
                    TextButton(onClick = {
                        pendingDeleteId = null
                        scope.launch {
                            busy = true
                            busyText = Strings.manager.modpack.applying
                            ModPackStore.deletePack(id)
                            busy = false
                        }
                    }) {
                        Text(Strings.confirm)
                    }
                },
                dismissButton = {
                    TextButton(onClick = { pendingDeleteId = null }) {
                        Text(Strings.cancel)
                    }
                }
            )
        }

        if (showClearBackupsConfirm) {
            AlertDialog(
                onDismissRequest = { showClearBackupsConfirm = false },
                title = { Text(Strings.manager.modpack.clearBackups) },
                text = { Text(Strings.manager.modpack.clearBackupsConfirm) },
                confirmButton = {
                    TextButton(onClick = {
                        showClearBackupsConfirm = false
                        val ok = ModPackBackup.clear()
                        needsRestart = false
                        message = if (ok) {
                            Strings.manager.modpack.clearBackupsDone
                        } else {
                            Strings.manager.modpack.failed("UNKNOWN")
                        }
                    }) {
                        Text(Strings.confirm)
                    }
                },
                dismissButton = {
                    TextButton(onClick = { showClearBackupsConfirm = false }) {
                        Text(Strings.cancel)
                    }
                }
            )
        }

        if (busy) {
            AlertDialog(
                onDismissRequest = {},
                title = { Text(busyText) },
                text = { CircularProgressIndicator() },
                confirmButton = {}
            )
        }

        message?.let { msg ->
            AlertDialog(
                onDismissRequest = { message = null },
                title = { Text(Strings.manager.container.title) },
                text = {
                    Text(
                        if (needsRestart) "$msg\n\n${Strings.manager.modpack.restartNeeded}" else msg
                    )
                },
                confirmButton = {
                    if (needsRestart) {
                        TextButton(onClick = {
                            message = null
                            exitApplication()
                        }) { Text(Strings.manager.modpack.restart) }
                    } else {
                        TextButton(onClick = { message = null }) { Text(Strings.confirm) }
                    }
                },
                dismissButton = if (needsRestart) {
                    {
                        TextButton(onClick = { message = null }) { Text(Strings.cancel) }
                    }
                } else null
            )
        }
    }

    override val title: String
        get() = Strings.manager.container.title
}
