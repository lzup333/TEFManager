package eternal.future.tefmanager.modpage

import android.app.Activity
import android.content.Intent
import android.net.Uri
import dalvik.system.DexClassLoader
import eternal.future.tefmanager.modpage.api.ModPage
import eternal.future.tefmanager.modpage.api.ModPageApi
import eternal.future.tefmanager.modpage.api.PageNode
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * Loads a mod page JAR and exposes the stable PageNode ABI to Dart through a
 * MethodChannel. The page never references Compose or Flutter classes.
 */
class ModPageHost(
    private val activity: Activity,
    private val channel: MethodChannel,
) : MethodChannel.MethodCallHandler {

    private var loader: DexClassLoader? = null
    private var page: ModPage? = null
    private var api: ModPageApiImpl? = null

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        closeInternal()
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "open" -> {
                    val jar = call.argument<String>("jarPath")
                    val cls = call.argument<String>("className")
                    val privatePath = call.argument<String>("privatePath")
                    val dataPath = call.argument<String>("dataPath")
                    if (jar == null || cls == null || privatePath == null || dataPath == null) {
                        result.error("bad-args", "missing arguments", null)
                        return
                    }
                    closeInternal()
                    val loaded = load(jar, cls, privatePath, dataPath)
                    result.success(loaded)
                }
                "event" -> {
                    val id = call.argument<String>("id")
                    val value = call.argument<String>("value")
                    if (page == null || api == null || id == null) {
                        result.success(currentTree())
                        return
                    }
                    page!!.onEvent(id, value, api!!)
                    result.success(currentTree())
                }
                "close" -> {
                    closeInternal()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        } catch (e: Throwable) {
            result.error("modpage", e.message ?: e::class.simpleName, null)
        }
    }

    private fun load(jarPath: String, className: String, privatePath: String, dataPath: String): Map<String, Any> {
        val original = File(jarPath)
        require(original.exists()) { "页面文件不存在: $jarPath" }
        val cache = File(activity.cacheDir, "modpage_${System.currentTimeMillis()}.jar")
        original.copyTo(cache, overwrite = true)
        cache.setReadOnly()
        val dexDir = File(activity.cacheDir, "modpage_dex_${System.currentTimeMillis()}")
        dexDir.mkdirs()

        val cl = DexClassLoader(
            cache.absolutePath,
            dexDir.absolutePath,
            null,
            ModPageHost::class.java.classLoader,
        )
        val clazz = cl.loadClass(className)
        require(ModPage::class.java.isAssignableFrom(clazz)) {
            "$className 未实现稳定的 ModPage 接口"
        }
        val instance = clazz.getDeclaredConstructor().newInstance() as ModPage
        loader = cl
        page = instance
        api = ModPageApiImpl(activity, channel, privatePath, dataPath)
        cacheFile = cache
        dexDirFile = dexDir

        val tree = JSONObject()
        tree.put("title", instance.title())
        tree.put("tree", serialize(instance.render(api!!)))
        return mapOf("json" to tree.toString())
    }

    private var cacheFile: File? = null
    private var dexDirFile: File? = null

    private fun currentTree(): Map<String, Any> {
        val p = page ?: return mapOf("json" to "{}")
        val tree = JSONObject()
        tree.put("title", p.title())
        tree.put("tree", serialize(p.render(api!!)))
        return mapOf("json" to tree.toString())
    }

    private fun closeInternal() {
        page = null
        api = null
        loader = null
        runCatching { cacheFile?.delete() }
        runCatching { dexDirFile?.deleteRecursively() }
        cacheFile = null
        dexDirFile = null
    }

    private fun serialize(node: PageNode): JSONObject {
        val obj = JSONObject()
        obj.put("type", node.type)
        val props = JSONObject()
        node.props.forEach { (key, value) ->
            when (value) {
                null -> props.put(key, JSONObject.NULL)
                is Number, is Boolean, is String -> props.put(key, value)
                else -> props.put(key, value.toString())
            }
        }
        obj.put("props", props)
        val children = JSONArray()
        node.children.forEach { children.put(serialize(it)) }
        obj.put("children", children)
        return obj
    }

    private class ModPageApiImpl(
        private val activity: Activity,
        private val channel: MethodChannel,
        override val privatePath: String,
        override val dataPath: String,
    ) : ModPageApi {
        private val stateFile = File(privatePath, "page-state.json")

        override fun state(key: String): String? = synchronized(this) {
            val values = readValues()
            values.optString(key, null)
        }

        override fun setState(key: String, value: String) = synchronized(this) {
            val values = readValues()
            values.put(key, value)
            stateFile.parentFile?.mkdirs()
            val root = JSONObject()
            root.put("values", values)
            stateFile.writeText(root.toString())
        }

        private fun readValues(): JSONObject = try {
            if (stateFile.exists()) JSONObject(stateFile.readText()).optJSONObject("values")
                ?: JSONObject()
            else JSONObject()
        } catch (_: Throwable) {
            JSONObject()
        }

        override fun openUrl(url: String) {
            activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }

        override fun close() {
            channel.invokeMethod("modpage.closed", null)
        }
    }
}
