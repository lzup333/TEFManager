package eternal.future.tefmanager.utils.modpack

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import eternal.future.tefmanager.Platform
import eternal.future.tefmanager.model.ModPackManifest
import eternal.future.tefmanager.strings.StringsResource
import eternal.future.tefmanager.utils.AppLogger
import eternal.future.tefmanager.utils.addon.AddonManager
import eternal.future.tefmanager.utils.addon.ModLoaderManager
import eternal.future.tefmanager.utils.addon.ModuleManager
import eternal.future.tefmanager.utils.addon.PluginManager
import kotlinx.serialization.json.Json
import okio.FileSystem
import okio.Path
import okio.SYSTEM
import okio.buffer
import kotlin.time.Clock

/*******************************************************************************
 * TEFManager - ModPackStore
 *
 * 整合包（容器）持久化：
 *   <data>/modpacks/<id>/ModPack.json
 *   <data>/modpacks/<id>/icon
 *   <data>/modpacks/<id>/pack.zip   每个容器保留自己那份原始包
 *   <data>/modpacks/<id>/initial    （标记初始容器）
 *******************************************************************************/

object ModPackStore {

    data class InstalledModPack(
        val id: String,
        val manifest: ModPackManifest,
        val iconPath: Path?,
        val zipPath: Path?,
        val initial: Boolean = false
    )

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        prettyPrint = true
    }

    private val root: Path get() = Platform.getData("modpacks")

    val packs = mutableStateListOf<InstalledModPack>()

    /** 当前生效的容器 id（单选）。 */
    var activeId by mutableStateOf<String?>(null)
        private set

    fun setActive(id: String?) {
        activeId = id
        runCatching {
            val f = root / "active.txt"
            if (id == null) {
                if (FileSystem.SYSTEM.exists(f)) FileSystem.SYSTEM.delete(f)
            } else {
                FileSystem.SYSTEM.createDirectories(root)
                FileSystem.SYSTEM.sink(f).buffer().use {
                    it.writeUtf8(id)
                    it.flush()
                }
            }
        }
    }

    fun refresh() {
        packs.clear()
        if (!FileSystem.SYSTEM.exists(root)) return
        runCatching {
            FileSystem.SYSTEM.list(root).forEach { dir ->
                val manifestFile = dir / "ModPack.json"
                if (FileSystem.SYSTEM.exists(manifestFile)) {
                    val text = FileSystem.SYSTEM.source(manifestFile).buffer().use { it.readUtf8() }
                    val manifest = json.decodeFromString(ModPackManifest.serializer(), text)
                    val icon = dir / "icon"
                    val zip = dir / "pack.zip"
                    packs.add(
                        InstalledModPack(
                            id = dir.name,
                            manifest = manifest,
                            iconPath = if (FileSystem.SYSTEM.exists(icon)) icon else null,
                            zipPath = if (FileSystem.SYSTEM.exists(zip)) zip else null,
                            initial = FileSystem.SYSTEM.exists(dir / "initial")
                        )
                    )
                }
            }
            // 初始容器排在最前，其余按创建时间倒序
            val sorted = packs.sortedWith(
                compareByDescending<InstalledModPack> { it.initial }
                    .thenByDescending { it.manifest.createdAt }
            )
            packs.clear()
            packs.addAll(sorted)

            activeId = runCatching {
                val f = root / "active.txt"
                if (FileSystem.SYSTEM.exists(f)) {
                    FileSystem.SYSTEM.source(f).buffer().use { it.readUtf8() }.trim().ifBlank { null }
                } else {
                    null
                }
            }.getOrNull()
        }.onFailure { AppLogger.e("ModPackStore.refresh failed", it) }
    }

    /** 保证存在一个「默认容器」（尚未导入任何容器时的存储快照）。 */
    suspend fun ensureInitialContainer() {
        refresh()
        val existing = packs.firstOrNull { it.initial }
        if (existing != null) {
            // 默认容器始终作为基线；没有记录时把它设为当前生效容器
            if (activeId == null) setActive(existing.id)
            return
        }

        val name = StringsResource.Strings.manager.modpack.initial
        val tmp = Platform.getDirectory("tmp") / "initial_container.zip"
        runCatching { if (FileSystem.SYSTEM.exists(tmp)) FileSystem.SYSTEM.delete(tmp) }

        val exportResult = ModPackManager.export(
            destZip = tmp,
            name = name
        )

        var saved: InstalledModPack? = null
        if (exportResult.isSuccess) {
            val manifest = ModPackManager.readManifest(tmp)
            if (manifest != null) saved = savePack(manifest, null, tmp, initial = true)
        } else {
            // 当前存储为空：创建一个空容器
            val manifest = ModPackManifest(
                name = name,
                createdAt = Clock.System.now().toEpochMilliseconds()
            )
            val items = listOf(
                ZipWriteItem.Bytes(
                    "ModPack.json",
                    json.encodeToString(ModPackManifest.serializer(), manifest).toByteArray()
                )
            )
            if (writeZipFile(tmp, items)) saved = savePack(manifest, null, tmp, initial = true)
        }

        saved?.let { setActive(it.id) }
        runCatching { if (FileSystem.SYSTEM.exists(tmp)) FileSystem.SYSTEM.delete(tmp) }
    }

    /**
     * 把当前存储保存回“当前生效容器”（切换前的提交）。
     * 这样在默认容器里手动装的 Mod，切走再切回来仍然存在。
     */
    suspend fun saveCurrentIntoActive(): Boolean {
        val id = activeId ?: return false
        val pack = find(id) ?: return false
        val tmp = Platform.getDirectory("tmp") / "container_save_active.zip"
        runCatching { if (FileSystem.SYSTEM.exists(tmp)) FileSystem.SYSTEM.delete(tmp) }
        return try {
            val result = ModPackManager.export(tmp, name = pack.manifest.name, author = pack.manifest.author)
            if (result.isFailure) return false

            val fresh = ModPackManager.readManifest(tmp) ?: return false
            // 保持原 id/名称/创建时间
            val merged = fresh.copy(
                name = pack.manifest.name,
                author = pack.manifest.author,
                createdAt = pack.manifest.createdAt
            )
            val dir = root / id
            FileSystem.SYSTEM.sink(dir / "ModPack.json").buffer().use {
                it.writeUtf8(json.encodeToString(ModPackManifest.serializer(), merged))
                it.flush()
            }
            FileSystem.SYSTEM.copy(tmp, dir / "pack.zip")
            FileSystem.SYSTEM.delete(tmp)
            refresh()
            true
        } catch (e: Exception) {
            AppLogger.e("ModPackStore.saveCurrentIntoActive failed", e)
            false
        }
    }

    fun savePack(
        manifest: ModPackManifest,
        iconFile: Path?,
        sourceZip: Path,
        initial: Boolean = false
    ): InstalledModPack? {
        return try {
            val id = buildId(manifest.name, manifest.createdAt)
            val dir = root / id
            FileSystem.SYSTEM.createDirectories(dir)

            FileSystem.SYSTEM.sink(dir / "ModPack.json").buffer().use {
                it.writeUtf8(json.encodeToString(ModPackManifest.serializer(), manifest))
                it.flush()
            }
            if (iconFile != null && FileSystem.SYSTEM.exists(iconFile)) {
                FileSystem.SYSTEM.copy(iconFile, dir / "icon")
            }
            FileSystem.SYSTEM.copy(sourceZip, dir / "pack.zip")
            if (initial) {
                FileSystem.SYSTEM.sink(dir / "initial").buffer().use {
                    it.writeUtf8("1")
                    it.flush()
                }
            }

            refresh()
            packs.firstOrNull { it.id == id }
        } catch (e: Exception) {
            AppLogger.e("ModPackStore.savePack failed", e)
            null
        }
    }

    /** 应用该整合包快照（覆盖并切换当前 Mod/Loader/内核）。 */
    suspend fun applyPack(id: String, onProgress: (String) -> Unit = {}): Result<Int> {
        val pack = find(id) ?: return Result.failure(IllegalStateException("NOT_FOUND"))
        val zip = pack.zipPath ?: return Result.failure(IllegalStateException("NO_PACKAGE"))
        // 切换前把当前存储提交回当前生效容器
        if (activeId != null && activeId != id) saveCurrentIntoActive()
        val result = ModPackManager.applyZip(zip, onProgress)
        if (result.isSuccess) setActive(id)
        return result
    }

    /**
     * 删除容器（彻底）：若为当前生效容器，先卸载当前 Mod/Loader，再删除容器记录。
     * 初始容器不可删除。
     */
    suspend fun deletePack(id: String): Boolean {
        val pack = find(id) ?: return false
        if (pack.initial) return false

        if (activeId == id) {
            uninstallAll()
            setActive(null)
            ModLoaderManager.reload()
            ModuleManager.reload()
            PluginManager.reload()
        }

        runCatching {
            val dir = root / id
            if (FileSystem.SYSTEM.exists(dir)) FileSystem.SYSTEM.deleteRecursively(dir)
        }
        refresh()
        return true
    }

    private suspend fun uninstallAll() {
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

    fun find(id: String): InstalledModPack? = packs.firstOrNull { it.id == id }

    private fun buildId(name: String, createdAt: Long): String {
        val safe = name.replace(Regex("[^a-zA-Z0-9._\\-\\u4e00-\\u9fa5]"), "_").take(40)
        return "${safe}_$createdAt"
    }
}
