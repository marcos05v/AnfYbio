package com.marcoscastro.anfybio

import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Canal "anfybio/pdf_text": el mismo que en iOS (ADR-0009). Allá lee
        // PDFKit; aquí PdfBox-Android (Apache 2.0), sin servicios externos.
        PDFBoxResourceLoader.init(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "anfybio/pdf_text")
            .setMethodCallHandler { call, result ->
                if (call.method != "extractText") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.arguments as? String
                if (path == null) {
                    result.error("argumento", "Falta la ruta del PDF", null)
                    return@setMethodCallHandler
                }
                // Leer un PDF puede tardar: fuera del hilo de la interfaz.
                worker.execute {
                    try {
                        val text = PDDocument.load(File(path)).use { document ->
                            PDFTextStripper().apply { sortByPosition = true }
                                .getText(document)
                        }
                        runOnUiThread { result.success(text) }
                    } catch (error: Exception) {
                        runOnUiThread {
                            result.error("pdf", error.message ?: "No se pudo leer el PDF", null)
                        }
                    }
                }
            }
    }
}
