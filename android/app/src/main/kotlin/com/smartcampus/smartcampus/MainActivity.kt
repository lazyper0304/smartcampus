package com.smartcampus.smartcampus

import android.content.ActivityNotFoundException
import android.content.Intent
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.smartcampus.smartcampus/file"
        private const val FILE_PROVIDER_AUTH = ".fileprovider"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openFile" -> openFile(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    // 用系统应用打开本地文件。
    // 关键：Android 7+ 禁止通过 Intent 暴露 file:// URI（FileUriExposedException），
    // 必须经 FileProvider 转为 content:// 并授予只读权限，否则 WPS 等无法读取。
    private fun openFile(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val path = call.argument<String>("path")
        if (path == null) {
            result.error("NO_PATH", "path is null", null)
            return
        }
        val file = File(path)
        if (!file.exists()) {
            result.error("NO_FILE", "文件不存在或已失效: $path", null)
            return
        }
        try {
            val uri = FileProvider.getUriForFile(
                this,
                "$packageName$FILE_PROVIDER_AUTH",
                file,
            )
            val ext = file.extension.lowercase()
            val mime = MimeTypeMap.getSingleton()
                .getMimeTypeFromExtension(ext) ?: "*/*"
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            result.error("NO_APP", "未找到可打开该文件的应用", null)
        } catch (e: Exception) {
            result.error("OPEN_FAIL", e.message ?: "unknown error", null)
        }
    }
}
