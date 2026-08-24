package com.smartcampus.smartcampus.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log
import com.smartcampus.smartcampus.MainActivity
import mobile.Mobile

/**
 * 校园 VPN 前台服务 — 建立 TUN 网卡并把 fd 交给 zju-connect 的 gvisor 栈。
 *
 * 分流策略（split tunnel）：仅路由内网网段 10/8、172.16/12、192.168/16，
 * 普通上网流量不走隧道，避免拖慢日常网络。MTU 与 zju-connect 保持一致（1400）。
 */
class YibinVpnService : VpnService() {
    companion object {
        const val EXTRA_CLIENT_IP = "client_ip"
        const val ACTION_STOP = "com.smartcampus.smartcampus.vpn.STOP"
        private const val TAG = "YibinVpn"
        private const val CHANNEL_ID = "vpn_channel"
        private const val NOTIFICATION_ID = 0x5650 // 'VP'
    }

    private var tunInterface: ParcelFileDescriptor? = null
    private var stackThread: Thread? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopTunnel()
            stopSelf()
            return START_NOT_STICKY
        }
        val clientIp = intent?.getStringExtra(EXTRA_CLIENT_IP)
        if (clientIp.isNullOrEmpty()) {
            stopSelf()
            return START_NOT_STICKY
        }
        startForeground(
            NOTIFICATION_ID,
            buildNotification("已连接 · $clientIp"),
        )
        establishTunnel(clientIp)
        return START_STICKY
    }

    /** 建立 TUN 并启动协议栈（阻塞运行，放后台线程） */
    private fun establishTunnel(clientIp: String) {
        if (tunInterface != null) return // 已在运行
        stackThread = Thread {
            try {
                val builder = Builder()
                    .addAddress(clientIp, 32)
                    .addRoute("10.0.0.0", 8)
                    .addRoute("172.16.0.0", 12)
                    .addRoute("192.168.0.0", 16)
                    .setMtu(1400)
                    .setSession("宜院宾果 · 校园VPN")
                tunInterface = builder.establish()
                val fd = tunInterface?.fd
                if (fd == null) {
                    Log.e(TAG, "establish TUN failed")
                    VpnBridge.notifyTunnelStopped()
                    return@Thread
                }
                Log.i(TAG, "TUN established, fd=$fd, starting stack")
                // 阻塞运行直到 TUN 关闭 / 登出；结束后通知 Flutter 掉线
                // （gomobile 将 Go int 映射为 Java long）
                Mobile.startStack(fd.toLong())
                Log.i(TAG, "stack exited")
                tunInterface?.close()
                tunInterface = null
                VpnBridge.notifyTunnelStopped()
            } catch (e: Throwable) {
                Log.e(TAG, "tunnel error", e)
                VpnBridge.notifyTunnelStopped()
            }
        }.also { it.start() }
        VpnBridge.notifyTunnelStarted()
    }

    private fun stopTunnel() {
        try {
            // 关闭 TUN 使 Mobile.startStack 的读写循环退出
            tunInterface?.close()
        } catch (e: Throwable) {
            Log.w(TAG, "close tun: ${e.message}")
        }
        tunInterface = null
        stackThread?.interrupt()
        stackThread = null
    }

    override fun onDestroy() {
        stopTunnel()
        super.onDestroy()
    }

    override fun onRevoke() {
        // 系统或用户在设置中撤销 VPN 权限
        stopTunnel()
        super.onRevoke()
    }

    // ==================== 前台通知 ====================

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "校园VPN",
            NotificationManager.IMPORTANCE_LOW,
        ).apply { description = "校园 VPN 连接状态" }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(text: String): Notification {
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("校园 VPN")
            .setContentText(text)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .build()
    }
}
