package eternal.future.tefmanager.utils.modpack

import eternal.future.tefmanager.ConfigurationState
import eternal.future.tefmanager.Platform
import eternal.future.tefmanager.model.ModItem
import eternal.future.tefmanager.model.ModLoaderItem
import eternal.future.tefmanager.model.ModPackEntry
import eternal.future.tefmanager.model.ModPackManifest
import eternal.future.tefmanager.utils.AppLogger
import eternal.future.tefmanager.utils.addon.AddonManager
import eternal.future.tefmanager.utils.addon.ModLoaderManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.IO
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
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
 * 整合包 = 存储容器/镜像：封装自己的一套 Mod / Loader / 内核。
 *  - 导出：基于主文件 + 元数据 + 图标重新组装可安装包
 *  - 导入：保存该容器，并“覆盖并切换”当前存储（先自动备份）
 *  - 应用：随时从已保存容器切回其内容（同一 Mod 的不同版本可分别存在于不同容器）
 *******************************************************************************/

object ModPackManager {
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        prettyPrint = true
        isLenient = true
    }

    private data class Built(val entry: ModPackEntry, val packagePath: Path)

    /** 判断选中的文件是普通附加包还是整合包。 */
    fun isModPack(path: Path): Boolean = try {
        ZipFile(FileSystem.SYSTEM.openReadOnly(path)).use {
            it.getEntry("ModPack.json") != null
        }
    } catch (e: Exception) {
        false
    }

    // ================================ 导出 ================================

    suspend fun export(
        destZip: Path,
        name: String,
        author: String = "",
        iconSource: Path? = null,
        includeLoaders: Boolean = true,
        includeKernel: Boolean = true,
        onProgress: (String) -> Unit = {}
    ): Result<Int> = withContext(Dispatchers.IO) {
        try {
            val tmp = Platform.getDirectory("tmp") / "modpack_export"
            FileSystem.SYSTEM.deleteRecursively(tmp)
            val packagesDir = tmp / "packages"
            FileSystem.SYSTEM.createDirectories(packagesDir)

            val built = mutableListOf<Built>()

            // ModLoader（可选）
            if (includeLoaders) {
                ModLoaderManager.packs.forEach { loader ->
                    onProgress(loader.name)
                    buildPackage(
                        packagesDir = packagesDir,
                        type = "modloader",
                        pkgId = loader.pkgId,
                        name = loader.name,
                        version = loader.version,
                        parentLoader = null,
                        mainFile = Platform.getData("modloader") / "pkg" / "${loader.pkgId}.tefpkg",
                        iconFile = Platform.getData("modloader") / "icons" / "${loader.pkgId}.icon",
                        infoJson = json.encodeToString(ModLoaderItem.serializer(), loader),
                        enabled = ModLoaderManager.isEnabled(loader.pkgId)
                    )?.let { built += it }
                }
            }

            // TEFKernel（可选）
            var kernelEntry: String? = null
            if (includeKernel) {
                val kernelDir = Platform.getData("tefkernel")
                val libs = runCatching { FileSystem.SYSTEM.list(kernelDir) }
                    .getOrDefault(emptyList())
                    .filter { it.name.startsWith("libtefkernel.") }
                if (libs.isNotEmpty()) {
                    onProgress("TEFKernel")
                    val info = buildJsonObject {
                        put("version", ConfigurationState.kernelVersion)
                        put("versionCode", 0)
                    }
                    val kernelZip = packagesDir / "tefkernel.zip"
                    val kernelItems = mutableListOf<ZipWriteItem>(
                        ZipWriteItem.Bytes("info.json", info.toString().toByteArray())
                    )
                    libs.forEach { kernelItems += ZipWriteItem.FileCopy(it.name, it) }
                    if (writeZipFile(kernelZip, kernelItems)) {
                        kernelEntry = "packages/tefkernel.zip"
                    }
                }
            }

            // Mods（遍历所有已安装 Loader，允许一个整合包包含多个 Loader 的 Mod）
            ModLoaderManager.packs.forEach { loader ->
                val manager = AddonManager.getOrCreateModManager(loader.pkgId, autoCreate = true)
                manager?.packs?.forEach { mod ->
                    onProgress(mod.name)
                    buildPackage(
                        packagesDir = packagesDir,
                        type = "mod",
                        pkgId = mod.pkgId,
                        name = mod.name,
                        version = mod.version,
                        parentLoader = loader.pkgId,
                        mainFile = Platform.getData("mods") / loader.pkgId / "mod" / mod.pkgId,
                        iconFile = manager.getIconFilePath(mod.pkgId),
                        infoJson = json.encodeToString(ModItem.serializer(), mod),
                        enabled = manager.isEnabled(mod.pkgId)
                    )?.let { built += it }
                }
            }

            if (built.isEmpty()) {
                FileSystem.SYSTEM.deleteRecursively(tmp)
                return@withContext Result.failure(IllegalStateException("EMPTY"))
            }

            val manifest = ModPackManifest(
                name = name,
                author = author,
                createdAt = Clock.System.now().toEpochMilliseconds(),
                iconEntry = if (iconSource != null && FileSystem.SYSTEM.exists(iconSource)) "icon.png" else null,
                kernelEntry = kernelEntry,
                kernelVersion = if (kernelEntry != null) ConfigurationState.kernelVersion else null,
                entries = built.map { it.entry }
            )

            val items = mutableListOf<ZipWriteItem>()
            items += ZipWriteItem.Bytes(
                "ModPack.json",
                json.encodeToString(ModPackManifest.serializer(), manifest).toByteArray()
            )
            if (iconSource != null && FileSystem.SYSTEM.exists(iconSource)) {
                items += ZipWriteItem.FileCopy("icon.png", iconSource)
            }
            kernelEntry?.let {
                items += ZipWriteItem.FileCopy(it, packagesDir / "tefkernel.zip")
            }
            built.forEach { items += ZipWriteItem.FileCopy(it.entry.packageEntry, it.packagePath) }

            val ok = writeZipFile(destZip, items)
            FileSystem.SYSTEM.deleteRecursively(tmp)
            if (!ok) Result.failure(IllegalStateException("WRITE_FAILED")) else Result.success(built.size)
        } catch (e: Exception) {
            AppLogger.e("ModPack export failed", e)
            Result.failure(e)
        }
    }

    private fun buildPackage(
        packagesDir: Path,
        type: String,
        pkgId: String,
        name: String,
        version: String,
        parentLoader: String?,
        mainFile: Path,
        iconFile: Path,
        infoJson: String,
        enabled: Boolean
    ): Built? {
        if (!FileSystem.SYSTEM.exists(mainFile)) {
            AppLogger.w("ModPack: main file missing for $pkgId: $mainFile")
            return null
        }

        val hasIcon = FileSystem.SYSTEM.exists(iconFile)
        val manifest = buildJsonObject {
            put("type", type)
            put("file", "file")
            if (parentLoader != null) put("parentLoader", parentLoader)
            if (hasIcon) put("iconFile", "icon.png")
        }

        val fileName = "${type}_${pkgId}.zip"
        val packagePath = packagesDir / fileName
        val items = mutableListOf<ZipWriteItem>(
            ZipWriteItem.Bytes("Manifest.json", manifest.toString().toByteArray()),
            ZipWriteItem.Bytes("Info.json", infoJson.toByteArray()),
            ZipWriteItem.FileCopy("file", mainFile)
        )
        if (hasIcon) items += ZipWriteItem.FileCopy("icon.png", iconFile)

        if (!writeZipFile(packagePath, items)) return null

        return Built(
            ModPackEntry(
                type = type,
                pkgId = pkgId,
                name = name,
                version = version,
                parentLoader = parentLoader,
                packageEntry = "packages/$fileName",
                enabled = enabled
            ),
            packagePath
        )
    }

    // ================================ 导入 / 应用 ================================

    fun readManifest(zipPath: Path): ModPackManifest? = try {
        ZipFile(FileSystem.SYSTEM.openReadOnly(zipPath)).use { zip ->
            val entry = zip.getEntry("ModPack.json") ?: return null
            val text = zip.getInputStream(entry).bufferedReader().use { it.readText() }
            json.decodeFromString(ModPackManifest.serializer(), text)
        }
    } catch (e: Exception) {
        AppLogger.e("ModPack: read manifest failed", e)
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

    /** 应用容器：备份当前存储 → 清空当前 Mod/Loader → 安装容器内容。 */
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

            // 1) 自动备份当前存储（Mod / Loader / 内核 等）
            onProgress("备份当前存储")
            ModPackBackup.backupNow("before_${manifest.name}")

            // 2) 清空当前 Mod / Loader（实现“切换存储”）
            onProgress("清理当前 Mod / Loader")
            clearCurrent()

            // 3) 安装内核
            manifest.kernelEntry?.let { ke ->
                val kernelPath = tmp / ke
                if (FileSystem.SYSTEM.exists(kernelPath)) {
                    onProgress("TEFKernel")
                    runCatching { AddonManager.installKernel(kernelPath) }
                }
            }

            // 4) 安装 Loader / Mod
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
                    AppLogger.e("ModPack: failed to install ${entry.pkgId}", e)
                }
            }

            FileSystem.SYSTEM.deleteRecursively(tmp)
            Result.success(ok)
        } catch (e: Exception) {
            AppLogger.e("ModPack apply failed", e)
            Result.failure(e)
        }
    }

    private fun manifestFileText(path: Path): String =
        FileSystem.SYSTEM.source(path).buffer().use { it.readUtf8() }

    private suspend fun clearCurrent() {
        // 先删除所有 Mod
        AddonManager.modManagersList.toMap().forEach { (_, manager) ->
            manager.packs.toList().forEach { mod ->
                runCatching { manager.delete(mod.pkgId) }
            }
        }
        AddonManager.modManagersList.keys.toList().forEach {
            runCatching { AddonManager.closeModManager(it) }
        }
        // 再删除所有 Loader
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
