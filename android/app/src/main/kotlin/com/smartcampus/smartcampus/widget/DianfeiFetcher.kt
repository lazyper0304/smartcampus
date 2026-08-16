package com.smartcampus.smartcampus.widget

import android.content.Context
import android.os.Handler
import android.os.Looper
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.nio.charset.Charset
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 电费实时查询引擎（原生端，桌面组件进程直接调用）。
 *
 * 电费接口全部为无需 cookie 的普通 POST（openId/meterId 在表单体中），
 * 因此桌面组件可在自身进程中直接发起 HTTP 查询，不再依赖 Flutter 推送的快照缓存。
 *
 * 与 Flutter 侧 DianfeiService 的 WebView JS 抓取等价，输出与
 * WidgetDianfeiData.toJson() 相同的 JSON 结构（含近 7 日条形图数据）。
 */
object DianfeiFetcher {

    private const val BASE = "http://dfcz.yibinu.edu.cn"
    private const val TAG = "DianfeiFetcher"

    /** 两次查询最小间隔，防止刷新连点/重复触发打爆接口 */
    private const val MIN_INTERVAL_MS = 10_000L
    private const val KEY_LAST_QUERY = "widget_dianfei_last_query"

    private const val TIMEOUT_MS = 10_000

    private val mainHandler = Handler(Looper.getMainLooper())
    private val refreshing = AtomicBoolean(false)

    /**
     * 发起一次后台实时查询。
     *
     * @return true = 本次真正发起了查询（回调必然被调用一次）；false = 节流/并发跳过（回调不会调用）。
     * 回调在主线程执行，[json] 为 null 表示网络完全不可达。
     */
    fun startQuery(
        context: Context,
        params: WidgetPrefs.DianfeiParams,
        onResult: (json: String?) -> Unit,
    ): Boolean {
        val now = System.currentTimeMillis()
        val prefs = WidgetPrefs.prefs(context)
        if (now - prefs.getLong(KEY_LAST_QUERY, 0L) < MIN_INTERVAL_MS) return false
        if (!refreshing.compareAndSet(false, true)) return false
        prefs.edit().putLong(KEY_LAST_QUERY, now).apply()

        Thread {
            val json = try {
                query(params)
            } catch (e: Exception) {
                android.util.Log.w(TAG, "query failed: ${e.message}")
                null
            } finally {
                refreshing.set(false)
            }
            mainHandler.post { onResult(json) }
        }.start()
        return true
    }

