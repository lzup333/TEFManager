package eternal.future.tefmanager.ui.screen.portrait

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import cafe.adriel.voyager.core.screen.Screen
import cafe.adriel.voyager.navigator.LocalNavigator
import eternal.future.tefmanager.Platform
import eternal.future.tefmanager.model.ModPackEntry
import eternal.future.tefmanager.strings.StringsResource.Strings
import eternal.future.tefmanager.ui.component.TefActionButton
import eternal.future.tefmanager.ui.component.TefLoaderCard
import eternal.future.tefmanager.ui.component.TefModCard
import eternal.future.tefmanager.utils.addon.AddonManager
import eternal.future.tefmanager.utils.addon.ModLoaderManager
import eternal.future.tefmanager.utils.modpack.ModPackStore
import kotlinx.coroutines.launch
import okio.Path

/*******************************************************************************
 * TEFManager - ModPackDetailScreen
 *
 * 整合包（容器）详情：应用此快照 = 覆盖并切换当前存储；
 * 应用后可单独开关包内某个 Mod/Loader。
 *******************************************************************************/

class ModPackDetailScreen(
    private val packId: String
) : Screen, MainScreen.TitledScreen {

    @Composable
    override fun Content() {
        LaunchedEffect(Unit) { ModPackStore.refresh() }

        val scope = rememberCoroutineScope()
        val navigator = LocalNavigator.current
        var busy by remember { mutableStateOf(false) }
        var busyText by remember { mutableStateOf("") }
        var message by remember { mutableStateOf<String?>(null) }
        var showDeleteConfirm by remember { mutableStateOf(false) }

        val pack = ModPackStore.find(packId)
        val entries = pack?.manifest?.entries.orEmpty()

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(vertical = 8.dp)
        ) {
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Text(
                        text = Strings.manager.modpack.contents(entries.size),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 8.dp)
                    )
                    TefActionButton(
                        icon = Icons.Default.SwapHoriz,
                        title = Strings.manager.modpack.apply,
                        onClick = {
                            scope.launch {
                                busy = true
                                busyText = Strings.manager.modpack.applying
                                val result = ModPackStore.applyPack(packId) { name ->
                                    busyText = "${Strings.manager.modpack.applying} $name"
                                }
                                busy = false
                                result.fold(
                                    onSuccess = { message = Strings.manager.modpack.applySuccess },
                                    onFailure = { e ->
                                        message = Strings.manager.modpack.failed(e.message ?: "UNKNOWN")
                                    }
                                )
                            }
                        }
                    )
                    if (pack?.initial != true) {
                        TextButton(onClick = { showDeleteConfirm = true }) {
                            Text(
                                text = Strings.manager.modpack.delete,
                                color = MaterialTheme.colorScheme.error
                            )
                        }
                    }
                }
                Spacer(modifier = Modifier.height(4.dp))
            }

            items(entries, key = { "${it.type}_${it.pkgId}" }) { entry ->
                var enabled by remember(entry.type, entry.pkgId) {
                    mutableStateOf(isEntryEnabled(entry))
                }

                val iconPath = entryIcon(entry)

                if (entry.type == "modloader" || entry.type == "plugin") {
                    TefLoaderCard(
                        name = entry.name,
                        version = entry.version,
                        description = entry.pkgId,
                        iconPath = iconPath,
                        enabled = enabled,
                        onEnableChange = {
                            enabled = it
                            setEntryEnabled(entry, it)
                        }
                    )
                } else {
                    TefModCard(
                        name = entry.name,
                        version = entry.version,
                        description = entry.pkgId,
                        iconPath = iconPath,
                        enabled = enabled,
                        onEnableChange = {
                            enabled = it
                            setEntryEnabled(entry, it)
                        }
                    )
                }
            }
        }

        if (showDeleteConfirm) {
            AlertDialog(
                onDismissRequest = { showDeleteConfirm = false },
                title = { Text(Strings.manager.modpack.delete) },
                text = { Text(Strings.manager.modpack.deleteConfirm) },
                confirmButton = {
                    TextButton(onClick = {
                        showDeleteConfirm = false
                        scope.launch {
                            ModPackStore.deletePack(packId)
                            navigator?.pop()
                        }
                    }) {
                        Text(Strings.confirm)
                    }
                },
                dismissButton = {
                    TextButton(onClick = { showDeleteConfirm = false }) {
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
                title = { Text(Strings.manager.modpack.title) },
                text = { Text(msg) },
                confirmButton = {
                    TextButton(onClick = { message = null }) { Text(Strings.confirm) }
                }
            )
        }
    }

    private fun isEntryEnabled(entry: ModPackEntry): Boolean = when (entry.type) {
        "modloader" -> ModLoaderManager.isEnabled(entry.pkgId)
        "mod" -> entry.parentLoader?.let {
            AddonManager.getOrCreateModManager(it, autoCreate = true)?.isEnabled(entry.pkgId)
        } ?: false
        else -> false
    }

    private fun setEntryEnabled(entry: ModPackEntry, enabled: Boolean) {
        when (entry.type) {
            "modloader" -> {
                if (enabled) ModLoaderManager.enable(entry.pkgId)
                else ModLoaderManager.disable(entry.pkgId)
            }
            "mod" -> entry.parentLoader?.let { loaderId ->
                val manager = AddonManager.getOrCreateModManager(loaderId, autoCreate = true)
                if (enabled) manager?.enable(entry.pkgId)
                else manager?.disable(entry.pkgId)
            }
        }
    }

    private fun entryIcon(entry: ModPackEntry): Path? = when (entry.type) {
        "modloader" -> Platform.getData("modloader") / "icons" / "${entry.pkgId}.icon"
        "plugin" -> Platform.getData("plugin") / "icons" / "${entry.pkgId}.icon"
        "module" -> Platform.getData("module") / "icons" / "${entry.pkgId}.icon"
        "mod" -> entry.parentLoader?.let {
            Platform.getData("mods") / it / "icons" / "${entry.pkgId}.icon"
        }
        else -> null
    }

    override val title: String
        get() = ModPackStore.find(packId)?.manifest?.name ?: Strings.manager.modpack.title
}
