package com.smartcampus.smartcampus

import android.content.ActivityNotFoundException
import android.content.Intent
import android.util.Log
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import com.smartcampus.smartcampus.widget.WidgetPrefs
import com.smartcampus.smartcampus.widget.WidgetUpdater
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.jvm.Volatile

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.smartcampus.smartcampus/file"
        private const val WIDGET_CHANNEL = "com.smartcampus.smartcampus/widget"
        private const val FILE_PROVIDER_AUTH = ".fileprovider"
        private const val TAG = "SmartWidget"

        /** 组件点击后待通知 Flutter 的目标（冷启动时引擎未就绪，暂存于此） */
        @Volatile
        private var pendingWidgetTarget: String? = null
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
        registerWidgetChannel(flutterEngine)
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // 冷启动：组件点击 → extra 暂存，Flutter 就绪后由 getPendingWidgetTarget 拉取
        intent?.getStringExtra(WidgetPrefs.EXTRA_TARGET)?.let {
            pendingWidgetTarget = it
            Log.d(TAG, "widget click (cold start): $it")
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // 热启动：组件点击 → extra 写入暂存 + 立即通知 Flutter（引擎已就绪）
        val target = intent.getStringExtra(WidgetPrefs.EXTRA_TARGET)
        if (target != null) {
            pendingWidgetTarget = target
            Log.d(TAG, "widget click (warm start): $target")
            val engine = flutterEngine
            if (engine != null) {
                MethodChannel(
                    engine.dartExecutor.binaryMessenger,
                    WIDGET_CHANNEL,
                ).invokeMethod("onWidgetClick", target)
            }
        }
    }

    override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
        super.onConfigurationChanged(newConfig)
        // 系统深色模式切换（跟随系统主题时）→ 刷新全部组件背景（Manifest configChanges 含 uiMode）
        WidgetUpdater.updateAll(this)
    }

    // ==================== 桌面组件通道 ====================

    private fun registerWidgetChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Flutter 侧课表加载后写入组件数据并刷新（2x2 + 4x2/4x4 全部）
                    "saveCourseData" -> {
                        val json = call.argument<String>("data")
                        if (json != null) {
                            WidgetPrefs.saveCourseData(this, json)
                            WidgetUpdater.updateAllCourseWidgets(this)
                        }
                        result.success(true)
                    }
                    // Flutter 侧电费查询后写入组件数据并刷新（2x2 + 4x2/4x4 全部）
                    "saveDianfeiData" -> {
                        val json = call.argument<String>("data")
                        if (json != null) {
                            WidgetPrefs.saveDianfeiData(this, json)
                            WidgetUpdater.updateAllDianfeiWidgets(this)
                        }
                        result.success(true)
                    }
                    // Flutter 侧绑定/解绑电表时写入查询参数（电费接口无需 cookie，
                    // 组件进程可凭此参数直接实时查询）
                    "saveDianfeiParams" -> {
                        val meterId = call.argument<String>("meterId") ?: ""
                        val openId = call.argument<String>("openId") ?: ""
                        val isAfter = call.argument<Int>("isAfter") ?: 0
                        WidgetPrefs.saveDianfeiParams(this, meterId, openId, isAfter)
                        result.success(true)
                    }
                    // 主题切换（dark / light）
                    "setWidgetTheme" -> {
                        val theme = call.argument<String>("theme") ?: "dark"
                        WidgetPrefs.setTheme(this, theme)
                        WidgetUpdater.updateAll(this)
                        result.success(true)
                    }
                    // 拉取组件点击目标（冷启动时 Flutter 就绪后调用一次）
                    "getPendingWidgetTarget" -> {
                        val target = pendingWidgetTarget
                        pendingWidgetTarget = null
                        result.success(target)
                    }
                    // 手动刷新所有组件
                    "refreshAllWidgets" -> {
                        WidgetUpdater.updateAll(this)
                        result.success(true)
                    }
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
