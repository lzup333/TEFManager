package eternal.future.tefmanager.modpage

import android.content.Context
import dalvik.system.DexClassLoader
import java.io.File
import java.io.FileNotFoundException

data class ModPageEntry(
    val loader: DexClassLoader,
    val cacheFile: File,
    val dexDir: File,
    val clazz: Class<*>,
    val instance: Any,
)

/** Reusable class loaders for mod pages, keyed by the page JAR path. */
object ModPageLoader {
    private val entries = mutableMapOf<String, ModPageEntry>()

    @Synchronized
    fun load(context: Context, jarPath: String, className: String): Result<ModPageEntry> {
        entries[jarPath]?.let { return Result.success(it) }
        return runCatching {
            val original = File(jarPath)
            if (!original.exists()) throw FileNotFoundException("页面文件不存在: $jarPath")

            val cacheFile = File(
                context.cacheDir,
                "mod_page_${System.currentTimeMillis()}_${original.name}.jar",
            )
            original.inputStream().use { input ->
                cacheFile.outputStream().use { output -> input.copyTo(output) }
            }
            cacheFile.setReadOnly()

            val dexDir = File(context.cacheDir, "mod_page_dex_${System.currentTimeMillis()}")
            dexDir.mkdirs()

            val loader = DexClassLoader(
                cacheFile.absolutePath,
                dexDir.absolutePath,
                null,
                ModPageLoader::class.java.classLoader,
            )
            val clazz = loader.loadClass(className)
            val instance = clazz.getDeclaredConstructor().newInstance()
            val entry = ModPageEntry(loader, cacheFile, dexDir, clazz, instance)
            entries[jarPath] = entry
            entry
        }
    }

    @Synchronized
    fun release(jarPath: String) {
        val entry = entries.remove(jarPath) ?: return
        runCatching {
            entry.cacheFile.delete()
            entry.dexDir.deleteRecursively()
        }
    }
}
