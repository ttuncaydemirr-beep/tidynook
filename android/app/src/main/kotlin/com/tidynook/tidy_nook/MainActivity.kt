package com.tidynook.tidy_nook

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Google UMP writes the TCF consent strings (IABTCF_*) into the app's DEFAULT SharedPreferences.
        // Dart reads them only to derive the Firebase Analytics consent signals (lib/monet/consent.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.tidynook.game/consent")
            .setMethodCallHandler { call, result ->
                if (call.method == "tcf") {
                    try {
                        val sp = applicationContext.getSharedPreferences(
                            applicationContext.packageName + "_preferences", Context.MODE_PRIVATE
                        )
                        val applies = try { sp.getInt("IABTCF_gdprApplies", 0) } catch (e: Exception) { 0 }
                        val purposes = try { sp.getString("IABTCF_PurposeConsents", "") ?: "" } catch (e: Exception) { "" }
                        result.success(mapOf("gdprApplies" to applies, "purposeConsents" to purposes))
                    } catch (e: Exception) {
                        result.success(null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
