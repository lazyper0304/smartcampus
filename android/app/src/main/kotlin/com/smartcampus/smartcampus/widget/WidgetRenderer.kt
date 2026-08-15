package com.smartcampus.smartcampus.widget

import android.content.Context
import android.content.res.ColorStateList
import android.os.Build
import android.widget.RemoteViews
import com.smartcampus.smartcampus.R
import org.json.JSONArray
import org.json.JSONObject

/**
 * 组件渲染器：把 WidgetPrefs 中的 JSON 数据渲染为 RemoteViews。
 *
 * 布局按实际尺寸（OPTION_APPWIDGET_MIN_WIDTH）三档切换：
 *  <180dp → small（2x2）；<300dp → medium（4x2）；≥300dp → large（4x4）
 * 配色按 WidgetPrefs 主题：dark（深色玻璃）/ light（浅色玻璃）。
 */
object WidgetRenderer {

    // ==================== 尺寸选择 ====================

    fun courseLayoutFor(widthDp: Int): Int = when {
        widthDp < 180 -> R.layout.widget_course_small
        widthDp < 300 -> R.layout.widget_course_medium
        else -> R.layout.widget_course_large
    }

    fun dianfeiLayoutFor(widthDp: Int): Int = when {
        widthDp < 180 -> R.layout.widget_dianfei_small
        widthDp < 300 -> R.layout.widget_dianfei_medium
        else -> R.layout.widget_dianfei_large
    }

    // ==================== 主题配色 ====================

    /** 深色玻璃主题（默认） */
    private val darkTheme = WidgetTheme(
        textPrimary = 0xFFFFFFFF.toInt(),
        textSecondary = 0xCCFFFFFF.toInt(),
        textTertiary = 0x99FFFFFF.toInt(),
        accent = 0xFF4D9FFF.toInt(),
        positive = 0xFF4CD97B.toInt(),
        warning = 0xFFFFB74D.toInt(),
        bgRes = R.drawable.widget_bg_dark,
        barTrack = 0x33FFFFFF.toInt(),
        barProgress = 0xFF4D9FFF.toInt(),
    )

    /** 浅色玻璃主题 */
    private val lightTheme = WidgetTheme(
        textPrimary = 0xFF1A1A2E.toInt(),
        textSecondary = 0x99000000.toInt(),
        textTertiary = 0x66000000.toInt(),
        accent = 0xFF2563EB.toInt(),
        positive = 0xFF16A34A.toInt(),
        warning = 0xFFEA8C00.toInt(),
        bgRes = R.drawable.widget_bg_light,
        barTrack = 0x1A000000.toInt(),
        barProgress = 0xFF2563EB.toInt(),
    )

    private fun themeFor(context: Context): WidgetTheme =
        if (WidgetPrefs.getTheme(context) == "light") lightTheme else darkTheme

    data class WidgetTheme(
        val textPrimary: Int,
        val textSecondary: Int,
        val textTertiary: Int,
        val accent: Int,
        val positive: Int,
        val warning: Int,
        val bgRes: Int,
        val barTrack: Int,
        val barProgress: Int,
    )

    // ==================== 课程表 ====================

