package com.selim.science

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import android.provider.Settings
import android.view.WindowManager
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val io = Executors.newSingleThreadExecutor()          // PdfRenderer allows ONE open page at a time -> serial
    private val ui = Handler(Looper.getMainLooper())
    private var pickResult: MethodChannel.Result? = null
    private var pdfFd: ParcelFileDescriptor? = null
    private var pdf: PdfRenderer? = null
    private val pickCode = 4711

    override fun onCreate(savedInstanceState: Bundle?) {
        // Anti-piracy: blocks screenshots, screen recording, external-display capture and the recents thumbnail
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }

    override fun onDestroy() { io.execute { closePdf() }; super.onDestroy() }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // ---------------- security ----------------
        MethodChannel(messenger, "selim/security").setMethodCallHandler { call, result ->
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

        // ---------------- device id / PDF picker / in-app PDF renderer (no third-party plugins) ----------------
        MethodChannel(messenger, "selim/native").setMethodCallHandler { call, result ->
            when (call.method) {
                "deviceInfo" -> result.success(mapOf(
                    "id" to (Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: ""),
                    "name" to "${Build.MANUFACTURER} ${Build.MODEL}"))

                "pickPdf" -> {
                    if (pickResult != null) { result.error("busy", "picker busy", null); return@setMethodCallHandler }
                    pickResult = result
                    val i = Intent(Intent.ACTION_OPEN_DOCUMENT).apply { addCategory(Intent.CATEGORY_OPENABLE); type = "application/pdf" }
                    startActivityForResult(i, pickCode)
                }

                "pdfOpen" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null) { result.error("args", "no bytes", null); return@setMethodCallHandler }
                    io.execute {
                        try {
                            closePdf()
                            // temp file is deleted right after opening: the data lives only behind the open descriptor
                            val f = File.createTempFile("p", ".pdf", cacheDir)
                            f.writeBytes(bytes)
                            val fd = ParcelFileDescriptor.open(f, ParcelFileDescriptor.MODE_READ_ONLY)
                            f.delete()
                            val r = PdfRenderer(fd)
                            pdfFd = fd; pdf = r
                            ui.post { result.success(r.pageCount) }
                        } catch (e: Throwable) { ui.post { result.error("pdf", e.message, null) } }
                    }
                }

                "pdfPage" -> {
                    val index = call.argument<Int>("index") ?: 0
                    val width = (call.argument<Int>("width") ?: 1080).coerceIn(300, 2400)
                    io.execute {
                        try {
                            val r = pdf ?: throw IllegalStateException("not_open")
                            val page = r.openPage(index)
                            try {
                                val h = (width.toFloat() / page.width * page.height).toInt().coerceAtLeast(1)
                                val bmp = Bitmap.createBitmap(width, h, Bitmap.Config.ARGB_8888)
                                bmp.eraseColor(Color.WHITE)
                                page.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                val out = ByteArrayOutputStream()
                                bmp.compress(Bitmap.CompressFormat.JPEG, 88, out)
                                bmp.recycle()
                                val data = out.toByteArray()
                                ui.post { result.success(data) }
                            } finally { page.close() }
                        } catch (e: Throwable) { ui.post { result.error("pdf", e.message, null) } }
                    }
                }

                "pdfClose" -> { io.execute { closePdf() }; result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    private fun closePdf() {
        try { pdf?.close() } catch (_: Throwable) {}
        try { pdfFd?.close() } catch (_: Throwable) {}
        pdf = null; pdfFd = null
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickCode) return
        val res = pickResult ?: return
        pickResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { res.success(null); return }
        io.execute {
            try {
                var name = "file.pdf"
                contentResolver.query(uri, null, null, null, null)?.use { c ->
                    if (c.moveToFirst()) { val i = c.getColumnIndex(OpenableColumns.DISPLAY_NAME); if (i >= 0) name = c.getString(i) ?: name }
                }
                val bytes = contentResolver.openInputStream(uri)!!.use { it.readBytes() }
                if (bytes.size > 60 * 1024 * 1024) throw IllegalStateException("too_large")
                ui.post { res.success(mapOf("name" to name, "bytes" to bytes)) }
            } catch (e: Throwable) { ui.post { res.error("pick", e.message, null) } }
        }
    }
}
