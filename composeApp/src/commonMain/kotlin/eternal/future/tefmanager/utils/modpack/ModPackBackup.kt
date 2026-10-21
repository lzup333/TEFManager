package eternal.future.tefmanager.utils.modpack

import eternal.future.tefmanager.Platform
import eternal.future.tefmanager.utils.AppLogger
import okio.FileSystem
import okio.Path
import okio.SYSTEM
import kotlin.time.Clock

/*******************************************************************************
 * TEFManager - ModPackBackup
 *
 * 导入整合包前，自动备份当前存储内容（Mod / Loader / 内核等）。
 *******************************************************************************/

object ModPackBackup {

    private val backupDirs = listOf("mods", "modloader", "module", "plugin", "tefkernel")

    fun backupNow(reason: String = "modpack"): Path? {
        return try {
            val safeReason = reason.replace(Regex("[^a-zA-Z0-9._\\-\\u4e00-\\u9fa5]"), "_").take(32)
            val root = Platform.getData("backups") /
                    "${safeReason}_${Clock.System.now().toEpochMilliseconds()}"
            FileSystem.SYSTEM.createDirectories(root)

            backupDirs.forEach { name ->
                val src = Platform.getData(name)
                if (FileSystem.SYSTEM.exists(src)) {
                    copyDir(src, root / name)
                }
            }
            AppLogger.i("ModPack backup created: $root")
            root
        } catch (e: Exception) {
            AppLogger.e("ModPack backup failed", e)
            null
        }
    }

    private fun copyDir(src: Path, dst: Path) {
        val fs = FileSystem.SYSTEM
        if (!fs.exists(src)) return
        fs.createDirectories(dst)

        fs.list(src).forEach { child ->
            val target = dst / child.name
            val metadata = runCatching { fs.metadata(child) }.getOrNull() ?: return@forEach
            if (metadata.isDirectory) {
                copyDir(child, target)
            } else {
                target.parent?.let { fs.createDirectories(it) }
                fs.copy(child, target)
            }
        }
    }
}
