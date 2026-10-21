package eternal.future.tefmanager.utils.modpack

import eternal.future.tefmanager.ConfigurationState
import eternal.future.tefmanager.Platform
import eternal.future.tefmanager.model.ModPackManifest
import eternal.future.tefmanager.utils.AppLogger
import eternal.future.tefmanager.utils.addon.AddonManager
import eternal.future.tefmanager.utils.addon.ModLoaderManager
import eternal.future.tefmanager.utils.addon.ModuleManager
import eternal.future.tefmanager.utils.addon.PluginManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.IO
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import no.synth.kmpzip.okio.ZipFile
import okio.FileSystem
import okio.Path
import okio.SYSTEM
import okio.buffer
import okio.source
import okio.use
import kotlin.time.Clock

/*******************************************************************************
 * TEFManager - ModPackManager
 *
 * 容器 = 整目录快照：包含材质/资源包、配置、Mod、Loader、内核。
 *  - 导出：把整个存储目录打包
 *  - 导入/应用：备份当前存储 → 还原整目录 → 热重载管理器（免重启）
 *******************************************************************************/

object ModPackManager {
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        prettyPrint = true
        isLenient = true
    }

    private val snapshotDirs = listOf("mods", "modloader", "module", "plugin", "tefkernel")

    fun isModPack(path: Path): Boolean = try {
        ZipFile(FileSystem.SYSTEM.openReadOnly(path)).use {
            it.getEntry("ModPack.json") != null
        }
    } catch (e: Exception) {
        false
    }

    // ================================ 导出（整目录） ================================

    suspend fun export(
        destZip: Path,
        name: String,
        author: String = "",
        iconSource: Path? = null,
        onProgress: (String) -> Unit = {}
    ): Result<Int> = withContext(Dispatchers.IO) {
        try {
            val items = mutableListOf<ZipWriteItem>()
            var count = 0

            snapshotDirs.forEach { root ->
                val dir = Platform.getData(root)
                if (FileSystem.SYSTEM.exists(dir)) {
                    count += addDirectoryToZip(dir, root, items)
                }
            }

            if (count == 0) {
                return@withContext Result.failure(IllegalStateException("EMPTY"))
            }

            val manifest = ModPackManifest(
                name = name,
                author = author,
                createdAt = Clock.System.now().toEpochMilliseconds(),
                kernelVersion = ConfigurationState.kernelVersion,
                fileCount = count
            )

            items += ZipWriteItem.Bytes(
                "ModPack.json",
                json.encodeToString(ModPackManifest.serializer(), manifest).toByteArray()
            )
            if (iconSource != null && FileSystem.SYSTEM.exists(iconSource)) {
                items += ZipWriteItem.FileCopy("icon.png", iconSource)
            }

            val ok = writeZipFile(destZip, items) { done, total -> onProgress("$done/$total") }
            if (!ok) Result.failure(IllegalStateException("WRITE_FAILED")) else Result.success(count)
        } catch (e: Exception) {
            AppLogger.e("Container export failed", e)
            Result.failure(e)
        }
    }

    private fun addDirectoryToZip(dir: Path, prefix: String, out: MutableList<ZipWriteItem>): Int {
        val fs = FileSystem.SYSTEM
        if (!fs.exists(dir)) return 0
        var count = 0
        fs.list(dir).forEach { child ->
            val meta = runCatching { fs.metadata(child) }.getOrNull() ?: return@forEach
            if (meta.isDirectory) {
                count += addDirectoryToZip(child, "$prefix/${child.name}", out)
            } else {
                out += ZipWriteItem.FileCopy("$prefix/${child.name}", child)
                count++
            }
        }
        return count
    }

    private fun copyDirectory(src: Path, dst: Path) {
        val fs = FileSystem.SYSTEM
        if (!fs.exists(src)) return
        fs.createDirectories(dst)
        fs.list(src).forEach { child ->
            val target = dst / child.name
            val meta = runCatching { fs.metadata(child) }.getOrNull() ?: return@forEach
            if (meta.isDirectory) {
                copyDirectory(child, target)
            } else {
                target.parent?.let { fs.createDirectories(it) }
                fs.copy(child, target)
            }
        }
    }

    // ================================ 导入 / 应用 ================================

    fun readManifest(zipPath: Path): ModPackManifest? = try {
        ZipFile(FileSystem.SYSTEM.openReadOnly(zipPath)).use { zip ->
            val entry = zip.getEntry("ModPack.json") ?: return null
            val text = zip.getInputStream(entry).bufferedReader().use { it.readText() }
            json.decodeFromString(ModPackManifest.serializer(), text)
        }
    } catch (e: Exception) {
        AppLogger.e("Container: read manifest failed", e)
        null
    }

    private fun extractEntry(zipPath: Path, entryName: String, out: Path): Boolean = try {
        ZipFile(FileSystem.SYSTEM.openReadOnly(zipPath)).use { zip ->
            val entry = zip.getEntry(entryName) ?: return false
            out.parent?.let { FileSystem.SYSTEM.createDirectories(it) }
            FileSystem.SYSTEM.sink(out).buffer().use { sink ->
                zip.getInputStream(entry).source().buffer().use { src ->
                    sink.writeAll(src)
                }
            }
            true
        }
    } catch (e: Exception) {
        false
    }

    suspend fun import(
        zipPath: Path,
        onProgress: (String) -> Unit = {}
    ): Result<Int> = withContext(Dispatchers.IO) {
        val manifest = readManifest(zipPath)
            ?: return@withContext Result.failure(IllegalStateException("NO_MANIFEST"))

        val iconTmp = Platform.getDirectory("tmp") / "modpack_icon.png"
        runCatching { FileSystem.SYSTEM.delete(iconTmp) }
        val hasIcon = extractEntry(zipPath, "icon.png", iconTmp)

        val saved = ModPackStore.savePack(
            manifest = manifest,
            iconFile = if (hasIcon) iconTmp else null,
            sourceZip = zipPath
        )
        runCatching { FileSystem.SYSTEM.delete(iconTmp) }

        if (saved == null) {
            return@withContext Result.failure(IllegalStateException("SAVE_FAILED"))
        }

        // 切换前把当前存储提交回当前生效容器
        ModPackStore.saveCurrentIntoActive()

        val result = applyZip(zipPath, onProgress)
        if (result.isSuccess) ModPackStore.setActive(saved.id)
        result
    }

    suspend fun applyZip(
        zipPath: Path,
        onProgress: (String) -> Unit = {}
    ): Result<Int> = withContext(Dispatchers.IO) {
        try {
            val tmp = Platform.getDirectory("tmp") / "modpack_apply"
            FileSystem.SYSTEM.deleteRecursively(tmp)
            if (!extractZipFile(zipPath, tmp)) {
                return@withContext Result.failure(IllegalStateException("EXTRACT_FAILED"))
            }

            val manifestFile = tmp / "ModPack.json"
            if (!FileSystem.SYSTEM.exists(manifestFile)) {
                FileSystem.SYSTEM.deleteRecursively(tmp)
                return@withContext Result.failure(IllegalStateException("NO_MANIFEST"))
            }
            val manifest = json.decodeFromString(ModPackManifest.serializer(), manifestFileText(manifestFile))

            onProgress("备份当前存储")
            ModPackBackup.backupNow("before_${manifest.name}")

            val result = applyFullSnapshot(manifest, tmp, onProgress)

            FileSystem.SYSTEM.deleteRecursively(tmp)
            result
        } catch (e: Exception) {
            AppLogger.e("Container apply failed", e)
            Result.failure(e)
        }
    }

    private fun applyFullSnapshot(
        manifest: ModPackManifest,
        tmp: Path,
        onProgress: (String) -> Unit
    ): Result<Int> {
        val fs = FileSystem.SYSTEM

        AddonManager.modManagersList.keys.toList().forEach {
            runCatching { AddonManager.closeModManager(it) }
        }

        onProgress("清理当前存储")
        snapshotDirs.forEach { root ->
            val dir = Platform.getData(root)
            runCatching { if (fs.exists(dir)) fs.deleteRecursively(dir) }
        }

        var count = 0
        snapshotDirs.forEach { root ->
            val src = tmp / root
            if (fs.exists(src)) {
                onProgress(root)
                copyDirectory(src, Platform.getData(root))
                count++
            }
        }

        // 热重载管理器，免重启生效
        ModuleManager.reload()
        PluginManager.reload()
        ModLoaderManager.reload()
        AddonManager.modManagersList.keys.toList().forEach {
            runCatching { AddonManager.closeModManager(it) }
        }
        AddonManager.refreshModManager(ModLoaderManager.packs)

        manifest.kernelVersion?.let { ConfigurationState.kernelVersion = it }

        return Result.success(count)
    }

    private fun manifestFileText(path: Path): String =
        FileSystem.SYSTEM.source(path).buffer().use { it.readUtf8() }
}
