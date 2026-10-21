package eternal.future.tefmanager.utils.modpack

import eternal.future.tefmanager.Platform
import eternal.future.tefmanager.model.ModItem
import eternal.future.tefmanager.model.ModLoaderItem
import eternal.future.tefmanager.model.ModPackManifest
import eternal.future.tefmanager.utils.AppLogger
import eternal.future.tefmanager.utils.addon.AddonManager
import eternal.future.tefmanager.utils.addon.ModLoaderManager
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
 *  - 导入/应用：备份当前存储 → 还原整目录 → 提示重启生效
 * 兼容旧的按包安装格式（Manifest 中 fullSnapshot=false）。
 *******************************************************************************/

object ModPackManager {
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        prettyPrint = true
        isLenient = true
    }

    /** 整目录快照包含的目录。 */
    private val snapshotDirs = listOf("mods", "modloader", "module", "plugin", "tefkernel")

    /** 判断选中的文件是普通附加包还是容器。 */
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

            // 应用配置
            val config = Platform.getData(null) / "app_config.json"
            if (FileSystem.SYSTEM.exists(config)) {
                items += ZipWriteItem.FileCopy("app_config.json", config)
                count++
            }

            if (count == 0) {
                return@withContext Result.failure(IllegalStateException("EMPTY"))
            }

            val manifest = ModPackManifest(
                name = name,
                author = author,
                createdAt = Clock.System.now().toEpochMilliseconds(),
                iconEntry = if (iconSource != null && FileSystem.SYSTEM.exists(iconSource)) "icon.png" else null,
                fullSnapshot = true,
                entries = emptyList()
            )

            items += ZipWriteItem.Bytes(
                "ModPack.json",
                json.encodeToString(ModPackManifest.serializer(), manifest).toByteArray()
            )
            if (iconSource != null && FileSystem.SYSTEM.exists(iconSource)) {
                items += ZipWriteItem.FileCopy("icon.png", iconSource)
            }

            val ok = writeZipFile(destZip, items) { done, total ->
                onProgress("$done/$total")
            }
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

    /** 导入：保存该容器并立即切换过去。 */
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

        applyZip(zipPath, onProgress)
    }

    /** 应用容器：备份当前存储 → 还原容器内容。 */
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

            // 自动备份当前存储
            onProgress("备份当前存储")
            ModPackBackup.backupNow("before_${manifest.name}")

            val result = if (manifest.fullSnapshot) {
                applyFullSnapshot(manifest, tmp, onProgress)
            } else {
                applyLegacy(manifest, tmp, onProgress)
            }

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

        // 关闭已打开的 Mod 数据库，避免覆盖时冲突
        AddonManager.modManagersList.keys.toList().forEach {
            runCatching { AddonManager.closeModManager(it) }
        }

        onProgress("清理当前存储")
        snapshotDirs.forEach { root ->
            val dir = Platform.getData(root)
            runCatching { if (fs.exists(dir)) fs.deleteRecursively(dir) }
        }
        val config = Platform.getData(null) / "app_config.json"
        runCatching { if (fs.exists(config)) fs.delete(config) }

        var count = 0
        snapshotDirs.forEach { root ->
            val src = tmp / root
            if (fs.exists(src)) {
                onProgress(root)
                copyDirectory(src, Platform.getData(root))
                count++
            }
        }
        val configSrc = tmp / "app_config.json"
        if (fs.exists(configSrc)) {
            val configDst = Platform.getData(null) / "app_config.json"
            runCatching {
                configDst.parent?.let { fs.createDirectories(it) }
                fs.copy(configSrc, configDst)
            }
            count++
        }

        return Result.success(count)
    }

    /** 兼容旧的按包安装格式。 */
    private suspend fun applyLegacy(
        manifest: ModPackManifest,
        tmp: Path,
        onProgress: (String) -> Unit
    ): Result<Int> {
        onProgress("清理当前 Mod / Loader")
        clearCurrent()

        manifest.kernelEntry?.let { ke ->
            val kernelPath = tmp / ke
            if (FileSystem.SYSTEM.exists(kernelPath)) {
                onProgress("TEFKernel")
                runCatching { AddonManager.installKernel(kernelPath) }
            }
        }

        val ordered = manifest.entries.sortedBy { typeOrder(it.type) }
        var ok = 0
        ordered.forEach { entry ->
            val pkg = tmp / entry.packageEntry
            if (!FileSystem.SYSTEM.exists(pkg)) return@forEach
            try {
                onProgress(entry.name)
                AddonManager.install(pkg)
                if (entry.enabled) {
                    runCatching {
                        when (entry.type) {
                            "modloader" -> ModLoaderManager.enable(entry.pkgId)
                            "mod" -> entry.parentLoader?.let {
                                AddonManager.getOrCreateModManager(it, true)?.enable(entry.pkgId)
                            }
                        }
                    }
                }
                ok++
            } catch (e: Exception) {
                AppLogger.e("Container: failed to install ${entry.pkgId}", e)
            }
        }
        return Result.success(ok)
    }

    private fun manifestFileText(path: Path): String =
        FileSystem.SYSTEM.source(path).buffer().use { it.readUtf8() }

    private suspend fun clearCurrent() {
        AddonManager.modManagersList.toMap().forEach { (_, manager) ->
            manager.packs.toList().forEach { mod ->
                runCatching { manager.delete(mod.pkgId) }
            }
        }
        AddonManager.modManagersList.keys.toList().forEach {
            runCatching { AddonManager.closeModManager(it) }
        }
        ModLoaderManager.packs.toList().forEach { loader ->
            runCatching { ModLoaderManager.delete(loader.pkgId) }
        }
    }

    private fun typeOrder(type: String): Int = when (type) {
        "modloader" -> 0
        "module" -> 1
        "plugin" -> 2
        "mod" -> 3
        else -> 9
    }
}
