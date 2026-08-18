package com.smartcampus.smartcampus.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 定时刷新广播接收器：AlarmManager 每 30 分钟触发一次，
 * 仅重绘所有课程表组件（按当前日期重新计算「今天」），不涉及电费组件/网络请求。
 */
class CourseWidgetAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        WidgetUpdater.updateAllCourseWidgets(context)
    }
}
