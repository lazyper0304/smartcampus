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
 * 电费桌面组件：
 *  - 数据源：WidgetPrefs（Flutter 侧在电费查询后写入）
 *  - 布局：按组件实际宽度切换 small/medium/large
 *  - 点击：打开 App 并跳转电费页（extra target=dianfei）
 */
class DianfeiWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (widgetId in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(widgetId)
            val widthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val layout = WidgetRenderer.dianfeiLayoutFor(widthDp)
            val views = WidgetRenderer.renderDianfei(
                context,
                layout,
                WidgetPrefs.loadDianfeiData(context),
            )
            bindClick(context, views, "dianfei")
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        val widthDp =
            newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val layout = WidgetRenderer.dianfeiLayoutFor(widthDp)
        val views = WidgetRenderer.renderDianfei(
            context,
            layout,
            WidgetPrefs.loadDianfeiData(context),
        )
        bindClick(context, views, "dianfei")
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetUpdater.updateDianfeiWidgets(context)
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
                .getAppWidgetIds(ComponentName(context, DianfeiWidgetProvider::class.java))
    }
}
