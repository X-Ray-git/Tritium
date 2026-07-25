package io.github.xraygit.tritium

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val moveToBackgroundChannel =
        "io.github.xraygit.tritium/move_to_background"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            moveToBackgroundChannel,
        ).setMethodCallHandler { call, result ->
            if (call.method == "moveTaskToBack") {
                result.success(moveTaskToBack(true))
            } else {
                result.notImplemented()
            }
        }
    }
}
