package com.smartcampus.smartcampus.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 定时刷新广播接收器：AlarmManager 每 30 分钟触发一次，
 * 重绘所有课程表/摸鱼日历/倒计时组件（按当前日期重新计算「今天」/「还有几天」），
 * 不涉及电费实时查询/网络请求。
 */
class CourseWidgetAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        WidgetUpdater.updateAllCourseWidgets(context)
        // 摸鱼日历与倒计时的「还有几天」同样需要跨天自动翻正
        WidgetUpdater.updateAllMoyuWidgets(context)
        WidgetUpdater.updateAllCountdownWidgets(context)
    }
}
