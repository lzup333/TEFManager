package eternal.future.tefmanager.modpage

import android.app.Activity
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.unit.dp
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Native Android overlay that hosts a mod-provided Compose page. */
class ModPageOverlay(
    private val activity: Activity,
    private val channel: MethodChannel,
) : MethodChannel.MethodCallHandler {

    private var composeView: ComposeView? = null
    private var currentJar: String? = null

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        close(notifyDart = false)
        channel.setMethodCallHandler(null)
    }

    val isOpen: Boolean get() = composeView != null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open" -> {
                val jar = call.argument<String>("jarPath")
                val cls = call.argument<String>("className")
                @Suppress("UNCHECKED_CAST")
                val params = call.argument<HashMap<String, Any>>("params") as? Map<String, *> ?: emptyMap<String, Any>()
                if (jar.isNullOrBlank() || cls.isNullOrBlank()) {
                    result.error("bad-args", "jarPath/className required", null)
                    return
                }
                close(notifyDart = false)
                open(jar, cls, params)
                result.success(true)
            }
            "close" -> {
                close(notifyDart = false)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    /** Called by MainActivity.onBackPressed; returns true when handled. */
    fun onBackPressed(): Boolean {
        if (!isOpen) return false
        close(notifyDart = true)
        return true
    }

    private fun open(jarPath: String, className: String, params: Map<String, *>) {
        val root = activity.findViewById<ViewGroup>(android.R.id.content) ?: return
        val entry = ModPageLoader.load(activity, jarPath, className)

        val view = ComposeView(activity).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            )
            elevation = 1000f
            setContent {
                MaterialTheme {
                    ModPageContent(entry, params)
                }
            }
        }
        root.addView(view)
        composeView = view
        currentJar = jarPath
    }

    private fun close(notifyDart: Boolean) {
        val view = composeView ?: return
        runCatching {
            (view.parent as? ViewGroup)?.removeView(view)
        }
        composeView = null
        currentJar?.let { ModPageLoader.release(it) }
        currentJar = null
        if (notifyDart) {
            channel.invokeMethod("modpage.closed", null)
        }
    }
}

@Composable
private fun ModPageContent(entry: Result<ModPageEntry>, params: Map<String, *>) {
    val failure = entry.exceptionOrNull()
    if (failure != null) {
        ModPageError(failure)
        return
    }

    val page = entry.getOrNull()!!
    val content = remember(page, params) {
        runCatching {
            val clazz = page.clazz
            val instance = page.instance
            runCatching {
                clazz.getMethod("initialize", Map::class.java).invoke(instance, params)
            }
            runCatching {
                clazz.getDeclaredField("params").apply { isAccessible = true }
                    .set(instance, params)
            }
            @Suppress("UNCHECKED_CAST")
            clazz.getDeclaredField("Content").apply { isAccessible = true }
                .get(instance) as @Composable () -> Unit
        }.getOrElse {
            it.printStackTrace()
            null
        }
    }

    if (content != null) {
        content()
    } else {
        ModPageError(IllegalStateException("页面缺少 Content 可组合字段"))
    }
}

@Composable
private fun ModPageError(error: Throwable) {
    Box(Modifier.fillMaxSize().padding(16.dp), contentAlignment = Alignment.Center) {
        Text(
            text = "页面加载失败: ${error.message ?: error::class.simpleName}",
            color = MaterialTheme.colorScheme.error,
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}
