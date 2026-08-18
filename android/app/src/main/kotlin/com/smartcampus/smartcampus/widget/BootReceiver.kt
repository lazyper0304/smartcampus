package com.smartcampus.smartcampus.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 开机广播接收器：设备重启后 AlarmManager 的定时任务会被清空，
 * 这里在重启完成后重新调度课程表组件的定时刷新（前提是用户添加了课程组件）。
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        if (WidgetUpdater.hasAnyCourseWidget(context)) {
            WidgetRefreshScheduler.schedule(context)
        }
    }
}
