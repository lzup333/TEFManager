package eternal.future.tefmanager.model

import kotlinx.serialization.Serializable

/*******************************************************************************
 * TEFManager - Container (ModPack)
 *
 * 容器清单。容器是一个整目录快照 zip：
 *   ModPack.json    本清单
 *   icon.png        （可选）容器图标
 *   mods/ modloader/ module/ plugin/ tefkernel/ + app_config.json
 *******************************************************************************/

@Serializable
data class ModPackManifest(
    val name: String = "Container",
    val author: String = "",
    val version: String = "1.0.0",
    val createdAt: Long = 0L,
    val kernelVersion: String? = null,
    val fileCount: Int = 0
)
