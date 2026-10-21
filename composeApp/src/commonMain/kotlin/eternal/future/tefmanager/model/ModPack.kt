package eternal.future.tefmanager.model

import kotlinx.serialization.Serializable

/*******************************************************************************
 * TEFManager - ModPack
 *
 * 整合包（ModPack）清单。整合包本身是一个 zip：
 *   ModPack.json          本清单
 *   icon.png              （可选）整合包图标
 *   packages/<id>.zip     由已安装项重新组装的可安装包
 *******************************************************************************/

@Serializable
data class ModPackManifest(
    val name: String = "ModPack",
    val author: String = "",
    val version: String = "1.0.0",
    val createdAt: Long = 0L,
    val iconEntry: String? = null,
    val kernelEntry: String? = null,
    val kernelVersion: String? = null,
    val entries: List<ModPackEntry> = emptyList()
)

@Serializable
data class ModPackEntry(
    val type: String,          // modloader / module / plugin / mod
    val pkgId: String,
    val name: String,
    val version: String,
    val parentLoader: String? = null,
    val packageEntry: String,
    val enabled: Boolean = false
)
