package com.smartcampus.smartcampus.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.os.Bundle

/**
 * 电费桌面组件（小/中/大三档尺寸，拖拽自动切换）：
 *  - 数据源：WidgetPrefs（App 侧查询后写入的最新快照）
 *  - 实时查询：绑定电表后，每次 onUpdate（添加/右上角刷新按钮）都在组件进程内
 *    直接请求电费接口（无需 cookie），成功后回写并重绘
 *  - 点击：打开 App 并跳转电费页（extra target=dianfei）
 */
class DianfeiWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (widgetId in appWidgetIds) {
            val widthDp = appWidgetManager.getAppWidgetOptions(widgetId)
                .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val layout = WidgetRenderer.dianfeiLayoutFor(widthDp)
            DianfeiWidgetBinder.renderWithQuery(context, appWidgetManager, widgetId, layout, this.javaClass)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        // 尺寸变化只重绘，不触发网络查询
        val widthDp = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val layout = WidgetRenderer.dianfeiLayoutFor(widthDp)
        appWidgetManager.updateAppWidget(
            appWidgetId,
            DianfeiWidgetBinder.build(context, layout, this.javaClass, appWidgetId),
        )
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetUpdater.updateDianfeiWidgets(context)
    }

    companion object {
        fun ids(context: Context): IntArray =
            AppWidgetManager.getInstance(context)
                .getAppWidgetIds(ComponentName(context, DianfeiWidgetProvider::class.java))
    }
}
