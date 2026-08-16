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

    /** 电费实时查询参数（电费接口无需 cookie，组件端可直接查询） */
    const val KEY_DIANFEI_METER = "widget_dianfei_meter"
    const val KEY_DIANFEI_OPENID = "widget_dianfei_openid"
    const val KEY_DIANFEI_IS_AFTER = "widget_dianfei_is_after"

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

    /** 电费实时查询参数（Flutter 侧绑定/解绑时写入；空 meterId 表示清空） */
    data class DianfeiParams(
        val meterId: String,
        val openId: String,
        val isAfterMoney: Int,
    )

    fun saveDianfeiParams(context: Context, meterId: String, openId: String, isAfter: Int) {
        val edit = prefs(context).edit()
        if (meterId.isEmpty() || openId.isEmpty()) {
            edit.remove(KEY_DIANFEI_METER)
                .remove(KEY_DIANFEI_OPENID)
                .remove(KEY_DIANFEI_IS_AFTER)
        } else {
            edit.putString(KEY_DIANFEI_METER, meterId)
                .putString(KEY_DIANFEI_OPENID, openId)
                .putInt(KEY_DIANFEI_IS_AFTER, isAfter)
        }
        edit.apply()
    }

    fun loadDianfeiParams(context: Context): DianfeiParams? {
        val p = prefs(context)
        val meter = p.getString(KEY_DIANFEI_METER, null) ?: return null
        val open = p.getString(KEY_DIANFEI_OPENID, null) ?: return null
        if (meter.isEmpty() || open.isEmpty()) return null
        return DianfeiParams(meter, open, p.getInt(KEY_DIANFEI_IS_AFTER, 0))
    }

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
