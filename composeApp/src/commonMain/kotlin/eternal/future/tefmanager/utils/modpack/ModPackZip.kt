package eternal.future.tefmanager.utils.modpack

import okio.Path

/*******************************************************************************
 * TEFManager - ModPackZip
 *
 * 平台相关的 zip 读写（当前仅 Android）。
 *******************************************************************************/

sealed class ZipWriteItem {
    data class Bytes(val entry: String, val bytes: ByteArray) : ZipWriteItem()
    data class FileCopy(val entry: String, val source: Path) : ZipWriteItem()
}

expect fun writeZipFile(zipPath: Path, items: List<ZipWriteItem>): Boolean

expect fun extractZipFile(zipPath: Path, destDir: Path): Boolean
