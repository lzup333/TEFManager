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
import eternal.future.tefmanager.strings.StringsResource.Strings
import eternal.future.tefmanager.ui.component.TefActionButton
import eternal.future.tefmanager.utils.modpack.ModPackStore
import kotlinx.coroutines.launch

/*******************************************************************************
 * TEFManager - ModPackDetailScreen
 *
 * 容器详情：应用（切换存储）/ 删除。切换为热重载，无需重启。
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

        fun applyContainer() {
            scope.launch {
                busy = true
                busyText = Strings.manager.modpack.applying
                val result = ModPackStore.applyPack(packId) { name ->
                    busyText = "${Strings.manager.modpack.applying} $name"
                }
                busy = false
                result.fold(
                    onSuccess = { message = Strings.manager.modpack.applySuccess },
                    onFailure = { e -> message = Strings.manager.modpack.failed(e.message ?: "UNKNOWN") }
                )
            }
        }

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
                        text = Strings.manager.modpack.snapshotSummary(pack?.manifest?.fileCount ?: 0),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 8.dp)
                    )
                    pack?.manifest?.kernelVersion?.let { v ->
                        Text(
                            text = "${Strings.settings.about.kernelVersion}: $v",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(horizontal = 8.dp)
                        )
                    }

                    TefActionButton(
                        icon = Icons.Default.SwapHoriz,
                        title = Strings.manager.modpack.apply,
                        onClick = { applyContainer() }
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
                            busy = true
                            busyText = Strings.manager.modpack.applying
                            ModPackStore.deletePack(packId)
                            busy = false
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

    override val title: String
        get() = ModPackStore.find(packId)?.manifest?.name ?: Strings.manager.modpack.title
}
