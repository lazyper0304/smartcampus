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
 * 摸鱼日历桌面组件：
 *  - 数据源：WidgetPrefs.KEY_MOYU（Flutter 侧在摸鱼卡片/管理页加载时写入；
 *    节日存「未来日期表」而非写死天数，daysLeft 由原生按设备时钟现算）
 *  - 布局：按组件实际宽度切换 small/medium/large
 *  - 点击：打开 App 并进入摸鱼日历管理页（extra target=moyu）
 */
class MoyuWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (widgetId in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(widgetId)
            val widthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val layout = WidgetRenderer.moyuLayoutFor(widthDp)
            val views = WidgetRenderer.renderMoyu(
                context,
                layout,
                WidgetPrefs.loadMoyuData(context),
            )
            bindClick(context, views)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        val widthDp = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val layout = WidgetRenderer.moyuLayoutFor(widthDp)
        val views = WidgetRenderer.renderMoyu(
            context,
            layout,
            WidgetPrefs.loadMoyuData(context),
        )
        bindClick(context, views)
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetUpdater.updateAllMoyuWidgets(context)
        // 启动定时刷新（跨天自动重算「还有几天」）；重复添加同 provider 时幂等
        WidgetRefreshScheduler.schedule(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        // 所有课程与摸鱼组件均已移除时才取消定时刷新
        if (!WidgetUpdater.hasAnyCourseWidget(context) &&
            !WidgetUpdater.hasAnyMoyuWidget(context)
        ) {
            WidgetRefreshScheduler.cancel(context)
        }
    }

    private fun bindClick(context: Context, views: RemoteViews) {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            putExtra(WidgetPrefs.EXTRA_TARGET, "moyu")
        }
        val pi = PendingIntent.getActivity(
            context,
            "moyu".hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.widget_root, pi)
    }

    companion object {
        fun ids(context: Context): IntArray =
            AppWidgetManager.getInstance(context)
                .getAppWidgetIds(ComponentName(context, MoyuWidgetProvider::class.java))
    }
}

/** 摸鱼日历固定尺寸基类：布局写死，不依赖 OPTION_APPWIDGET_MIN_WIDTH。 */
abstract class FixedMoyuWidgetProvider : AppWidgetProvider() {

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
        WidgetRefreshScheduler.schedule(context)
    }

    final override fun onDisabled(context: Context) {
        super.onDisabled(context)
        if (!WidgetUpdater.hasAnyCourseWidget(context) &&
            !WidgetUpdater.hasAnyMoyuWidget(context)
        ) {
            WidgetRefreshScheduler.cancel(context)
        }
    }

    private fun render(
        context: Context,
        manager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (widgetId in appWidgetIds) {
            val views = WidgetRenderer.renderMoyu(
                context,
                layoutId,
                WidgetPrefs.loadMoyuData(context),
            )
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                putExtra(WidgetPrefs.EXTRA_TARGET, "moyu")
            }
            val pi = PendingIntent.getActivity(
                context,
                "moyu".hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, pi)
            manager.updateAppWidget(widgetId, views)
        }
    }

    fun ids(context: Context): IntArray =
        AppWidgetManager.getInstance(context)
            .getAppWidgetIds(ComponentName(context, this.javaClass))
}

/** 摸鱼日历 · 4x2 固定尺寸（横向长条，最近 3 项目标，复用 medium 布局） */
class MoyuWidgetProvider4x2 : FixedMoyuWidgetProvider() {
    override val layoutId: Int get() = R.layout.widget_moyu_medium
}

/** 摸鱼日历 · 4x4 固定尺寸（详情，最近 5 项目标 + 更新时间，复用 large 布局） */
class MoyuWidgetProvider4x4 : FixedMoyuWidgetProvider() {
    override val layoutId: Int get() = R.layout.widget_moyu_large
}
