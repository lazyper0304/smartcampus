package com.smartcampus.smartcampus.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import com.smartcampus.smartcampus.R

/**
 * 组件批量更新入口：Flutter 侧数据写入后调用（经 MainActivity MethodChannel），
 * 遍历已添加的组件 id 重新渲染。
 *  - 可拖拽组件（2x2 起）：按各自当前尺寸（OPTION_APPWIDGET_MIN_WIDTH）选布局
 *  - 固定尺寸组件（4x2 / 4x4）：布局写死
 */
object WidgetUpdater {

    fun updateCourseWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        for (widgetId in CourseWidgetProvider.ids(context)) {
            val widthDp =
                manager.getAppWidgetOptions(widgetId)
                    .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val layout = WidgetRenderer.courseLayoutFor(widthDp)
            manager.updateAppWidget(
                widgetId,
                WidgetRenderer.renderCourse(
                    context,
                    layout,
                    WidgetPrefs.loadCourseData(context),
                ),
            )
        }
    }

    fun updateDianfeiWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        for (widgetId in DianfeiWidgetProvider.ids(context)) {
            val widthDp =
                manager.getAppWidgetOptions(widgetId)
                    .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val layout = WidgetRenderer.dianfeiLayoutFor(widthDp)
            manager.updateAppWidget(
                widgetId,
                DianfeiWidgetBinder.build(
                    context,
                    layout,
                    DianfeiWidgetProvider::class.java,
                    widgetId,
                ),
            )
        }
    }

    /** 课程表 · 4x2 固定尺寸 */
    fun updateCourse4x2Widgets(context: Context) {
        updateFixedCourse(context, CourseWidgetProvider4x2::class.java, R.layout.widget_course_medium)
    }

    /** 课程表 · 4x4 固定尺寸 */
    fun updateCourse4x4Widgets(context: Context) {
        updateFixedCourse(context, CourseWidgetProvider4x4::class.java, R.layout.widget_course_large)
    }

    /** 电费 · 4x2 固定尺寸 */
    fun updateDianfei4x2Widgets(context: Context) {
        updateFixedDianfei(context, DianfeiWidgetProvider4x2::class.java, R.layout.widget_dianfei_medium)
    }

    /** 电费 · 4x4 固定尺寸 */
    fun updateDianfei4x4Widgets(context: Context) {
        updateFixedDianfei(context, DianfeiWidgetProvider4x4::class.java, R.layout.widget_dianfei_large)
    }

    private fun updateFixedCourse(
        context: Context,
        provider: Class<out AppWidgetProvider>,
        layout: Int,
    ) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, provider))
        for (widgetId in ids) {
            manager.updateAppWidget(
                widgetId,
                WidgetRenderer.renderCourse(context, layout, WidgetPrefs.loadCourseData(context)),
            )
        }
    }

    private fun updateFixedDianfei(
        context: Context,
        provider: Class<out AppWidgetProvider>,
        layout: Int,
    ) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, provider))
        for (widgetId in ids) {
            manager.updateAppWidget(
                widgetId,
                DianfeiWidgetBinder.build(context, layout, provider, widgetId),
            )
        }
    }

    /** 全量刷新所有课程组件（2x2 可拖拽 + 4x2/4x4 固定） */
    fun updateAllCourseWidgets(context: Context) {
        updateCourseWidgets(context)
        updateCourse4x2Widgets(context)
        updateCourse4x4Widgets(context)
    }

    /** 全量刷新所有电费组件（2x2 可拖拽 + 4x2/4x4 固定） */
    fun updateAllDianfeiWidgets(context: Context) {
        updateDianfeiWidgets(context)
        updateDianfei4x2Widgets(context)
        updateDianfei4x4Widgets(context)
    }

    /** 主题切换后全量刷新（可拖拽 + 固定尺寸全部） */
    fun updateAll(context: Context) {
        updateAllCourseWidgets(context)
        updateAllDianfeiWidgets(context)
    }

    /** 是否存在任意课程表组件（用于决定是否调度/取消定时刷新） */
    fun hasAnyCourseWidget(context: Context): Boolean {
        return CourseWidgetProvider.ids(context).isNotEmpty() ||
            AppWidgetManager.getInstance(context)
                .getAppWidgetIds(ComponentName(context, CourseWidgetProvider4x2::class.java))
                .isNotEmpty() ||
            AppWidgetManager.getInstance(context)
                .getAppWidgetIds(ComponentName(context, CourseWidgetProvider4x4::class.java))
                .isNotEmpty()
    }
}
