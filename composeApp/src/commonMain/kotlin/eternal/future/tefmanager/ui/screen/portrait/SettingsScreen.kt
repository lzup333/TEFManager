package eternal.future.tefmanager.ui.screen.portrait

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material.icons.filled.BeachAccess
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.LocalFlorist
import androidx.compose.material.icons.filled.NaturePeople
import androidx.compose.material.icons.filled.NightsStay
import androidx.compose.material.icons.filled.SettingsSystemDaydream
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Update
import androidx.compose.material.icons.filled.UploadFile
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import cafe.adriel.voyager.core.screen.Screen
import eternal.future.tefmanager.BuildConfig
import eternal.future.tefmanager.ConfigurationState
import eternal.future.tefmanager.ConfigurationState.AppConfig
import eternal.future.tefmanager.Platform
import eternal.future.tefmanager.model.UpdateInfo
import eternal.future.tefmanager.strings.StringsResource
import eternal.future.tefmanager.strings.StringsResource.Strings
import eternal.future.tefmanager.ui.component.TefActionButton
import eternal.future.tefmanager.ui.component.TefSelector
import eternal.future.tefmanager.ui.component.TefSelectorWithIcon
import eternal.future.tefmanager.ui.component.TefSwitchItem
import eternal.future.tefmanager.ui.dialogs.ModuleType
import eternal.future.tefmanager.ui.dialogs.UpdateDialog
import eternal.future.tefmanager.utils.AppLogger
import eternal.future.tefmanager.utils.NetworkService
import eternal.future.tefmanager.utils.addon.AddonManager
import eternal.future.tefmanager.utils.addon.ModuleManager
import eternal.future.tefmanager.utils.exitApplication
import eternal.future.tefmanager.utils.isVersionGreater
import eternal.future.tefmanager.utils.openUrl
import io.github.vinceglb.filekit.dialogs.FileKitMode
import io.github.vinceglb.filekit.dialogs.compose.rememberFilePickerLauncher
import io.github.vinceglb.filekit.name
import io.github.vinceglb.filekit.size
import io.github.vinceglb.filekit.source
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.io.buffered
import kotlinx.io.files.Path
import kotlinx.io.files.SystemFileSystem
import okio.FileSystem
import okio.Path.Companion.toPath
import okio.SYSTEM

/*******************************************************************************
 * TEFManager - SettingsScreen
 *
 * 外观复刻自旧版设置页：单列 LazyColumn + Selector / Switch / ActionButton。
 *******************************************************************************/

object SettingsScreen : Screen, MainScreen.TitledScreen {