    /** 同步执行四步查询，输出组件 JSON；网络完全不可达时返回 null。 */
    private fun query(params: WidgetPrefs.DianfeiParams): String? {
        // 1. openId → wechatUserId
        val userBody = try {
            post("/kddz/electricmeterpost/index", "openId=" + enc(params.openId))
        } catch (e: Exception) {
            return null
        }
        var wechatUserId = ""
        val uj = parse(userBody)
        if (uj?.optInt("code") == 200 && !uj.isNull("data")) {
            wechatUserId = uj.optJSONObject("data")?.optString("wechatId", "") ?: ""
        }

        // 2. 余量查询（依赖 wechatUserId + meterId + isAfterMoney）
        var balance = "--"
        var total = "--"
        var status = ""
        var price = 0.55
        if (wechatUserId.isNotEmpty()) {
            val yuBody = try {
                post(
                    "/kddz/electricmeterpost/electricMeterQuery",
                    "wechatUserId=" + enc(wechatUserId) +
                        "&electricUserUid=" + enc(params.meterId) +
                        "&isAfterMoney=" + params.isAfterMoney,
                )
            } catch (e: Exception) {
                null
            }
            val yj = yuBody?.let { parse(it) }
            if (yj?.optInt("code") == 200 && !yj.isNull("data")) {
                val d = yj.optJSONObject("data")
                if (d != null) {
                    balance = fmt1(d.optDouble("shengyu", 0.0))
                    total = fmt1(d.optDouble("leiji", 0.0))
                    status = d.optString("zhuangtai", "")
                    price = d.optDouble("price", 0.55)
                }
            }
        }

        // 3. 月度汇总（仅需 meterId）
        var monthKwh = "--"
        var monthMoney = "--"
        val cal = Calendar.getInstance()
        val ym = String.format(Locale.US, "%04d-%02d", cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1)
        val monthBody = try {
            post(
                "/kddz/electricmeterpost/GetMonthEleAndMoneyList",
                "meterid=" + enc(params.meterId) + "&startMonth=" + ym + "-01&endMonth=" + ym + "-01",
            )
        } catch (e: Exception) {
            null
        }
        val mj = monthBody?.let { parse(it) }
        if (mj?.optInt("code") == 200 && !mj.isNull("data")) {
            val list = mj.optJSONObject("data")?.optJSONArray("data") ?: JSONArray()
            if (list.length() > 0) {
                val first = list.optJSONObject(0)
                if (first != null) {
                    monthKwh = fmt1(first.optDouble("total", 0.0))
                    monthMoney = fmt2(first.optDouble("money", 0.0))
                }
            }
        }

        // 4. 日度明细（30 天，仅需 meterId）
        val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        val start = Calendar.getInstance().apply { add(Calendar.DAY_OF_MONTH, -29) }
        val dayBody = try {
            post(
                "/kddz/electricmeterpost/GetMonthDayEleList",
                "meterid=" + enc(params.meterId) +
                    "&startTime=" + sdf.format(start.time) +
                    "&endTime=" + sdf.format(cal.time),
            )
        } catch (e: Exception) {
            null
        }
        val fullDays = mutableListOf<JSONObject>()
        val dj = dayBody?.let { parse(it) }
        if (dj?.optInt("code") == 200 && !dj.isNull("data")) {
            val list = dj.optJSONObject("data")?.optJSONArray("data") ?: JSONArray()
            for (i in 0 until list.length()) {
                val e = list.optJSONObject(i) ?: continue
                val kwh = e.optDouble("total", 0.0)
                fullDays.add(
                    JSONObject()
                        .put("label", dayLabel(e.optString("endtime", "")))
                        .put("kwh", kwh)
                        .put("kwhText", fmt1(kwh)),
                )
            }
        }
        // 与 Flutter buildDianfeiData 一致：只保留最近 7 天
        val days = JSONArray()
        val recent = if (fullDays.size > 7) fullDays.subList(fullDays.size - 7, fullDays.size) else fullDays
        for (d in recent) days.put(d)

        val now = Calendar.getInstance()
        val updatedAt = String.format(
            Locale.US, "%d月%d日 %02d:%02d",
            now.get(Calendar.MONTH) + 1,
            now.get(Calendar.DAY_OF_MONTH),
            now.get(Calendar.HOUR_OF_DAY),
            now.get(Calendar.MINUTE),
        )
        return JSONObject()
            .put("balance", balance)
            .put("status", status)
            .put("monthKwh", monthKwh)
            .put("monthMoney", monthMoney)
            .put("total", total)
            .put("days", days)
            .put("updatedAt", updatedAt)
            .toString()
    }

    // ==================== HTTP ====================

    /** 表单 POST，返回解码后的响应文本；非 2xx 或网络错误抛异常。 */
    private fun post(path: String, body: String): String {
        val conn = URL(BASE + path).openConnection() as HttpURLConnection
        try {
            conn.requestMethod = "POST"
            conn.connectTimeout = TIMEOUT_MS
            conn.readTimeout = TIMEOUT_MS
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
            conn.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }

            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val bytes = stream?.let { readAll(it) } ?: ByteArray(0)
            return decodeText(bytes)
        } finally {
            conn.disconnect()
        }
    }

    private fun readAll(input: java.io.InputStream): ByteArray {
        val buffer = ByteArrayOutputStream()
        input.use { ins ->
            val chunk = ByteArray(4096)
            while (true) {
                val n = ins.read(chunk)
                if (n < 0) break
                buffer.write(chunk, 0, n)
            }
        }
        return buffer.toByteArray()
    }

    /** 优先 UTF-8；若出现替换字符则按 GBK 重新解码（老系统常返回 GBK）。 */
    private fun decodeText(bytes: ByteArray): String {
        val utf8 = String(bytes, Charsets.UTF_8)
        if (!utf8.contains('\uFFFD')) return utf8
        return String(bytes, Charset.forName("GBK"))
    }

    private fun parse(text: String): JSONObject? = try {
        JSONObject(text)
    } catch (e: Exception) {
        null
    }

    private fun enc(v: String): String = URLEncoder.encode(v, "UTF-8")

    private fun fmt1(v: Double): String = String.format(Locale.US, "%.1f", v)

    private fun fmt2(v: Double): String = String.format(Locale.US, "%.2f", v)

    /** "2026-08-15" → "8/15"（与 Flutter buildDianfeiData 一致） */
    private fun dayLabel(endtime: String): String {
        if (endtime.length < 10) return endtime
        return try {
            val m = endtime.substring(5, 7).toInt()
            val d = endtime.substring(8, 10).toInt()
            "$m/$d"
        } catch (e: Exception) {
            endtime
        }
    }
}
