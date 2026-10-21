package eternal.future.tefmanager.utils.modpack

import eternal.future.tefmanager.utils.AppLogger
import okio.FileSystem
import okio.Path
import okio.Path.Companion.toPath
import okio.SYSTEM
import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

/*******************************************************************************
 * TEFManager - ModPackZip (Android)
 *******************************************************************************/

actual fun writeZipFile(zipPath: Path, items: List<ZipWriteItem>): Boolean {
    return try {
        zipPath.parent?.let { FileSystem.SYSTEM.createDirectories(it) }
        val file = zipPath.toString().let { File(it) }
        file.parentFile?.mkdirs()

        ZipOutputStream(file.outputStream().buffered()).use { zos ->
            items.forEach { item ->
                when (item) {
                    is ZipWriteItem.Bytes -> {
                        zos.putNextEntry(ZipEntry(item.entry))
                        zos.write(item.bytes)
                        zos.closeEntry()
                    }
                    is ZipWriteItem.FileCopy -> {
                        if (FileSystem.SYSTEM.exists(item.source)) {
                            zos.putNextEntry(ZipEntry(item.entry))
                            File(item.source.toString()).inputStream().buffered().use { input ->
                                input.copyTo(zos)
                            }
                            zos.closeEntry()
                        }
                    }
                }
            }
        }
        true
    } catch (e: Exception) {
        AppLogger.e("writeZipFile failed: $zipPath", e)
        false
    }
}

actual fun extractZipFile(zipPath: Path, destDir: Path): Boolean {
    return try {
        FileSystem.SYSTEM.createDirectories(destDir)
        val dest = File(destDir.toString())
        val destCanonical = dest.canonicalPath

        ZipInputStream(File(zipPath.toString()).inputStream().buffered()).use { zis ->
            var entry = zis.nextEntry
            while (entry != null) {
                val name = entry.name
                // 防止 zip slip
                if (!name.contains("..")) {
                    val outFile = File(dest, name)
                    val outCanonical = outFile.canonicalPath
                    if (outCanonical == destCanonical || outCanonical.startsWith(destCanonical + File.separator)) {
                        if (entry.isDirectory) {
                            outFile.mkdirs()
                        } else {
                            outFile.parentFile?.mkdirs()
                            outFile.outputStream().buffered().use { out ->
                                zis.copyTo(out)
                            }
                        }
                    }
                }
                zis.closeEntry()
                entry = zis.nextEntry
            }
        }
        true
    } catch (e: Exception) {
        AppLogger.e("extractZipFile failed: $zipPath", e)
        false
    }
}
