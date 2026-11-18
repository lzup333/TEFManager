package eternal.future.tefmanager.utils

import android.content.Context
import com.android.apksig.ApkSigner
import com.android.apksig.KeyConfig
import org.bouncycastle.jce.provider.BouncyCastleProvider
import java.io.File
import java.security.KeyStore
import java.security.PrivateKey
import java.security.Security
import java.security.cert.X509Certificate

/**
 * Signs the patched APK with the same certificate as the official TEFManager
 * build (BKS keystore in assets).
 */
class ApkSigner(private val context: Context) {

    companion object {
        private const val STORE_PASSWORD = "EternalFuture@2026"
        private const val KEY_ALIAS = "TEFManager"
        private const val KEY_PASSWORD = "EternalFuture@2026"
        private const val KEYSTORE_FILE = "tefmanager.bks"

        init {
            if (Security.getProvider(BouncyCastleProvider.PROVIDER_NAME) == null) {
                Security.addProvider(BouncyCastleProvider())
            }
        }
    }

    fun signApkInPlace(apkFile: File): Boolean {
        return try {
            val tempFile = File.createTempFile("temp_signed", ".apk", apkFile.parentFile)
            val success = signApk(apkFile, tempFile)
            if (success) {
                if (apkFile.delete() && tempFile.renameTo(apkFile)) {
                    true
                } else {
                    tempFile.delete()
                    false
                }
            } else {
                tempFile.delete()
                false
            }
        } catch (e: Exception) {
            AppLogger.e("Sign apk failed: ${e.message}", e)
            false
        }
    }

    fun signApk(inputApk: File, outputApk: File): Boolean {
        return try {
            val keyStore = loadBksKeyStore()
            val privateKey =
                keyStore.getKey(KEY_ALIAS, KEY_PASSWORD.toCharArray()) as PrivateKey
            val certificateChain = keyStore.getCertificateChain(KEY_ALIAS)
                .map { it as X509Certificate }
                .toTypedArray()

            val signerConfig = ApkSigner.SignerConfig.Builder(
                KEY_ALIAS,
                KeyConfig.Jca(privateKey),
                certificateChain.asList(),
            ).build()

            ApkSigner.Builder(listOf(signerConfig))
                .setInputApk(inputApk)
                .setOutputApk(outputApk)
                .setV1SigningEnabled(false)
                .setV2SigningEnabled(true)
                .setV3SigningEnabled(false)
                .setMinSdkVersion(24)
                .build()
                .sign()
            true
        } catch (e: Exception) {
            AppLogger.e("Sign apk failed: ${e.message}", e)
            false
        }
    }

    private fun loadBksKeyStore(): KeyStore {
        val keyStore = KeyStore.getInstance("BKS")
        context.assets.open(KEYSTORE_FILE).use { input ->
            keyStore.load(input, STORE_PASSWORD.toCharArray())
        }
        return keyStore
    }
}
