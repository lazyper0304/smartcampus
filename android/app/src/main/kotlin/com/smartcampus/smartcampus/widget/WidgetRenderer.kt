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
            renderCourseEmpty(views, layoutId, theme, hasData = false)
            return views
        }

        views.setTextViewText(R.id.tv_title, json.optString("title", "今日课程"))

        // 原生计算「今天」：避免 Flutter 写死星期几导致跨天不刷新。
        // days 为新格式（整学期课程，含 weeks），courses 为旧格式兼容。
        val today = currentDayOfWeek() // 1=周一 … 7=周日
        val weekNames = arrayOf("周一", "周二", "周三", "周四", "周五", "周六", "周日")
        val daysObj = json.optJSONObject("days") // 兼容旧格式：取 JSON 对象
        val legacyCourses = json.optJSONArray("courses")
        val hasData = daysObj != null || legacyCourses != null

        // 教学周次：优先用 firstMonday 锚点按设备时钟现场推算，彻底消除「周次滞后」；
        // 无锚点时回退到 Flutter 写入的 currentWeek 兜底。
        val firstMondayMillis = json.optLong("firstMonday", -1L)
        val computedWeek = if (firstMondayMillis > 0) {
            computeWeekFromMonday(firstMondayMillis)
        } else {
            json.optInt("currentWeek", 1)
        }

        val courses: JSONArray
        val weekLabel: String
        if (daysObj != null) {
            // 取出当日课程，再按推算出的教学周次过滤（weeks 为空表示每周都有）
            val raw = daysObj.optJSONArray(today.toString()) ?: JSONArray()
            courses = filterByWeek(raw, computedWeek)
            weekLabel = "第 ${computedWeek} 周 · ${weekNames[today - 1]}"
        } else {
            // 旧格式：直接使用写死的 courses 与 week
            courses = legacyCourses ?: JSONArray()
            weekLabel = json.optString("week", "")
        }
        views.setTextViewText(R.id.tv_week, weekLabel)

        // 更新时间（三档布局均有，左下角显示"更新于 M月d日 HH:mm"）
        val updated = json.optString("updatedAt", "")
        if (updated.isNotEmpty()) {
            views.setViewVisibility(R.id.tv_update, android.view.View.VISIBLE)
            views.setTextViewText(R.id.tv_update, "更新于 $updated")
            views.setTextColor(R.id.tv_update, theme.textTertiary)
        } else {
            views.setViewVisibility(R.id.tv_update, android.view.View.GONE)
        }

        val isEmpty = !hasData || courses.length() == 0

        // 小号：仅第一节课 + 共 N 节
        if (layoutId == R.layout.widget_course_small) {
            if (isEmpty) {
                views.setViewVisibility(R.id.tv_course1_name, android.view.View.GONE)
                views.setViewVisibility(R.id.tv_course1_time, android.view.View.GONE)
                views.setViewVisibility(R.id.tv_more, android.view.View.GONE)
                views.setViewVisibility(R.id.tv_empty, android.view.View.VISIBLE)
                views.setTextViewText(
                    R.id.tv_empty,
                    if (hasData) "今日无课" else "暂无课程数据",
                )
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
            views.setTextViewText(
                R.id.tv_empty,
                if (hasData) "今日无课" else "暂无课程数据",
            )
            views.setTextColor(R.id.tv_empty, theme.textSecondary)
        } else {
            views.setViewVisibility(R.id.tv_empty, android.view.View.GONE)
        }

        return views
    }

    /**
     * 当前星期几（1=周一 … 7=周日）。
     * 用 Calendar 而非 java.time（兼容 minSdk 24）。
     */
    private fun currentDayOfWeek(): Int {
        val cal = java.util.Calendar.getInstance()
        val dow = cal.get(java.util.Calendar.DAY_OF_WEEK) // 1=周日 … 7=周六
        return if (dow == java.util.Calendar.SUNDAY) 7 else dow - 1
    }

    /**
     * 由校历第一周周一（epoch millis）按设备时钟推算当前教学周次。
     * 镜像 course_service.dart::_estimateWeekFromMonday：
     *   week = (本周周一 − firstMonday) / 7天 + 1，clamp[1,30]，未来第一周→1。
     * 以「当日零点」归零后再回退到本周周一，避免时分导致的跨周边界 off-by-one。
     */
    private fun computeWeekFromMonday(firstMondayMillis: Long): Int {
        val first = java.util.Calendar.getInstance().apply {
            timeInMillis = firstMondayMillis
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }
        if (first.timeInMillis > System.currentTimeMillis()) return 1

        val today = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }
        val dow = currentDayOfWeek() // 1=周一 … 7=周日
        today.add(java.util.Calendar.DAY_OF_MONTH, -(dow - 1)) // 回退到本周周一

        val dayMillis = 24L * 60 * 60 * 1000
        val days = ((today.timeInMillis - first.timeInMillis) / dayMillis).toInt()
        val est = days / 7 + 1
        return if (est < 1 || est > 30) 1 else est
    }

    /**
     * 按教学周次过滤当日课程：weeks 为空表示每周都有课；
     * 否则仅保留 weeks 含 [week] 的课程（与 Flutter 侧 weeks 语义一致）。
     */
    private fun filterByWeek(courses: JSONArray, week: Int): JSONArray {
        val result = JSONArray()
        for (i in 0 until courses.length()) {
            val c = courses.optJSONObject(i) ?: continue
            val weeksArr = c.optJSONArray("weeks")
            val show = if (weeksArr == null || weeksArr.length() == 0) {
                true
            } else {
                var contains = false
                for (j in 0 until weeksArr.length()) {
                    if (weeksArr.optInt(j, 0) == week) { contains = true; break }
                }
                contains
            }
            if (show) result.put(c)
        }
        return result
    }

    private fun renderCourseEmpty(
        views: RemoteViews,
        layoutId: Int,
        theme: WidgetTheme,
        hasData: Boolean,
    ) {
        views.setTextColor(R.id.tv_title, theme.textPrimary)
        views.setTextColor(R.id.tv_week, theme.textSecondary)
        views.setViewVisibility(R.id.tv_update, android.view.View.GONE)
        val emptyText = if (hasData) "今日无课" else "暂无课程数据"
        if (layoutId == R.layout.widget_course_small) {
            views.setViewVisibility(R.id.tv_course1_name, android.view.View.GONE)
            views.setViewVisibility(R.id.tv_course1_time, android.view.View.GONE)
            views.setViewVisibility(R.id.tv_more, android.view.View.GONE)
            views.setViewVisibility(R.id.tv_empty, android.view.View.VISIBLE)
            views.setTextViewText(R.id.tv_empty, emptyText)
            views.setTextColor(R.id.tv_empty, theme.textSecondary)
            return
        }
        // medium 布局只有 3 个槽位，large 布局有 5 个 —— 只隐藏本布局存在的行
        val slots = if (layoutId == R.layout.widget_course_medium) 3 else 5
        for (i in 1..slots) {
            views.setViewVisibility(rowId(i), android.view.View.GONE)
        }
        views.setViewVisibility(R.id.tv_empty, android.view.View.VISIBLE)
        views.setTextViewText(R.id.tv_empty, emptyText)
        views.setTextColor(R.id.tv_empty, theme.textSecondary)
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

    /**
     * 渲染电费组件视图。
     *
     * @param refreshing true = 正在实时查询：右上角显示刷新进度圈（隐藏刷新按钮）
     * @param hint 大号布局 tv_update 的替换文案（如"刷新失败"/"请先在App绑定电表"），
     *             为 null 时显示 json 中的更新时间
     */
    fun renderDianfei(
        context: Context,
        layoutId: Int,
        dataJson: String?,
        theme: WidgetTheme = themeFor(context),
        refreshing: Boolean = false,
        hint: String? = null,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, layoutId)
        views.setInt(R.id.widget_root, "setBackgroundResource", theme.bgRes)
        views.setTextColor(R.id.tv_title, theme.textPrimary)
        views.setTextColor(R.id.tv_balance_unit, theme.textTertiary)

        // 右上角刷新按钮 / 刷新进度圈（三种布局均有）
        views.setViewVisibility(
            R.id.btn_dianfei_refresh,
            if (refreshing) android.view.View.GONE else android.view.View.VISIBLE,
        )
        views.setViewVisibility(
            R.id.pb_dianfei_refresh,
            if (refreshing) android.view.View.VISIBLE else android.view.View.GONE,
        )
        // 图标按主题着色（矢量图白色基底，此处覆盖）
        views.setInt(R.id.btn_dianfei_refresh, "setColorFilter", theme.textSecondary)
        if (Build.VERSION.SDK_INT >= 31) {
            views.setColorStateList(
                R.id.pb_dianfei_refresh,
                "setIndeterminateTintList",
                ColorStateList.valueOf(theme.textSecondary),
            )
        } else {
            views.setInt(R.id.pb_dianfei_refresh, "setIndeterminateTint", theme.textSecondary)
        }

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

        // 更新时间（或提示文案，三档布局均有，左下角显示"更新于 M月d日 HH:mm"）
        val message = hint
            ?: json?.optString("updatedAt", "")?.let { "更新于 $it" }
        if (!message.isNullOrEmpty()) {
            views.setViewVisibility(R.id.tv_update, android.view.View.VISIBLE)
            views.setTextViewText(R.id.tv_update, message)
            views.setTextColor(R.id.tv_update, theme.textTertiary)
        } else {
            views.setViewVisibility(R.id.tv_update, android.view.View.GONE)
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
