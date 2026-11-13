package com.selim.science

import android.os.Bundle
import android.view.WindowManager
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Anti-piracy: blocks screenshots, screen recording, external-display capture and the recents thumbnail
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "selim/security").setMethodCallHandler { call, result ->
            when (call.method) {
                "threats" -> result.success(SecurityChecks.threats(this))
                "externalDisplay" -> result.success(SecurityChecks.externalDisplay(this))
                "integrityToken" -> {
                    val nonce = call.argument<String>("nonce")
                    val project = call.argument<String>("project")?.toLongOrNull()
                    if (nonce == null || project == null) { result.error("args", "bad args", null); return@setMethodCallHandler }
                    IntegrityManagerFactory.create(applicationContext)
                        .requestIntegrityToken(IntegrityTokenRequest.builder().setNonce(nonce).setCloudProjectNumber(project).build())
                        .addOnSuccessListener { result.success(it.token()) }
                        .addOnFailureListener { result.error("integrity", it.message, null) }
                }
                else -> result.notImplemented()
            }
        }
    }
}
