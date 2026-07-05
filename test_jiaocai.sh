/// 教材查询 API 测试脚本
/// 运行方式：在 smartphone 项目目录下 flutter run 启动后触发
///
/// 手动测试步骤：
/// 1. 登录 app
/// 2. 打开教材查询页面（触发 JiaocaiService.fetchOrders）
/// 3. 查看 debug 输出的 HTTP 请求日志
///
/// 如需独立测试 API，可复制以下 curl 命令在终端运行:
///
/// # 替换 COOKIE 为实际值
/// COOKIE="JSESSIONID=...; MOD_AUTH_CAS=..."
///
/// # 1. 获取 BBWID
/// curl -s 'https://ehall.yibinu.edu.cn/jwapp/sys/jwpubapp/modules/bb/cxjwggbbcs.do' \
///   -H 'Cookie: $COOKIE' \
///   -H 'X-Requested-With: XMLHttpRequest' \
///   --data '*search=true&pageSize=999'
///
/// # 2. 获取 BBKEY 表单
/// curl -s 'https://ehall.yibinu.edu.cn/jwapp/sys/frReport2/show.do?reportlet=cjcx/xsjcdgfytj.cpt&XH=240105118' \
///   -H 'Cookie: $COOKIE' \
///   -o step2_response.html
///
/// # 3. 提交表单（处理 302）
/// # 从 step2_response.html 中提取 BBKEY
/// BBKEY="$(grep -oP 'name="BBKEY" value="\K[^"]+' step2_response.html)"
/// curl -s -D - -o step3_response.html \
///   'https://ehall.yibinu.edu.cn/jwapp/sys/frReport2/show.do' \
///   -H 'Cookie: $COOKIE' \
///   --data "BBKEY=$BBKEY&XH=240105118&reportlet=cjcx/xsjcdgfytj.cpt"
///
/// # 查看响应头，找到 Location
/// # 然后 GET 那个 URL
/// echo "检查 step3_response.html 中的 sessionID..."
/// 