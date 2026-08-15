package com.smartcampus.smartcampus.widget

import android.content.Context
import android.content.res.Configuration

/**
 * 桌面组件数据桥：Flutter 侧把课程/电费数据以 JSON 写入 SharedPreferences，
 * 原生 AppWidgetProvider 读取后渲染 RemoteViews。
 *
 * 关键：AppWidget 运行在独立进程中，无法直接访问 Dart 内存缓存
 * （DataCache），必须经 SharedPreferences 持久化桥接。
 */
object WidgetPrefs {
    private const val PREFS_NAME = "smartcampus_widgets"

    /** 课程组件数据 JSON */
    const val KEY_COURSE = "widget_course_data"

    /** 电费组件数据 JSON */
    const val KEY_DIANFEI = "widget_dianfei_data"

    /** 组件主题：system（跟随系统，默认）/ dark / light */
    const val KEY_THEME = "widget_theme"

    /** 组件点击跳转目标 extra（MainActivity 读取，经 MethodChannel 通知 Flutter） */
    const val EXTRA_TARGET = "widget_target"

    fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun saveCourseData(context: Context, json: String) {
        prefs(context).edit().putString(KEY_COURSE, json).apply()
    }

    fun loadCourseData(context: Context): String? =
        prefs(context).getString(KEY_COURSE, null)

    fun saveDianfeiData(context: Context, json: String) {
        prefs(context).edit().putString(KEY_DIANFEI, json).apply()
    }

    fun loadDianfeiData(context: Context): String? =
        prefs(context).getString(KEY_DIANFEI, null)

    /** 主题：固定跟随系统深色模式（白天浅色→白底、深色模式→黑底；已移除手动切换入口） */
    fun getTheme(context: Context): String = systemTheme(context)

    /** 系统当前是否为深色模式 */
    fun systemTheme(context: Context): String {
        val nightMode = context.resources.configuration.uiMode and
            Configuration.UI_MODE_NIGHT_MASK
        return if (nightMode == Configuration.UI_MODE_NIGHT_YES) "dark" else "light"
    }

    fun setTheme(context: Context, theme: String) {
        prefs(context).edit().putString(KEY_THEME, theme).apply()
    }
}
