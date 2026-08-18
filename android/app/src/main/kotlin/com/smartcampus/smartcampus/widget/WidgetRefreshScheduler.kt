package com.smartcampus.smartcampus.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent

/**
 * 课程表组件定时刷新调度器。
 *
 * 组件「今天」的星期几必须在原生渲染时按当前日期计算（见 WidgetRenderer），
 * 但 widget_info 的 updatePeriodMillis=0，系统不会自动重绘。
 * 因此这里用 AlarmManager 周期性触发一次轻量重绘（仅读 SharedPreferences + 重建 RemoteViews，
 * 无网络请求），保证跨天后「今天」能在几十分钟内自动翻正，无需打开 App。
 */
object WidgetRefreshScheduler {

    private const val ACTION = "com.smartcampus.smartcampus.widget.COURSE_REFRESH"
    private const val REQUEST_CODE = 0x4321

    /** 调度：每 30 分钟触发一次课程组件重绘（setRepeating 为系统批处理，无需精确闹钟权限） */
    fun schedule(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pi = pendingIntent(context) ?: return
        // 首次延迟 1 分钟，避免与添加组件时的渲染挤占；之后每 30 分钟一次
        val first = System.currentTimeMillis() + 60_000L
        am.setRepeating(
            AlarmManager.RTC,
            first,
            AlarmManager.INTERVAL_HALF_HOUR,
            pi,
        )
    }

    /** 取消调度（最后一个课程组件被移除时调用） */
    fun cancel(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pi = pendingIntent(context) ?: return
        am.cancel(pi)
    }

    private fun pendingIntent(context: Context): PendingIntent? {
        val intent = Intent(context, CourseWidgetAlarmReceiver::class.java).apply {
            action = ACTION
        }
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
