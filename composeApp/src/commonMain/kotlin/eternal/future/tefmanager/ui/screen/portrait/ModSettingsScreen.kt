package eternal.future.tefmanager.ui.screen.portrait

import androidx.compose.runtime.Composable
import cafe.adriel.voyager.core.screen.Screen
import cafe.adriel.voyager.navigator.LocalNavigator
import eternal.future.tefmanager.ui.component.ModSettingsContent
import eternal.future.tefmanager.utils.addon.AddonManager

/*******************************************************************************
 * TEFManager - ModSettingsScreen
 *
 * 独立的模组设置界面。屏幕只保存可序列化的 loaderId / modPkgId，
 * 模组与设置存储在组合时解析（避免 Voyager 序列化导航栈时崩溃）。
 *******************************************************************************/

class ModSettingsScreen(
    private val loaderId: String,
    private val modPkgId: String
) : Screen, MainScreen.TitledScreen {

    private fun findMod() =
        AddonManager.modManagersList[loaderId]?.packs?.find { it.pkgId == modPkgId }

    @Composable
    override fun Content() {
        val navigator = LocalNavigator.current
        val manager = AddonManager.modManagersList[loaderId]
        val mod = manager?.packs?.find { it.pkgId == modPkgId }
        val store = manager?.getSettingsStore(modPkgId)

        if (mod != null && store != null) {
            ModSettingsContent(mod, store) { navigator?.pop() }
        }
    }

    override val title: String
        get() = findMod()?.name ?: "模组设置"
}
