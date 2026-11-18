package eternal.future.tefmanager

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.Locale

/**
 * Android side of the Flutter MethodChannel `eternal.future.tefmanager/native`.
 *
 * The Kotlin Multiplatform version used global singletons; here everything is
 * scoped to the activity and exposed as plain method calls.
 */
class NativeBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val CHANNEL = "eternal.future.tefmanager/native"
        private const val REQ_PICK = 2101
        private const val REQ_SAVE = 2102
        private val TARGET_PACKAGES = listOf(
            "com.and.games505.Terraria",
            "com.and.games505.TerrariaPaid",
        )
        private const val META_DATA_KEY = "TEFManager-Patch"
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())

    private var pendingPick: MethodChannel.Result? = null
    private var pendingSave: MethodChannel.Result? = null
    private var pendingSaveSource: String? = null

    fun attach() {
        channel.setMethodCallHandler(this)
    }

    fun detach() {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "paths" -> result.success(paths())
            "device.info" -> result.success(deviceInfo())
            "game.list" -> result.success(listGames())
            "game.launch" -> launchGame(call.argument<String>("package"), result)
            "module.active" -> result.success(Platform.isAndroidModuleActive)
            "root.hasPermission" -> runAsync(result) { PermissionManager.hasRootPermission(activity) }
            "root.grantAccess" -> runAsync(result) {
                val pkg = call.argument<String>("package")
                if (pkg.isNullOrBlank()) false else PermissionManager.grantReadWriteAccess(activity, pkg)
            }
            "service.start" -> {
                startFileProviderService()
                result.success(true)
            }
            "service.stop" -> {
                activity.stopService(Intent(activity, FileProviderForegroundService::class.java))
                result.success(true)
            }
            "file.pick" -> pickFiles(call, result)
            "file.export" -> exportFile(call, result)
            "url.open" -> {
                val url = call.argument<String>("url")
                if (url.isNullOrBlank()) {
                    result.success(false)
                } else {
                    activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                    result.success(true)
                }
            }
            else -> result.notImplemented()
        }
    }

    // -------------------------------------------------------------------------
    // Paths / device
    // -------------------------------------------------------------------------

    private fun paths(): Map<String, String> = mapOf(
        "externalFiles" to (activity.getExternalFilesDir(null)?.absolutePath ?: activity.filesDir.absolutePath),
        "externalCache" to (activity.externalCacheDir?.absolutePath ?: activity.cacheDir.absolutePath),
        "cache" to activity.cacheDir.absolutePath,
        "files" to activity.filesDir.absolutePath,
    )

    private fun deviceInfo(): Map<String, Any> = mapOf(
        "arch" to Build.SUPPORTED_ABIS.firstOrNull().orEmpty(),
        "sdk" to Build.VERSION.SDK_INT,
        "os" to "Android ${Build.VERSION.RELEASE}",
        "model" to "${Build.MANUFACTURER} ${Build.MODEL}",
        "locale" to Locale.getDefault().toLanguageTag(),
        "dynamicColor" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S),
        "moduleActive" to Platform.isAndroidModuleActive,
    )

    // -------------------------------------------------------------------------
    // Games
    // -------------------------------------------------------------------------

    private fun listGames(): List<Map<String, Any>> {
        val pm = activity.packageManager
        val out = ArrayList<Map<String, Any>>()
        for (pkg in TARGET_PACKAGES) {
            try {
                val info = pm.getPackageInfo(pkg, PackageManager.GET_META_DATA)
                val include = Platform.isAndroidModuleActive ||
                    info.applicationInfo?.metaData?.getBoolean(META_DATA_KEY, false) == true
                if (!include) continue
                val versionName = info.versionName ?: "1.0"
                val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    info.longVersionCode.toInt()
                } else {
                    @Suppress("DEPRECATION")
                    info.versionCode
                }
                val apk = info.applicationInfo?.sourceDir?.let(::File)
                val size = apk?.length() ?: 0L
                val modified = apk?.lastModified() ?: 0L
                val hash = MessageDigest.getInstance("MD5").run {
                    update("$pkg|$versionName|$versionCode|$modified|$size".toByteArray())
                    digest().joinToString("") { "%02x".format(it) }
                }
                out.add(
                    mapOf(
                        "apkPackName" to pkg,
                        "version" to versionName,
                        "versionCode" to versionCode,
                        "hash" to hash,
                        "architecture" to Build.SUPPORTED_ABIS.firstOrNull().orEmpty(),
                    )
                )
            } catch (_: PackageManager.NameNotFoundException) {
                // Game not installed.
            } catch (_: Exception) {
                // Ignore a broken package entry.
            }
        }
        return out
    }

    private fun launchGame(pkg: String?, result: MethodChannel.Result) {
        if (pkg.isNullOrBlank()) {
            result.success(false)
            return
        }
        runAsync(result) {
            try {
                if (!Platform.isAndroidModuleActive) {
                    startFileProviderService()
                    Thread.sleep(200)
                } else if (!PermissionManager.hasRootPermission(activity)) {
                    return@runAsync false
                } else {
                    PermissionManager.grantReadWriteAccess(activity, pkg)
                }
                val intent = activity.packageManager.getLaunchIntentForPackage(pkg) ?: return@runAsync false
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                activity.startActivity(intent)
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun startFileProviderService() {
        val intent = Intent(activity, FileProviderForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            activity.startForegroundService(intent)
        } else {
            activity.startService(intent)
        }
    }

    // -------------------------------------------------------------------------
    // SAF
    // -------------------------------------------------------------------------

    private fun pickFiles(call: MethodCall, result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("busy", "Another picker is already open", null)
            return
        }
        pendingPick = result
        val multiple = call.argument<Boolean>("multiple") ?: false
        val mimeTypes = call.argument<List<String>>("mimeTypes") ?: listOf("*/*")
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeTypes.firstOrNull() ?: "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        activity.startActivityForResult(intent, REQ_PICK)
    }

    private fun exportFile(call: MethodCall, result: MethodChannel.Result) {
        if (pendingSave != null) {
            result.error("busy", "Another save dialog is already open", null)
            return
        }
        val source = call.argument<String>("path")
        val name = call.argument<String>("name") ?: "tefmanager_export"
        if (source.isNullOrBlank() || !File(source).exists()) {
            result.success(false)
            return
        }
        pendingSave = result
        pendingSaveSource = source
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_TITLE, name)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        }
        activity.startActivityForResult(intent, REQ_SAVE)
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        when (requestCode) {
            REQ_PICK -> {
                val result = pendingPick ?: return true
                pendingPick = null
                if (resultCode != Activity.RESULT_OK || data == null) {
                    result.success(emptyList<String>())
                    return true
                }
                val uris = ArrayList<Uri>()
                data.clipData?.let { clip ->
                    for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri)
                }
                data.data?.let { uris.add(it) }
                Thread {
                    val paths = ArrayList<String>()
                    for (uri in uris) {
                        try {
                            paths.add(copyToCache(uri))
                        } catch (_: Exception) {
                            // Skip unreadable URIs.
                        }
                    }
                    mainHandler.post { result.success(paths) }
                }.start()
                return true
            }
            REQ_SAVE -> {
                val result = pendingSave ?: return true
                val source = pendingSaveSource
                pendingSave = null
                pendingSaveSource = null
                if (resultCode != Activity.RESULT_OK || data?.data == null || source == null) {
                    result.success(false)
                    return true
                }
                val dest = data.data!!
                Thread {
                    val ok = try {
                        activity.contentResolver.openOutputStream(dest)?.use { out ->
                            File(source).inputStream().use { it.copyTo(out) }
                        }
                        true
                    } catch (_: Exception) {
                        false
                    }
                    mainHandler.post { result.success(ok) }
                }.start()
                return true
            }
        }
        return false
    }

    private fun copyToCache(uri: Uri): String {
        val dir = File(activity.cacheDir, "picked").apply { mkdirs() }
        var name = "picked_${System.currentTimeMillis()}"
        activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) name = cursor.getString(index)
            }
        }
        val target = File(dir, name)
        activity.contentResolver.openInputStream(uri)?.use { input ->
            target.outputStream().use { input.copyTo(it) }
        }
        return target.absolutePath
    }

    // -------------------------------------------------------------------------

    private fun <T> runAsync(result: MethodChannel.Result, block: () -> T) {
        Thread {
            val value = try {
                block()
            } catch (e: Exception) {
                mainHandler.post { result.error("native", e.message, null) }
                return@Thread
            }
            mainHandler.post { result.success(value) }
        }.start()
    }
}
