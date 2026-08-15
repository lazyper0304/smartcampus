package com.smartcampus.smartcampus.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.RemoteViews
import com.smartcampus.smartcampus.MainActivity
import com.smartcampus.smartcampus.R

/**
 * 固定尺寸桌面组件：部分系统（如部分 ColorOS / 三方桌面）不支持拖拽放大，
 * 为此提供 4x2 / 4x4 两个固定尺寸条目，布局在代码中写死，不依赖 OPTION_APPWIDGET_MIN_WIDTH。
 *
 * 与可拖拽组件（CourseWidgetProvider / DianfeiWidgetProvider）的关系：
 *  - 可拖拽组件：按当前实际宽度三档切换布局（small/medium/large）
 *  - 固定组件：始终渲染子类声明的 layoutId（medium=4x2 横向 / large=4x4 详情）
 */
abstract class FixedCourseWidgetProvider : AppWidgetProvider() {

    /** 固定使用的课程布局 */
    abstract val layoutId: Int

    final override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        render(context, appWidgetManager, appWidgetIds)
    }

    final override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        render(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    final override fun onEnabled(context: Context) {
        super.onEnabled(context)
        val manager = AppWidgetManager.getInstance(context)
        render(context, manager, ids(context))
    }

    private fun render(
        context: Context,
        manager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (widgetId in appWidgetIds) {
            val views = WidgetRenderer.renderCourse(
                context,
                layoutId,
                WidgetPrefs.loadCourseData(context),
            )
            bindClick(context, views, "course")
            manager.updateAppWidget(widgetId, views)
        }
    }

    private fun bindClick(context: Context, views: RemoteViews, target: String) {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            putExtra(WidgetPrefs.EXTRA_TARGET, target)
        }
        val pi = PendingIntent.getActivity(
            context,
            target.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.widget_root, pi)
    }

    fun ids(context: Context): IntArray =
        AppWidgetManager.getInstance(context)
            .getAppWidgetIds(ComponentName(context, this.javaClass))
}

/** 课程表 · 4x2 固定尺寸（横向长条，最多 3 节课，复用 medium 布局） */
class CourseWidgetProvider4x2 : FixedCourseWidgetProvider() {
    override val layoutId: Int get() = R.layout.widget_course_medium
}

/** 课程表 · 4x4 固定尺寸（详情，最多 5 节课 + 更新时间） */
class CourseWidgetProvider4x4 : FixedCourseWidgetProvider() {
    override val layoutId: Int get() = R.layout.widget_course_large
}

abstract class FixedDianfeiWidgetProvider : AppWidgetProvider() {

    /** 固定使用的电费布局 */
    abstract val layoutId: Int

    final override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        render(context, appWidgetManager, appWidgetIds)
    }

    final override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        render(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    final override fun onEnabled(context: Context) {
        super.onEnabled(context)
        val manager = AppWidgetManager.getInstance(context)
        render(context, manager, ids(context))
    }

    private fun render(
        context: Context,
        manager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (widgetId in appWidgetIds) {
            val views = WidgetRenderer.renderDianfei(
                context,
                layoutId,
                WidgetPrefs.loadDianfeiData(context),
            )
            bindClick(context, views, "dianfei")
            manager.updateAppWidget(widgetId, views)
        }
    }

    private fun bindClick(context: Context, views: RemoteViews, target: String) {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            putExtra(WidgetPrefs.EXTRA_TARGET, target)
        }
        val pi = PendingIntent.getActivity(
            context,
            target.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.widget_root, pi)
    }

    fun ids(context: Context): IntArray =
        AppWidgetManager.getInstance(context)
            .getAppWidgetIds(ComponentName(context, this.javaClass))
}

/** 电费 · 4x2 固定尺寸（横向长条：余额 + 状态 + 本月统计，复用 medium 布局） */
class DianfeiWidgetProvider4x2 : FixedDianfeiWidgetProvider() {
    override val layoutId: Int get() = R.layout.widget_dianfei_medium
}

/** 电费 · 4x4 固定尺寸（详情：余额 + 三统计 + 近 7 日条形图 + 更新时间） */
class DianfeiWidgetProvider4x4 : FixedDianfeiWidgetProvider() {
    override val layoutId: Int get() = R.layout.widget_dianfei_large
}