    fun renderCourse(
        context: Context,
        layoutId: Int,
        dataJson: String?,
        theme: WidgetTheme = themeFor(context),
    ): RemoteViews {
        val views = RemoteViews(context.packageName, layoutId)
        views.setInt(R.id.widget_root, "setBackgroundResource", theme.bgRes)

        // 标题 / 周次
        views.setTextColor(R.id.tv_title, theme.textPrimary)
        views.setTextColor(R.id.tv_week, theme.textSecondary)

        val json = runCatching { dataJson?.let { JSONObject(it) } }.getOrNull()
        if (json == null) {
            renderCourseEmpty(views, layoutId, theme)
            return views
        }

        views.setTextViewText(R.id.tv_title, json.optString("title", "今日课程"))
        views.setTextViewText(R.id.tv_week, json.optString("week", ""))

        val courses = json.optJSONArray("courses") ?: JSONArray()
        val isEmpty = json.optBoolean("empty", courses.length() == 0)

        // 小号：仅第一节课 + 共 N 节
        if (layoutId == R.layout.widget_course_small) {
            if (isEmpty) {
                views.setViewVisibility(R.id.tv_course1_name, android.view.View.GONE)
                views.setViewVisibility(R.id.tv_course1_time, android.view.View.GONE)
                views.setViewVisibility(R.id.tv_more, android.view.View.GONE)
                views.setViewVisibility(R.id.tv_empty, android.view.View.VISIBLE)
                views.setTextColor(R.id.tv_empty, theme.textSecondary)
            } else {
                views.setViewVisibility(R.id.tv_empty, android.view.View.GONE)
                val first = courses.optJSONObject(0)
                views.setTextViewText(R.id.tv_course1_name, first?.optString("name", "") ?: "")
                views.setTextViewText(
                    R.id.tv_course1_time,
                    listOf(
                        first?.optString("time", ""),
                        first?.optString("room", ""),
                    ).filter { it.isNullOrEmpty().not() }.joinToString(" · "),
                )
                views.setTextColor(R.id.tv_course1_name, theme.textPrimary)
                views.setTextColor(R.id.tv_course1_time, theme.textSecondary)
                if (courses.length() > 1) {
                    views.setViewVisibility(R.id.tv_more, android.view.View.VISIBLE)
                    views.setTextViewText(R.id.tv_more, "等 ${courses.length() - 1} 节课")
                    views.setTextColor(R.id.tv_more, theme.textTertiary)
                } else {
                    views.setViewVisibility(R.id.tv_more, android.view.View.GONE)
                }
            }
            return views
        }

        // 中号/大号：列表槽位渲染
        val slots = if (layoutId == R.layout.widget_course_medium) 3 else 5
        for (i in 1..slots) {
            val rowVisible = i <= courses.length() && !isEmpty
            views.setViewVisibility(rowId(i), if (rowVisible) android.view.View.VISIBLE else android.view.View.GONE)
            if (!rowVisible) continue
            val course = courses.optJSONObject(i - 1)
            views.setTextViewText(timeId(i), course?.optString("time", "") ?: "")
            views.setTextViewText(nameId(i), course?.optString("name", "") ?: "")
            views.setTextViewText(roomId(i), course?.optString("room", "") ?: "")
            views.setTextColor(timeId(i), theme.textSecondary)
            views.setTextColor(nameId(i), theme.textPrimary)
            views.setTextColor(roomId(i), theme.textTertiary)
        }

        if (isEmpty) {
            views.setViewVisibility(R.id.tv_empty, android.view.View.VISIBLE)
            views.setTextColor(R.id.tv_empty, theme.textSecondary)
        } else {
            views.setViewVisibility(R.id.tv_empty, android.view.View.GONE)
        }

        if (layoutId == R.layout.widget_course_large) {
            val updated = json.optString("updatedAt", "")
            if (updated.isNotEmpty()) {
                views.setViewVisibility(R.id.tv_update, android.view.View.VISIBLE)
                views.setTextViewText(R.id.tv_update, "更新于 $updated")
                views.setTextColor(R.id.tv_update, theme.textTertiary)
            } else {
                views.setViewVisibility(R.id.tv_update, android.view.View.GONE)
            }
        }
        return views
    }

    private fun renderCourseEmpty(views: RemoteViews, layoutId: Int, theme: WidgetTheme) {
        views.setTextColor(R.id.tv_title, theme.textPrimary)
        views.setTextColor(R.id.tv_week, theme.textSecondary)
        if (layoutId == R.layout.widget_course_small) {
            views.setViewVisibility(R.id.tv_course1_name, android.view.View.GONE)
            views.setViewVisibility(R.id.tv_course1_time, android.view.View.GONE)
            views.setViewVisibility(R.id.tv_more, android.view.View.GONE)
            views.setViewVisibility(R.id.tv_empty, android.view.View.VISIBLE)
            views.setTextViewText(R.id.tv_empty, "暂无课程数据")
            views.setTextColor(R.id.tv_empty, theme.textSecondary)
            return
        }
        // medium 布局只有 3 个槽位，large 布局有 5 个 —— 只隐藏本布局存在的行
        val slots = if (layoutId == R.layout.widget_course_medium) 3 else 5
        for (i in 1..slots) {
            views.setViewVisibility(rowId(i), android.view.View.GONE)
        }
        views.setViewVisibility(R.id.tv_empty, android.view.View.VISIBLE)
        views.setTextViewText(R.id.tv_empty, "暂无课程数据")
        views.setTextColor(R.id.tv_empty, theme.textSecondary)
        if (layoutId == R.layout.widget_course_large) {
            views.setViewVisibility(R.id.tv_update, android.view.View.GONE)
        }
    }

