package eternal.future.tefmanager

import android.content.Intent
import eternal.future.tefmanager.modpage.ModPageOverlay
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var bridge: NativeBridge? = null
    private var modPageOverlay: ModPageOverlay? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bridge = NativeBridge(this, flutterEngine.dartExecutor.binaryMessenger).also {
            it.attach()
        }

        val modPageChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "eternal.future.tefmanager/modpage",
        )
        modPageOverlay = ModPageOverlay(this, modPageChannel)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (bridge?.onActivityResult(requestCode, resultCode, data) == true) {
            return
        }
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (modPageOverlay?.onBackPressed() == true) return
        @Suppress("DEPRECATION")
        super.onBackPressed()
    }

    override fun onDestroy() {
        modPageOverlay?.dispose()
        modPageOverlay = null
        bridge?.detach()
        bridge = null
        super.onDestroy()
    }
}
