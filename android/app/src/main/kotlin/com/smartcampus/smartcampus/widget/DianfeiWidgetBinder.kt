package com.smartcampus.smartcampus.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.smartcampus.smartcampus.MainActivity
import com.smartcampus.smartcampus.R

/**
 * 电费组件统一构建/绑定逻辑（可拖拽 + 4x2/4x4 固定尺寸共用）：
 *  - 渲染 RemoteViews（WidgetRenderer）
 *  - 绑定整卡点击（打开 App 跳电费页）
 *  - 绑定右上角刷新按钮（广播 APPWIDGET_UPDATE 触发 onUpdate → 重新实时查询）
 *  - 有查询参数时发起原生端实时查询（无需 cookie），成功后回写并重绘
 */
object DianfeiWidgetBinder {

    /**
     * 渲染 + 绑定（不发起查询）：用于数据推送后的重绘、尺寸变化重绘。
     */
    fun build(
        context: Context,
        layoutId: Int,
        provider: Class<out AppWidgetProvider>,
        widgetId: Int,
        refreshing: Boolean = false,
        hint: String? = null,
    ): RemoteViews {
        val views = WidgetRenderer.renderDianfei(
            context,
            layoutId,
            WidgetPrefs.loadDianfeiData(context),
            refreshing = refreshing,
            hint = hint,
        )
        bindOpenApp(context, views)
        bindRefresh(context, views, provider, widgetId)
        return views
    }

    /**
     * onUpdate 入口：渲染当前数据；若已绑定电表（有查询参数）则发起原生端实时查询，
     * 查询成功后回写 SharedPreferences 并重绘组件。
     */
    fun renderWithQuery(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
        layoutId: Int,
        provider: Class<out AppWidgetProvider>,
    ) {
        val params = WidgetPrefs.loadDianfeiParams(context)
        val stored = WidgetPrefs.loadDianfeiData(context)

        if (params == null) {
            // 未绑定电表：渲染已存数据（无数据时大号布局提示去 App 绑定）
            val hint = if (stored == null && layoutId == R.layout.widget_dianfei_large) {
                "请先在App中绑定电表"
            } else {
                null
            }
            manager.updateAppWidget(widgetId, build(context, layoutId, provider, widgetId, hint = hint))
            return
        }

        // 发起实时查询（节流/并发被跳过时不显示刷新态，避免卡在进度圈）
        val started = DianfeiFetcher.startQuery(context, params) { json ->
            if (json != null) {
                WidgetPrefs.saveDianfeiData(context, json)
                manager.updateAppWidget(widgetId, build(context, layoutId, provider, widgetId))
            } else {
                // 网络失败：回退显示旧数据 + 大号布局提示
                val hint = if (layoutId == R.layout.widget_dianfei_large) "刷新失败" else null
                manager.updateAppWidget(widgetId, build(context, layoutId, provider, widgetId, hint = hint))
            }
        }
        manager.updateAppWidget(
            widgetId,
            build(context, layoutId, provider, widgetId, refreshing = started),
        )
    }

    /** 整卡点击：打开 App 并跳转电费页 */
    private fun bindOpenApp(context: Context, views: RemoteViews) {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            putExtra(WidgetPrefs.EXTRA_TARGET, "dianfei")
        }
        val pi = PendingIntent.getActivity(
            context,
            "dianfei".hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.widget_root, pi)
    }

    /** 右上角刷新按钮：广播 APPWIDGET_UPDATE 触发本 Provider 的 onUpdate */
    private fun bindRefresh(
        context: Context,
        views: RemoteViews,
        provider: Class<out AppWidgetProvider>,
        widgetId: Int,
    ) {
        val intent = Intent(context, provider).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(widgetId))
        }
        // requestCode 用 widgetId 偏移，避免与整卡点击 PendingIntent 冲突
        val pi = PendingIntent.getBroadcast(
            context,
            100_000 + widgetId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.btn_dianfei_refresh, pi)
    }
}