    private fun rowId(i: Int): Int = when (i) {
        1 -> R.id.course_row_1
        2 -> R.id.course_row_2
        3 -> R.id.course_row_3
        4 -> R.id.course_row_4
        else -> R.id.course_row_5
    }

    private fun timeId(i: Int): Int = when (i) {
        1 -> R.id.tv_time_1
        2 -> R.id.tv_time_2
        3 -> R.id.tv_time_3
        4 -> R.id.tv_time_4
        else -> R.id.tv_time_5
    }

    private fun nameId(i: Int): Int = when (i) {
        1 -> R.id.tv_name_1
        2 -> R.id.tv_name_2
        3 -> R.id.tv_name_3
        4 -> R.id.tv_name_4
        else -> R.id.tv_name_5
    }

    private fun roomId(i: Int): Int = when (i) {
        1 -> R.id.tv_room_1
        2 -> R.id.tv_room_2
        3 -> R.id.tv_room_3
        4 -> R.id.tv_room_4
        else -> R.id.tv_room_5
    }

    // ==================== 电费 ====================

    fun renderDianfei(
        context: Context,
        layoutId: Int,
        dataJson: String?,
        theme: WidgetTheme = themeFor(context),
    ): RemoteViews {
        val views = RemoteViews(context.packageName, layoutId)
        views.setInt(R.id.widget_root, "setBackgroundResource", theme.bgRes)
        views.setTextColor(R.id.tv_title, theme.textPrimary)
        views.setTextColor(R.id.tv_balance_unit, theme.textTertiary)

        val json = runCatching { dataJson?.let { JSONObject(it) } }.getOrNull()
        val balance = json?.optString("balance", "--") ?: "--"
        val status = json?.optString("status", "") ?: ""
        val monthKwh = json?.optString("monthKwh", "--") ?: "--"
        val monthMoney = json?.optString("monthMoney", "--") ?: "--"
        val total = json?.optString("total", "--") ?: "--"

        views.setTextViewText(R.id.tv_balance, balance)
        views.setTextColor(R.id.tv_balance, theme.textPrimary)

        // 状态：合闸绿 / 分闸橙（三种布局均有 tv_status；无数据时隐藏）
        if (status.isNotEmpty()) {
            views.setViewVisibility(R.id.tv_status, android.view.View.VISIBLE)
            views.setTextViewText(R.id.tv_status, status)
            val isOn = status.contains("合闸")
            views.setTextColor(R.id.tv_status, if (isOn) theme.positive else theme.warning)
        } else {
            views.setViewVisibility(R.id.tv_status, android.view.View.GONE)
        }

        // 中/大号：本月统计
        if (layoutId == R.layout.widget_dianfei_medium ||
            layoutId == R.layout.widget_dianfei_large
        ) {
            views.setTextViewText(R.id.tv_month_kwh, monthKwh)
            views.setTextViewText(R.id.tv_month_money, monthMoney)
            views.setTextColor(R.id.tv_month_kwh, theme.textPrimary)
            views.setTextColor(R.id.tv_month_money, theme.textPrimary)
            views.setTextColor(R.id.tv_label_month_kwh, theme.textTertiary)
            views.setTextColor(R.id.tv_label_month_money, theme.textTertiary)
        }

        // 大号：累计 + 近 7 日条形图
        if (layoutId == R.layout.widget_dianfei_large) {
            views.setTextViewText(R.id.tv_total, total)
            views.setTextColor(R.id.tv_total, theme.textPrimary)
            views.setTextColor(R.id.tv_label_total, theme.textTertiary)
            views.setTextColor(R.id.tv_label_chart, theme.textTertiary)

            val days = json?.optJSONArray("days") ?: JSONArray()
            var maxKwh = 0.0
            for (i in 0 until days.length()) {
                val kwh = days.optJSONObject(i)?.optDouble("kwh", 0.0) ?: 0.0
                if (kwh > maxKwh) maxKwh = kwh
            }
            if (maxKwh <= 0) maxKwh = 1.0

            for (i in 1..7) {
                if (i <= days.length()) {
                    views.setViewVisibility(dayRowId(i), android.view.View.VISIBLE)
                    val day = days.optJSONObject(i - 1)
                    views.setTextViewText(dayId(i), day?.optString("label", "") ?: "")
                    views.setTextViewText(kwhId(i), day?.optString("kwhText", "") ?: "")
                    views.setTextColor(dayId(i), theme.textTertiary)
                    views.setTextColor(kwhId(i), theme.textTertiary)

                    val kwh = day?.optDouble("kwh", 0.0) ?: 0.0
                    val progress = ((kwh / maxKwh) * 100).toInt().coerceIn(2, 100)
                    // RemoteViews 无 setProgressTintList；用 setColorStateList 反射调用
                    // ProgressBar 的 tint 方法（API 31+，官方推荐用法）。低版本回退 XML 静态色。
                    if (Build.VERSION.SDK_INT >= 31) {
                        views.setColorStateList(
                            barId(i),
                            "setProgressTintList",
                            ColorStateList.valueOf(theme.barProgress),
                        )
                        views.setColorStateList(
                            barId(i),
                            "setProgressBackgroundTintList",
                            ColorStateList.valueOf(theme.barTrack),
                        )
                    }
                    views.setProgressBar(barId(i), 100, progress, false)
                } else {
                    views.setViewVisibility(dayRowId(i), android.view.View.GONE)
                }
            }
        }

        // 大号：更新时间
        if (layoutId == R.layout.widget_dianfei_large) {
            val updated = json?.optString("updatedAt", "") ?: ""
            if (updated.isNotEmpty()) {
                views.setViewVisibility(R.id.tv_update, android.view.View.VISIBLE)
                views.setTextViewText(R.id.tv_update, "更新于 $updated")
                views.setTextColor(R.id.tv_update, theme.textTertiary)
            } else {
                views.setViewVisibility(R.id.tv_update, android.view.View.GONE)
            }
        }

        return views
    }

