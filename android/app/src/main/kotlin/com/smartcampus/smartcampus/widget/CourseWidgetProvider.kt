package com.smartcampus.smartcampus.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.smartcampus.smartcampus.MainActivity
import com.smartcampus.smartcampus.R

/**
 * 课程表桌面组件：
 *  - 数据源：WidgetPrefs（Flutter 侧在课表加载后写入）
 *  - 布局：按组件实际宽度切换 small/medium/large
 *  - 点击：打开 App 并跳转课表页（extra target=course）
 */
class CourseWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (widgetId in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(widgetId)
            val widthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val layout = WidgetRenderer.courseLayoutFor(widthDp)
            val views = WidgetRenderer.renderCourse(
                context,
                layout,
                WidgetPrefs.loadCourseData(context),
            )
            bindClick(context, views, "course")
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        // 用户拖拽改变大小 → 按新尺寸切换布局
        val widthDp =
            newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val layout = WidgetRenderer.courseLayoutFor(widthDp)
        val views = WidgetRenderer.renderCourse(
            context,
            layout,
            WidgetPrefs.loadCourseData(context),
        )
        bindClick(context, views, "course")
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        // 首次添加组件：把当前已缓存数据立即渲染（无数据时显示占位）
        WidgetUpdater.updateCourseWidgets(context)
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

    companion object {
        fun ids(context: Context): IntArray =
            AppWidgetManager.getInstance(context)
                .getAppWidgetIds(ComponentName(context, CourseWidgetProvider::class.java))
    }
}
