package io.github.xraygit.tritium

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val moveToBackgroundChannel =
        "io.github.xraygit.tritium/move_to_background"
    private val deepLinkChannelName =
        "io.github.xraygit.tritium/deep_link"
    private var deepLinkChannel: MethodChannel? = null
    private var pendingInitialLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingInitialLink = extractDeepLink(intent)
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

        deepLinkChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deepLinkChannelName,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "getInitialLink") {
                    result.success(pendingInitialLink)
                    pendingInitialLink = null
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val url = extractDeepLink(intent) ?: return
        val channel = deepLinkChannel
        if (channel == null) {
            pendingInitialLink = url
        } else {
            channel.invokeMethod("onLink", url)
        }
    }

    private fun extractDeepLink(intent: Intent?): String? {
        if (intent == null) return null
        if (intent.action != Intent.ACTION_VIEW && intent.action != Intent.ACTION_EDIT) {
            return null
        }
        return intent.dataString
    }
}