    private fun dayRowId(i: Int): Int = when (i) {
        1 -> R.id.chart_row_1
        2 -> R.id.chart_row_2
        3 -> R.id.chart_row_3
        4 -> R.id.chart_row_4
        5 -> R.id.chart_row_5
        6 -> R.id.chart_row_6
        else -> R.id.chart_row_7
    }

    private fun dayId(i: Int): Int = when (i) {
        1 -> R.id.tv_day_1
        2 -> R.id.tv_day_2
        3 -> R.id.tv_day_3
        4 -> R.id.tv_day_4
        5 -> R.id.tv_day_5
        6 -> R.id.tv_day_6
        else -> R.id.tv_day_7
    }

    private fun barId(i: Int): Int = when (i) {
        1 -> R.id.bar_1
        2 -> R.id.bar_2
        3 -> R.id.bar_3
        4 -> R.id.bar_4
        5 -> R.id.bar_5
        6 -> R.id.bar_6
        else -> R.id.bar_7
    }

    private fun kwhId(i: Int): Int = when (i) {
        1 -> R.id.tv_kwh_1
        2 -> R.id.tv_kwh_2
        3 -> R.id.tv_kwh_3
        4 -> R.id.tv_kwh_4
        5 -> R.id.tv_kwh_5
        6 -> R.id.tv_kwh_6
        else -> R.id.tv_kwh_7
    }
}
