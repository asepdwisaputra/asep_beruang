package com.asepberuang.asep_beruang

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "com.asepberuang.app/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "saveToDownloads") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val path = call.argument<String>("path")
                val fileName = call.argument<String>("fileName")
                if (path.isNullOrBlank() || fileName.isNullOrBlank()) {
                    result.error("INVALID_ARGUMENT", "Path dan nama file wajib diisi.", null)
                    return@setMethodCallHandler
                }
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    result.error("UNSUPPORTED_ANDROID", "Ekspor langsung memerlukan Android 10 atau lebih baru.", null)
                    return@setMethodCallHandler
                }

                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                    put(
                        MediaStore.Downloads.MIME_TYPE,
                        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                    )
                    put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }
                val resolver = applicationContext.contentResolver
                val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                if (uri == null) {
                    result.error("DOWNLOADS_UNAVAILABLE", "Tidak dapat membuat file di folder Download.", null)
                    return@setMethodCallHandler
                }

                try {
                    val source = File(path)
                    if (!source.isFile) {
                        throw IllegalStateException("File laporan sementara tidak ditemukan.")
                    }
                    resolver.openOutputStream(uri)?.use { output ->
                        source.inputStream().use { input -> input.copyTo(output) }
                    } ?: throw IllegalStateException("Tidak dapat menulis file ke folder Download.")
                    val completed = ContentValues().apply {
                        put(MediaStore.Downloads.IS_PENDING, 0)
                    }
                    resolver.update(uri, completed, null, null)
                    result.success(fileName)
                } catch (error: Exception) {
                    resolver.delete(uri, null, null)
                    result.error("EXPORT_FAILED", error.message ?: "Ekspor Excel gagal.", null)
                }
            }
    }
}
