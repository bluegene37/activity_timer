package dev.genexis.activitytimer

import io.flutter.embedding.android.FlutterActivity

// Gene - Nov, 22, 2026: Preserved original minimal MainActivity and added platform MethodChannel for local timezone lookup and system notification settings deep link.
// class MainActivity : FlutterActivity()
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      "dev.genexis.activitytimer/platform",
    ).setMethodCallHandler { call, result ->
      when (call.method) {
        "getLocalTimezone" -> {
          result.success(TimeZone.getDefault().id)
        }
        "openNotificationSettings" -> {
          result.success(openAppNotificationSettings())
        }
        else -> result.notImplemented()
      }
    }
  }

  private fun openAppNotificationSettings(): Boolean {
    return try {
      val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
          putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        }
      } else {
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
          data = Uri.fromParts("package", packageName, null)
        }
      }
      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      startActivity(intent)
      true
    } catch (_: Throwable) {
      try {
        val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
          data = Uri.fromParts("package", packageName, null)
          addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(fallback)
        true
      } catch (_: Throwable) {
        false
      }
    }
  }
}
