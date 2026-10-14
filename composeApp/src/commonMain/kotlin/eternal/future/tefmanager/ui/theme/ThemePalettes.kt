package eternal.future.tefmanager.ui.theme

import androidx.compose.material3.ColorScheme
import eternal.future.tefmanager.ui.theme.palette.autumn.darkScheme as autumnDark
import eternal.future.tefmanager.ui.theme.palette.autumn.lightScheme as autumnLight
import eternal.future.tefmanager.ui.theme.palette.green.darkScheme as greenDark
import eternal.future.tefmanager.ui.theme.palette.green.lightScheme as greenLight
import eternal.future.tefmanager.ui.theme.palette.ocean.darkScheme as oceanDark
import eternal.future.tefmanager.ui.theme.palette.ocean.lightScheme as oceanLight
import eternal.future.tefmanager.ui.theme.palette.pink.darkScheme as pinkDark
import eternal.future.tefmanager.ui.theme.palette.pink.lightScheme as pinkLight
import eternal.future.tefmanager.ui.theme.palette.purple.darkScheme as purpleDark
import eternal.future.tefmanager.ui.theme.palette.purple.lightScheme as purpleLight
import eternal.future.tefmanager.ui.theme.palette.yellow.darkScheme as yellowDark
import eternal.future.tefmanager.ui.theme.palette.yellow.lightScheme as yellowLight

/*******************************************************************************
 * TEFManager - ThemePalettes
 *
 * 移植自 TEFModLoader 的配色方案系统：
 * 0 = 沧海明月 (ocean) / 1 = 朱雀烈阳 (autumn) / 2 = 翠竹幽林 (green)
 * 3 = 金秋稻香 (yellow) / 4 = 桃花春水 (pink) / 5 = 紫气东来 (purple)
 *******************************************************************************/

object ThemePalettes {
    const val COUNT = 6
    const val DEFAULT = 0

    val lightSchemes: List<ColorScheme> = listOf(
        oceanLight,
        autumnLight,
        greenLight,
        yellowLight,
        pinkLight,
        purpleLight
    )

    val darkSchemes: List<ColorScheme> = listOf(
        oceanDark,
        autumnDark,
        greenDark,
        yellowDark,
        pinkDark,
        purpleDark
    )

    fun scheme(index: Int, darkTheme: Boolean): ColorScheme {
        val i = index.coerceIn(0, COUNT - 1)
        return if (darkTheme) darkSchemes[i] else lightSchemes[i]
    }
}
