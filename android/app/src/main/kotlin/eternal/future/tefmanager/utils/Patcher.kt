package eternal.future.tefmanager.utils

import android.content.Context
import com.android.tools.build.apkzlib.zip.ZFile
import com.android.tools.build.apkzlib.zip.ZFileOptions
import com.apk.axml.aXMLDecoder
import com.apk.axml.aXMLEncoder
import com.wind.meditor.core.ManifestEditor
import com.wind.meditor.property.AttributeItem
import com.wind.meditor.property.ModificationProperty
import org.w3c.dom.Document
import org.w3c.dom.Element
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.InputStream
import java.io.StringWriter
import javax.xml.parsers.DocumentBuilderFactory
import javax.xml.transform.OutputKeys
import javax.xml.transform.TransformerFactory
import javax.xml.transform.dom.DOMSource
import javax.xml.transform.stream.StreamResult

/**
 * Injects TEFLoader into an APK (external / non-root mode) and re-signs it.
 *
 * Direct port of the Kotlin Multiplatform implementation, with progress
 * reported as i18n keys so the Flutter UI can render the same messages.
 */
object Patcher {

    enum class PatchPhase(val key: String) {
        PREPARING("home.patch.progress.preparing"),
        OPENING_APK("home.patch.progress.openApk"),
        UNZIP_DEX("home.patch.progress.unzipDex"),
        READING_MANIFEST("home.patch.progress.readingManifest"),
        MODIFYING_APPLICATION("home.patch.progress.modifyingApplication"),
        MODIFYING_APP_COMPONENT_FACTORY("home.patch.progress.modifyingAppComponentFactory"),
        ADDING_METADATA("home.patch.progress.addingMetadata"),
        ADDING_PROVIDER("home.patch.progress.addingProvider"),
        REPLACING_MANIFEST("home.patch.progress.replacingManifest"),
        ADDING_DEX("home.patch.progress.addingDex"),
        REPACKAGING_APK("home.patch.progress.repackagingApk"),
        SIGNING_APK("home.patch.progress.signingApk"),
        COMPLETED("home.patch.progress.completed"),
        FAILED("home.patch.progress.failed"),
    }

    enum class PatchOption { APPLICATION, APP_COMPONENT_FACTORY }

    /** @return null on success, otherwise an error message. */
    fun patch(
        context: Context,
        apkPath: String,
        option: PatchOption,
        onProgress: (PatchPhase) -> Unit,
    ): String? {
        onProgress(PatchPhase.PREPARING)
        val apkFile = File(apkPath)
        if (!apkFile.exists()) return "APK not found: $apkPath"

        return try {
            ZFile.openReadWrite(apkFile, ZFileOptions()).use { dst ->
                onProgress(PatchPhase.OPENING_APK)
                onProgress(PatchPhase.UNZIP_DEX)
                val dexCount = getDexCount(dst)

                val manifestEntry = dst.get("AndroidManifest.xml")
                    ?: return fail(onProgress, "AndroidManifest.xml not found in APK")

                onProgress(PatchPhase.READING_MANIFEST)
                manifestEntry.open().use { stream ->
                    onProgress(
                        if (option == PatchOption.APPLICATION) {
                            PatchPhase.MODIFYING_APPLICATION
                        } else {
                            PatchPhase.MODIFYING_APP_COMPONENT_FACTORY
                        }
                    )
                    onProgress(PatchPhase.ADDING_METADATA)
                    onProgress(PatchPhase.ADDING_PROVIDER)

                    val manifest = modifyManifest(context, stream, option)
                    onProgress(PatchPhase.REPLACING_MANIFEST)
                    dst.add("AndroidManifest.xml", ByteArrayInputStream(manifest))

                    onProgress(PatchPhase.ADDING_DEX)
                    val dex = context.assets.open("tefloader.dex")
                    dst.add("classes$dexCount.dex", dex)
                }
                onProgress(PatchPhase.REPACKAGING_APK)
            }

            onProgress(PatchPhase.SIGNING_APK)
            if (!ApkSigner(context).signApkInPlace(apkFile)) {
                return fail(onProgress, "Signature failed")
            }
            onProgress(PatchPhase.COMPLETED)
            null
        } catch (e: Exception) {
            AppLogger.e("Patching failed", e)
            onProgress(PatchPhase.FAILED)
            e.toString()
        }
    }

    private fun fail(onProgress: (PatchPhase) -> Unit, message: String): String {
        onProgress(PatchPhase.FAILED)
        return message
    }

    private fun modifyManifest(
        context: Context,
        inputStream: InputStream,
        option: PatchOption,
    ): ByteArray {
        val axml = aXMLDecoder(inputStream).decodeAsString()

        val factory = DocumentBuilderFactory.newInstance().apply { isNamespaceAware = true }
        val document = factory.newDocumentBuilder()
            .parse(ByteArrayInputStream(axml.toByteArray(Charsets.UTF_8)))
        document.documentElement.normalize()

        val property = ModificationProperty()
        addProvider(document)
        property.addApplicationAttribute(
            AttributeItem(
                if (option == PatchOption.APPLICATION) "name" else "appComponentFactory",
                "eternal.future.tefkernel." + if (option == PatchOption.APPLICATION) {
                    "TefLoaderApplication"
                } else {
                    "TefLoaderAppComponentFactory"
                },
            )
        )
        addMetaData(document, "TEFManager-Patch", "true")
        addMetaData(document, "TEFManager-Patch-Version", "1.0.0")

        val transformer = TransformerFactory.newInstance().newTransformer().apply {
            setOutputProperty(OutputKeys.OMIT_XML_DECLARATION, "no")
            setOutputProperty(OutputKeys.METHOD, "xml")
            setOutputProperty(OutputKeys.INDENT, "no")
            setOutputProperty(OutputKeys.ENCODING, "UTF-8")
        }
        val writer = StringWriter()
        transformer.transform(DOMSource(document), StreamResult(writer))

        val encoded = aXMLEncoder().encodeString(writer.toString(), context)
        encoded.inputStream().use { stream ->
            ByteArrayOutputStream().use { out ->
                ManifestEditor(stream, out, property).processManifest()
                return out.toByteArray()
            }
        }
    }

    private fun addMetaData(document: Document, name: String, value: String) {
        val application = document.documentElement
            .getElementsByTagName("application").item(0) as? Element ?: return
        val metaData = document.createElement("meta-data")
        metaData.setAttribute("android:name", name)
        metaData.setAttribute("android:value", value)
        application.appendChild(metaData)
    }

    private fun addProvider(document: Document) {
        val queries = document.createElement("queries")
        val provider = document.createElement("provider")
        provider.setAttribute("android:authorities", "eternal.future.tefkernel.fileprovider")
        queries.appendChild(provider)
        val application = document.documentElement
            .getElementsByTagName("application").item(0) as? Element ?: return
        document.documentElement.insertBefore(queries, application)
    }

    private fun getDexCount(zFile: ZFile): Int =
        zFile.entries().count { entry ->
            val name = entry.centralDirectoryHeader.name
            name.startsWith("classes") && name.endsWith(".dex")
        } + 1
}
