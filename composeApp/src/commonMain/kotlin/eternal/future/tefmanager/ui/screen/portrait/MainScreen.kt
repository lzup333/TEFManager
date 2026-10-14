package eternal.future.tefmanager.ui.screen.portrait

import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.outlined.Extension
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Palette
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Widgets
import androidx.compose.material.icons.rounded.Extension
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Palette
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.Widgets
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import cafe.adriel.voyager.core.annotation.InternalVoyagerApi
import cafe.adriel.voyager.core.screen.Screen
import cafe.adriel.voyager.navigator.Navigator
import cafe.adriel.voyager.transitions.FadeTransition
import eternal.future.tefmanager.strings.StringsResource.Strings
import eternal.future.tefmanager.ui.component.AppTopBar
import eternal.future.tefmanager.ui.component.RefreshIconButton
import eternal.future.tefmanager.ui.dialogs.UpdateOutdatedDialog
import eternal.future.tefmanager.utils.addon.AddonManager
import eternal.future.tefmanager.utils.exitApplication
import eternal.future.tefmanager.utils.openUrl
import org.jetbrains.compose.resources.painterResource
import tefmanager.composeapp.generated.resources.Res
import tefmanager.composeapp.generated.resources.tefmanager_logo

/*******************************************************************************
 * TEFManager - MainScreen
 * Copyright (C) 2026 eternalfuture-e38299
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 *
 * Author: eternalfuture-e38299
 * GitHub: https://github.com/eternalfuture-e38299
 * Created: 2026/2/4
 *******************************************************************************/

@OptIn(ExperimentalMaterial3Api::class)
object MainScreen : Screen {
    interface TitledScreen {
        val title: String
        val refreshAction: (() -> Unit)?
            get() = null
    }

    data class NavigationItem(
        val screen: Screen,
        val selectedIcon: ImageVector,
        val unselectedIcon: ImageVector,
        val label: String,
        val isPrimary: Boolean = false
    )

    @OptIn(InternalVoyagerApi::class)
    @Composable
    override fun Content() {
        var showUpdateOutdatedDialog by remember { mutableStateOf(false) }

        val navigationItems = buildNavigationItems()

        LaunchedEffect(Unit) {
            AddonManager.updateOutdatedComponents(
                onNeedUpdate = {
                    showUpdateOutdatedDialog = true
                },
                onUpdateComplete = {
                    showUpdateOutdatedDialog = false
                }
            )
        }

        Navigator(
            screen = HomeScreen,
            key = "main_navigator"
        ) { navigator ->
            Scaffold(
                modifier = Modifier.fillMaxSize(),
                containerColor = MaterialTheme.colorScheme.surfaceDim,
                topBar = {
                    val currentScreen = navigator.lastItem
                    val titled = currentScreen as? TitledScreen
                    val title = titled?.title ?: ""
                    val isRoot = navigationItems.any { it.screen::class == currentScreen::class }
                    val isHome = currentScreen::class == HomeScreen::class

                    // 主页右上角三点菜单：设置 / 退出
                    val menuItems = mapOf(
                        Strings.settings.title to Pair(Icons.Default.Settings) {
                            navigator.push(SettingsScreen)
                        },
                        Strings.common.exit to Pair(Icons.AutoMirrored.Filled.ExitToApp) {
                            exitApplication()
                        }
                    )

                    AppTopBar(
                        title = title,
                        showBackButton = !isRoot,
                        showMenu = isHome,
                        onBackClick = { navigator.pop() },
                        menuItems = menuItems,
                        actions = {
                            titled?.refreshAction?.let { action ->
                                RefreshIconButton(
                                    refreshAction = action
                                )
                            }
                        }
                    )
                },
                bottomBar = {
                    ModernBottomNavigation(navigator = navigator, navigationItems = navigationItems)
                }
            ) { paddingValues ->
                if (showUpdateOutdatedDialog) UpdateOutdatedDialog {}

                Surface(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues),
                    color = MaterialTheme.colorScheme.surface,
                    tonalElevation = 2.dp
                ) {
                    // 使用淡入淡出动画，过渡更自然
                    FadeTransition(
                        navigator = navigator,
                        animationSpec = tween(durationMillis = 200)
                    )
                }
            }
        }
    }

    @Composable
    private fun buildNavigationItems(): List<NavigationItem> = listOf(
        NavigationItem(
            screen = HomeScreen,
            selectedIcon = Icons.Rounded.Home,
            unselectedIcon = Icons.Outlined.Home,
            label = Strings.home.title,
            isPrimary = true
        ),
        NavigationItem(
            screen = ModScreen,
            selectedIcon = Icons.Rounded.Extension,
            unselectedIcon = Icons.Outlined.Extension,
            label = Strings.manager.mod.title
        ),
        NavigationItem(
            screen = ManagerScreen,
            selectedIcon = Icons.Rounded.Widgets,
            unselectedIcon = Icons.Outlined.Widgets,
            label = Strings.manager.title
        )
    )

    @Composable
    private fun ModernBottomNavigation(navigator: Navigator, navigationItems: List<NavigationItem>) {
        val currentScreen = navigator.lastItem
        val selectedIndex = navigationItems.indexOfFirst { it.screen::class == currentScreen::class }
            .coerceAtLeast(0)

        NavigationBar(
            containerColor = MaterialTheme.colorScheme.surface,
            tonalElevation = 2.dp
        ) {
            navigationItems.forEachIndexed { index, item ->
                val selected = index == selectedIndex

                NavigationBarItem(
                    selected = selected,
                    onClick = {
                        if (!selected) {
                            navigator.push(item.screen)
                        }
                    },
                    icon = {
                        Icon(
                            imageVector = item.selectedIcon,
                            contentDescription = item.label,
                            modifier = Modifier.size(24.dp)
                        )
                    },
                    label = {
                        Text(
                            text = item.label,
                            maxLines = 1
                        )
                    },
                    alwaysShowLabel = false,
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}