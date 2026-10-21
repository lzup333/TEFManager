package eternal.future.tefmanager.ui.component

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.ArrowDropUp
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp

/*******************************************************************************
 * TEFManager - TefSettingWidgets
 *
 * 复刻自 TEFModLoader 的设置组件（Selector / selectorWithIcon /
 * SettingsSwitchItem / ModernCheckBox / ActionButton / GeneralTextInput）。
 *******************************************************************************/

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TefSelector(
    title: String,
    defaultSelectorId: Int,
    selectorMap: Map<Int, String>,
    modifier: Modifier = Modifier,
    onClick: (Int) -> Unit = {}
) {
    var selectedId by remember { mutableStateOf(defaultSelectorId) }
    var expanded by remember { mutableStateOf(false) }

    ExposedDropdownMenuBox(
        expanded = expanded,
        onExpandedChange = { expanded = it },
        modifier = Modifier.padding(10.dp)
    ) {
        OutlinedTextField(
            readOnly = true,
            value = selectorMap[selectedId] ?: "",
            onValueChange = {},
            label = { Text(title) },
            trailingIcon = {
                Icon(
                    imageVector = if (expanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                    contentDescription = "Expand",
                    modifier = Modifier.clickable { expanded = !expanded }
                )
            },
            modifier = modifier.menuAnchor(MenuAnchorType.PrimaryEditable, true)
        )
        ExposedDropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false }
        ) {
            selectorMap.forEach { (id, name) ->
                DropdownMenuItem(
                    text = { Text(text = name) },
                    onClick = {
                        onClick(id)
                        selectedId = id
                        expanded = false
                    }
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TefSelectorWithIcon(
    title: String,
    defaultSelectorId: Int = 0,
    selector: Map<Int, Pair<String, ImageVector>>,
    modifier: Modifier = Modifier,
    onClick: (Int) -> Unit = {}
) {
    val validDefault = if (selector.containsKey(defaultSelectorId)) {
        defaultSelectorId
    } else {
        selector.keys.firstOrNull() ?: 0
    }
    var selectedId by remember { mutableStateOf(validDefault) }
    var expanded by remember { mutableStateOf(false) }
    val arrow = if (expanded) Icons.Default.ArrowDropUp else Icons.Default.ArrowDropDown

    ExposedDropdownMenuBox(
        expanded = expanded,
        onExpandedChange = { expanded = it },
        modifier = Modifier.padding(10.dp)
    ) {
        OutlinedTextField(
            readOnly = true,
            value = selector[selectedId]?.first ?: "",
            onValueChange = {},
            label = { Text(title) },
            trailingIcon = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = selector[selectedId]?.second ?: Icons.Default.MoreVert,
                        contentDescription = "Theme Icon"
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Icon(
                        imageVector = arrow,
                        contentDescription = "Expand",
                        modifier = Modifier.clickable { expanded = !expanded }
                    )
                }
            },
            modifier = modifier.menuAnchor(MenuAnchorType.PrimaryEditable, true)
        )
        ExposedDropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false }
        ) {
            selector.forEach { (id, pair) ->
                DropdownMenuItem(
                    onClick = {
                        selectedId = id
                        onClick(id)
                        expanded = false
                    },
                    text = {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(imageVector = pair.second, contentDescription = null)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(text = pair.first)
                        }
                    }
                )
            }
        }
    }
}

@Composable
fun TefSwitchItem(
    iconOn: ImageVector? = null,
    iconOff: ImageVector? = null,
    title: String,
    contentDescription: String = "",
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit = {},
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            val currentIcon = when {
                checked && iconOn != null -> iconOn
                !checked && iconOff != null -> iconOff
                iconOn != null -> iconOn
                else -> iconOff
            }

            currentIcon?.let {
                Icon(
                    imageVector = it,
                    contentDescription = null,
                    modifier = Modifier.size(24.dp)
                )
            }

            Column {
                Text(text = title, style = MaterialTheme.typography.titleMedium)
                if (contentDescription.isNotEmpty()) {
                    Text(
                        text = contentDescription,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }
        }
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange
        )
    }
}

@Composable
fun TefActionButton(
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    title: String,
    description: String? = null,
    onClick: () -> Unit
) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(8.dp),
        color = MaterialTheme.colorScheme.primary.copy(alpha = 0.1f),
        contentColor = MaterialTheme.colorScheme.primary,
        modifier = modifier
            .padding(vertical = 8.dp, horizontal = 16.dp)
            .fillMaxWidth()
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Start,
            modifier = Modifier.padding(vertical = 12.dp, horizontal = 16.dp)
        ) {
            if (icon != null) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(modifier = Modifier.width(16.dp))
            }
            Column {
                Text(text = title, style = MaterialTheme.typography.titleMedium)
                if (!description.isNullOrBlank()) {
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = description,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                    )
                }
            }
        }
    }
}

@Composable
fun TefGeneralTextInput(
    title: String,
    value: String,
    onValueChange: (String) -> Unit,
    leadingIcon: (@Composable () -> Unit)? = null,
    trailingIcon: (@Composable () -> Unit)? = null,
    modifier: Modifier = Modifier,
    placeholder: String? = null,
    singleLine: Boolean = true
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(title) },
        leadingIcon = leadingIcon?.let { { it() } },
        trailingIcon = trailingIcon?.let { { it() } },
        modifier = modifier,
        placeholder = if (!placeholder.isNullOrBlank()) {
            { Text(placeholder) }
        } else null,
        singleLine = singleLine
    )
}
