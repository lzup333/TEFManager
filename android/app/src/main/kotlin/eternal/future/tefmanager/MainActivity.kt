package eternal.future.tefmanager

import android.content.Intent
import eternal.future.tefmanager.modpage.ModPageHost
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var bridge: NativeBridge? = null
    private var modPageHost: ModPageHost? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bridge = NativeBridge(this, flutterEngine.dartExecutor.binaryMessenger).also {
            it.attach()
        }
        modPageHost = ModPageHost(
            this,
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "eternal.future.tefmanager/modpage"),
        )

    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (bridge?.onActivityResult(requestCode, resultCode, data) == true) {
            return
        }
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        modPageHost?.dispose()
        modPageHost = null
        bridge?.detach()
        bridge = null
        super.onDestroy()
    }
}
