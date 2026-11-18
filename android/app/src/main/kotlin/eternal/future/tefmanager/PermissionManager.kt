package eternal.future.tefmanager

import android.content.Context
import java.io.File

/**
 * Root-mode helpers: share the manager's external directory with the game's
 * UID so the injected kernel can read mods.
 */
object PermissionManager {

    fun getTefManagerDirectory(context: Context): File = File(
        context.getExternalFilesDir(null)?.parentFile?.parentFile,
        "eternal.future.tefmanager",
    )

    fun grantReadWriteAccess(context: Context, targetPackage: String): Boolean {
        return try {
            val dir = getTefManagerDirectory(context)
            if (!dir.exists()) dir.mkdirs()
            val appInfo = context.packageManager.getApplicationInfo(targetPackage, 0)
            val uid = appInfo.uid
            executeRootCommand("chown -R :$uid \"${dir.absolutePath}\"")
            executeRootCommand("chmod -R 2770 \"${dir.absolutePath}\"")
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun executeRootCommand(cmd: String) {
        val process = Runtime.getRuntime().exec(arrayOf("su", "-c", cmd))
        val code = process.waitFor()
        if (code != 0) throw IllegalStateException("su failed ($code): $cmd")
    }

    fun hasRootPermission(context: Context): Boolean {
        @Suppress("UNUSED_VARIABLE")
        val unused = context
        return try {
            Runtime.getRuntime().exec(arrayOf("su", "-c", "echo test")).waitFor() == 0
        } catch (_: Exception) {
            false
        }
    }
}
