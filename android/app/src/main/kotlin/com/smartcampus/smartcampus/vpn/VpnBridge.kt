package com.smartcampus.smartcampus.vpn

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import mobile.CaptchaProvider
import mobile.Mobile
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * 校园 VPN 桥接 — 基于 zju-connect gomobile AAR（开源 EasyConnect 协议实现）。
 *
 * 流程：Mobile.login(server, user, pwd) → 返回虚拟内网 IP（失败返回空串）
 *      → 启动 YibinVpnService 建立 TUN → Mobile.startStack(fd) 接管分流。
 * 断开：停止服务（关闭 TUN）→ Mobile.logout()。
 */
object VpnBridge {
    private const val TAG = "YibinVpn"
    private val mainHandler = Handler(Looper.getMainLooper())

    /** 默认接入主机名（zju-connect 要求纯主机名，禁带 scheme） */
    private const val DEFAULT_VPN_HOST = "vpn.yibinu.edu.cn"

    /**
     * 归一化服务器地址：去掉 scheme 与尾部斜杠，只留主机名。
     * zju-connect 内部自拼 https://<host>/por/login_auth.csp，
     * 传入 "https://vpn.yibinu.edu.cn" 会拼成 https://https://...（DNS 解析
     * hostname="https" 失败）。UI 层可继续以完整 URL 形式存储展示。
     */
    fun normalizeServer(raw: String): String {
        var s = raw.trim()
            .removePrefix("https://")
            .removePrefix("http://")
            .trimEnd('/')
        if (s.isEmpty()) s = DEFAULT_VPN_HOST
        return s
    }

    /** Flutter 事件出口（MainActivity 注册） */
    private var onEvent: ((Map<String, Any?>) -> Unit)? = null

    /**
     * 验证码请求出口：参数 (base64图片, 结果回调)。
     * 由 MainActivity 注入（经 MethodChannel 弹 Flutter 对话框）。
     */
    private var captchaRequester: ((String, (String) -> Unit) -> Unit)? = null

    /** 防并发登录（gomobile login 为阻塞调用，内部有互斥但外部也拦一层） */
    @Volatile
    private var connecting = false

    fun setEventSink(sink: ((Map<String, Any?>) -> Unit)?) {
        onEvent = sink
    }

    fun setCaptchaRequester(requester: ((String, (String) -> Unit) -> Unit)?) {
        captchaRequester = requester
    }

    /**
     * 注册图形验证码回调（幂等）。学校服务器强制验证码（RndImg=1），
     * Go 侧拉取 rand_code.csp 图片后经此回调阻塞等待用户输入。
     * 超时 3 分钟返回空串视为放弃。
     */
    private fun ensureCaptchaBridge() {
        Mobile.setCaptchaProvider(object : CaptchaProvider {
            override fun getCaptcha(imageBase64: String?): String {
                val requester = captchaRequester ?: return ""
                val latch = CountDownLatch(1)
                val code = AtomicReference("")
                mainHandler.post {
                    requester(imageBase64 ?: "") { c ->
                        code.set(c ?: "")
                        latch.countDown()
                    }
                }
                latch.await(3, TimeUnit.MINUTES)
                return code.get()
            }
        })
    }

    private fun emit(type: String, payload: Map<String, Any?> = emptyMap()) {
        mainHandler.post { onEvent?.invoke(payload + mapOf("type" to type)) }
    }

    /**
     * 连接（阻塞式登录，必须在后台线程调用；MethodChannel 结果经主线程回传）。
     * 成功后启动 VpnService 建立 TUN 并把 fd 交给 startStack。
     */
    fun connectAsync(
        context: Context,
        username: String,
        password: String,
        server: String,
        debugLog: Boolean = false,
        onResult: (clientIp: String?) -> Unit,
    ) {
        if (connecting) {
            onResult(null)
            return
        }
        connecting = true
        Thread {
            var clientIp: String? = null
            try {
                val host = normalizeServer(server)
                Log.i(TAG, "login to $host ...")
                ensureCaptchaBridge()
                // debugLogin 开启 zju-connect 详细日志（token/IP 阶段失败点定位）
                clientIp = if (debugLog) {
                    Mobile.debugLogin(host, username, password)
                } else {
                    Mobile.login(host, username, password)
                }
                Log.i(TAG, "login result: $clientIp")
                if (!clientIp.isNullOrEmpty()) {
                    // 启动前台 VPN 服务建立 TUN
                    val intent = Intent(context, YibinVpnService::class.java)
                        .putExtra(YibinVpnService.EXTRA_CLIENT_IP, clientIp)
                    context.startForegroundService(intent)
                } else {
                    // 登录失败：透传 Go 侧真实错误（验证码取消/密码错/网络等）
                    val err = Mobile.lastError()
                    if (!err.isNullOrEmpty()) {
                        emit("error", mapOf("message" to err))
                    }
                }
            } catch (e: Throwable) {
                Log.e(TAG, "login error", e)
                emit("error", mapOf("message" to (e.message ?: "登录异常")))
            } finally {
                connecting = false
                val ip = clientIp
                mainHandler.post { onResult(ip?.takeIf { it.isNotEmpty() }) }
            }
        }.start()
    }

    /** 断开：停服务（关 TUN → startStack 退出）+ 注销登录 */
    fun disconnect(context: Context) {
        Thread {
            try {
                val intent = Intent(context, YibinVpnService::class.java)
                    .setAction(YibinVpnService.ACTION_STOP)
                context.startService(intent)
                Mobile.logout()
                Log.i(TAG, "logged out")
            } catch (e: Throwable) {
                Log.e(TAG, "disconnect error", e)
            }
        }.start()
    }

    /** 隧道已建立（由 YibinVpnService 回调） */
    fun notifyTunnelStarted() = emit("tunnelStarted")

    /** 隧道已断开（非主动断开的掉线场景） */
    fun notifyTunnelStopped() = emit("tunnelStopped")
}
