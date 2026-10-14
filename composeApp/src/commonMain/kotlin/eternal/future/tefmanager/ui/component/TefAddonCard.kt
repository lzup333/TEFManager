package eternal.future.tefmanager.ui.component

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Extension
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import eternal.future.tefmanager.utils.toFileUrlString
import io.kamel.image.KamelImage
import io.kamel.image.asyncPainterResource
import okio.FileSystem
import okio.Path
import okio.SYSTEM

/*******************************************************************************
 * TEFManager - TefAddonCard
 *
 * 复刻自 TEFModLoader 的两种卡片外观：
 *  - TefModCard    : EFMod 卡片（右侧 Switch，可展开）
 *  - TefLoaderCard : Loader 卡片（右侧 Checkbox，可展开）
 *******************************************************************************/

@Composable
fun TefModCard(
    name: String,
    enabled: Boolean = true,
    onEnableChange: (Boolean) -> Unit = {},
    author: String? = null,
    version: String? = null,
    description: String = "",
    iconPath: Path? = null,
    showToggle: Boolean = true,
    onDelete: (() -> Unit)? = null,
    onInfo: (() -> Unit)? = null,
    onOpen: (() -> Unit)? = null,
    onSettings: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    TefAddonCard(
        name = name,
        author = author,
        version = version,
        description = description,
        enabled = enabled,
        onEnableChange = onEnableChange,
        useCheckbox = false,
        showToggle = showToggle,
        iconPath = iconPath,
        circleIcon = false,
        onDelete = onDelete,
        onInfo = onInfo,
        onOpen = onOpen,
        onSettings = onSettings,
        modifier = modifier
    )
}

@Composable
fun TefLoaderCard(
    name: String,
    enabled: Boolean,
    onEnableChange: (Boolean) -> Unit,
    author: String? = null,
    version: String? = null,
    description: String = "",
    iconPath: Path? = null,
    showToggle: Boolean = true,
    onDelete: (() -> Unit)? = null,
    onInfo: (() -> Unit)? = null,
    onOpen: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    TefAddonCard(
        name = name,
        author = author,
        version = version,
        description = description,
        enabled = enabled,
        onEnableChange = onEnableChange,
        useCheckbox = true,
        showToggle = showToggle,
        iconPath = iconPath,
        circleIcon = true,
        onDelete = onDelete,
        onInfo = onInfo,
        onOpen = onOpen,
        modifier = modifier
    )
}

@Composable
private fun TefAddonCard(
    name: String,
    author: String?,
    version: String?,
    description: String,
    enabled: Boolean,
    onEnableChange: (Boolean) -> Unit,
    useCheckbox: Boolean,
    showToggle: Boolean,
    iconPath: Path?,
    circleIcon: Boolean,
    onDelete: (() -> Unit)?,
    onInfo: (() -> Unit)?,
    onOpen: (() -> Unit)?,
    onSettings: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    var expanded by remember { mutableStateOf(false) }

    ElevatedCard(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clickable { expanded = !expanded },
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                TefAddonIcon(iconPath = iconPath, circle = circleIcon)

                Spacer(modifier = Modifier.width(16.dp))

                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = name,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    // 始终保留「作者」「版本」两行，保证与旧版卡片高度一致
                    Text(
                        text = if (!author.isNullOrBlank()) "by $author" else "",
                        fontSize = 14.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.padding(top = 4.dp)
                    )
                    Text(
                        text = if (!version.isNullOrBlank()) "v$version" else "",
                        fontSize = 14.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                if (showToggle) {
                    if (useCheckbox) {
                        Checkbox(checked = enabled, onCheckedChange = onEnableChange)
                    } else {
                        Switch(checked = enabled, onCheckedChange = onEnableChange)
                    }
                }
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
                        if (onOpen != null) {
                            IconButton(onClick = onOpen) {
                                Icon(Icons.Default.Extension, contentDescription = "Open")
                            }
                        }
                        if (onSettings != null) {
                            IconButton(onClick = onSettings) {
                                Icon(Icons.Default.Tune, contentDescription = "Settings")
                            }
                        }
                        if (onDelete != null) {
                            IconButton(onClick = onDelete) {
                                Icon(
                                    Icons.Default.Delete,
                                    contentDescription = "Delete",
                                    tint = MaterialTheme.colorScheme.error
                                )
                            }
                        }
                        if (onInfo != null) {
                            IconButton(onClick = onInfo) {
                                Icon(Icons.Default.Info, contentDescription = "Details")
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    Text(
                        text = description,
                        fontSize = 14.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

@Composable
private fun TefAddonIcon(iconPath: Path?, circle: Boolean) {
    val shape = if (circle) CircleShape else RoundedCornerShape(8.dp)
    val hasIcon = iconPath != null && FileSystem.SYSTEM.exists(iconPath)

    if (hasIcon) {
        KamelImage(
            resource = { asyncPainterResource(data = iconPath!!.toFileUrlString()) },
            contentDescription = null,
            modifier = Modifier
                .size(48.dp)
                .clip(shape)
        )
    } else {
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(shape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.Memory,
                contentDescription = null,
                modifier = Modifier.size(32.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