    @Composable
    override fun Content() {
        val snackbarHostState = remember { SnackbarHostState() }
        val scope = rememberCoroutineScope()
        val networkService = remember { NetworkService() }

        var updateInfo by remember { mutableStateOf<UpdateInfo?>(null) }
        var showUpdateDialog by remember { mutableStateOf(false) }

        val kernelPicker = rememberFilePickerLauncher(mode = FileKitMode.Single) { file ->
            if (file == null) return@rememberFilePickerLauncher
            val tmp = Path((Platform.getDirectory("tmp") / file.name).toString())
            tmp.parent?.let { SystemFileSystem.createDirectories(it) }
            SystemFileSystem.sink(tmp).buffered().use { sink ->
                sink.write(file.source(), file.size())
                sink.flush()
            }
            AddonManager.installKernel(tmp.toString().toPath())
            SystemFileSystem.delete(tmp)
        }

        fun checkForUpdates() {
            scope.launch {
                try {
                    snackbarHostState.showSnackbar(Strings.common.checkingUpdate)

                    val info = networkService.fetchUpdateInfoWithRetry(
                        "https://raw.githubusercontent.com/eternalfuture-e38299/TEFManager/main/update.json"
                    )

                    if (info == null) {
                        snackbarHostState.showSnackbar(Strings.common.updateFailed(Strings.error.cantGetUpdate))
                        return@launch
                    }

                    val currentTefManagerVersion = BuildConfig.VERSION_NAME
                    val currentKernelVersion = ConfigurationState.kernelVersion
                    val currentLoaderVersion = ConfigurationState.kernelVersion
                    val currentLanguageVersion = ModuleManager.getPackItem("eternal.future.languagepackextension")?.version
                    val currentFontVersion = ModuleManager.getPackItem("eternal.future.fontpackextension")?.version
                    val currentTextureVersion = ModuleManager.getPackItem("eternal.future.texturepackextension")?.version
                    val currentMusicVersion = ModuleManager.getPackItem("eternal.future.audiopackextension")?.version

                    val built = UpdateInfo(
                        tefmanager = info.tefmanager?.takeIf { isVersionGreater(it.newVersion, currentTefManagerVersion) },
                        tefkernel = info.tefkernel?.takeIf { isVersionGreater(it.newVersion, currentKernelVersion) },
                        tefloader = info.tefloader?.takeIf {
                            isVersionGreater(it.newVersion, currentLoaderVersion) && Platform.isDesktop
                        },
                        language = info.language?.takeIf {
                            currentLanguageVersion == null || isVersionGreater(it.newVersion, currentLanguageVersion)
                        },
                        font = info.font?.takeIf {
                            currentFontVersion == null || isVersionGreater(it.newVersion, currentFontVersion)
                        },
                        texture = info.texture?.takeIf {
                            currentTextureVersion == null || isVersionGreater(it.newVersion, currentTextureVersion)
                        },
                        music = info.music?.takeIf {
                            currentMusicVersion == null || isVersionGreater(it.newVersion, currentMusicVersion)
                        }
                    )

                    val hasUpdate = built.tefmanager != null || built.tefkernel != null || built.tefloader != null ||
                            built.language != null || built.font != null || built.texture != null || built.music != null

                    if (hasUpdate) {
                        updateInfo = built
                        showUpdateDialog = true
                    } else {
                        snackbarHostState.showSnackbar(Strings.common.latestVersion)
                    }
                } catch (e: Exception) {
                    AppLogger.e("Failed to check for updates", e)
                    snackbarHostState.showSnackbar(Strings.common.updateFailed(e.message ?: "UNKNOWN"))
                }
            }
        }

        val themeMap = mapOf(
            0 to (Strings.settings.appearance.ocean to Icons.Default.BeachAccess),
            1 to (Strings.settings.appearance.autumn to Icons.Default.LocalFireDepartment),
            2 to (Strings.settings.appearance.green to Icons.Default.NaturePeople),
            3 to (Strings.settings.appearance.yellow to Icons.Default.LocalFlorist),
            4 to (Strings.settings.appearance.pink to Icons.Default.Favorite),
            5 to (Strings.settings.appearance.purple to Icons.Default.Star)
        )

        val languageMap = mapOf(
            StringsResource.Language.System.ordinal to Strings.settings.followSystem,
            StringsResource.Language.ZhHans.ordinal to "简体中文",
            StringsResource.Language.En.ordinal to "English",
            StringsResource.Language.Ru.ordinal to "Русский"
        )

        val followSystem = ConfigurationState.themeMode == AppConfig.ThemeMode.SYSTEM
        val darkTheme = ConfigurationState.themeMode == AppConfig.ThemeMode.DARK

        Box(modifier = Modifier.fillMaxSize()) {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(8.dp)
            ) {
                item {
                    Text(
                        Strings.settings.general.title,
                        modifier = Modifier.padding(4.dp),
                        style = MaterialTheme.typography.titleSmall,
                        color = MaterialTheme.colorScheme.primary
                    )

                    TefSelector(
                        title = Strings.settings.general.language,
                        defaultSelectorId = ConfigurationState.language.ordinal,
                        selectorMap = languageMap,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(4.dp),
                        onClick = { ConfigurationState.language = StringsResource.Language.entries[it] }
                    )

                    TefSelectorWithIcon(
                        title = Strings.settings.appearance.palette,
                        defaultSelectorId = ConfigurationState.themePalette,
                        selector = themeMap,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(4.dp),
                        onClick = { ConfigurationState.themePalette = it }
                    )

                    TefSwitchItem(
                        title = Strings.settings.followSystem,
                        contentDescription = Strings.settings.appearance.paletteDec,
                        checked = followSystem,
                        onCheckedChange = { check ->
                            ConfigurationState.themeMode = if (check) {
                                AppConfig.ThemeMode.SYSTEM
                            } else if (darkTheme) {
                                AppConfig.ThemeMode.DARK
                            } else {
                                AppConfig.ThemeMode.LIGHT
                            }
                        },
                        modifier = Modifier
                            .padding(4.dp)
                            .fillMaxWidth(),
                        iconOn = Icons.Default.SettingsSystemDaydream
                    )

                    if (!followSystem) {
                        TefSwitchItem(
                            iconOff = Icons.Default.WbSunny,
                            iconOn = Icons.Default.NightsStay,
                            title = Strings.settings.appearance.darkTheme,
                            contentDescription = Strings.settings.appearance.themeDec,
                            checked = darkTheme,
                            onCheckedChange = { check ->
                                ConfigurationState.themeMode =
                                    if (check) AppConfig.ThemeMode.DARK else AppConfig.ThemeMode.LIGHT
                            },
                            modifier = Modifier
                                .padding(4.dp)
                                .fillMaxWidth()
                        )
                    }

                    TefSwitchItem(
                        title = Strings.settings.general.update,
                        contentDescription = Strings.settings.general.updateDec,
                        checked = ConfigurationState.autoUpdate,
                        onCheckedChange = { ConfigurationState.autoUpdate = it },
                        modifier = Modifier
                            .padding(4.dp)
                            .fillMaxWidth()
                    )
                }

                item {
                    Text(
                        Strings.settings.about.title,
                        modifier = Modifier.padding(4.dp),
                        style = MaterialTheme.typography.titleSmall,
                        color = MaterialTheme.colorScheme.primary
                    )

                    // 导入内核
                    TefActionButton(
                        icon = Icons.Default.UploadFile,
                        title = Strings.settings.about.import,
                        onClick = { kernelPicker.launch() }
                    )

                    // 检查更新（独立按钮）
                    TefActionButton(
                        icon = Icons.Default.Update,
                        title = Strings.settings.about.checkUpdate,
                        onClick = { checkForUpdates() }
                    )

                    TefActionButton(
                        icon = Icons.Default.Star,
                        title = Strings.settings.about.github,
                        description = Strings.settings.about.developerName,
                        onClick = {
                            openUrl("https://github.com/eternalfuture-e38299/TEFManager")
                            Unit
                        }
                    )

                    TefActionButton(
                        icon = Icons.AutoMirrored.Filled.ExitToApp,
                        title = Strings.common.exit,
                        onClick = { exitApplication() }
                    )
                }
            }

            SnackbarHost(
                hostState = snackbarHostState,
                modifier = Modifier.align(Alignment.BottomCenter)
            )
        }

        val info = updateInfo
        if (showUpdateDialog && info != null) {
            UpdateDialog(
                updateInfo = info,
                onDismiss = { showUpdateDialog = false },
                onModuleInstalled = { moduleType, downloadedPath ->
                    when (moduleType) {
                        ModuleType.TEFLoader -> {
                            val targetFile = Platform.getData("tefkernel") / "tefloader.zip"
                            if (FileSystem.SYSTEM.exists(downloadedPath)) {
                                FileSystem.SYSTEM.copy(downloadedPath, targetFile)
                                FileSystem.SYSTEM.delete(downloadedPath)
                            }
                        }
                        ModuleType.TEFKernel -> AddonManager.installKernel(downloadedPath)
                        else -> runBlocking { AddonManager.install(downloadedPath) }
                    }
                }
            )
        }
    }

    override val title: String
        get() = Strings.settings.title
}
