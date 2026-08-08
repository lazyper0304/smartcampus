# CHANGELOG

## [Unreleased]

### 🎯 优化
- **widget_test 修复过时断言**：启动页 smoke test 原断言旧登录页文案（'宜宾学院'/'智慧校园登录'），登录页 UI 已更新为'宜院宾果'后恒失败——改为断言当前 SplashPage 品牌与加载文案，并在测试内推进时间结算 SplashPage 的 800ms 延迟（测试环境无凭据 → autoRelogin 立即返回 → 进入登录页，无残留 Timer）。

### 🎨 UI 优化
- **应用网格与首页常用功能图标统一放大**：宫格图标链路整体上调——方块占卡片宽 **0.55 → 0.60**，`appTileGlass` 图标 `(方块×0.52).clamp(20,32)` → **`(方块×0.56).clamp(22,36)`**（应用网格 `_buildAppCard` 与首页 `_QuickAppTile` 同步，两处视觉统一）。手机 4 列图标约 +3~4px（约 15%）、平板/桌面 8 列 +4px（约 12%），方块 0.60 下卡片内垂直空间仍充足（不溢出）。
- **应用页分类切换网格动画修复（图标卡片切换无动画根因）**：`_AppsPage._buildContent` 的 key 原先挂在内部 `GridView`（外层 `LayoutBuilder` 无 key），而 `AnimatedSwitcher` 用 `Widget.canUpdate(runtimeType+key)` 对比 child——同类型同 key 判定为"同一 widget"，切换分类时不播放入场动画（网格瞬间替换）。**修复：key 上移到 `_buildContent` 返回值（`LayoutBuilder`/空状态 `Padding` 均加 `ValueKey('tab_$_tabIndex')`）**——切换 tab 触发 200ms 新网格从右滑入 + 淡入（`reverseDuration: Duration.zero` 旧网格立即移除减半负载）；搜索时 tab 不变、key 不变 → 网格原地更新不动画（与注释意图一致）。
- **应用页分类切换图标动画**：`GlassCategoryBar` 分类项图标由静态切换改为选中动画——选中项图标 `AnimatedScale` 放大 1.18（220ms easeOutCubic）+ 颜色 200ms 平滑过渡（`TweenAnimationBuilder`）。缩放用 `Transform.scale` 不占布局空间，`IntrinsicHeight`/分割线高度不跳动；应用页分类 tab（vertical）与二级页分段（横排）统一生效。

### 🐛 修复
- **LiquidBackground 页面级计数在 build 期间通知监听者**：`initState` 同步 `pageBgCount.value++`（ValueNotifier），而全局垫底层（main.dart builder）的 `ValueListenableBuilder(pageBgCount)` 可能正处 build 阶段 → 触发 "setState() called during build"（widget_test 启动页挂载即暴露）。**修复：页面级背景计数延后到首帧（addPostFrameCallback）递增**，`_counted` 标志保证 dispose 配对递减（防"一帧内卸载"计数错乱）；视觉行为不变。
- **登录页 → 首页过渡时"一段透明"**：`MainScreen` 的 `GlassScaffold(background: SizedBox.shrink())` + 首页/应用页透明 Scaffold 使整个主界面路由完全透明（依赖 Navigator 之外的全局背景）。CupertinoPageRoute 右滑转场期间新路由（主界面）滑入时透明区域直接透出下层路由——用户透过首页看到登录页表单/启动页文字（"一段透明"），转场完成才切到全局背景。**修复：`MainScreen` 背景改为页面级 `LiquidBackground()`**（与登录页/二级页一致）：无自定义背景图时渲染同主题渐变+气泡（不透明，转场不再透出下层）；有自定义背景图时组件内部自动透明、继续透出全局背景图（行为不回归）。
- **CARSI / 邮件系统 / 玻尔科研"必须先访问学科竞赛才能免密登录"根因修复（SSO 会话探测错位）**：`AuthService.ensureFreshSession` 原先用 `verifySession()` 探测 **ehall 业务会话**（`dqxnxq.do`）判断会话新鲜度，但这三个 SSO WebView 免密登录依赖的是 **authserver 的 TGC（CASTGC）**——App 运行期间 TGC 空闲过期（约 30 分钟）远早于 ehall 会话存活期，导致 TGC 已死时误判"会话新鲜"、跳过自动重登、向 WebView 注入死 CASTGC（卡在 CAS 登录页）；学科竞赛因 scjx2 401 自愈会触发 `autoRelogin()` 完整重登刷新 TGC，故"先进学科竞赛再进其他 SSO 应用"才正常。**修复：新增 `SharedHttpClient.verifyCasTgc()`** 直接探测 authserver（带现有 cookie GET 登录页，302 = SSO 放行即 TGC 有效，200 登录表单 = 已过期），`ensureFreshSession` 改用它；CAS 登录 URL 收敛为公共常量 `kCasLoginUrl`（core/http_client.dart，`CasLoginService.yibinLoginUrl` 引用之，消除两处维护漂移）。
- **宫格图标「偏左」+「课表卡片消失」同源修复（Clickable Stack 约束）**：`Clickable`（lib/core/input_adaptation.dart）内部 `Stack` 默认 `topStart` 对齐 + `StackFit.loose` 会把父 tight 约束变 loose——宫格 Column 收缩到内容宽度后被顶到左上（图标偏左，适配后引入 Clickable 的回归）；上一轮改用 `StackFit.expand` 又引入新 bug：expand 用 `constraints.biggest` 生成 tight，在高度无界容器（ListView 内 Column(stretch) 的卡片）里把 ∞ 高度 tight 化 → 布局爆炸「课表卡片消失」。**终版修复：`alignment: Alignment.center` + 保持默认 `StackFit.loose`**（居中但不强制尺寸）——widget test 验证图标居中偏移 = 0、无界高度卡片高度正常 56px 不消失。
- **手机宫格列数与图标过小**：`appGridColumns` 4 列断点 520 → **260**（覆盖含 320 老机所有手机，3 列仅留 < 260）；`appTileGlass` 图标 `size×0.42` → `(size×0.52).clamp(20, 32)`（手机 4 列 15.8px → 20-26px ≈ 适配前 24）；图标方块比例 0.45 → 0.55。

## [1.1.7] - 2026-08-04

### ✨ 新增
- 页面切换改 iOS 风格动画（CupertinoPageRoute 右滑推入 + 边缘返回手势）；主界面 tab 切换 / 应用页分类切换动画。
- 自定义背景图提升到全局（所有页面统一应用，二级页面同步生效）。
- 内容卡片、宫格方块、搜索栏、弹窗全面玻璃化（静态玻璃 + 磨砂玻璃）。
- 更新日志改独立页面（含下拉刷新）；检查更新单窗原地切换。

### 🐛 修复
- GlassCard shader 玻璃在 GLES 设备不渲染（改 BackdropFilter/静态玻璃）。
- BackdropFilter 在列表 overscroll 变透（静态玻璃方案根治）。
- 自定义背景时页面内容丢失。

### 🎯 优化
- 功耗：背景气泡动画降速、列表逐项动画移除、宫格方块去 shader 组件。

## [1.1.9] - 2026-08-07

### 🎯 优化（深度大屏适配 · 平板与 Windows 统一界面）
- **多输入适配（触控 / 鼠标 / 键盘）**：新增 `lib/core/input_adaptation.dart` 模块——① `adaptiveVisualDensity`：全局组件密度随屏宽切换（触控 comfortable 宽松 / 桌面 compact 紧凑，经 MaterialApp builder 动态覆盖全部 Material 组件）；② `Clickable` 通用组件（组合 FocusableActionDetector + GestureDetector）：可点击元素统一获得鼠标手型光标 + 键盘 Enter/空格 激活 + 悬停/焦点高亮（触控零回归）；③ `AppShortcuts` 全局快捷键：Esc 返回上一页（经 MaterialApp.navigatorKey 触达路由栈）。已接入：IosCard、IosListTile、首页/应用页宫格卡片、侧栏项（InkWell mouseCursor）。
- **宫格网格更紧凑**：图标卡片 `childAspectRatio` 0.82 → 0.95（接近正方形，减少图标在卡片内的上下留白）+ `mainAxisSpacing` 14 → 10（行间距收紧），首页常用功能与应用页网格同步。
- **宫格图标间距收紧**：首页常用功能与应用页网格卡片图标与文字的间距 8 → 5，卡片更紧凑。
- **设置页卡片自适应**：`IosListTile` 新增 `scale` 参数（图标容器/图标/标题/副标题按比例缩放，默认 1.0 行为不变）；responsive.dart 新增 `adaptiveCardScale`（`(卡片宽/520).clamp(1.0, 1.2)`）。设置页左右两栏各按实际栏宽计算 scale：个人信息卡（头像/字号/占位图）、外观/账号/关于分组卡同步放大，消除大屏"大卡小内容"；窄屏卡片 < 520 时 scale=1.0，行为与固定尺寸完全一致。
- **宫格卡片字体自适应**：新增 `adaptiveTileFontSize`（responsive.dart）——宫格文字字号随卡片实际宽度缩放（`cardWidth × 0.085`，clamp 10~14），与图标方块 45% 同链路；大屏大卡片字号同步放大（8 列 ≈13）、窄屏小卡片缩小（3 列 ≈10.5），图标与文字比例全程协调。
- **首页两栏内容重排**：宽屏左栏只放「常用功能」宫格（flex 2）、右栏堆叠「今日课程 + 校园新闻」卡片（flex 3），卡片区获得更多阅读宽度；窄屏回落顺序不变（常用功能 → 今日课程 → 新闻）。
- **宫格卡片大小自适应**：首页常用功能与应用页网格的玻璃图标方块不再固定 56px——改为按卡片实际宽度 45% 计算（LayoutBuilder），`appTileGlass` 内部图标同步按方块 42% 缩放。大屏 6/8 列大卡片图标放大、窄屏 3 列小卡片缩小，整条链路（卡片宽 → 方块 → 图标）随容器自适应，消除"大卡片小图标"失衡。
- **首页 / 设置大屏两栏布局**：新增通用分栏组件 `AdaptiveSplitView`（lib/core/adaptive_split_view.dart，`kSplitBreakpoint`=760）——宽屏左右两栏并排、窄屏上下堆叠（等价原单列，零回归），纯宽度驱动、首页与设置页复用。首页宽屏：左栏「常用功能 + 今日课程」、右栏「校园新闻」；设置宽屏：左栏「个人信息 + 外观」、右栏「账号 + 关于」。两页 `MaxWidthContent` 放宽至 `kGridMaxWidth`（1200）以容纳两栏。
- **二级页面铺满全屏**（产品决策）：约 50 个二级页面的 `contentMaxWidth` 限宽参数全部移除，页面内容铺满整屏；`SimplePage.contentMaxWidth` 参数与限宽逻辑保留（默认 0 = 不限宽）备用，`kListMaxWidth`/`kDenseMaxWidth`/`kGridMaxWidth` 常量保留定义。仅登录页表单保留 480 居中限宽（非二级界面）。
- **应用网格列数自适应**：应用页网格原写死 4 列 → 按实际渲染宽度 3→4→6→8 列；首页「常用功能」宫格同步改用统一 `appGridColumns`（基于 LayoutBuilder 约束而非 MediaQuery 全宽，避免 MaxWidthContent 限宽内列数虚高、卡片被挤压）。
- **侧边导航栏液态玻璃化**：宽屏侧栏（任务栏）由简单毛玻璃升级为视觉液态玻璃——顶部高光渐变模拟折射、BackdropFilter 20px 模糊、与内容区悬浮投影分隔、右侧边缘亮线；选中项为玻璃胶囊（accent 渐变 + 白色高光描边 + 左侧指示条）并加桌面悬停/点按反馈；顶部新增品牌玻璃方块。⚠️ 不用 GlassCard/GlassButton 等 shader 组件（Android GLES 设备 shader 玻璃不渲染会白屏，与平板一致性冲突），视觉液态玻璃全平台稳定。
- **侧栏选中态放大优化**：选中胶囊垂直/水平 padding 增大（9→14 / 6→12）更饱满，图标 AnimatedScale 平滑放大 22→约 26，文字 11→12 加粗；修复左侧指示条 `Positioned(left:-12)` 被 Stack 默认 Clip.hardEdge 裁剪不可见的问题（显式 `Clip.none` + Center 垂直居中），选中反馈更明确。

### 🐛 修复（Windows WebView 注入类闪退 / 会话预热）
- **CARSI（玻尔科研）补全会话预热**：`BohriumPage._injectCookies` 注入前先 `AuthService.ensureFreshSession()`（与邮件系统一致）——CASTGC 在 App 运行期间可能已过期，直接注入"死 cookie"会卡在 CAS 登录页；预热后才有新鲜的 cookie 可注入。
- **CARSI 补全 WebView2 共享环境**：BohriumPage 的 InAppWebView 与 CookieManager 上一轮未接入共享环境（仅 WebViewPage 覆盖）——Windows 上页面环境 + CookieManager 默认环境双环境并发初始化同一 userDataFolder 仍会 native 崩溃；现 InAppWebView 传 `webViewEnvironment: sharedCasEnvironment`、注入改用 `CookieManager.instance(webViewEnvironment:)`，与邮件同方案。
- **onWebViewReady 超时对齐**：30s → 60s（与 autoRelogin 超时一致），避免 Windows 网络差时 `ensureFreshSession` 预热被超时腰斩、cookie 未注入卡 CAS 登录页。

### 🐛 修复（PDF 预览跨平台 · flutter_pdfview 不支持 Windows）
- **Windows 打开 PDF 附件报 `TargetPlatform.windows is not yet supported`**：flutter_pdfview 仅支持 Android/iOS。新增 `lib/core/platform_pdf_view.dart` 跨平台组件——Android/iOS 保留应用内 PDFView 渲染（翻页/缩放），**Windows 等桌面端显示引导占位 +「用系统应用打开」按钮（复用 openFileWithSystem，ShellExecute 唤起系统默认 PDF 查看器）**。接入：office 文件预览、通知公告附件、校园网服务附件、校历详情 4 处。

### 🐛 修复（Windows 附件打开 · MissingPluginException）
- **Windows 下载附件后"打开文件"失败**：`openFile` MethodChannel 只在 Android 有原生实现（FileProvider），Windows 直接 MissingPluginException。新增 `lib/core/open_file.dart` 平台分发：Android 保留 MethodChannel（content:// + 授权），**Windows/桌面走 `url_launcher` 打开 `file://` URI（ShellExecute 唤起系统默认关联程序，支持 doc/xlsx/pdf/zip/图片）**；office 预览、校园网服务附件、通知公告 PDF 三个入口统一接入。

### 🎯 优化（资讯详情页图片）
- **移除资讯详情页图片缩放层**：`NewsDetailPage` 正文图片不再用 `InteractiveViewer` 包裹（Windows 鼠标滚轮在图片上会缩放图片而非滚动页面，误触体验差）——图片改为纯展示，滚轮直接滚动页面。

### 🐛 修复（Windows 字体 · 字重合成与 Cupertino 混排）
- **字重合成加粗**：微软雅黑仅 400/700 两个真实字重，`FontWeight.w800/w900`（32px 大标题等）在 Windows 被 DirectWrite 合成加粗，渲染发虚/过粗、粗细不均——全局规整 w800/w900 → w700（雅黑真实 Bold，iOS 端 w700≈w800 观感差异可忽略），涉及 ios_kit（设置大标题）、safety_page、erke_page。
- **Cupertino 组件字体兜底**：GlassScaffold 内部基于 CupertinoPageScaffold，Cupertino 组件默认用平台字体（Windows = Segoe UI）不吃 Material `fontFamily`——新增 `cupertinoOverrideTheme`（CupertinoThemeData.textTheme.textStyle.fontFamily = 微软雅黑），杜绝与周围雅黑混排粗细不一。

### 🐛 修复（通知公告时间获取）
- 修复「通知公告（tzgg.htm）列表/详情页时间获取不到」：列表日期 HTML 为 `<div class="date"><p>MM.dd</p><span>yyyy</span></div>`，月日与年分处不同标签，`_extractDate` 旧正则用 `\s*` 连接无法跨越 `</p><span>` 标签，三条正则全部落空返回空；详情页 `发布[日期]` 字符类漏匹配「期」字（`发布日期：`），同样返回空。
- `ColumnService._extractDate` 新增针对 `class="date"` 结构的精确匹配（`<p>MM.dd</p>` + `<span>yyyy</span>`），并保留宽松兜底；详情页日期正则修正为 `发布日期?`。已用官网真实 HTML 验证：6 条列表全部正确解析为 `yyyy-MM-dd`。

### ✨ 新增（校园网服务 · 免 WebView 抓取 + 附件下载）
- 网络服务页「校园网服务」项改为抓取 `nm.yibinu.edu.cn/xywfw.htm` 渲染（不再用内置 WebView）：列表解析 `info/1020/`，标题取 `<a title>`，日期取 `<span class="clock-ico">日期：yyyy-MM-dd</span>`，按日期倒序。
- 详情页图文解析 `v_news_content`；日期 `日期：yyyy年MM月dd日`，附件走 `download.jsp?wbfileid=` 通道（文件名取自 `<a>` 文本，如「教职工校园网用户申请表.pdf」），无需登录态可直接 GET 下载。
- 附件下载：字节落到本地临时文件 → PDF 应用内 `flutter_pdfview` 预览；其它类型（doc/xlsx/zip/图片）经 MethodChannel `openFile` 走系统 FileProvider 打开，`NetworkServiceItem` 新增 `page` 字段优先于 `url` 跳转。
- 新增 `lib/network/campus_network_service*.dart`（model/service/list/detail/viewer 5 文件），与资讯栏目 ColumnService 解耦。
- 「多媒体服务」（dmtjsfw.htm，栏目 1022）复用同一模块：`CampusNetworkService` 列表地址改为构造参数、`fetchList` 栏目匹配由 `info/1020/` 放宽为 `info/\d+/`，`CampusNetworkServicePage` 接收 `service`+`title` 通用化；附件实测 `virtual_attach_file.vsb?afc=...&e=.pdf` 直接返回 1.4MB 真实 PDF，可下载预览。
- 「VPN 服务」（VPNfw.htm，栏目 1023）同样复用该模块，验证列表 4 条、详情页结构与 1020/1022 一致（`v_news_content` + 脚本内嵌 PDF 预览，已由脚本剔除修复覆盖）。
- 「虚拟机服务」（xnjfw.htm，栏目 1029）同样复用该模块，验证列表 2 条（`宜宾学院虚拟机服务说明` 等，日期 2024-09-06），页面结构与前三个栏目完全一致；至此 nm.yibinu.edu.cn 下 4 个服务栏目全部脱离内置 WebView。
- 「网站服务」（wzfw.htm）为**单页栏目**（整页即一篇《网站申请与建设指南》，无列表），新增 `CampusNetworkArticlePage`：按 URL 自行抓取详情后复用 `CampusNetworkDetailPage` 渲染，含加载/错误/重试三态。解析器同步兼容单页结构——标题优先取 `nry-tit > h1`（该页 `<title>` 是栏目名「网站服务」而非文章名）、日期兼容 `日期： yyyy-MM-dd`、正文容器 `v_news_content` 缺失时退回 `id="vsb_content"`。实测解析出 19 段正文 + 3 个附件（插件安装说明.docx 1.2MB / VSBBrowserHelperSetup.zip 70.6MB / VSBExtension.rar 20KB，均 HTTP 200 可直接下载）。

### 🎯 优化（网络服务跳转与大附件下载）
- 网络服务页所有链接项一律走内置 WebView：原先 `ms/mail/vpn/oa/web` 子域走 `LaunchMode.externalApplication` 跳系统浏览器，离开 App 后回不到原上下文；现统一 `pushPage(WebViewPage(...))`，AppBar 标题由固定「网络服务」改为具体服务名，并移除 `url_launcher` 依赖引用。
- 附件下载改流式落盘：`CampusNetworkService.getBytes` → `downloadToFile`，边收边写 `IOSink` 并回调进度，不再用 `List<int>` 累积整包（Dart int 装箱会把 70MB 放大数倍，移动端易 OOM）；附件页显示百分比/已下载体积，setState 限流 120ms；PDF 判定改用流式捕获的文件头 4 字节。

### 🐛 修复（栏目页标题）
- `CampusNetworkServicePage` 的 AppBar 标题硬编码为「校园网服务」，导致多媒体服务 / VPN 服务 / 虚拟机服务三个栏目页顶部标题全部显示为「校园网服务」；改为使用传入的 `widget.title`。

### 🐛 修复（校园网服务正文乱码）
- 详情页 `v_news_content` 首段为 `<p><script>var vsb_pdf_image_data=...;showVsbpdfIframe("/virtual_attach_file.vsb?...&e=.pdf",...)</script></p>`（vsb 内嵌 PDF 预览），旧 `_parseContent` 把 `<p>` 内脚本源码去标签后当正文渲染成乱码。
- 修复：`_parseContent` 提取段落文本前先剔除 `<script>/<style>` 内联块；PDF 仍经下方 `download.jsp?wbfileid=` 链接作为可下载附件（已验证正常捕获）。

### ✨ 新增（校园网服务内嵌 PDF 预览）
- VPN 服务详情页 7867（宜宾学院VPN管理办法）正文为 vsb 内嵌 PDF：正文容器首段仅含 `showVsbpdfIframe` 脚本，**无 `<a>` 附件、无 `<img>`**，旧逻辑剔除脚本后正文全空、PDF 不可见。
- `_parseContent` 新增 `vsb_pdf_image_data` 分支：提取脚本内 `var vsb_pdf_image_data = ["/virtual_attach_file.vsb?afc=...&e=.jpg", ...]` 逐页预览 JPG 数组，作为内联 `ContentBlock(image)` 直接显示（7867 实测 7 张预览图）；新增 `_absolute()` 把相对路径拼成 `https://nm.yibinu.edu.cn/...`，`<img>` 分支同步复用。
- `fetchDetail` 附件扫描：在 `<a>` 循环后，从 `showVsbpdfIframe("...")` 与 `<iframe src="...e=.pdf">` 两处提取 PDF 本体 URL，作为附件加入（7867 → 1 个 `宜宾学院VPN管理办法.pdf` 附件）。
- **按用户要求不去重**：移除原先「已有 PDF 则跳过 vsb PDF」的按内容去重逻辑，现仅做 URL 级去重——3893 同时列出 `教职工校园网用户申请表.pdf`（download.jsp）与 `A区、B区教职工公寓校园网申请.pdf`（vsb），4037 同时列出 `PDF 文件`（iframe）与 `多媒体设备使用说明.pdf`（`<a>`）。
- 三类内嵌 PDF 形态已验证：① 7867 仅脚本预览（0 `<a>` 附件）→ 7 图 + 1 PDF 附件；② 3893 1 图 + download.jsp PDF + vsb PDF（两文件内容相同，均保留）；③ 4037 iframe PDF + PC 下载兜底文本 + `<a>` PDF（均保留）。单页型（wzfw：19 段 + 3 附件）、纯列表型（1029：4 段 + 0 附件）回归无影响。

### 🐛 修复（CARSI 游客模式拦截）
- CARSI 入口（`app_data.dart` 的 `allApps`，`AppEntry(name:'CARSI')`）此前无 `requiresLogin` 标记，游客模式（无账号密码）可直接进入并打开 `ds.carsi.edu.cn` 的 Shibboleth 登录页，但本地无 CASTGC、IdP 放行失败，实际不可用却无提示。
- 修复：给 CARSI 条目补 `requiresLogin: true`；拦截逻辑（`main_screen.dart _buildAppCard` 与 `ios_kit.dart _openApp` 已有的 `GuestMode.active && entry.requiresLogin` 判断 + `showGuestLoginDialog`）自动生效，游客点击弹「需要登录」并引导去登录页。`dart analyze lib/home/app_data.dart` 通过。

## [1.1.8] - 2026-08-05

### 🐛 修复（邮件 / CARSI 会话预热）
- 修复「必须先成功访问学科竞赛，邮件系统和 CARSI 才能正常进入，否则卡在登录页」：App 运行期间 authserver 的 TGC（CASTGC）会在服务端过期，本地 cookie 罐留下「死 cookie」，此前只有学科竞赛（scjx2 bootstrap 失败 → autoRelogin）隐式刷新会话，邮件 / CARSI 直接注入死 cookie 卡 CAS 登录页。
- `AuthService` 新增 `ensureFreshSession()` 会话预热：本地无 CASTGC 或 `verifySession` 探测（302 = 过期）判定失效 → autoRelogin 用已存账号密码静默重登刷新。
- `SharedHttpClient` 新增 `hasCastgc()`（遍历 cookie 桶判断本地是否持有 TGC）。
- 邮件 `MailPage.onWebViewReady` 注入前先 `ensureFreshSession()`；CARSI 入口新增 `onWebViewReady`（预热 + 注入统一认证 cookie，凭 `.yibinu.edu.cn` 父域 CASTGC 在 IdP 自动放行）并补上桌面 UA 伪装（CARSI 联盟资源站对移动 UA 拒绝服务）。

### 🔧 重构（CAS cookie 注入器抽取）
- 新增 `core/cas_webview.dart`：`injectCasCookiesToWebView` 公共注入器（按原域注入 CASTGC → 父域、authserver cookie → authserver 域），邮件 / CARSI 等 SSO WebView 共用；`MailService.injectCasCookiesToWebView` 改为委托公共实现。

### ✨ 新增（CARSI 服务）
- 应用中心「服务」新增「CARSI」：`WebViewPage` 打开教育网统一认证资源共享登录（`ds.carsi.edu.cn/Shibboleth.sso/Login`，entityID=宜宾学院 IdP，target=wxds），`app_data.dart` 注册 service 分类入口（手机 UA，与常规浏览一致）。
- `WebViewPage` 新增可选 `notice` 参数（标题下方提示条，深橙 0xFFC2410C + info 图标）；CARSI 传入「部分资源（如知网）不支持在线阅读和下载」——知网在线阅读/下载在 WebView 内无法通过来源/Token 校验（已尝试 UA 伪装 + supportMultipleWindows + 去 X-Requested-With + Referer 补全均失败），明示用户避免困惑。

### 🐛 修复（CARSI 在线阅读/下载「来源应用不正确」）
- 根因①：Android WebView **默认 `supportMultipleWindows=false` 时静默忽略 `window.open()`**——知网下载/阅读弹窗根本没打开（日志 `bar.cnki.net common.js: jQuery is not defined` 是页面移动版/窗口异常的连带现象），SID 会话校验失败即报「来源应用不正确」。
- 根因②：知网等 CARSI 资源站点对移动/WebView UA 返回精简页面并拒绝服务。
- `WebViewPage` 修复：① 开启 `supportMultipleWindows: true` + `javaScriptCanOpenWindowsAutomatically: true`，`onCreateWindow` 拦截新窗口请求（6.x 返回 `Future<bool?>`，false=不创建新窗口）在当前 WebView 内 `loadUrl` 加载；② 新增 `desktopUserAgent` 参数（桌面 Chrome UA 伪装），CARSI 入口开启；③ 补 JS 弹窗自动确认（alert/confirm/prompt）防阻塞。
- ⚠️ 原生 WebView 设置（supportMultipleWindows）**必须重新编译安装生效，热更新无效**。

### 🔧 重构（WebViewPage 统一邮件系统）
- `WebViewPage` 新增可选 `onWebViewReady` 回调（WebView 创建后、加载 URL 前执行），加载方式由 `initialUrlRequest` 改为手动 `loadUrl`，保证 SSO cookie 注入先于页面加载。
- `mail_page.dart` 重写为复用 `WebViewPage` 的薄壳：仅保留 `MailService.injectCasCookiesToWebView` 注入（onWebViewReady），**删除底部工具栏（后退/前进/首页/刷新）、AppBar 刷新/菜单、CAS 登录提示条、自定义 UA/JS 弹窗处理**；返回按钮/手势行为与 WebViewPage 一致（按钮直接退出，手势回退历史）。

### 🔧 重构（WebViewPage 迁移 SimplePage）
- `webview_page.dart` 由裸 `LiquidBackground` + `Scaffold` 改为 `SimplePage(child: PopScope(...))`（默认自带液态背景），对齐二级页规范（转场透明滑入透底隐患消除）。

### ✨ 新增（网上评教）
- 应用中心「教务」新增「网上评教」：`lib/wspj/`（`wspj.dart` 模型 / `wspj_service.dart` 服务 / `wspj_page.dart` 页面），对接 ehall jwwspj 应用（入口 appId=`5077744448763966`）。
- 服务层：`ensureSession`（appMultiGroupEntranceList 入口链预热 `_WEU` 会话，302 过期 / 403 自动重登同 kccx 范式）；`fetchModules`（emappagelog/config/jwwspj.do 模块列表）；`fetchConfig`（cxcssz.do 评教系统参数：PJXNXQ 学期 / PJKSSJ / PJJSSJ 时间窗口等，querySetting 与网页端一致）；`fetchSemesters`（xnxqcx.do 学年学期）；`fetchQuestionnaires`（cxxspjwjlb.do 学生评教问卷列表，CPR=学号&XNXQDM=学期&SFFB=1）。
- 页面：评教时间窗口信息卡（进行中/未开始/已结束状态徽标）+ 学年学期切换（GlassFilterChip）+ 问卷列表卡片（总分/类型标签、已完成/待评教徽标、WJSM 问卷说明弹窗），四态 + 下拉刷新。
- `app_data.dart` 注册「网上评教」教务分类入口（requiresLogin）。

### ✨ 新增（学科竞赛·公示公告）
- 学科竞赛主页新增第三 Tab「公示公告」：`listNoticeStuPage` 公告列表（缓存优先 + 静默刷新 + 滚动分页 + 置顶标签 + 四态），`getNoticeById` 详情页（标题/发布人/时间/正文 HTML 转纯文本），附件 PDF 带 cookie 下载后应用内预览（`flutter_pdfview`），非 PDF 附件用系统浏览器打开。
- 新增 `lib/race/notice.dart`（模型 + HTML 转文本）、`notice_page.dart`（列表）、`notice_detail_page.dart`（详情）、`notice_pdf_page.dart`（PDF 预览）；`race_service.dart` 增加 `fetchNotices`/`cachedNotices`/`fetchNoticeDetail`/`cachedNoticeDetail`（scjx2 `/config/sys/baseNotice/*`，currentRoutePath=`/homeageStu`，签名/401 自愈复用 Scjx2ApiService）。
- **PDF 预览右上角新增「下载」**：官方下载通道 `GET /config/sys/download/downNotice?id=<公告id>&name=<URL编码文件名>`（带签名头）→ 临时文件 → FileProvider 交给系统应用打开（可保存/分享）；`Scjx2ApiService` 新增带签名 GET 字节下载 `downloadBytes`（⚠️ params 传已编码形态参与签名，URL 手动拼接防双重编码），`RaceService` 新增 `downloadNoticeFile`。
- 微调：移除公告列表/详情的「置顶」文字标签显示（模型字段保留）。

### 🐛 修复（下载接口返回非 PDF）
- `SharedHttpClient._sendBytes`（getBytes）补上缺失的 gzip/deflate 手动解压——此前服务器 gzip 响应时 getBytes 返回压缩字节（downNotice 错误响应 73 字节被误判为非 PDF）；验证码/附件预览等 getBytes 调用方一并受益。
- `Scjx2ApiService.downloadBytes` 改用 `getRaw`（带 HTTP 状态码 + 已解压字节），非 200 时打印服务端错误 body 便于定位，401/404 提示重新登录。
- **downNotice 下载 500「参数错误!」根因**：zhxhsign 必须对**原始未编码 name**（UTF-8 中文）签名——离线反推验证与抓包值完全匹配（DevTools 负载的 `%E5%85%B3...` 仅为展示形态）；`downloadBytes` 改为「签名用原始值 + URL 拼接时 `Uri.encodeComponent`」，`downloadNoticeFile` 传原始文件名。

### 🎨 UI 优化（第二课堂登录按钮玻璃化 + 展开卡/下拉同色填充）
- 登录按钮（erke_login_page「登录」含 loading、erke_page「登录第二课堂」）→ `GlassActionButton`（primary 玻璃），重试按钮 → secondary。
- 成绩单展开卡（erke_page SmoothExpansionTile）→ `smoothGlassStyle(context)` 背景同色填充。

### 🎨 UI 优化（smooth 组件全面玻璃化：教材查询/学业完成/课程表/空闲教室）
- 抽取公共 `smoothGlassStyle(context)`（lib/core/smooth_styles.dart）：背景渐变同色系填充（LiquidBackground 同款参数），painter 写死 alpha 0.90 下卡片/下拉面板与背景融为一体（视觉玻璃面板），accent 描边/高光由 painter 绘制。
- 应用：教材查询（SmoothExpansionTile）、学业完成/毕业要求（SmoothExpansionTile）、课程表学期选择（SmoothSelect）、空闲教室周次/教学楼选择（SmoothSelect）；成绩页 `_glassStyle` 收敛为公共函数。

### 🎨 UI 优化（成绩查询学期详情卡片玻璃化·终版）
- 保留 `SmoothExpansionTile`（用户要求，交互/动画不变）。smooth_dropdown 1.0.0 painter 写死填充 alpha 0.90/0.92（真半透明不可行）→ 改用**背景渐变同色系填充**（`_glassStyle` 的 palette fillTop/fillBottom 取 LiquidBackground 同款渐变参数）：卡片区域与背景融为一体，视觉即玻璃面板；accent 描边/高光由 painter 绘制。移除手写 _SemesterCard。

### 🎨 UI 优化（成绩查询学期详情卡片玻璃化·二次修复）
- 首次尝试给 SmoothExpansionTile 传半透明 palette 无效：smooth_dropdown 1.0.0 的卡片 painter（smooth_card_painter.dart）把填充 alpha **写死 0.90/0.92**，半透明色被强制覆盖成实色。
- 改为**手写玻璃展开卡** `_SemesterCard`：contentCardGlass（玻璃卡，圆角 14）+ AnimatedSize 展开动画 + chevron 旋转指示；标题栏/表头/成绩行样式与内容不变；移除 SmoothExpansionTile 依赖（成绩页删 smooth_dropdown/smooth_styles import）。

### 🎨 UI 优化（成绩查询学期详情卡片玻璃化）
- 各学期展开卡片（SmoothExpansionTile）填充从实色 accent 掺白/深灰改为**半透明玻璃填充**（`SmoothPalette.fillTop/fillBottom` 用 contentCardGlass 同款参数：白 45%/38%、深灰 55%/48%），透出液态玻璃背景；描边/圆角/动效继承公共 smoothStyle（新增 `_glassStyle`）。

### 🎯 优化（深度功耗优化，样式不变）
- **后台/锁屏零动画**：`LiquidBackground` 改为 StatefulWidget + 生命周期监听——App 切后台/锁屏时整棵背景子树 `TickerMode` 暂停（气泡动画 + 页面内容动画一并停），前台恢复继续，零视觉变化。
- **消除被遮挡背景层动画**：新增全局页面层计数 `pageBgCount`——全局垫底层（`isGlobal`）被二级页/详情页背景覆盖时自动暂停气泡（TickerMode 暂停而非移除组件，恢复无跳变）；每屏只保留一层气泡动画（此前二级页 = 全局层 + 页面层两层气泡同时跑）。
- 全局垫底层标记：main.dart builder 两处 `LiquidBackground` → `isGlobal: true`。

### ✨ 新增（应用页「最近」分类容量 6 → 16）
- 最近使用列表上限从 6 提升到 16（`_recentLimit` 常量）；`_recordUsage` 截断与 `_loadRecents` 加载均按新上限处理（老数据兼容）。

### 🎨 UI 优化（综合素质卡片徽章玻璃化 + 删除标题栏分割线）
- 右上角"合格/等级"徽章从实色浅绿/浅橙底改为**玻璃徽章**（半透明渐变 + 同色描边，合格=绿/其它=橙）。
- 删除学期标题栏底部灰色分割线（`Border(bottom: grey[100])`），卡片标题与内容自然衔接。

### 🔧 重构（抽取玻璃操作按钮 GlassActionButton + 5 页按钮全面玻璃化）
- 新增 `lib/core/glass_action_button.dart`：`GlassActionButton`——玻璃操作按钮（primary 主题色玻璃 30%→22% + 主题色描边 + 主题色文字；secondary 中性玻璃 + 白描边），支持 icon / loading（转圈）/ disabled（弱化）/ 自定义色（安全页红）/ height / fullWidth / fontSize；Material+InkWell 水波纹；⚠️ 命名避开 liquid_glass_widgets `GlassButton`。
- 替换实心按钮：空闲教室（查询+重试+日期/节次 chips→GlassFilterChip）、课程查询（查询+重试+考试类型/课程层次 chips→GlassFilterChip）、全校方案（查询+重试+年级 chips→GlassFilterChip）、电费（绑定并查询+生成订单，未选金额自动禁用弱化）、校园安全（拨打按钮→GlassActionButton；110/119/120 紧急按钮→红色玻璃）、kccx/qxfacx 详情页重试按钮。

### 🔧 重构（抽取玻璃筛选按钮公共组件 GlassFilterChip）
- 新增 `lib/core/glass_filter_chip.dart`：`GlassFilterChip`——玻璃按钮（半透明渐变 + 白描边，选中态 accent 玻璃 + accent 描边 + 加粗 + 200ms 动画），圆角/字号/内边距可配；⚠️ 命名避开 liquid_glass_widgets 自带 `GlassChip`。
- 全校课表学院筛选 chips 改引用公共组件（原手写 AnimatedContainer 玻璃实现）。

### 🎨 UI 优化（全校课表学院分类按钮玻璃化）
- 学院筛选 chips 从实色（选中 accent 实心 / 未选中 accent 8% 浅底）改为**玻璃按钮**：半透明渐变 + 白色高光描边（内容卡同款参数）；选中态 accent 玻璃 + accent 描边 + 加粗 + 200ms 动画。保持按钮形态（横向滚动 chips，非分段栏）。

### 🎨 UI 优化（全校课表搜索框玻璃化）
- 搜索框去掉手写实色填充（浅色 `grey.shade100` / 深色 `2A2A3E`，盖住玻璃背景），`fillColor` 改跟随全局主题（静态玻璃半透明白/深灰），与课程查询搜索框一致。

### 🎨 UI 优化（课程表 / 学科竞赛 / 创新创业切换栏统一玻璃化）
- 课程表「周课表/学期课表」：Material `SegmentedButton` → `GlassCategoryBar`。
- 学科竞赛「学科竞赛/我的竞赛」、创新创业「我参与的项目/我申请的项目」：实心胶囊 `PillTabBar` → `GlassCategoryBar`（选中态从实心 accent 滑块改为玻璃卡 + accent12% 背景，与全 App 统一）。
- 删除已无引用的 `lib/core/pill_tab_bar.dart`。

### 🔧 重构（抽取玻璃分类栏公共组件 GlassCategoryBar）
- 新增 `lib/core/glass_category_bar.dart`：`GlassCategoryBar` + `GlassCategoryItem`——玻璃卡 + 0.5px 竖分割线 + 选中项 accent12% 圆角背景 + 200ms 切换动画；`IntrinsicHeight + Row(stretch)` 等高；支持 `vertical`（图标上文字下，主界面应用页 tab）/ 横排（二级页分段）两种布局，容器圆角/内边距/字号可配。
- 替换两处重复实现：`main_screen.dart` 应用页分类栏（原手写 IosCard + Row）与 `dianfei_page.dart` 近7/30天切换（原手写 contentCardGlass + Row）均改为引用公共组件。

### 🎨 UI 优化（电费近7天/近30天选择栏玻璃化）
- 选择栏从 Material `SegmentedButton`（实色分段样式）改为**玻璃分类栏**：`contentCardGlass` 玻璃卡 + 0.5px 竖分割线 + 选中项 accent12% 圆角背景（`IntrinsicHeight + Row(stretch)` 保证分割线与选中背景等高），与应用页分类栏同款规范，替代项目弃用的 SegmentedControl 样式。

### 🎨 UI 优化（电费逐日明细玻璃化）
- 逐日明细每行从手写 `Card`（深色模式 `Colors.grey[850]` 实色覆盖、圆角 8、灰描边）改为 `contentCardGlass` 玻璃卡（圆角 12、半透明渐变 + 白描边），与页面剩余电量/本月汇总/折线图等卡片统一；深色模式不再盖住玻璃背景。

### 🐛 修复（临港电费进入时透明阶段——唯一未包 SimplePage 的二级页）
- 根因：全局背景（LiquidBackground）在 Navigator 下层、**不随路由滑动**；电费页裸 `Scaffold`（透明背景、无自己的背景层）转场时"透明页面滑入、透出底层"，表现为**只有临港电费**进入时有透明阶段——其它二级页均包了 `SimplePage`（自带 LiquidBackground 背景层，随路由一起滑入）。
- 修复：电费页 build 外包 `SimplePage`（statusBarStyle 默认 auto），与 course/kccx/qxfacx/erke 等全部二级页一致。

### 🔧 重构（统一所有二级页面转场为 iOS 右滑）
- 根因：race / my_race / srtp / kccx / qxfacx / office_search / 第二课堂（erke ×2 处）内部二级跳转用 `MaterialPageRoute`（Android 默认**淡入透明**转场），与应用页统一的 `pushPage`（CupertinoPageRoute 右滑）混用——进入部分页面先出现"透明阶段"，转场体验不一致。
- 修复：全部替换为 `pushPage` / `replacePage`（navigation.dart，CupertinoPageRoute）；补 5 个文件 navigation import；清理 erke_page 未用 `nav` 变量、`context.mounted` 守卫跨 async gap。全 App 二级页面统一右滑推入 + 边缘返回。

### 🎨 UI 优化（电费页加载态）
- 查询加载态从裸转圈改为玻璃卡 + 转圈 + 「正在查询电费…」文案，转场滑入时页面有内容，避免"全透明页面"空感。

### 🎨 UI 优化（电费查询链接输入框样式统一）
- 输入框去掉手写实色 `Card` 包装（会盖住玻璃背景），改用全局 `inputDecorationTheme`（玻璃填充 + 圆角 12 描边 + accent 聚焦边框），与登录页 / 课程查询搜索框风格一致；新增 `link_rounded` 前缀图标、`alignLabelWithHint`，多行限制 4 行。
- 说明文字改 `textSecondary(context)` 主题色；查询失败错误文字由红色改规范深橙 `Color(0xFFC2410C)`；清理 `_buildSetup` 无用 `isDark` 参数；去掉输入框 `autofocus`（进页面不自动聚焦，避免一直显示主题色聚焦边框）。
- 全局输入框 `focusedBorder` 由主题色（accent，浅色模式紫色聚焦边框）改为中性白描边（加亮加粗仅作聚焦反馈，与主题色解耦），全 App 输入框一致。
- 电费链接输入框改单行（`maxLines: 1`）：多行框内容不满时文字贴顶不居中，单行保证文字垂直居中，长链接横向滚动。

### 🐛 修复（今日课表周数不符：进入显示旧值/离谱值，手动刷新才正确）
- **根因一（会话缺失）**：`fetchCurrentWeek` 未先 `ensureSession()`——无 wdkb 模块会话时 `dqzc.do` 被 ehall 网关 302 到 CAS 登录页（postForm 自动跟随 → 200 登录页 HTML），jsonDecode 失败后静默回退。
- **根因二（回退离谱）**：回退走 `_calcCurrentWeek()` 硬编码 3/1 估算，暑假（8 月）算出第 23 周——正是"进入显示 23 周、刷新后变 1 周（服务器真实值，负 ZC clamp）"的直接原因。
- **根因三（缓存跨周）**：`fetchCurrentWeek`/`fetchClassCurrentWeek` 缓存 key 固定 + DataCache 1 天 TTL，跨周后旧缓存仍有效。
- **修复**：① 两处周次请求前置 `ensureSession()`/`ensureKcbcxSession()`（与 fetchCourses/fetchClassSchedule 一致，幂等）；② 回退改为基于校历 firstMonday 估算（`_estimateWeekFromMonday`：未开学/寒暑假 → 1，与服务器 clamp 一致），删除硬编码 3/1 的 `_calcCurrentWeek`；③ 缓存 key 追加日期，跨天自动失效。首页今日课程 / 课表页 / 全校课表高亮一并受益。

### 🐛 修复（学科竞赛等 scjx2 模块"用久了只有手动重新登录才成功"）
- **根因一**：`AuthService.autoRelogin()` 复用已 `loadCookies()` 的旧 client，内存罐是"多代 cookie 混合"（过期 CASTGC/JSESSIONID/route 残留 + 本次新 cookie）；`Scjx2ApiService` 把脏罐注入 WebView 干扰 authserver CAS 会话判定 → SSO 刷新回环 → bootstrap 失败。手动登录页用全新 client（无旧 cookie）所以天然成功。
- **根因二**：`_captureCastgcOverHttps` 从客户端 cookie 罐抓 CASTGC 而非本次登录响应头——补登录被验证码/风控拦截时会把 loadCookies 加载的"死 TGC"误判为成功并落盘。
- **修复**：① `autoRelogin()` 登录前 `client.clearCookies()`（内存+磁盘，与手动登录行为一致）+ static 互斥锁链串行化并发调用（SplashPage / scjx2 401 自愈 / kccx / qxfacx 403 重试共用）；② `_captureCastgcOverHttps` 改从 302 响应 `Set-Cookie: CASTGC=` 解析本次新 TGC，解析不到不落盘不误报。


- 根因：`LiquidBackground` 有自定义背景时返回 `SizedBox.shrink()`，把 `child`（页面内容）一并丢弃——空闲教室/学业完成等用 SimplePage(background) 的页面只剩背景。
- 修复：改为 `return child ?? const SizedBox.shrink();`——透出全局背景图同时保留内容。

### 🐛 修复（自定义背景在二级界面生效）
- 根因：二级页面（SimplePage / login / calendar / race / srtp / vrmap 等自绘页面）各自渲染不透明 `LiquidBackground`，盖住全局背景图。
- 修复：`LiquidBackground` 组件内部 `ValueListenableBuilder` 监听 `backgroundNotifier`——有自定义背景图时不渲染（透出全局背景图），无则正常渐变背景；SimplePage 恢复简单版（统一由 LiquidBackground 处理），设置/重置背景即时刷新全 app。

### ✨ 新增（自定义背景应用到全部页面）
- 外观设置的自定义背景图从「仅主界面」提升到**全局**（main.dart builder 监听 `backgroundNotifier`）：所有页面（主界面 + 全部二级页）统一显示背景图（`Image.file` + 半透明遮罩保证可读性），默认仍为 `LiquidBackground`；新增 `dart:io` import。
- `main_screen.dart`：`GlassScaffold.background` 改透明（全局背景透出），删除主界面独立的 `Image.file` 背景逻辑及 `_overlayColor`/相关 unused import。

### 🎨 UI 优化（电费页卡片玻璃化）
- 剩余电量卡 / 本月汇总卡（用电量·电费）/ 时段汇总卡（近X天用电）/ 折线图卡：从 accent 渐变实色底 / 实色白底改为**静态玻璃**（`contentCardGlass` 同款：半透明渐变 + 白色高光描边），文字改主题色；低电量数字用深橙提示、状态徽章用 accent/深橙。

### 🔧 重构（电费查询模块化，三层架构）
- `lib/dianfei/` 按模块化铁律拆分为三层：
  - **`dianfei_models.dart`**：`DayData`（日度明细）/ `DianfeiStatus`（余量/累计/状态/电价/月度汇总/微信用户ID）/ `DianfeiQueryResult`。
  - **`dianfei_service.dart`**：`DianfeiService`——`parseLink`（链接解析）、`query`（HeadlessInAppWebView 三接口抓取 + 解析 + 缓存）、`createRechargeOrder`（充值下单）、`loadSummary`/`saveSummary`（本地缓存）。
  - **`dianfei_page.dart`**：页面只调 Service + 渲染（原 1152 行 → 约 900 行）；`_query`/`_doRecharge`/`_initLoad` 改调 Service。
- 弹窗玻璃化（补回 git 恢复丢失）：解绑确认、订单已创建改磨砂玻璃 Dialog（`glassDialog`）。

### 🎨 UI 优化（临港电费弹窗玻璃化）
- 新增 `glassDialog`（ios_kit.dart）公共磨砂玻璃弹窗容器（`BackdropFilter` blur 20 + 半透明渐变 + 白描边）。
- 电费页（dianfei_page.dart）「解绑电表」确认弹窗与「订单已创建」结果弹窗从实色 `AlertDialog` 改为**磨砂玻璃 Dialog**（淡遮罩 25%）；页面卡片已随全局 `cardTheme` 玻璃化，渐变强调卡（余额/统计）保留。

### 🎨 UI 优化（所有加载弹窗统一磨砂玻璃）
- 新增 `showGlassLoadingDialog`（ios_kit.dart）：磨砂玻璃加载弹窗（`BackdropFilter` blur 20 + 半透明渐变 + 转圈 + 文案，淡遮罩 25%）。
- 替换 5 处旧 Card loading 弹窗：资讯（news_list / column_list）、办公网（office_list）、毕业要求（「正在重新计算」）、首页（「加载中」）。
- 检查更新弹窗（`_UpdateCheckDialog`，update_dialogs.dart）加 `BackdropFilter`（blur 20）磨砂玻璃——loading/结果全状态统一模糊。
- 顺带清理毕业要求页死代码（`progress` 未用变量）。

### 🐛 修复（添加常用功能弹窗顶部多余模糊）
- 弹窗顶部 40px 留白从 `Container.margin` 移到**最外层 `Padding`**——此前 `BackdropFilter` 覆盖 ClipRRect 全区域（含留白区）导致弹窗上方多出一片模糊带；现模糊只作用于弹窗本体。

### 🎨 UI 优化（添加常用功能弹窗加模糊）
- 「添加常用功能」底部弹窗（`_QuickAppPickerSheet`，ios_kit.dart）加 `BackdropFilter`（blur 20）——磨砂玻璃效果，背后页面模糊透出；填充降至白 45%/深灰 55%（弹窗是固定容器，采样稳定，无卡片 overscroll 变透问题）；恢复 `dart:ui` import。

### 🎨 UI 优化（宫格方块改回圆角矩形）
- `appTileGlass`（应用网格/首页常用功能格子）从圆形改回**圆角矩形**（`BorderRadius.circular(16)`，恢复 `radius` 参数默认 16），渐变/描边不变。

### 🎨 UI 优化（宫格方块改圆形）
- `appTileGlass`（应用网格/首页常用功能格子）从圆角方块改为**圆形**（`BoxShape.circle`，iOS 图标底样式），渐变/描边参数不变。

### 🎨 UI 优化（应用/首页宫格方块改静态玻璃）
- 应用网格卡片与首页「常用功能」格子的 `GlassButton`（shader 组件，GLES 设备不渲染 + 30+ 个同时渲染掉帧/耗电）改为**静态玻璃方块**（ios_kit.dart 新增 `appTileGlass`，与内容卡片同款：半透明渐变 + 白色高光描边 + 圆角 16）——视觉统一、无 shader 依赖、性能提升；全库已无 GlassButton 使用。

### 🎯 优化（应用分类切换掉帧）
- 分类切换 `AnimatedSwitcher` 设 `reverseDuration: Duration.zero`——旧网格**立即移除**，不再与新高网格（各 30+ 卡片）同时渲染 200ms（双倍负载 → 掉帧主因），只渲染新网格滑入+淡入。
- 应用网格卡片包 `RepaintBoundary`——隔离每张卡（含玻璃组件）绘制，切换/滚动只重绘变化的项。

### 🎨 UI 优化（今日课程卡右上角只显示周次）
- 首页「今日课程」卡右上角角标去掉星期（原「第X周 · 周X」→「第X周」）；教学周外（`_currentWeek <= 0`）不显示角标。

### 🎯 优化（功耗与动画掉帧）
- **背景气泡动画降耗**（`lib/core/liquid_background.dart`）：`FluidBackground` velocity 55→**28**（animated）/ 15→10（static），气泡形变周期 4s→**6s**——所有页面背景的持续动画 GPU 负载约减半。
- **列表逐项动画移除**（`calendar_page` / `employ_page` / `jiaocai_page`）：`_DelayedFadeSlide` 由「逐项错峰淡入+上浮」（`index*50ms` / `index%10*30`，列表长时**并发大量 AnimationController 导致首帧掉帧**）改为**无动画直显**（StatelessWidget），删除对应 State 类。
- 排查确认：splash 脉冲、tab/分类切换、首页 2 处卡片淡入均为一次性/短时动画，无持续 ticker。

### 🔧 重构（检查更新弹窗单窗原地切换）
- `showUpdateCheckFlow`（update_dialogs.dart）重构为**单个玻璃弹窗**（`_UpdateCheckDialog` StatefulWidget）：「正在检查更新…」→ 结果返回后**原地切换**为 已是最新 / 发现新版本（可滚动说明 + 稍后/下载）/ 失败重试，不再关闭后另弹新窗；删除 `_showUpdateDialog`/`_showUpToDateDialog`/`_showSnack`。

### 🎨 UI 优化（「已是最新版本」改居中玻璃弹窗）
- 「已是最新版本」从底部 SnackBar 改为**居中玻璃提示弹窗**（`_showUpToDateDialog`）：成功图标 + 版本号 + 全宽「好的」按钮，玻璃底（白 45%/深灰 55%）+ 淡遮罩 25%，`insetPadding` 四周 24 屏幕正中间，不再被底部导航栏遮挡。

### 🎨 UI 优化（检查更新弹窗玻璃化并居中）
- `_showUpdateDialog`（update_dialogs.dart）：`AlertDialog` 实色改为**静态玻璃 Dialog**（半透明白 45%/深灰 55% + 淡遮罩 25%），内容 `SingleChildScrollView` 可滚动；`insetPadding` 四周 24 保证**屏幕正中间**且不贴底（避免与浮动玻璃导航栏区域重叠）。

### 🎨 UI 优化（更新日志/常用功能标题改 AppBar 样式）
- 更新日志页（`changelog_page.dart`）与常用功能页（`quick_apps_page.dart`）顶部标题从 `IosLargeTitle` 大标题改为 **AppBar 导航栏标题**（与隐私协议页一致）：顶部居中标题 + 返回按钮，移除 SafeArea 冗余（AppBar 自带状态栏处理）。

### 🔧 重构（更新日志弹窗改独立页面）
- 新增 `lib/settings/update/changelog_page.dart` `ChangelogPage`：iOS 大标题 + 每版本一张静态玻璃卡（版本徽章 + 日期 + 正文），自带 加载中 / 失败重试 / 空 / 列表 四态 + 下拉刷新（RefreshIndicator），SimplePage 液态玻璃背景。
- `showChangelogFlow`（update_dialogs.dart）改为 `pushPage` 跳转页面；删除弹窗实现 `_showChangelogDialog` 与 loading 对话框；清理未使用 import。

### 🎨 UI 优化（隐私协议/更新日志卡片玻璃化）
- 隐私协议页（`privacy_policy_page.dart`）：2 处 Card 移除自带实色 `color`（accent 6% / 实色白），跟随全局 `cardTheme` 静态玻璃。
- 更新日志对话框（`update_dialogs.dart`）：`Dialog` 背景改静态玻璃（半透明白 45% / 深灰 55%）+ 遮罩 black54 → 淡黑 25%（透出页面背景）；「检查更新/加载日志」加载对话框同步淡遮罩。

### 🎨 UI 优化（分类切"全部"时消除垂直跳动动画）
- `AnimatedSwitcher` 增加 `layoutBuilder`：Stack 对齐从默认居中改为**顶部对齐**——分类切换时新旧网格高度不同（如"全部"更高）不再垂直居中错位，消除"向上进入"的跳动，只保留左右滑动+淡入。

### 🎨 UI 优化（应用页分类切换改左右滑动动画）
- 应用页分类切换动画改为**左右滑动**：新内容从右侧 15% 滑入 + 淡入（`SlideTransition` + `FadeTransition`，220ms easeOutCubic/easeInCubic）。

### 🎨 UI 优化（应用页分类切换动画去微缩放）
- 应用页分类切换动画移除 `ScaleTransition`（0.98→1.0 微放大），仅保留 **200ms 渐变淡入**。

### 🎨 UI 优化（二级界面卡片与搜索栏统一静态玻璃）
- **全局 `cardTheme`**（main.dart）：92 处二级页面 Material `Card` 从实色改为**半透明静态玻璃**（浅色白 38% / 深色深灰 48% + 白色高光描边、圆角 14、`surfaceTintColor` 透明）——透出 LiquidBackground，无 BackdropFilter 滚动稳定，与主界面 `contentCardGlass` 同款参数。
- **全局 `inputDecorationTheme`**：所有 `TextField`/搜索框改为半透明玻璃填充（白 38%/深灰 48%）+ 白色描边（聚焦仍 accent），二级页搜索栏（kccx 课程查询、qxfacx 全校方案、办公网等）自动统一。
- 移除 kccx 显式 `fillColor`（accent 6%）与 dianfei 电费明细 Card 的深色 `color`，跟随主题玻璃。

### ✨ 新增（应用页分类切换淡入动画）
- `main_screen.dart`：应用网格外包 `AnimatedSwitcher`（200ms）——分类（最近/全部/教务/服务/资讯）切换时 **淡入 + 轻微放大（0.98→1.0）**（iOS 风格）；`GridView` 的 `ValueKey('tab_$_tabIndex')` 触发切换，搜索过滤不换 key 不动画。

### ✨ 新增（首页/应用/设置 tab 切换淡入动画）
- `main_screen.dart`：主界面三 tab 切换从无动画 `IndexedStack` 改为 `_buildPagesStack()`——Stack 常驻三页（保留各自滚动/加载状态），非活跃页透明度 0 + `IgnorePointer` + `TickerMode`（暂停动画），切换时 **250ms iOS 风格淡入**；窄屏/宽屏（侧边栏）两种布局均生效。

### ✨ 新增（所有页面切换改 iOS 风格动画）
- `lib/core/navigation.dart`：页面转场从 `page_transition`（fade 淡入）改为 **`CupertinoPageRoute`**——右滑推入 + 下层视差 + 上层轻微缩放（iOS 标准 400ms 转场），并支持 **iOS 边缘左滑返回手势**（interactive pop）。`pushPage` / `replacePage` / `pushAndClear` 全部生效，覆盖所有二级页面与 启动→登录→主界面 跳转。
- 移除 `page_transition` 依赖（pubspec.yaml）。

### 🎨 UI 优化（应用页搜索栏改静态玻璃样式）
- 应用页搜索栏从 `GlassSearchBar`（shader 玻璃，GLES 设备不渲染）改为**静态玻璃**（`main_screen.dart` `_buildSearchBar`）：半透明渐变填充（顶部高光）+ 白色高光描边 + 圆角 12 + 高度 42，与内容卡片同款参数；保留搜索/清除图标与输入逻辑（`_searchCtrl` listener 驱动，无 `showsCancelButton`）。

### 🔧 重构（卡片去除 BackdropFilter 改静态玻璃）
- 用户要求"直接去掉 BackdropFilter"：`contentCardGlass`（IosCard/IosListGroup/登录卡）与「添加常用功能」底部弹窗移除 `BackdropFilter`/`RepaintBoundary`，改**静态玻璃**——半透明渐变填充（顶部略亮模拟反光）+ 白色高光描边，无 blur 采样依赖 → **overscroll 永不"变透"**；删除 `dart:ui` import。

### 🐛 修复（滚动 overscroll 卡片变透 · 降 blur 提填充保底）
- RepaintBoundary 未解决：BackdropFilter 与 iOS 橡皮筋（BouncingScrollPhysics 位移+裁剪）组合是 Flutter 平台级限制，采样仍会被破坏。
- 调整 `contentCardGlass`（ios_kit.dart）：blur 26 → **12**（降低采样依赖）、填充白 30% → **40%** / 深灰 40% → **50%**（视觉保底）→ overscroll 时即使 blur 失效，卡片呈半透明浅卡而非全透。

### 🐛 修复（滚动到顶/底时卡片变透）
- **根因**：`BackdropFilter` 在 ListView 滚动/overscroll（橡皮筋）时被裁剪 + 位移 → 采样区域破坏、blur 失效 → 卡片只剩 30% 填充，看起来"变透"。
- **修复**：`contentCardGlass` 外包 `RepaintBoundary`（ios_kit.dart），独立绘制层避免与滚动容器合并重绘导致的采样异常。

### 🎨 UI 优化（卡片玻璃去除厚重白色底）
- 用户"还是有白色底色"：`contentCardGlass` 填充从白 66%/深灰 72% 大幅降至 **白 30%/深灰 40%**（透出 LiquidBackground 渐变/气泡），描边改**白色高光细边**（浅色 45%/深色 10%，iOS 玻璃边缘感）；「添加常用功能」底部弹窗填充同步降至白 40%/深灰 50%。

### 🐛 修复（卡片玻璃在 GLES 设备不渲染 → 改 BackdropFilter 毛玻璃）
- **根因**：`GlassCard` 的 shader 玻璃在无 Impeller/Vulkan（GLES）设备上 `ImageFilter.isShaderFilterSupported == false` → 不渲染玻璃、直接透出背景（LiquidBackground 浅色渐变下看起来就是白色卡片）。
- **修复**：`IosCard` / `IosListGroup` / 登录表单卡改用 **BackdropFilter 手写毛玻璃**（`contentCardGlass` 容器，ios_kit.dart：半透明白 66% / 深灰 72% + `blur 26` + 细描边，Flutter 内置 blur 全设备有效）；删除 `contentCardGlassSettings`（GlassCard 参数函数）。「添加常用功能」底部弹窗原方案即 BackdropFilter，不受影响。
- 卡片结构：`ClipRRect > BackdropFilter(blur 26) > Container(半透明白, 圆角, 描边) > Material(transparency) > Padding`。

### 🎨 UI 优化（内容卡片全面液态玻璃化）
- 用户要求"所有白色卡片使用 iOS 液态玻璃"：`IosCard` / `IosListGroup`（ios_kit.dart）内部实色白底（90-92%）改为**液态玻璃**——`GlassCard(useOwnLayer: true, quality: standard)` + 统一参数 `contentCardGlassSettings(context)`（glassColor 白66%/深灰72%、blur 26、standardOpacityMultiplier 0.85、whitenStrength 0.4、thickness 30），透出 LiquidBackground 渐变/气泡；内部透明 `Material` 保留主题继承。
- 登录表单卡（login_page.dart）同步玻璃化（useOwnLayer + 同参数）；「添加常用功能」底部弹窗（ios_kit.dart）改 `ClipRRect + BackdropFilter(blur 26) + 半透明白` 毛玻璃（顶部圆角 22）。
- ⚠️ 规范变更：推翻"内容区实色底"旧准则，内容卡片与导航/控制层统一液态玻璃（standard 管线滚动安全）。

### 🎨 UI 优化（应用页分类宫格卡片四周留白等边）
- 卡片内边距 `symmetric(vertical: 6)` → **`EdgeInsets.all(8)`**（上下左右等边）；卡片下方与网格间距 20 → **16**（与上方搜索框间距 16、页面左右 16 对齐）→ 卡片内外四周留白统一等边。

### 🎨 UI 优化（应用页分类宫格卡片高度与选中状态动态契合）
- 改用 `IntrinsicHeight + Row(stretch)`：分割线与选中背景（AnimatedContainer）自动拉伸至内容全高，高度随文字实际行高动态适配——彻底解决固定分割线高度与选中背景不齐的问题；选中背景切换加 200ms 淡入动画。

### 🎨 UI 优化（应用页分类宫格卡片高度比例微调）
- 分割线高度 30 → **46**（贯穿图标+文字内容区，此前偏短不协调）；卡片垂直 padding 10 → 8、单元 padding 4 → 3 → 卡片总高约 66，与设置页分组卡观感一致。

### 🎨 UI 优化（应用页分类选择改统一宫格卡片 + 内部分割线）
- 应用页分类栏从分段控件（GlassSegmentedControl）改为**统一宫格卡片**（`main_screen.dart` `_buildTabBar` 用 `IosCard` 玻璃卡）：5 个分类等宽横排、图标+文字竖排，相邻分类间 0.5px 竖分割线（与 `IosListGroup` 分隔线同规格）；选中项浅 accent 背景圆角 + accent 色加粗，未选中 `textSecondary`。

### 🎨 UI 优化（应用页分类选择样式优化）
- `IosSegmentedControl`（`lib/core/ios_kit.dart`）：高度 36 → **44**（竖排布局 图标16+文字13 不再拥挤）；新增显式选中/未选中文字样式（选中 `textPrimary` w600 / 未选中 `textSecondary` w500，替代依赖 CupertinoTheme 回退的 60% 透明度）；图标尺寸交由内部 IconTheme 统一（移除外部 size 15）；指示器 padding 2 → 3；新增 iOS 26 按压辉光 `glowColor: accent 18%`（默认软白在浅色下不可见）。

### 🎨 UI 优化（应用页网格固定 4 列并对齐首页常用功能间距）
- 应用页网格去掉自适应列数（`appGridColumns`），固定 `crossAxisCount: 4`；上下间距 `mainAxisSpacing 18 → 14`、左右 `crossAxisSpacing 8`、卡片比例 `childAspectRatio 0.82`，与首页「常用功能」宫格完全一致。

### 🎨 UI 优化（应用页顶部状态栏留白与设置页对齐）
- 应用页（`lib/home/main_screen.dart` `_AppsPage`）此前**漏包 `SafeArea`**（GlassScaffold 不自动 SafeArea），窄屏下标题顶到状态栏、上方无空白；补 `SafeArea(bottom: false)`，并将顶部 padding 统一为 10（原窄屏 12 / 宽屏 28）→ 与首页/设置页顶部结构一致（状态栏下留白 + 大标题）。

### 🎨 UI 优化（应用页/设置页顶部眉标文字移除）
- 设置页（`lib/settings/settings_page.dart`）顶部 `IosLargeTitle` 移除 `eyebrow: '宜院宾果'`，仅保留大标题「设置」。
- 应用页（`lib/home/main_screen.dart`）顶部大标题「应用」上方无眉标文字（旧版本显示的「全部校园服务」在当前代码中已不存在），两页顶部结构一致，仅保留大标题。

### 🐛 修复（账号/关于卡残留默认 margin）
- **根因**：此前批量给 `IosListGroup` 加 `margin: EdgeInsets.zero` 时只命中无 `header` 的调用格式——**带 `header:` 的账号/关于两组被漏掉**，仍带默认 16px 边距 → 比上方两张卡窄 32px。
- **修复**：账号/关于两组补 `margin: EdgeInsets.zero`；并把 `IosListGroup` **默认 margin 改为 `EdgeInsets.zero`**（页面 ListView 均已提供 padding），从根上杜绝同类遗漏。

### 🐛 修复（设置页四卡片宽度强制一致）
- `width: double.infinity` 在 loose 约束下可能不生效（尤其个人信息卡 loading 状态无 Expanded 会收缩）→ 改用**终极保险**：设置页与常用功能管理页主 Column 改 `crossAxisAlignment: CrossAxisAlignment.stretch`，强制个人信息卡/外观/账号/关于四卡同宽，任何状态下不收缩。

### 🐛 修复（设置分组卡宽度与个人信息卡不一致）
- **根因**：设置页 `Column(crossAxisAlignment: CrossAxisAlignment.start)` 为 loose 约束，`IosListGroup` 的 Container 无显式宽度 → 宽度被内容收缩；个人信息卡内容含 `Expanded` 会撑满 → 分组卡比个人信息卡窄。
- **修复**（`lib/core/ios_kit.dart`）：`IosListGroup` 容器加 `width: double.infinity`，与同列卡片对齐。

### 🎨 优化（启动/过渡界面统一 LiquidBackground）
- 用户"登录过后的过渡界面也要使用 LiquidBackground"：`SplashPage`（验证 Cookie 过渡页）去掉品牌渐变，改用默认 `LiquidBackground` + 文字/图标主题色（`colorScheme.onSurface`）。至此 启动页 / 登录页 / 首次获取信息页 / 主界面 / 全部二级页面 均统一主界面同款背景。

### 🎨 优化（二级页面自带主界面同款背景）
- 用户要求"二级界面也要有主界面同款背景，不是直接透明"——每页**自带** LiquidBackground，不依赖全局透出。
- **`SimplePage` 新增 `background` 参数（默认 true）**：内置 `LiquidBackground(child: 内容)` → 38 个业务页自动获得主界面同款背景；主界面两个 tab 页（首页/设置）传 `background: false`（MainScreen GlassScaffold 已提供背景，避免叠加）。
- **10 个直接 Scaffold 的独立页补包 LiquidBackground**：校历服务（2 个页面类）/ 调停补 / 电费查询 / WebView 通用页 / 竞赛详情 / 我的竞赛详情 / SRTP 详情 / VR 地图；外观页给 `GlassPage` 加 `background`；首次获取信息页去掉品牌渐变改 LiquidBackground + 文字主题色。
- 全局 builder 底层 LiquidBackground 保留作为兜底（转场瞬间背景连续）。

### 🎨 优化（所有页面统一主界面同款背景）
- 用户要求"二级页面和登录页都要是主界面那个背景，不要半透明也不要品牌界面"：
  - `main.dart` 主题 `scaffoldBackgroundColor` 从半透明（0.78/0.82）改为 **`Colors.transparent`** → 所有二级页面完全透出 builder 层 LiquidBackground（气泡全清晰显示，无遮罩层）；
  - `login_page.dart`：背景去掉品牌蓝渐变，改用默认 `LiquidBackground()`（主题渐变 + 气泡）；状态栏 `light → auto`；标题「宜院宾果」白色改为跟随主题（`colorScheme.onSurface`）。
- 移除主题中不再使用的 `bgColor` 变量。

### 🎨 优化（背景动态改用 fluid_background 气泡）
- 新增依赖 `fluid_background: ^1.0.5`（官方 verified publisher，无额外依赖，全平台）。
- `lib/core/liquid_background.dart` 重构：`LiquidBackground` 从「自绘光斑动画」改为「主题渐变底色 + `FluidBackground` 彩色气泡层」（气泡 = 彩色渐隐圆 + 内置 blur，缓慢漂移，`velocity 55`、`bubblesSize 420`、尺寸渐变 4s）。接口不变（child / colors / animated），主界面 / 全局路由底层 / 登录页零改动自动升级；`colors` 参数同时控制渐变底色与气泡色（登录页品牌蓝渐变 → 蓝系气泡）。
- 组件由 StatefulWidget 简化为 StatelessWidget（动画由包自管）。

### 🎨 优化（背景模块化：全部页面统一液态玻璃背景）
- **新增 `lib/core/liquid_background.dart` 公共组件** `LiquidBackground`（渐变 + 3 光斑正弦漂移动画，16s 循环；支持 `child` 覆盖层、`colors` 自定义渐变、`animated` 开关）——首页/全局/登录页统一复用，**禁止再手写纯色/私有背景**。
- **`main_screen.dart`**：删除私有 `_buildDefaultBackground`/`_glowBlob`/`_bgCtrl`（SingleTickerProviderStateMixin 一并移除），GlassScaffold 默认背景改用 `LiquidBackground`。
- **`main.dart`**：MaterialApp.builder 底层改用 `LiquidBackground(child: Theme(...))` → 二级页面 Scaffold 半透明透出动态光斑背景。
- **`login_page.dart`**：品牌蓝渐变背景改用 `LiquidBackground(colors: 品牌蓝渐变)`，保留白字可读性 + 新增动态光斑。

### 🎨 优化（全局二级页面去纯色背景）
- **根因**：业务页 `Scaffold` 默认使用主题不透明背景色（接近纯色），登录页已有渐变但 52 个二级页面全是纯色。
- **修复**（`main.dart` 全局机制，一处改动覆盖全部页面）：
  - `MaterialApp.builder` 底层铺设**全局 accent 渐变背景**（浅色 accent 掺白系 / 深色暗黑系，随主题/强调色动态变化）；
  - 主题 `scaffoldBackgroundColor` 改为**半透明**（浅 0.78 / 深 0.82）→ 所有业务页 Scaffold 透出渐变；
  - 主界面/登录页/启动页自身不透明背景盖住全局层，不受影响；Dialog/SnackBar 浮层不受影响。

### 🎨 优化（设置界面卡片宽度一致）
- **根因**：`IosListGroup` 默认自带 16px 水平 margin，而设置页/常用功能管理页的 ListView 已提供 16px padding → 分组卡片比个人信息卡（Card 无 margin）窄 32px。
- **修复**：`settings_page.dart` 三处 + `quick_apps_page.dart` 一处 `IosListGroup` 显式 `margin: EdgeInsets.zero`，所有卡片边缘对齐。

### 🎨 优化（应用宫格按钮玻璃参数统一为底部导航栏参数）
- 用户要求"应用按钮参数也改成这样"：`GlassScaffold` 页面级 `settings`（grouped 子 widget 继承，宫格 GlassButton 同源）改为底部导航栏同款 `thickness 30 / blur 5 / glowIntensity 1.2 / refractiveIndex 2.6 / specularSharpness sharp / standardOpacityMultiplier 0.8`，应用页与首页宫格按钮玻璃质感统一。

### 🎨 优化（背景光斑动效：缓慢漂移）
- 用户要求"光斑要能动起来"：`_MainScreenState` 加 `SingleTickerProviderStateMixin` + 16s 循环 `AnimationController`，三处光斑以不同相位/幅度做正弦漂移（iOS 26 动态壁纸感）；玻璃背景采样随之动态变化，底部栏模糊/折射内容始终在动。

### 🎨 优化（首页/设置页透出渐变背景）
- **根因**：首页/设置页内部 `Scaffold` 默认使用主题不透明背景色，把 `GlassScaffold` 的渐变+光斑背景完全盖住（应用页无 Scaffold 所以能看到渐变）。
- **修复**：`home_dashboard.dart` / `settings_page.dart` 的 `Scaffold` 加 `backgroundColor: Colors.transparent`，透出玻璃背景源；独立路由页（如常用功能管理页）保持主题背景不透出前页。

### 🎨 优化（底部导航栏透出文字）
- 用户要求"透出下面的文字"：`blur 10 → 2`（文字基本清晰透出）、`thickness 44 → 24`、`standardOpacityMultiplier 1 → 0.8`、`glowIntensity 1.6 → 1.2`；保留 `premium + refractiveIndex 2.6 + specularSharpness sharp`（折射边缘）。页面级 settings 用户已自行调至低模糊（thickness 10/blur 5）。

### 🎨 优化（底部导航栏通透：仅调低模糊）
- 仅 `blur 20 → 10` 实现通透（更清晰透出背景）；其余参数恢复折射生效版：`thickness 44 / glowIntensity 1.6 / refractiveIndex 2.6 / specularSharpness sharp / standardOpacityMultiplier 1`。

### 🎨 优化（底部导航栏更通透的液态玻璃）
- 用户确认折射生效后要求"更通透"：`thickness 44→28`（更薄）、`blur 20→10`（更透亮）、`glowIntensity 1.6→1.2`（光晕收敛）、`standardOpacityMultiplier 1→0.7`（比 Apple 基准 6% 更透）、保留 `premium + refractiveIndex 2.6 + specularSharpness.sharp`（折射与镜面高光不衰减）。

### 🎨 优化（底部导航栏折射效果：显式 Premium + 强折射参数）
- **根因**：折射（refraction）+ 色散（chromatic aberration）是 **Premium 质量完整 shader 管线的专属能力**，Standard 为轻量 shader 无折射。底部栏虽被 GlassScaffold 默认提升 premium，但在部分设备/场景下质量推断可能回退，折射不生效。
- **修复**（`main_screen.dart`）：`GlassTabBar.bottom` **显式 `quality: GlassQuality.premium`**；折射参数增强（`refractiveIndex 2.2 → 2.6`）+ `specularSharpness: GlassSpecularSharpness.sharp`（镜面高光）；背景光斑饱和度提升（alpha 0.4→0.55）让滚动经过玻璃时的折射变形肉眼可感知。

### 🎨 优化（液态玻璃真实效果：默认背景改为渐变 + 光斑）
- **根因**：液态玻璃必须模糊「背景内容」——原默认背景是**纯色**（`Container(color: defaultBg)`），模糊纯色仍是纯色，玻璃呈现为半透明实块而非玻璃（README 明确："Without a controlled background, glass surfaces can appear flat, incorrectly tinted, or invisible"）。
- **修复**（`main_screen.dart`）：默认背景改为 **iOS 26 风格多彩渐变 + 三处装饰光斑**（RadialGradient 圆形渐隐，浅色清新/深色霓虹）。底部导航栏滚动时真实模糊渐变与光斑 → 液态玻璃质感；首页玻璃卡片边缘透出渐变。用户自定义背景图片逻辑不变（遮罩基色独立 `_overlayColor`）。

### 🎨 优化（底部导航栏液态玻璃效果）
- 底部 `GlassTabBar.bottom` 玻璃参数从 `blur: 1`（近乎无模糊的半透明实块）调优为 iOS 26 风格液态玻璃：`thickness 44 / blur 20 / glowIntensity 1.4 / refractiveIndex 2.2`，明显模糊透出背景。底部栏由 `GlassScaffold` 自动提升 premium 质量（完整 shader 折射 + 色散），由 `warmUpImpellerPipeline` 预热保证 GLES 兼容。

### 🐛 修复（底部导航栏 label 字体解耦问题）
- **根因**：`GlassBottomBar`（`GlassTabBar.bottom`）的标签文字默认样式 `fontSize 11 + 选中/未选字重`，**未指定颜色**——依赖 `DefaultTextStyle`。解耦后 bottomBar 区域无 Material 祖先 → label 回退**纯黑**（深色模式下黑字在深色玻璃上完全看不见）。
- **修复**（`main_screen.dart`）：底部导航栏包透明 `Material`（恢复主题字体）+ 给 `GlassTabBar.bottom` 传显式 `textStyle`（11px，浅色 `#6E6E80` / 深色 `#9E9EB0`）双保险。侧边栏文字在 body Material 内已正常。

### 🐛 修复（Material 解耦导致字体异常 + 文字去红色）
- **字体异常根因**：0.26.0+ `GlassScaffold` 内部是 `CupertinoPageScaffold`，**不提供 Material 的 `DefaultTextStyle`**——无子 `Scaffold` 的页面（应用页）所有 `Text` 回退到 Flutter 默认样式（14px 纯黑），字体字号/字色异常。
- **修复**：`main_screen.dart` 的 `GlassScaffold.body` 外层包透明 `Material`（恢复主题字体继承 + Material 祖先；首页/设置页自带 Scaffold 不受影响）。
- **文字去红色**（统一替换为深橙 `#C2410C`，保留警示感）：错误提示（erke 登录、电费查询）、「解绑」确认、「已终止/驳回/不通过」状态标签（srtp/学科竞赛）、停课/调停补标记（课程表/调课）、不及格分数（成绩/学业完成）、PDF 标签（校历）；全局表单校验错误文字 `errorStyle` 去红。红色图标、删除背景、安全页主题红保留（非文字）。

### 🎨 优化（玻璃内容卡片可读性 → 实色底）
- **根因**：`GlassQuality.standard` 默认玻璃透明度仅 **6%**（Apple 匹配基准，适合导航层），此前内容卡片全部做成玻璃 → 文字直接透出背景，对比度不足"看不清"。违背 iOS 26 设计准则（内容区保持不透明，玻璃只用于导航/控制层）。
- **修复**（`lib/core/ios_kit.dart`）：`IosCard` 卡片内部加高对比实色底（浅色白 0.9 / 深色 `#1C1C1E` 0.94），保留玻璃边缘质感；`IosListGroup` 重构为 iOS 分组卡片样式（实色底 + 圆角描边 + 自动分隔线）；登录卡 `Material` 同样加实色底（0.92/0.95）。
- 导航层（GlassTabBar 底部栏、GlassButton 宫格方块）保持玻璃不变——保留液态玻璃亮点。

### 🐛 修复（登录页 No Material widget found + SnackBar 失效）
- **根因**：liquid_glass_widgets 0.26.0 起 **Material 完全解耦**——`GlassCard`/`GlassScaffold`（内部 `CupertinoPageScaffold`）不再提供 Material 祖先。登录表单由 `Card` 改为 `GlassCard` 后，内部 `TextField`/`Checkbox` 等 Material 组件失去 Material 祖先 → 运行时报 `No Material widget found`；同时登录失败提示 `SnackBar` 因无 Material `Scaffold` 宿主而无法显示。
- **修复**（`lib/auth/login_page.dart`）：`GlassScaffold` body 包一层透明 `Scaffold`（`backgroundColor: Colors.transparent`，提供 Material 祖先 + SnackBar 宿主，不影响玻璃渲染）；登录卡 `GlassCard` 内包 `Material(type: transparency)` 承载表单。
- **前瞻修复**（`lib/core/ios_kit.dart`）：`IosCard` 统一在 `GlassCard` 内包透明 `Material`——首页卡片里的 `TextButton`（查看完整课表）/`FilledButton`（游客去登录）等 Material 组件不再缺祖先。
- 验证：analyze No issues；`flutter build apk --debug` 成功。

### 🎯 优化（常用功能自定义迁移至设置页）
- 首页「常用功能」宫格改为**只读展示**（点击直达应用），移除首页编辑模式（自定义按钮/抖动/删除/拖拽）。
- **新增 `lib/settings/quick_apps_page.dart` 常用功能管理页**（设置 → 外观 → 常用功能）：已添加列表（**左滑删除** + **长按拖拽排序**）、「添加常用功能」入口（底部弹窗从全部应用搜索添加，上限 12），修改即时生效并**自动刷新首页宫格**。
- 数据层抽取为 `QuickAppsStore`（`lib/core/ios_kit.dart`：load/save/默认值/maxCount），新增全局 `quickAppsChangedNotifier` 变更通知器（设置页修改后首页监听刷新）。

### 🎨 完全重构 UI 风格：iOS 液态玻璃（Liquid Glass）
- **新增 `lib/core/ios_kit.dart`（iOS 风格组件库）**：
  - `IosLargeTitle`（iOS 大标题 + 日期眉题）、`IosSectionHeader`（分组标题）、`IosCard`（玻璃内容卡片）、`IosListGroup`（玻璃分组列表）、`IosListTile`（iOS 风格条目 + chevron）、`IosSegmentedControl`（玻璃分段控件封装）；统一超椭圆圆角（squircle）。
- **首页全新布局**（`lib/home/home_dashboard.dart`）：
  - 顶部 iOS 大标题 + 时段问候语（早上好/下午好/晚上好 + 姓名，游客显示欢迎语）+ 日期眉题；
  - **✨ 常用功能宫格**：默认 8 个（课程表/成绩查询/校历服务/校园新闻/临港电费/校车时间/网络服务/VR地图），点击直达；自定义（增删/拖拽排序）在「设置 → 常用功能」管理页，配置持久化到 `home_quick_apps`；
  - 今日课程 / 校园新闻改为玻璃卡片，周次标签胶囊化。
- **主框架**（`lib/home/main_screen.dart`）：底部 `GlassTabBar` 换 Cupertino 图标；应用页改为 iOS 大标题 + `GlassSearchBar` 玻璃搜索 + `GlassSegmentedControl` 分类分段 + 控制中心风格玻璃宫格。
- **设置页**（`lib/settings/settings_page.dart`）：分组列表全面玻璃化（`IosListGroup` + `IosListTile`），含个人信息卡、外观/账号/关于三分组。
- **全局主题 iOS 化**（`lib/main.dart`）：iOS 系统分组背景（浅 `#F2F2F7` / 深黑）、卡片圆角 14 + 细描边无阴影、`#E5E5EA` 分隔线。
- 登录页登录卡片改液态玻璃（透出品牌渐变背景）；外观页标题对齐 iOS 分组标题。

### 🐛 修复（进入应用白屏 → liquid_glass_widgets 升级 0.29.1）
- **根因**：旧版 `liquid_glass_widgets 0.21.3` 的 Impeller 管道预热是 **no-op**（通过未挂载的 `LiquidGlassLayer` widget 预热，未挂载即不栅格化，GPU 无实际工作）。在 Android **无 Vulkan 支持**的设备（MediaTek / 中端骁龙，走 Impeller GLES）上，`glCompileShader`+`glLinkProgram` 于首帧在 raster 线程**同步执行**（100–800ms），与 `nativeSurfaceChanged` 表面初始化竞争 → 首帧渲染失败，进入应用白屏。
- **修复**：`pubspec.yaml` 升级 `liquid_glass_widgets` `^0.21.3 → ^0.29.1`（最低要求 Flutter ≥ 3.41，本机 3.44 ✓）：
  - 0.29.1 `initialize()` 默认 `warmUpImpellerPipeline: true`——在 `runApp` 前用 1×1 离屏表面真实栅格化两种 premium shader，GLES 管道编译在原生启动屏背后完成，不再与表面初始化竞争；
  - 顺带获得：Android 冷启动 Infinity/NaN 崩溃修复、`GlassScaffold` 转场透明修复（issue #177）、Vulkan 合成位竞争修复。
- **适配**：`main.dart` 的 `LiquidGlassWidgets.wrap()` 补传 `brightnessResolver: Theme.maybeBrightnessOf`（0.29.1 起 MaterialApp 用户必须，修复深色系统 + 浅色应用时玻璃阴影丢失 #124）。其余 API（GlassScaffold/GlassTabBar/GlassCard/GlassSegmentedControl/GlassButton/LiquidRoundedSuperellipse 等）0.29.1 完全向后兼容，零改动。
- 验证：全 `lib` `dart analyze` 0 error；`flutter build apk --debug` 构建成功（52s）。

### 🐛 修复（首页仍白屏 → GlassQuality 从 premium 降为 standard）
- **二次根因（日志定位）**：升级 0.29.1 后逻辑层正常（课程请求已发出、无任何异常），但渲染仍白屏。官方文档明确：**`GlassQuality.premium` 仅适合静态非滚动表面，在 `ListView`/`CustomScrollView` 内于 Impeller 上可能渲染错误**。项目全局主题设为 premium（0.21.3 时代遗留），而首页/应用页/设置页全是滚动列表中的玻璃卡片/宫格 → 内容静默不渲染 → 整页白屏。
- **修复**：`main.dart` 全局 `GlassThemeVariant.quality: premium → standard`（官方推荐默认，95% 场景适用，滚动内容安全；导航栏/底部栏由 `GlassScaffold` 的 `GlassIsolationScope` 自动提升 premium，观感不降）。
- **消除 `settings provided without useOwnLayer` 警告**：grouped 模式下 per-widget `settings` 被父层忽略并打印警告。改为页面玻璃参数统一由 `GlassScaffold.settings` 提供（`thickness 32 / blur 14`），`IosCard`/宫格 `GlassButton`/登录 `GlassCard` 不再传 per-widget settings（`lib/core/ios_kit.dart` 删除 `kIosCardGlass`/`kIosTileGlass` 常量，改为设计约束注释）。
- 验证：全 `lib` analyze 0 error；`flutter build apk --debug` 25s 成功。

### ✨ 新增（邮件系统）
- 新增「邮件系统」应用入口（服务分类，需登录），内置 WebView 打开 `http://mailmid.yibinu.edu.cn/index/index/oauthLogin`（宜宾学院邮箱，phpCAS 1.3.2 接入学校统一认证），复用统一登录免密进入邮箱。
- 认证链路（curl 实测确认）：未登录访问 oauthLogin → 302 到 `authserver.yibinu.edu.cn/authserver/login?service=http://mailmid.../oauthLogin` → CAS 验证 CASTGC → 302 回 `oauthLogin?ticket=ST-xxx` → phpCAS 验证 → 服务端 Set-Cookie 建立邮件会话。
- 新模块 `lib/mail/`（Service / Page 两层）：
  - `mail_service.dart`：`MailService` —— `injectCasCookiesToWebView` 按原域注入统一认证 cookie（**CASTGC → 父域 `.yibinu.edu.cn`** Secure+HttpOnly 供 https authserver 放行 SSO；authserver 自身 cookie → authserver 域；不注入 ehall 业务 cookie）；`hasLocalCasSession` 检查本地会话；
  - `mail_page.dart`：`MailPage` —— 加载 oauthLogin 自动 SSO；CAS 登录页停留检测（提示条引导手动登录兜底）、加载进度条、底部工具栏（后退/前进/首页/刷新）、菜单（外部浏览器打开/清除缓存，清缓存后自动重注入 cookie）。
- 注：mailmid 为 http 明文站点，Android 已全局开启 `usesCleartextTraffic`（无需改 Manifest）；CAS 顶层导航不受混合内容限制，WebView 已设 `MIXED_CONTENT_ALWAYS_ALLOW` 兜底。
- `lib/home/app_data.dart` 注册 `MailPage` 入口（服务分类，✉️ 图标）。

### 🔧 版本号升级至 1.1.6
- `VERSION` / `pubspec.yaml`（1.1.6+8）/ `lib/core/version.dart` / `README.md` 徽章 四处同步升级；Android versionCode 由 flutter.versionCode 从 pubspec 读取，自动 +1（7→8）。
- 1.1.6 新增内容：全校方案查询模块（列表/年级筛选/详情课程组树）。

### 🔧 版本号升级至 1.1.5
- `VERSION` / `pubspec.yaml`（1.1.5+7）/ `lib/core/version.dart` 三处同步升级；Android versionCode 由 flutter.versionCode 从 pubspec 读取，自动 +1。
- 1.1.5 新增内容：玻尔科研平台（CAS SSO 内置 WebView）、课程查询（搜索/筛选/分页/详情）及 403 与转圈修复。

### 🐛 修复（课程查询 403 服务器拒绝访问）
- **根因（实测定位）**：ehall 网关（rump/e）对 kccx 业务 POST 校验 `_WEU` 会话 cookie，缺失/失效即返回 403（用抓包 cookie 逐个剔除验证：去掉 `_WEU` 必 403，`MOD_AUTH_CAS`/`JSESSIONID`/`route`/`asessionid` 均无影响，Referer 的 `gid_` 也无影响）。`_WEU` 只能通过有效 ehall 登录链获得。
- **修复**（`lib/kccx/kccx_service.dart`）：
  - `ensureSession` 改为 **noRedirect 手动跟随重定向**（门户 `new/index.html` + kccx 首页，逐跳 GET），确保重定向链中间响应的 Set-Cookie 都被捕获（Dart HttpClient 自动跟随会丢弃中间响应 Set-Cookie）；
  - **新增 ehall 应用入口链**：`appMultiGroupEntranceList?appId=...` → GET 返回的带 `gid_` 的 targetUrl（`gid_` 为**会话级**标识，实测不同应用相同；kcbcx 全校课表已验证此链是建立 ehall 网关会话 `_WEU` 的关键——kcbcx 无 `_WEU` 同样 403 证明其 ensureSession 正是靠此链拿到 `_WEU`）；
  - `fetchCourses` / `fetchCourseDetail` 遇 403 时**自动重登**（`AuthService.autoRelogin`，记住密码时用已存账号密码刷新 ehall 会话）→ 重新预热 → 重试一次；未记住密码时提示「登录已过期，请重新登录后重试（403）」；403 前后打印各域 cookie 名便于定位。
- 备注：用户给出的 `appShow?appId=4766860087431764` 实为「全校方案查询」（qxfacx），课程查询无 appId（入口 `thirdAppIndexShell.html`），本修复不依赖 appId。

### 🐛 修复（课程查询一直转圈无响应）
- **根因**：`kccx_page.dart` 在 `initState` 中调用 `_loadFirstPage()`，其首行 `FocusScope.of(context).unfocus()` 在 initState 阶段依赖 InheritedWidget（FocusScope）→ Flutter 抛异常 → async 异常被静默吞掉 → `_isLoading` 永远为 true → 页面一直转圈。
- **修复**：键盘收起逻辑移到用户交互回调 `_submitSearch()`（查询按钮 / 输入框提交时执行），`_loadFirstPage` 不再在 initState 调用链中访问 InheritedWidget。
- 列表底部新增分页进度提示：「已加载 X / 共 Y 条 · 上滑加载更多」/「已加载全部 Y 条课程」（全量 1 万+ 条课程走服务端分页 + 无限滚动）。

### ✨ 新增（课程查询）
- 新增「课程查询」应用入口（教务分类，需登录），基于 ehall jwapp「课程查询」（kccx 模块）按 课程名/课程号 搜索、考试类型/课程层次 筛选课程信息。
- 新模块 `lib/kccx/`（严格模块化：Model / Service / Page 三层）：
  - `kccx.dart`：`KccxCourse`（课程：KCM 课程名 / KCH 课程号 / XF 学分 / XS 学时 / KKDWDM 开课单位 / KSLXDM 考试类型 / KCFZR 负责人 / KCCCDM 课程层次 / KCZTDM 状态等，手写 fromJson 兜底）、`KccxPageResult`（分页结果）；
  - `kccx_service.dart`：`ensureSession`（GET kccx 首页预热）、`fetchCourses`（kcxxcx.do，querySetting 组装 KCM/KCH 包含匹配 + KSLXDM/KCCCDM 等值过滤，默认 `KCZTDM=1` 仅查启用课程，分页无限滚动）、`fetchCourseDetail`（initKcdg.do，按 KCH 取课程完整信息）；
  - `kccx_page.dart`：课程名/课程号双搜索框 + 考试类型 chips（全部/考试/考查）+ 课程层次 chips（全部/本科/专科）+ 查询按钮；四态 + 分页无限滚动 + 下拉刷新；课程卡片展示 课程名/课程号/学分·学时/开课单位/考试类型/课程层次/负责人，点击进入详情页；
  - `kccx_detail_page.dart`：课程详情页（initKcdg.do），头部卡片 + 基本信息/单位信息/教学信息/其他 分组展示完整课程字段。
- `lib/home/app_data.dart` 注册 `KccxPage` 入口。

### ✨ 新增（玻尔科研平台）
- 新增「玻尔科研」应用入口（教务分类，需登录），内置 WebView 打开 `https://yibinu.bohrium.com/`（深势科技 Bohrium 高校定制版），复用学校 CAS 统一认证免密登录。
- 新模块 `lib/bohrium/`（模块化两层：Service / Page）：
  - `bohrium_service.dart`：`BohriumService` —— `injectCasCookiesToWebView` 从 `SharedHttpClient` 提取 authserver/yibinu/ehall 域 cookie（含 Secure/HttpOnly 的 **CASTGC**，按 `.yibinu.edu.cn` 父域 + isSecure 注入）到 WebView，使 CAS SSO 自动放行；`hasLocalCasSession` 检查本地是否有可注入会话；
  - `bohrium_page.dart`：`BohriumPage` —— 加载平台首页，initState 先注入 cookie 再进 WebView；CAS 登录页停留检测（提示条引导手动登录兜底）、加载进度条、底部工具栏（后退/前进/首页/刷新）、菜单（外部浏览器打开/清除缓存，清缓存后自动重注入 cookie）。
- 平台认证链路已确认：未登录 302 到 `authserver.yibinu.edu.cn` CAS → 回跳 `/cas_login?ticket=...` → `POST /platform-gateway/v1/account/cas_login` 兑换 token（localStorage `brmToken`）。
- `lib/home/app_data.dart` 注册 `BohriumPage` 入口。

### ✨ 新增（全校方案查询）
- 新增「全校方案」应用入口（教务分类，需登录），基于 ehall jwapp「全校方案查询」（qxfacx 模块，入口 `appShow?appId=4766860087431764`）查询全校已发布培养方案。
- 新模块 `lib/qxfacx/`（严格模块化：Model / Service / Page 三层）：
  - `qxfacx.dart`：`QxFacxPlan`（培养方案：PYFAMC 方案名 / NJDM 年级 / DWDM 院系 / ZYDM 专业 / ZYFXDM 专业方向 / XDLXDM 修读类型 / XQLXDM 学期类型 / XZNX 学制 / XWDM 学位 / KSXNDM·KSXQDM 开始学年学期 / ZSYQXF 最少学分 / PYMB 培养目标 / XDYQ 修读要求 / FATS 方案特色 / ZGXK 主干学科 / ZYZYSY 主要专业实验 / ZGKC 主干课程 / FAZTDM 状态 / SHYJ 审核意见 等，手写 fromJson 兜底；`qxfacxHtmlToText` 用 html 包把富文本 HTML 转纯文本——PYMB/XDYQ 等字段有的是 HTML、有的是纯文本，统一处理）、`QxFacxPageResult`（分页结果）、`QxFacxKz`（课程组：KZH 课组号 / KZM 课组名 / KZLXDM 课组类型(01课组/02平台) / KCZXF·KCZXS 组内学分·学时 / ZSXDXF 最少修读学分 / ZSXDMS 最少门数 / KCZMS 门数 / XDYQ 修读要求 / FKZH 父组号，FKZH↔KZH 构建树）、`QxFacxKzCourse`（课组课程：KCH/KCM/XF/XS/KCXZDM 必修选修/KSLXDM 考试考查/SFZGKC 是否主干/KZH 所属课组/XNXQ 开课学期）；
  - `qxfacx_service.dart`：`ensureSession`（appMultiGroupEntranceList?appId=4766860087431764 → 带 gid_ 的 targetUrl → 门户 → qxfacx 首页，noRedirect 手动跟随重定向建 `_WEU` 网关会话）、`fetchPlans`（qxpyfacx.do，querySetting 支持 **NJDM 年级过滤**（与网页端"点击年级分类"一致，条件首位）+ 默认过滤已发布 FAZTDM=99 + PYFAMC 名称包含搜索，`*order=-NJDM,+DWDM,+ZYDM` 与网页端一致，分页无限滚动；403 → `AuthService.autoRelogin` 重登重试一次）、`fetchKzcx`（kzcx.do 课程组）+ `fetchKzkccx`（kzkccx.do 课组课程，均按 PYFADM，共用 `_parseRows` 通用解析）；
  - `qxfacx_page.dart`：**年级分类 chips**（全部/2026级~2021级，横向滚动，点击即筛选）+ 方案名称搜索框 + 四态 + 分页无限滚动 + 下拉刷新；卡片展示 方案名/年级/院系/专业标签/修读类型·学制·学分；
  - `qxfacx_detail_page.dart`：方案详情（列表接口已返回完整字段，无需二次请求）——头部卡片（方案名+已发布状态+年级）+ 基本信息 + 培养目标/修读要求/主干学科/主干课程/主要专业实验/方案特色 富文本区块 + **课程设置**（并行加载课程组 `kzcx.do` + 课组课程 `kzkccx.do`，按 FKZH↔KZH 构建课程组树，平台/课组分层缩进，点击组展开/收起：组信息（学分/学时/门数/修读要求）+ 组内课程列表（课程名/课程号/学分学时/必修选修/考试考查/主干/开课学期））+ 审核信息；
- `lib/home/app_data.dart` 注册 `QxFacxPage` 入口。

### 🎯 优化（进入应用强制重新登录，彻底告别手动重登）
- **问题**：会话过期后（服务端 TTL）本地 cookie 是"死 cookie"，复用会触发 CAS 刷新回环；此前自动续期依赖用户勾选"记住密码"保存凭据，未勾选则只能手动重新登录。
- **方案（用户确认方向）**：**每次进入应用都用本地保存的账号密码走真实 CAS 登录**，不再复用/校验本地 cookie 有效期，保证会话永远新鲜。
- **改动**：
  - `lib/main.dart` `SplashPage._checkSession`：删除「loadCookies → verifySession 判断会话」逻辑；有本地凭据 → 直接 `AuthService.autoRelogin()`（完整 CAS 登录刷新 CASTGC/ehall cookie 并落盘）→ 成功进主界面；无凭据或登录失败 → 登录页。游客模式不变。
  - `lib/auth/login_page.dart`：**凭据总是保存**（`username`/`password` 与勾选状态解耦），`remember_password` 仅控制登录页自动填充；「记住密码」默认勾选。
  - `lib/auth/auth_service.dart`：`autoRelogin()` 不再要求 `remember_password=true`，只要有账号密码即静默重登。
- **效果**：冷启动每次都拿到全新会话（学科竞赛等 scjx2 模块 bootstrap 必成功）；运行时请求 401/404 仍走自动续期（`request` → autoRelogin → WebView SSO）。唯一需要手动登录的场景：首次安装使用、主动退出登录、自动重登失败（如验证码 OCR 连续失败）。

### 🐛 修复（学科竞赛"用久了又无法获取"：回环误判 + cookie 域混淆 + 并发互斥）
- **症状**：应用使用较长时间后学科竞赛/创新创业无法获取数据；会话过期后的自动重登（bootstrapLogin WebView SSO）经常失败，需清应用数据重登才能恢复。
- **根因（代码级定位，4 处缺陷）**：
  1. **刷新回环检测误伤正常 SSO**（`scjx2_api_service.dart`）：旧逻辑统计「4 秒内 onLoadStart 总次数 ≥6 判定回环」。正常 CAS SSO 链路（zxcas → authserver → ticket 回跳 → scjx2 home → 模块）在快网络下 4 秒内可达 6+ 跳 → 被误判为刷新回环 → 硬重置一次 → 第二遍仍误判 → 直接放弃 → bootstrap 失败 → 自愈断裂（网络越快越容易失败，与"时好时坏、清缓存碰运气"吻合）。
  2. **cookie 注入域混淆 + 死 cookie 累积**：`_injectEhallCookiesToWebView` 把 ehall/yibinu/authserver 全部 cookie 统一挂到 `.yibinu.edu.cn` 父域注入，authserver 会收到 ehall 的 JSESSIONID/route/_WEU 等本不该发给它的 cookie（本地 cookie 罐从不清理且忽略 path，长期累积过期变体）→ 干扰 CAS 会话判定、助长回环。
  3. **bootstrapLogin 无并发保护**：race 双 Tab 同时初始化、request 401 自愈与页面 `_tryBootstrap` 可能并发调用 bootstrapLogin，多个 Headless WebView 互相 `deleteAllCookies` 清空对方注入的 cookie → SSO 混乱。
  4. **JSON code=401 自愈失败时抛 `[code=401]`**：页面按「未登录 scjx2/登录已过期」识别登录异常，识别不到 → 无法引导重新登录。
- **修复**：
  - 回环检测改为**按 URL 频率**：同一 URL 10 秒内重复加载 ≥3 次才判定回环（正常 SSO 每个 URL 只加载一次，不误伤）；
  - 注入**按原域清洗**：CASTGC→父域 `.yibinu.edu.cn`（Secure+HttpOnly）、authserver cookie→authserver 域、ehall 业务 cookie→ehall 域，消除域混淆；
  - `bootstrapLogin` 加**互斥锁**（Future 链串行化，成败均推进锁链）；
  - JSON code=401 自愈失败改抛「登录已过期，请重新登录」；
  - 页面（race/my_race/srtp 三个列表页）自愈失败时错误页新增「**重新登录**」按钮 → 跳登录页（替代原"请前往 WebView 登录"死胡同提示）。

### 🐛 修复（学科竞赛数据获取失败：CAS 登录 https service + 缓存回退兜底）
- **根因**：`cas_login_service.dart` 的 `yibinLoginUrl` 仍使用 **http service**（`http://ehall.yibinu.edu.cn/login?service=http://...`），服务端已拒绝该入口（POST 恒 200 失败页无提示）→ 会话过期后 `autoRelogin` / 手动重登 / `bootstrapLogin` 全部失败 → scjx2 race 接口 401/404 → 学科竞赛永远"无法获取到"（缓存加再多也无用）。
- **修复**（`lib/auth/cas_login_service.dart` + `lib/auth/captcha_service.dart`）：
  - `yibinLoginUrl` 改为 **https service**（`https://authserver.yibinu.edu.cn/authserver/login?service=https%3A%2F%2Fehall.yibinu.edu.cn%3A443%2Flogin%3Fservice%3Dhttps%3A%2F%2Fehall.yibinu.edu.cn%2Fnew%2Findex.html`，verify_yibinu.py 已验证成功）；
  - `needCaptcha.html` / `captcha.html` 同步改 https；`_captureCastgcOverHttps` 不再 `replaceFirst('http://', ...)`（URL 本身已是 https）。
- **缓存真正生效**（`lib/race/race_service.dart` + `lib/race/race_page.dart` + `lib/race/my_race_page.dart`）：
  - Service 四个 fetch 方法：请求失败（网络抖动/5xx/解析失败等**非登录类**异常）时**回退缓存**返回，不再直接抛错；登录类异常（未登录 scjx2/登录已过期）仍上抛走 bootstrap 引导；
  - 新增 `cachedCompetitions()` / `cachedMyRaces()`；
  - 页面首屏改为**缓存优先**：有缓存秒开旧数据 + 后台静默刷新（`_refreshSilently`），无缓存才走网络；下拉刷新/重试保持强制刷新；bootstrap 成功后强制走网络拿最新。


### 🔧 版本号升级至 1.1.4
- `VERSION` / `pubspec.yaml`（1.1.4+6）/ `lib/core/version.dart` 三处同步升级；Android versionCode 由 flutter.versionCode 从 pubspec 读取，自动 +1。

### 🐛 修复（课表周次错位：2026-2027-1 第一周未排课）
- **症状**：2026-2027 第 1 学期「第 2 周」显示为 9/21，实际应为 9/14（第一周 9/7 未返校、课表从第 2 周起排）。
- **根因（实测服务端确认）**：`cxxljc.do` 返回 `XQKSRQ=2026-09-09`（所在周周一=9/7）、课程 `SKZC` 最小周次=2（第 1 周无课）；但 `dqzc.do` 在寒暑假返回**负 ZC**（8/2 实测 `ZC=-6`），原 `fetchCurrentWeek` 用 ZC 反推 `firstMonday = 今天-(ZC-1)*7-...` 得到 9/14 → 第 2 周显示 9/21，整体错位一周。
- **修复**：
  - `lib/course/course_service.dart` `fetchCurrentWeek`：`firstMonday` 改为**优先取校历 `XQKSRQ` 所在周的周一**（9/9 周三→9/7 周一），不再用负 ZC 反推；`ZC<1` 时 clamp 到第 1 周；`fetchSemesterCalendar` 缓存 key 加学期后缀（防跨学期污染）。
  - `fetchClassCurrentWeek`（kcbcx 全校课表）：`ZC<1` clamp 到第 1 周。
  - `lib/course/all_class_schedule_page.dart`：班级课表 `firstMonday` 同样优先取 `XQKSRQ` 所在周周一。
- 顺带说明：2026-2027-1 总周数 ZZC=20，课程实际 2~19 周（第 1 周空、第 19 周结束）。

### ✨ 新增（空闲教室查询）
- 新增「空闲教室」应用入口（教务分类，需登录），基于 ehall jwapp「空闲教室」模块，按 学期+周次+星期（+教学楼）实时查询空闲教室。
- 新模块 `lib/kxjas/`（严格模块化：Model / Service / Page 三层）：
  - `kxjas.dart`：`KxjasBuilding`（教学楼）、`KxjasClassroom`（教室，含 JC1~JC20 占用节次解析、座位数）、`KxjasPeriod`（大节/时段）、`KxjasPageResult`（分页结果），手写 fromJson 兜底解析；
  - `kxjas_service.dart`：`ensureSession`（GET index.do 预热）、`fetchBuildings`（jxlcx.do 循环拉全量+缓存）、`fetchPeriods`（cxjcqk.do 大节列表+缓存）、`fetchFreeClassrooms`（cxjsqk.do，querySetting 组装 JXLDM 教学楼 / DJ 大节过滤）、`fetchCurrentWeek`（dqzc.do）；
  - `kxjas_page.dart`：星期 chips（默认今天）+ 周次下拉（默认当前教学周）+ 教学楼下拉（默认全部）+ 大节 chips（默认全部节次，1-2节/3-4节/5-6节/7-8节/9-11节）+ 查询按钮；四态 + 分页无限滚动 + 下拉刷新；教室卡片展示类型/楼层/座位与「空闲」标签。
- 🎨 空闲教室筛选区顶部新增**当前学期只读展示**（「2025-2026 学年 第 2 学期」，取自 `KxjasService.defaultXnxqdm`），不可选择。
- `lib/home/app_data.dart` 注册 `KxjasPage` 入口。

### 🐛 修复（登录失败提示：自定义友好文案，不再抛 HTML 片段）
- **问题**：账号/密码错误时 CAS 返回登录页 HTML（HTTP 200），异常消息拼了 HTML 片段（`登录失败（HTTP 200）：<!DOCTYPE html>...`），显示给用户不友好。
- **修复**（`lib/auth/cas_login_service.dart`）：
  - 新增 `LoginRejectedException`（业务性登录拒绝，不重试；`toString` 返回友好文案）；
  - 新增 `_extractLoginError()`：解析失败页 HTML 提取 `#tips`/`.login-error-tip` 等错误提示；取不到时关键词兜底（账号或密码错误 / 验证码错误 / 账号已停用或不存在 / 登录失败请重试）；
  - `_checkLoginResponse` 与 `_loginWithCaptcha` 改为抛 `LoginRejectedException(友好文案)`，验证码错误仍重试、账号密码错误立即停止。

### 🔧 恢复「登录需先获取到个人信息再进入界面」
- **恢复** `lib/splash/fetch_info_page.dart`（FetchInfoPage，自 git 历史还原）与 `lib/splash/` 目录：登录/会话校验后若本地无学生信息缓存，进入「正在获取个人信息…」过渡页并**阻塞到获取成功**才放行主界面（`fetchUntilSuccess` 持续重试）。
- `lib/xuegong/student_info_manager.dart` 恢复 `fetchUntilSuccess()`。
- `lib/main.dart` `_checkSession`（会话有效 + 自动重登两条路径）与 `lib/auth/login_page.dart`（登录成功）改回：有缓存直接 `MainScreen`，无缓存跳 `FetchInfoPage`。

### 🐛 修复（学工 WebView 不再弹出「用户已停用或不存在」）
- SSO 登录失败时学工系统 JS `alert()` 提示「用户已停用或不存在」，`InAppWebView` 默认弹 Android 系统对话框。
- **修复**：`lib/xuegong/webview_xuegong_page.dart`（可见学工 WebView）与 `lib/xuegong/xuegong_data_service.dart`（Headless 后台获取）的 WebView 均新增 `onJsAlert`/`onJsConfirm`/`onJsPrompt` 拦截——`JsAlertResponseAction.CONFIRM` 静默关闭，仅打日志，不再弹窗。

### 🐛 修复（个人信息获取：页面加载等待加长 + 两个崩溃点）
- **加载等待加长、提高成功率**（`lib/xuegong/xuegong_data_service.dart`）：目标页渲染等待由固定 4 秒改为**轮询 `.minemine` 个人信息区块出现（最多 10 秒）**，未出现再兜底等 4 秒——学工页有 `onLoadAction is not defined` JS 错误、渲染慢时显著提升成功率；HTML 提取失败重试 1→3 次（间隔 5 秒）；总超时 60→90 秒。
- **修 RangeError 崩溃**：`onLoadStop` 的 `url.substring(0, 80)` 在 URL 短于 80 字符时越界（日志 `Invalid value: Not in inclusive range 0..61: 80`），改为长度判断后安全截断。
- **修空 cookie 注入断言崩溃**：`_injectCookies` 跳过空值 cookie（否则 `CookieManager.setCookie` 断言 `value.isNotEmpty` 失败，日志 `Failed assertion: line 79 pos 12`）。

### 🎨 UI 优化（个人信息卡片：自动获取 + 正在获取中状态）
- 设置页个人信息卡片：无缓存时**进入即自动拉取**（学号、姓名、专业等），获取期间显示「正在获取个人信息…」转圈状态，**不再显示「点击获取个人信息」**占位文案。
- 获取失败时显示「获取失败，点击重试」（副文案保留「手动拉取学号、姓名、专业等信息」），点击仍可手动拉取；有数据时展示完整信息不变。

### ✨ 新增（进入主界面后后台自动获取个人信息）
- 上一条移除「首次登录阻塞获取」后，个人信息改为**后台静默获取**：`lib/home/main_screen.dart` 的 `MainScreen.initState` 在非游客模式（`userId` 非空）下触发 `StudentInfoManager.ensureBackgroundFetch(client)`，不阻塞 UI。
- `lib/xuegong/student_info_manager.dart` 新增 `ensureBackgroundFetch()`：已有缓存或已在抓取中则直接返回（静态并发防抖），否则循环 `fetchAndCache` 每 3 秒重试**直到成功**，成功后由 `fetchAndCache` 自动写缓存并退出。
- 效果：登录/进主界面零等待，个人信息在后台自动补齐，设置页可直接看到最新资料。

### 🔧 移除「首次登录获取个人信息」阻塞步骤
- **删除** `lib/splash/fetch_info_page.dart`（FetchInfoPage）及整个 `lib/splash/` 目录：原流程登录/会话校验后若本地无学生信息缓存，会先进入「正在获取个人信息…」过渡页并**阻塞到获取成功**才放行进入主界面。
- **流程简化**：`lib/main.dart`（Splash 会话校验 + 自动重登两条路径）与 `lib/auth/login_page.dart`（登录成功）均改为**直接进入 `MainScreen`**，不再判断个人信息缓存、不再跳转 FetchInfoPage。
- `lib/xuegong/student_info_manager.dart` 删除已无引用的 `fetchUntilSuccess()`；`getCached()` / `fetchAndCache()` / `clearCache()` 保留（设置页个人资料仍按需后台获取与清除缓存）。

### 🔧 版本号升级至 1.1.3
- 同步更新根目录 `VERSION`、`pubspec.yaml`（`version: 1.1.3+5`，build 4→5）、`lib/core/version.dart`（`appVersion`）、README 徽章。

### ✨ 新增（设置「关于」区交流群入口）
- 设置「关于」区新增「交流群」项（`lib/settings/settings_page.dart`），点击加入 QQ 群【宜院宾果】。
- **拉起策略**：Android 用 `intent://` scheme 指定 `com.tencent.mobileqq` 包名**直接拉起 QQ**（带 `browser_fallback_url`，QQ 未安装时自动回退浏览器）；其它平台（Windows 桌面等）直接 `launchUrl` 打开 `https://qm.qq.com/q/miOeBHKlRS`；拉起异常时兜底浏览器打开。

### ✨ 新增（scjx2 大学生创新创业训练计划「SRTP」）
- 应用网格「教务」区新增「大学生创新创业」入口（`lib/home/app_data.dart`，`Icons.rocket_launch_rounded`），进入「我参与的项目」。
- `lib/scjx2/scjx2_api_service.dart` 模块表新增 `srtp`（入口 `zxcas`、模块路径 `/SRTP/`、home 标记 `homeageStu`），使 `bootstrapLogin(moduleId: 'srtp')` 能走完整 SSO 引导，token 独立缓存（`scjx2_srtp_token`）。
- 新增 `lib/srtp/` 模块：`srtp.dart`（模型：`SrtpProjectItem` / `SrtpProjectPageResult` / `SrtpProjectDetail` / `SrtpStu` / `SrtpTea` / `SrtpAudit` / `SrtpResult` / `SrtpBudget`）、`srtp_service.dart`（`fetchMyJoinedProjects` / `fetchProjectDetail`，复用 `Scjx2ApiService.request` 签名与 401 重登兜底）、`srtp_page.dart`（列表四态+分页，阶段标签 申报/中期/结题 + 状态色点 已终止/申报中/已结题）、`srtp_detail_page.dart`（项目简介、成员含负责人标记、指导教师、经费预算/明细、审核记录时间线、成果、项目文件与基本信息）。
- 接口：`POST /srtp/srtp/myProject/listIsMeJoinProjectsPage`（首屏 body `{}` 与抓包一致，加载更多带 `{currpage,pagesize}`）、`POST /srtp/srtp/common/stuProjectShow`（body 含固定 `include` 串 + `stage:0` + `role:'other'`，`currentRoutePath=/12001/modules/srtp/stu/joinProject`）。

### 🐛 Bug 修复（SRTP 详情加载失败：数字字段 String/num 类型不稳定）
- **问题**：结题/终止项目点开详情报 `type 'String' is not a subtype of type 'num?' in type cast`，加载失败。
- **根因**：`stuProjectShow` 响应的 `budget[].cost`（及可能存在的 `spend[].cost`）返回的是**字符串** `"1000"`，而顶层 `cost`/`confirm_cost` 返回的是**数字** `20000`；`SrtpBudget.fromJson` 用 `as num?` 强转导致 TypeError。无预算明细的申报中项目不受影响。
- **修复**（`lib/srtp/srtp.dart`）：新增 `_toDouble()` 兼容 num 与字符串的安全解析，应用于 `SrtpProjectDetail.cost` / `confirmCost` / `SrtpBudget.cost` 三处，替换 `as num?` 强转。

### ✨ 新增（SRTP「我申请的项目」+ 页面双 Tab 化）
- 「大学生创新创业」页改为**双 Tab**（`lib/srtp/srtp_page.dart`）：「我参与的项目」/「我申请的项目」，各自独立四态 + 分页状态机（`AutomaticKeepAliveClientMixin` 保持切换状态），共享阶段/状态标签组件（申报/中期/结题、已终止/申报中/已结题）。
- 新增接口 `POST /srtp/srtp/myProject/listProjectProgressPage`（body 首屏 `{}` 与抓包一致，加载更多带分页参数；`currentRoutePath=/12001/modules/srtp/stu/myProject`），`SrtpService.fetchMyAppliedProjects()`；模型新增 `SrtpAppliedProjectItem` / `SrtpAppliedProjectPageResult`（列表项自带 `summary`/`dep_name`/`project_no`/`apply_date`/`stu_name` 等，卡片直接展示简介/负责人/学院/申请时间，`cost` 走 `_toDouble`）。
- 详情页 `SrtpDetailPage` 构造参数改为基础字段（`projectId`/`projectName`/`planName`/`stage`/`state`/`routePath`），兼容参与/申请两种列表项；`SrtpService.fetchProjectDetail` 增加 `routePath` 可选参数（参与页与申请页的 currentRoutePath 不同，不参与 HMAC 仅透传）。

### 🎨 UI 优化（药丸胶囊式分段切换）
- 新增公共组件 `lib/core/pill_tab_bar.dart`（`PillTabBar`）：整体圆角胶囊轨道（主题色浅底）+ 内部实心主题色滑块（`AnimatedAlign` 平滑滑动）+ 白色加粗选中文字，支持任意数量标签，与 `TabController` 双向同步（点击 / TabBarView 手势滑动）。
- **SRTP 页**：TabBar 改为 `PillTabBar`（我参与的项目 / 我申请的项目）。
- **学科竞赛页**（`lib/race/race_page.dart`）：重构为双 Tab ——「学科竞赛」列表（原逻辑迁至 `_RaceListTab`，keep-alive）+「我的竞赛」（复用 `MyRacePage` 新增 `embedded` 嵌入模式，隐藏自身 AppBar 避免嵌套标题栏），切换用同一 `PillTabBar`；原 AppBar「我的竞赛」入口按钮移除（已由 Tab 承担），标题固定为「学科竞赛」。
- SRTP 入口名与页面标题由「大学生创新创业」精简为「创新创业」。

### ✨ 新增（scjx2 学科竞赛「我的竞赛」）
- 学科竞赛页（`lib/race/race_page.dart`）AppBar 新增「我的竞赛」入口，进入 `lib/race/my_race_page.dart`：分页列表（下拉刷新 + 滚动加载更多 + 空态/错误态 + 引导登录兜底），卡片展示作品名 / 竞赛名 / 承办学院 / 学年 / 团队标记，并按审核状态着色标签（通过=绿 / 驳回=红 / 审核中=橙）。
- 列表接口 `POST /race/race/stuRace/listMyRacePage`（body `{currpage, pagesize}`，`currentRoutePath` 取抓包值 `/9001/modules/sjjx/race/stu/race/myRace/list`）。
- 新增「我的竞赛」详情页 `lib/race/my_race_detail_page.dart`：接口 `POST /race/race/raceTeam/queryById?id=<teamId>`（空 body、id 走 query），展示作品/竞赛信息、团队成员（排名徽标、队长标记、学号、专业班级）、指导教师（工号、排名）、审核意见时间线（教师、状态、时间、意见，含竖线连接）、报名附件与报名信息。
- `lib/race/race.dart` 新增模型：`MyRaceItem` / `MyRacePageResult` / `MyRaceDetail` / `MyRaceOpinion` / `MyRaceTeamStu` / `MyRaceTeamTch`（手写 fromJson 兜底解析）。
- `lib/race/race_service.dart` 新增 `fetchMyRaces()` / `fetchMyRaceDetail()`，沿用 `Scjx2ApiService.request` 统一签名与 401 自动重登/引导登录兜底，带 `DataCache` 缓存与 `forceRefresh`。

### 🐛 Bug 修复（scjx2 学科竞赛：会话票据过期导致刷新循环 / 获取失败）
- **根因（修正）**：此前判定为「WebView 缓存累积触发风控」并不完整。真正主因是 `_client` 持久化到 LocalStorage 的 `CASTGC`（CAS 票据）/ehall 会话在**服务端有 TTL**，过期后本地仍以"永久有效"的 cookie 保存；`bootstrapLogin` 每次都把这份额外**已失效的"死 cookie"**注回 WebView → 触发 CAS 重定向刷新回环，表现为「首次能获取、用一段时间后拉不到，清掉应用数据重登就好」。上一轮的最小修复只清了 WebView 瞬时缓存、却把同一份死 cookie 又注回，故未能根治。
- **修复**（`lib/scjx2/scjx2_api_service.dart`）：
  - 为 `bootstrapLogin` 增加**自愈合**：首轮用现有 cookie 注入 WebView 失败（命中刷新回环）后，调用 `AuthService.autoRelogin()` 用已存账号密码静默重登，刷新 `_client` 拿到与"清数据重登"完全相同的新 `CASTGC`，清掉旧 token 后用新 cookie 重试一次——即把"手动重登就好"自动化。
  - **刷新回环检测改为只重置一次**：检测到回环先硬重置（清缓存 + 全清 cookie + 重新注入 SSO + 重载）一次；若仍回环则判定为 cookie 已失效，立即中止本轮、交由外层自动重登刷新，避免拿过期 cookie 反复空转。
  - 注：`autoRelogin` 仅在用户勾选"记住密码"时生效；若未勾选则降级为手动重新登录（race 页已给出"登录失败，请前往 WebView 登录"提示）。

### ✨ 新增（自动登录 / 会话静默续期）
- 新增 `AuthService.autoRelogin()`：当检测到会话 cookie 失效时，自动用已保存的账号密码（需用户勾选"记住密码"）走 `CasLoginService` 完整真实登录链路重新登录，刷新 ehall 会话并 https 补 CASTGC；比注入 cookie 可靠（Chromium 常忽略注入的 Secure/HttpOnly cookie）。无凭据或登录失败则降级为手动登录页。
- 接入**启动会话校验**（`lib/main.dart` `_checkSession`）：`verifySession()` 失效且存有凭据时先静默自动重登，成功直接进入主页，避免每次启动都手动输密码。
- 接入 **scjx2 运行时 401/404**（`lib/scjx2/scjx2_api_service.dart` `request` 的 HTTP 401/404 与 JSON code=401 两处）：会话过期先自动重登刷新 ehall 会话，再走 WebView SSO 引导，提升学科竞赛等模块的容错。

### ✨ 新增（隐私协议）
- 设置「关于」区新增「隐私协议」入口，跳转独立 `PrivacyPolicyPage`（`lib/settings/privacy_policy_page.dart`）。
- 内容涵盖：账号密码仅本机沙盒存储、不上传第三方服务器；会话凭证仅用于访问学校官方接口；课表/成绩/竞赛等数据版权归学校；第三方非官方客户端声明；可随时退出登录清除本地数据；免责声明。

### 🎨 UI 优化（设置「关于」区扁平化，移除关于子页）
- 将原「关于」子页中的**检查更新 / 更新日志 / 作者**三项上移至设置页「关于」区，与「隐私协议」并列展示，无需再进入二级页面。
- **移除「关于」入口与 `AboutPage`**：内容已全部并入设置页，二级页面成为冗余，删除 `lib/settings/about_page.dart` 及对应设置项；版本号改由「检查更新」的副标题呈现（`当前版本 v$appVersion`）。
- 「关于」区最终为 4 项：隐私协议 / 检查更新 / 更新日志 / 作者。
- `lib/settings/settings_page.dart`：迁入 `_checkUpdate` / `_showChangelog` / `_compareVersion` / `_showSnack` / `_openUrl` 实现，并补充 `dart:convert`、`http`、`url_launcher` 依赖。
- `_buildSettingTile` 的 `onTap` 参数改为可空（`VoidCallback?`），传 `null` 时自动隐藏右侧箭头，用于「作者」这类纯展示项。

### 🔧 重构（设置页更新逻辑模块化，抽离至 lib/settings/update/）
- **动机**：此前「关于」区扁平化时把检查更新 / 更新日志 / 版本比较 / 外链跳转等逻辑内联进 `SettingsPage` 巨型 `State` 类，导致设置页约 720 行、更新逻辑与 UI 强耦合、难以复用与单测。
- **拆分**：新增独立模块 `lib/settings/update/`，与设置页彻底解耦：
  - `update_models.dart`：纯数据模型 `UpdateCheckResult` / `ReleaseInfo`，与 UI 无关。
  - `update_service.dart`：`UpdateService` 静态方法 `checkForUpdate()` / `fetchReleases()` / `compareVersion()`，封装 GitHub Releases API 请求、版本号比较、APK 下载地址解析（`UpdateException` 统一异常）；纯逻辑、无 `BuildContext` 依赖，可独立单测。
  - `update_dialogs.dart`：`showUpdateCheckFlow(context)` / `showChangelogFlow(context)` 两个入口流程，内部封装 loading 弹窗、发现新版本 / 已是最新提示、更新日志对话框与外链跳转；`_showSnack` / `_openUrl` 随更新逻辑一并迁出。
- **设置页收敛**：`settings_page.dart` 删除内联的 `_checkUpdate` / `_showChangelog` / `_compareVersion` / `_showSnack` / `_openUrl` 及 `http` / `url_launcher` / `dart:convert` 依赖，仅保留两处 `onTap` 调用（`showUpdateCheckFlow(context)` / `showChangelogFlow(context)`），行数由约 720 降至约 460，行为完全一致。`accentColorNotifier` 经 `main.dart` 引入（与原设置页来源一致）。

### 🐛 Bug 修复（设置页 / 首页底部内容被浮动导航栏遮挡）
- **问题**：窄屏下的浮动玻璃导航栏 `GlassTabBar.bottom` 是**浮层**、不占布局空间，而设置页 `ListView` 底部内边距仅 16、首页仅 24，导致「关于」区最后几项被导航栏盖住且无法继续上滑露出。
- **修复**：`lib/core/responsive.dart` 新增公共常量与工具方法 `kBottomBarSafePadding`(120) / `kBottomSafePaddingWide`(32) / `bottomBarSafePadding(context)`，统一计算滚动内容的底部避让留白（宽屏走侧边 Rail、无底部浮栏，仅保留常规间距）。
- 设置页（`settings_page.dart`）与首页（`home_dashboard.dart`）的 `ListView` 底部内边距改用该方法；同时将外层 `SafeArea` 设为 `bottom: false`，避免系统手势区插入与避让留白重复叠加。
- 应用页（`main_screen.dart`）原先硬编码的 `isWide ? 32.0 : 120.0` 一并改为复用 `bottomBarSafePadding(context)`，消除魔数重复。

## [1.1.2]

### 🐛 Bug 修复（CI 构建失败：jni 1.0.1 回归）
- **修复 Android Release 构建失败**：`flutter build apk --release` 在 Gradle 评估 `:jni` 项目时失败，报 `Could not find method kotlin()`（位于 `jni-1.0.1/android/build.gradle` 第 84 行）。根因为 dart-lang/jni `1.0.1`（构建当天发布）的 `android/build.gradle` 仍调用 `kotlin {}` DSL，与 `settings.gradle.kts` 锁定的 Kotlin Gradle Plugin `2.3.20` 不兼容；而 jni 自 `0.11.0` 起已移除对 `kotlin_gradle_plugin` 的依赖。
- **修复方式**：在 `pubspec.yaml` 增加 `dependency_overrides`，将 `jni` 锁定为 `1.0.0`（该版本不触发 `kotlin()` 调用）。不动 Kotlin / AGP / Gradle 版本链，避免引入新的兼容问题。

### ✨ 新增（VR地图 B区）
- **VR地图新增「B区」查看**：`lib/vrmap/vrmap_page.dart` 的校区列表新增 B区 全景入口（`https://vr.douhuiai.com/v/ffbf5ea3eu05_1-1785058130.html`）。AppBar 右侧「切换校区」菜单基于列表动态生成，新增后自动出现 B区 选项，无需改动其余 UI。

### 🐛 Bug 修复（后台保活与 Cookie 持久化）
- **App 进后台不再被强制关闭**：`lib/main.dart` 的 `didChangeAppLifecycleState` 在 `paused`（进后台）时原本会调用 `SystemNavigator.pop()` 直接 `finish()` 掉 Activity，导致 App 一旦切到后台就被杀、从最近任务消失。现改为进后台**仅保存 Cookie、不再关闭 App**，进程保留在后台可随时返回（即"不自动删除后台"）。
- **Cookie 自动保存保障**：保留 `SharedHttpClient.saveCookies()`（落盘到 `LocalStorage`，含 ehall 精简版），并在 `detached`（进程即将销毁）时追加一次兜底保存；配合每次请求后 3 秒防抖自动保存，会话在后台/被杀后仍能恢复。WebView 自身 SSO Cookie 由 `flutter_inappwebview` 持久化存储，不受影响。

### 🎯 优化（横屏 / Windows 桌面适配）
- **响应式布局框架**：新增 `lib/core/responsive.dart`，提供 `isWideScreen()`（断点 600，对应 Material 3 compact→expanded）、`appGridColumns()`（按可用宽度 3→6 列）、`MaxWidthContent`（宽屏下居中并约束最大宽度，窄屏无副作用）。
- **主壳导航自适应**（`lib/home/main_screen.dart`）：窗口宽度 ≥ 600 时，底部浮动玻璃导航栏（`GlassTabBar.bottom`）自动切换为玻璃风格**侧边导航栏（Rail）**（自建 `ClipRRect + BackdropFilter` 毛玻璃侧栏 + 选中态高亮），充分利用横屏/桌面横向空间；底部栏在宽屏下置空。
- **应用网格列数自适应**：应用页网格列数随可用宽度从 3 列递增至 6 列（横屏/桌面展示更多应用），内边距随宽屏收敛（顶部 56→28、底部 120→32），内容最大宽度约束为 1200 居中。
- **列表页宽屏约束**：首页（`home_dashboard.dart`）与设置页（`settings_page.dart`）的内容居中并限制最大宽度（760），避免超宽屏下卡片被拉伸过宽。
- **Windows 原生最小窗口尺寸**（`windows/runner/flutter_window.cpp`）：新增 `WM_GETMINMAXINFO` 处理，最小窗口尺寸设为 600×680，桌面端窗口缩放下限更合理（同时保证侧边导航布局始终生效）。
- **Web 端方向放开**（`web/manifest.json`）：`orientation` 由 `portrait-primary` 改为 `any`，PWA 在横屏下不再被强制竖屏。

### 📝 文档
- 重写 `README.md`：替换 Flutter 默认模板，补充项目简介、功能特性（教务/服务/资讯三类）、游客模式说明、技术栈、快速开始、项目结构、开源协议与声明链接，版本徽章标注 `1.1.0`。

### ✨ 新增（开源声明）
- 新增 `LICENSE`（MIT 许可证）与 `开源声明.md`（中文开源声明）：声明本项目为宜宾学院智慧校园**第三方非官方**客户端，仅供学习交流、数据版权归学校所有、账号仅本地存储不上传第三方、使用风险自负等免责条款。
- `pubspec.yaml` 补充 `homepage`/`repository`/`issue_tracker`/`license: MIT` 元数据，完善开源包信息。

### 🔧 重构
- 版本号升级至 `1.1.0`：同步更新根目录 `VERSION`、`pubspec.yaml` 的 `version: 1.1.0+2`，及 `lib/core/version.dart` 的 `appVersion`（关于页/设置页展示的版本号）。

### ✨ 新增（游客登录）
- **登录页新增「游客登录」入口**：无需账号密码即可进入应用，仅可使用无需登录的功能（校历服务、教学单位、职能部门、电费、校车、就业、网络服务、校园安全、VR 地图、办公网、全部资讯栏目等）。
  - 新建 `lib/core/guest_mode.dart`：游客态全局状态（内存标记 + `LocalStorage` key `guest_mode` 持久化），提供 `load()/enter()/exit()`。
  - 新建 `lib/core/guest_guard.dart`：`showGuestLoginDialog()` 统一拦截弹窗（「需要登录」提示 + 取消/去登录），去登录时退出游客态并跳转登录页。
  - `lib/home/app_data.dart`：`AppEntry` 新增 `requiresLogin` 字段，9 个需登录功能（课程表、全校课表、成绩查询、考试安排、学业完成、综合素质、教材查询、学科竞赛、第二课堂）标记为 `true`。
  - `lib/home/main_screen.dart`：游客态下需登录入口置灰 + 右上角锁角标，点击弹「需要登录」引导弹窗而不进入页面。
  - `lib/home/home_dashboard.dart`：游客态跳过课程接口调用，「今日课程」卡片显示「游客模式下无法查看课程」+「去登录」按钮；校园新闻正常可用。
  - `lib/settings/settings_page.dart`：游客态个人信息卡替换为「游客模式」占位卡（点击去登录）；「退出登录」替换为「登录账号」（保留已记住的凭据）；正常退出登录时同步清除游客标记。
  - `lib/auth/login_page.dart`：登录卡片底部新增「游客登录」按钮；统一认证登录成功时自动退出游客模式。
  - `lib/main.dart`：`SplashPage` 启动时恢复游客标记，游客态跳过 Cookie 会话校验直接进首页。

### ✨ 新增（QQ 频道）
- **QQ 频道入口（内置 WebView）**：首页应用网格「服务」分类新增「QQ频道」入口，点击通过内置 WebView（复用 `lib/news/webview_page.dart` 的通用 `WebViewPage`）打开 `https://pd.qq.com/s/bq4dam2kg`；公开链接无需登录，游客模式亦可访问。
- **「加入频道」拉起 QQ 客户端**：`WebViewPage` 新增 `shouldOverrideUrlLoading`，拦截非 `http(s)` 的自定义协议（如 QQ 频道页内的 `mqqapi://`），自动通过 `url_launcher` 调起 QQ 客户端并加入频道，避免 WebView 因无法解析该协议而报错；对纯 `http(s)` 页面（如 VR 地图）无副作用。
- **返回手势回退浏览历史**：`WebViewPage` 改用 `PopScope(canPop: false)` 包裹，系统返回手势/返回键优先调用 `controller.goBack()` 回退 WebView 内部历史，仅当已到首页（无历史）时才退出页面，避免直接返回应用网格界面。

### ✨ 新增
- **办公网服务（原生解析，非 WebView）**：首页应用网格「服务」分类新增「办公网」入口，改用原生解析渲染，不再套壳 WebView
  - 入口 `lib/office/office_home_page.dart`：以 Tab 形式呈现四个栏目（上级文件 / 党委系统 / 行政系统 / 教学教辅，对应 `b_id=14/15/16/17`）
  - `lib/office/office_service.dart`：原生 HTTP 抓取 + **GBK 解码**（`gbk_codec`），正则解析列表与详情；`fetchColumn(bId, {offset})` 支持分页（`offset` 每页 +20），`_parseNextOffset()` 扫描分页栏判断是否存在下一页；结果缓存至 `DataCache`（TTL 1 天，按 `office_col_${bId}_${offset}` 分页缓存）
    - 列表项分两类：`detail.asp?n_id=NN`（HTML 文章，原生解析标题/日期/作者/正文/附件）与 `showdoc.asp?id=NN`（直接返回 PDF 二进制流，视为文件）
    - 详情正文容器为 `<td class="content">`，段落为 `<P>` 块，附件链接（.pdf/.docx 等）提取为可点击条目
  - `lib/office/office_list_page.dart`：列表 UI（loading / error / 重试 / **上拉加载下一页（offset 每页 +20 无限滚动）** / 文件项以 PDF 图标标注）
  - `lib/office/office_detail_page.dart`：详情 UI（标题 + 日期 + 作者 + 段落 + 附件卡片）
  - 交互规则：`detail.asp` 文章 → 原生详情页；`showdoc.asp` 文件与详情附件 → 通过 `url_launcher` 调起外部应用/浏览器打开（不进入应用内 WebView）
  - 目标站点 `http://off.yibinu.edu.cn` 为老式 ASP 架构、`gb2312` 编码、仅 http 明文、无 CAS 统一认证的公开办公门户
  - iOS 端 `Info.plist` 已配置 `NSAppTransportSecurity` 例外放行 `off.yibinu.edu.cn` 的 http 明文加载；Android 端 `usesCleartextTraffic="true"` 已支持

### ✨ 新增（办公网站内搜索）
- **办公网站内搜索**：`OfficeService.search(keyword, {offset})` 调 `search.asp`，关键词按 **GBK 字节** 做百分号编码（`张` → `%D5%C5`，非 UTF-8），`Submit=%CB%D1`（查）为站点真实字节；结果 GBK 解码后按新正则解析（`<A HREF="detail.asp?n_id=NN">标题</A>` 后跟 `[YYYY-M-D]`，标题内 `<font color=red><b>关键词</b></font>` 高亮需去标签）
  - 分页步长 **offset +15**（与栏目列表的 +20 不同）；`_parseNextOffset()` 泛化为同时匹配 `list_b.asp` 与 `search.asp` 分页栏、返回**真实**下一页 offset（不再写死步长）
  - 新增 `lib/office/office_search_page.dart`：独立全屏搜索结果页（`SimplePage` + `Scaffold` + AppBar 内联搜索框，body 复用 `OfficeListPage(searchKeyword:)`）
  - `lib/office/office_home_page.dart`：AppBar 增加搜索图标，点击弹输入框，确认后 push `OfficeSearchResultsPage`
  - `lib/office/office_list_page.dart`：`OfficeListPage` 构造函数新增可选 `searchKeyword`（与 `bId` 二选一），`_load`/`_loadNextPage` 在搜索模式下改调 `search()`，卡片/滚动/分页 UI 完全复用
  - 经 Python 实测：搜索 张 在 `offset=0 / 15` 返回不同 15 条、0 重叠，确认 +15 步长；GBK 编码与站点真实链接逐字节一致

### ✨ 新增（办公网文件预览）
- **办公网所有文件可点击预览**：新建 `lib/office/office_file_preview_page.dart` 作为统一文件预览入口，列表文件项（`showdoc.asp`）与详情页附件共用。
  - **PDF（含 `showdoc.asp` 直接返回的二进制流）**：进入即自动下载到 `path_provider` 临时目录，用 `flutter_pdfview` 的 `PDFView(filePath:)` 在应用内渲染，支持翻页/缩放；AppBar 提供「用其他应用打开」入口。
  - **DOCX / XLSX / PPT / ZIP / TXT 等**：移动端无可靠应用内渲染器，改为展示文件信息卡（类型图标 + 文件名 + 来源 URL）并提供「下载并用其他应用打开」按钮（`launchUrl` external，如 WPS）。
  - 文件类型按扩展名判定（`_extensionOf` + `_typeLabel`/`_typeIcon`），`showdoc.asp` 默认视为 PDF；下载带进度显示与失败重试。
- `lib/office/office_detail_page.dart`：附件卡片点击由直接 `launchUrl` 外部打开改为 push 预览页；移除不再使用的 `url_launcher` 导入。

### ✨ 新增（全校课表查询）
- **教务新增「全校课表」入口**：浏览/搜索全校所有班级并查看其周课表、未排课程、调停补记录。对应 ehall 教务 `kcbcx`（课程表查询）应用、`bjkcb`（班级课表）模块，入口 `appId=4766960573884517`。
  - 新建 `lib/course/course.dart` 数据模型：`SchoolClass`（班级，解析 `BJDM`/`BJMC`/`YXDM_DISPLAY`/`ZYDM_DISPLAY`/`NJ`/`SJRS`/`CSRS`/`SFYPK`）、`ClassSemesterInfo`（学期信息，`totalWeeks`←`ZZC`、`startDateStr`←`XQKSRQ`）、`ClassCourseChange`（调停补记录，字段优先级「新值 > 旧值」：`XSKXQ`/`XSKZC`/`XSKJS`/`XJASMC` 存在时优先，否则 `SKXQ`/`SKZC`/`YSKJS`/`JASMC`）。
  - 新建 `lib/course/course_service.dart` kcbcx 模块方法：`ensureKcbcxSession()`（appId 入口流程 + kcbcx 首页 GET）、`fetchAllClasses()`（循环分页全量拉取 `bjcx.do`，缓存 `all_classes_$xnxqdm`）、`fetchClassSchedule()`（`bjkcb.do`，复用现有 `Course.fromJson`，缓存 `class_schedule_${xnxqdm}_$bjdm`）、`fetchClassUnarranged()`（`bjwpkc.do`）、`fetchClassChanges()`（`bjdkkc.do`）、`fetchClassSemesterInfo()`（`cxxljc.do`）、`fetchClassCurrentWeek()`（`dqzc.do`）；新增 `_formHeadersKcbcx(host)` 头构造器（Referer 指向 kcbcx 首页）。
  - 抽出可复用课表网格组件 `lib/course/course_grid.dart`：导出 `kDayLabels`、`generateCourseColors`、`tagBadgeColor`、`showCourseDetailSheet`、`CourseWeekBar`；`CourseScheduleGrid`（按当前周过滤的课程列表渲染周网格，含表头/背景行/卡片/滑动切周），供个人课表页与全校课表页共用。
  - 重构 `lib/course/course_page.dart`：删除私有的网格/配色/详情逻辑，改用 `CourseScheduleGrid`（个人课表 UI 与行为不变）。
  - 新建 `lib/course/all_class_schedule_page.dart`：列表态（学期选择 + 搜索框 + 学院筛选 chips + 班级卡片显示已排课/未排课与人数）；详情态（点进班级并行拉取课表/未排课/调停补/学期信息/当前周 → `CourseWeekBar` + `CourseScheduleGrid` + 未排课程列表 + 调停补列表）。
  - `lib/home/app_data.dart`：教务分类新增 `AppEntry(icon: Icons.groups_rounded, name: '全校课表', pageBuilder: AllClassSchedulePage)`。

### ✨ 新增（第二课堂 · 独立登录）
- **教务新增「第二课堂」入口**：`erke.yibinu.edu.cn` 与「智慧校园 / CAS」**完全独立**——独立账号密码登录、独立 JWT token，仅校园内网可访问，故入口卡同样挂「校园网」角标。
  - 新建 `lib/second_classroom/erke_models.dart`：数据模型 `ErkeProfile`（学院/班级/姓名/学号）、`ErkeReportItem`（分类学分）、`ErkeTranscriptItem`（单条活动记录）、`ErkeTranscript`（汇总 + 按分类聚合）。
  - 新建 `lib/second_classroom/erke_service.dart`：`ErkeService.login(username, password)` POST `prod-api/login`（JSON：`{"username":..,"password":..}`）返回 `token`；`fetchTranscript(username, token)` GET `prod-api/transcript/item/{username}` 带 `Authorization: Bearer <token>`，`401/403` 抛 `ErkeAuthExpiredException`。直接用 `http` 包（不经 CAS 的 `SharedHttpClient`）。
  - 新建 `lib/second_classroom/erke_login_page.dart`：**独立登录页**（SimplePage + 学号/密码表单 + 显隐密码），成功后把 `token`/`username` 存入 `LocalStorage`（`erke_token`/`erke_username`），pop(true)。明确提示「与智慧校园相互独立、仅校园网可访问」。
  - 新建 `lib/second_classroom/erke_page.dart`：主页读取本地 token 决定登录态；未登录/过期 → 居中引导卡「登录第二课堂」；已登录 → 学生信息卡（姓名/学院/班级 + 总学分 + 活动数）、分类学分网格（2×2）、活动明细按分类折叠（`SmoothExpansionTile`）。AppBar 提供「退出登录」清除 token。
  - `lib/home/app_data.dart`：教务分类新增 `AppEntry(icon: Icons.assignment_ind_rounded, name: '第二课堂', badge: OfficeCampusCornerBadge(), pageBuilder: ErkeLoginPage)`（点击卡片直接进入登录页）。

### 🎨 UI 优化（第二课堂登录页）
- **点击卡片直接进登录页，去掉中间过渡页**：`app_data.dart` 第二课堂入口由 `ErkePage` 改为 `ErkeLoginPage`；登录成功用 `Navigator.pushReplacement(ErkePage)`（返回即退出模块，无中间页）；`ErkePage` 的 token 失效兜底（`_openLogin`）与「退出登录」也改为 `pushReplacement(ErkeLoginPage)`，杜绝页面堆叠。
- **新增初始密码提示**：登录页加主题色描边提示框，明确「初始密码格式：学号 + @10641 + Yibin（例：240105118@10641Yibin）」。
- **新增「记住密码」**：登录页加勾选框；勾选且登录成功 → 本地保存密码（`erke_password`）；取消 → 清除。进入登录页时若有已存密码则**自动预填账号密码但不自动登录**（用户仍需点「登录」）。「退出登录」仅清除 `erke_token`，保留已记住的账号密码，下次进入仍预填。
- `flutter analyze lib/home/app_data.dart lib/second_classroom` → **No issues found**。

### 🎨 UI 优化（办公网内网标识）
- **办公网入口卡标注「校园网」标识**：办公网（off.yibinu.edu.cn）仅能在校内网/内网环境访问与打开。用户要求仅在该应用「服务」网格的**入口卡**上提示，故标识只加在入口卡，列表卡片与详情页不加。
  - 新建 `lib/office/office_widgets.dart`：
    - `OfficeCampusCornerBadge`：网格入口卡**右上角**的实心小胶囊（`Icons.lan_rounded` + 「校园网」白字），不占用卡片主体布局，跟随主题色。
    - `OfficeCampusBadge`（行内胶囊，含 Tooltip「需连接校园内网（off.yibinu.edu.cn）才能访问」），暂未使用，保留备用。
  - `lib/home/app_data.dart`：`AppEntry` 新增可选 `badge` 字段；办公网条目挂 `OfficeCampusCornerBadge()`。
  - `lib/home/main_screen.dart`：`_buildAppCard` 用 `Stack` 包裹 `Card`，当 `entry.badge != null` 时在右上角（`top:4, right:4`）渲染该角标；顺手移除一处未使用的 `data_cache.dart` 导入。
  - 回退：移除此前加在 `office_list_page.dart` 列表卡片与 `office_detail_page.dart` 详情页头部的 `OfficeCampusBadge`（用户要求只保留入口卡标识），并删除两文件对应的 `office_widgets` 导入。
- `lib/office/office_list_page.dart`：文件项（`item.isFile`）点击由直接 `launchUrl` 改为 push 预览页；移除不再使用的 `url_launcher` 导入。

### 🐛 Bug 修复（办公网文件预览页崩溃）
- **`RenderFlex overflowed by 1140px` 崩溃**：预览页的错误态 `Column`（`_buildError`）为不可滚动的固定列，当错误信息较长时超出视口触发 Flutter 布局异常。`_buildOtherFile`（非 PDF 文件信息页）同理。
  - 修复：`_buildError` 改为 `LayoutBuilder + SingleChildScrollView + ConstrainedBox(minHeight)` 结构，内容超长时可滚动且短内容仍垂直居中；`_buildOtherFile` 外层 `Padding` 改为 `SingleChildScrollView`。
- **PDF 原生 `result_code:408 / found=0` 加载失败**：根因是下载到的内容并非合法 PDF（服务端返回非 200 / HTML 错误页 / 空文件），但代码仍把该路径交给 `PDFView`，原生 PDF 引擎无法打开文件。
  - 修复：`_download` 新增两道校验——① HTTP 状态码必须 `== 200`，否则抛友好错误；② PDF 写入后校验文件头 4 字节为 `%PDF` 且大小 `> 0`，不合法则抛「下载的内容不是有效的 PDF 文件（可能需校内网络访问权限，或链接已失效）」。校验失败不走 `PDFView`，从根本上避免原生崩溃。
  - 顺带将本地临时文件名改为**纯 ASCII 时间戳**（`office_${micros}.pdf`），去掉中文路径，规避部分 Android 原生 PDF 引擎对 UTF-8 路径的拒绝（日志 `servname:(null)... found=0` 即文件打不开的表现）。
- **`FileUriExposedException`（非 PDF 文件点开即崩）**：点 DOCX/XLSX/PPT/ZIP 等「下载并用其他应用打开」时，原直接用 `url_launcher` 以 `file://` URI 拉起外部应用，触发 Android 7+ 的 `FileUriExposedException`（日志 `file:///data/.../cache/office_xxx.docx exposed beyond app through Intent.getData()`）。
  - 根因：Android 7+ 禁止通过 Intent 暴露 `file://` URI，必须经 `FileProvider` 包装为 `content://` 并授予 `FLAG_GRANT_READ_URI_PERMISSION`，而 `url_launcher` 不会加该权限。
  - 修复：新增原生 `MethodChannel`（`com.smartcampus.smartcampus/file` 的 `openFile`）——在 `MainActivity.kt` 注册，内部用 `FileProvider.getUriForFile` 生成 `content://` 并带授权 flag 调起 `ACTION_VIEW`；`AndroidManifest.xml` 新增 `androidx.core.content.FileProvider` provider（`${applicationId}.fileprovider` + `res/xml/office_file_paths.xml`，覆盖内部与外部缓存目录）；Dart 侧 `_openFileWithSystem` 通过 channel 调用，并对 `NO_APP`（无 WPS 等）/ `NO_FILE` 给出友好提示。PDF 应用内渲染路径不受影响（flutter_pdfview 直接读本地路径，不走 Intent）。

### 🐛 Bug 修复
- **全校课表列表态「无法切换学期」**：`AllClassSchedulePage._loadSemestersAndClasses()` 内部无条件执行 `_listXnxqdm = _service.defaultXnxqdm`，覆盖掉学期选择 `onChanged` 刚写入的 `_listXnxqdm = v`，下拉框选完即被重置回默认学期，表现为「无法切换」。修复：方法新增可选 `xnxqdm` 参数，仅首次（`_listXnxqdm` 为空）回落默认值；`onChanged` 改为 `if (v != null) _loadSemestersAndClasses(xnxqdm: v)`。详情态 `_buildDetailSemesterBar` 逻辑本身正确（设 `_detailXnxqdm` 后调 `_openClass`，无重置），不受影响。
- **办公网分页 URL 补齐 `god` 参数**：原 `fetchColumn` 请求 `list_b.asp?b_id=XX&offset=N`（无 god）。实测服务端忽略 `god`、仅认 `offset`，但站点自身生成的链接均带 `&god=offset+1`。为彻底贴合站点链接格式、消除歧义，现请求 URL 显式携带 `&god=${offset+1}`。分页步进逻辑（`nextOffset = currentOffset + 20`，顺序翻页）经实测正确，无漏页/重复。
- **办公网详情附件获取不到（两类根因）**：以 `detail.asp?n_id=35303` 为例，附件 `<a href="wordfile/2026file/关于张皓岚等结束任职试用期的通知.pdf">` 此前取不到。
  - 根因①（漏检）：原解析只扫描 `<td class="content">` 内的 `<P>` 块，而该附件链接**直接裸置于 content td 内**（无 `<P>` 包裹），导致整条被跳过。现改为先对**整个 content td HTML** 全量扫描 `<A HREF>` 附件链接（按 href 去重），`<P>` 段落段仅抽取正文文本。
  - 根因②（URL 未编码）：附件 href 含**原始中文路径**（`关于张皓岚等…pdf`），直接丢给 `launchUrl` 浏览器无法解析。新增 `_encodeUrl()` 对路径各段做 UTF-8 百分号编码（已编码段 `%XX` 跳过避免二次编码），`_resolve()` 统一经它返回，生成的 URL 与站点真实可打开链接逐字节一致（已 Python 校验：`wordfile/2026file/%E5%85%B3…pdf`）。
  - 顺带去除 `_isAttachment()` 中重复的 `filedown` 判断行。

### 🐛 Bug 修复（学科竞赛 / 学工 SSO 多数失败、偶发成功）
- **根因**：scjx2（学科竞赛）/ 学工 走 CAS SSO 自动登录，必须携带有效 `CASTGC`（TGC）authserver 才会放行；而 `CasLoginService` 全程用 `http://` 登录，浏览器 / HttpClient 会拒存 `Secure` 的 `CASTGC`，导致 WebView 永远停在 CAS 登录页（偶发成功仅因系统残留的历史 CASTGC）。
  - 此前计划的「https 补登录捕获 CASTGC」方案从未落地，记忆中记为「已修复」与代码实际不符。
- **修复**：`CasLoginService.login()` 在主流程（http）成功后，新增 https 补登录步骤（`_captureCastgcOverHttps`），用同一账号密码走一次完整 https 登录，从 302 响应的 `Set-Cookie: CASTGC=...; Secure; HttpOnly` 抓取 TGC；`SharedHttpClient._send` 自动解析并随 `saved_cookies` 持久化，同时显式落到 `yibinu.edu.cn` / `authserver.yibinu.edu.cn` 桶供注入器读取。该步骤包 try/catch，失败不影响 ehall 主流程。
- **注入器增强**：`Scjx2ApiService._injectEhallCookiesToWebView` 兜底扫描所有 cookie 桶确保 CASTGC 进入注入集合，并对 `CASTGC` 以 `isSecure:true` + `isHttpOnly:true` 注入（与学工注入器一致）。注入前后打印 `Scjx2: CASTGC present/missing` 便于验证。学工注入器（已带 `isSecure`）因此被顺带修好。
- 验证：`flutter analyze lib/auth/cas_login_service.dart lib/scjx2/scjx2_api_service.dart` → No issues found。

### 🐛 Bug 修复（首页「今日课程」误显示已结课周次的课程）
- **根因**：`home_dashboard.dart` 的 `_todayWeek` 在 `initState` 被错误赋值为 `DateTime.now().weekday`（星期几，1-7），随后却被当作「教学周次」用于过滤 `c.weeks.contains(_todayWeek)`。学期进入第 21 周（`dqzc.do` 返回 `ZC=21`）后，真实教学周次 21 不在任何课程的 `weeks` 列表里，但星期的数字（如周三=3）几乎必然落在课程 `weeks`（通常 1-18）中，于是仍把当天课程当作「有课」显示。周课表页（`course_page.dart`）的同类变量 `_todayWeek` 正确取自 `fetchCurrentWeek().week`，唯独首页漏了这一步。
- **修复**：`_loadTodayCourses` 先调用 `service.fetchCurrentWeek()` 取得真实教学周次（失败则回退为 0，仅按星期过滤），再按「`c.day == 今天星期` && `c.weeks.contains(真实教学周次)`」过滤。学期结束后第 21 周不再命中任何课程，正确显示「今天没有课程」。字段由误导性的 `_todayWeek` 重命名为 `_currentWeek`。

## [1.0.9] - 2026-07-19

### 🎯 优化
- 版本号从 1.0.8 升级到 1.0.9（同步更新 `pubspec.yaml` / `VERSION` / `lib/core/version.dart` / `android/local.properties`，`versionCode` 由 1 递增至 2）

## [1.0.8] - 2026-07-18

### 🎯 优化
- 版本号从 1.0.7 升级到 1.0.8（同步更新 `VERSION` / `pubspec.yaml` / `lib/core/version.dart`）

### 🔧 重构
- **课程表页面彻底重构为圆角卡片风格**：周课表课程卡片改用 `Material` + 圆角 + 阴影浮层，纯色半透明背景 + 白色文字，替代原纯色边框块风格
  - 新增 `lib/course/course_config.dart` 配置模型（11 项可配置 + 持久化到本地存储）
  - 新增 `lib/course/course_config_page.dart` 设置页面（布局/显示/尺寸/样式/颜色五大区域）
  - 可配置项：显示调课入口 / 隐藏时间段 / 隐藏日期 / 显示网格线 / 单元格高度（80~200px）/ 头部高度（30~60px）/ 隐藏节次号 / 隐藏教师 / 文字缩放（0.7~1.5x）/ 圆角半径（0~16px）/ 12 色自定义课程配色
  - 自定义颜色支持点击 HSV 调色盘换色 + 长按恢复默认
  - 卡片新增上课节次显示，`tagBadgeColor` 统一标签底色（实验→橙色）
  - 学期课表卡片同步适配圆角、教师隐藏、文字缩放等配置
  - 配置入口：AppBar 新增齿轮按钮
  - 配置立即生效（`onChanged` 回调实时更新课程页 state）

### 🎨 UI 优化
- **课程表实验课卡片简化**：实验课不再显示实验项目名（`exp_name`），只保留「实验」橙色小标签 + 课程名 + 教室，周课表卡片更紧凑易读
- **学期课表同课程合并**：同一天 + 同一课程名 + 同一教师的多个时间片合并为一张卡片，节次/周次/教室取并集展示。理论课与实验课（`tag` 不同）天然按类型分开合并。学期课卡新增「实验」橙色小标签
  - 新增 `Course.sectionRangesCompact` getter：合并连续节次区间，单节/连续区间/多段都正确显示（如 `3节` / `1-2节` / `1-2节,5-6节` / `1节,3-5节,8节`）
  - 新增 `_mergeSameCourses()` 工具方法：按 `(name, teacher, tag)` 分组后并集 sections/weeks，position 用「、」拼接

### 🐛 Bug 修复
- **TEACH 模块 API 404**：scjx2 `teach` 模块的 API 路径修正为 `/teach/teach/stuTime/listStuTimePage`（每段路径均包含模块名），同时重构 `Scjx2ApiService.bootstrapLogin` 支持多模块独立 token（`race` / `teach` / `grad`），cookie 同步改用 `CookieManager.getCookies` 绕过 httpOnly 限制，bootstrap 改为「zxcas 入口 + 模块内 navigate」两步式，先清空 scjx2 域 cookie 防止跨实例残留

### ✨ 新增
- **学科竞赛 API 模式**：通过分析 scjx2.yibinu.edu.cn RACE 系统前端 JavaScript 源码，逆向出 API 签名算法
  - `signature`: HMAC-SHA512(`{timestamp}-{nonce}`, `zxtd_256-bit-secret-key-2025-8-7`)
  - `zhxhsign`: HMAC-SHA256(序列化参数, `zhxintd201020301`)
  - 新建 `race_signer.dart` 封装两个签名生成函数
  - `RaceService` 改用 `SharedHttpClient.postJson` + 自构造签名头直接调用 `listStuRacePage` 接口，不再依赖 WebView DOM 提取
  - 完整流程 Python 验证：返回 HTTP 200，totalCount=72，与前端数据一致
- **学科竞赛详情页**：新建 `race_detail_page.dart`，点击列表项可进入详情
  - 调 `toRaceApply?race_id=xxx` 接口获取完整信息
  - 展示：竞赛名称、类型/级别/状态 Tag、教师信息、学院、主办单位、学年、是否分组、经费、子项列表、完整内容
  - 下拉刷新、错误重试、未登录自动引导登录
- **zxcas 引导登录**：新增 `RaceService.bootstrapLogin()`，首次进入学科竞赛或登录过期时启动 HeadlessInAppWebView 走 CAS SSO，登录成功后从 `window.sessionStorage.getItem('key1')` 提取 JWT 缓存到 `LocalStorage`，后续纯 API 调用无需可见 WebView

### 🎯 优化
- **RaceService 完全重写**：去除原来复杂的「CAS SSO + Vue 路由跳转 + fetch 拦截器 + DOM 表格解析」长流程，改为「首次 WebView 登录 + 之后纯 HTTP API」的简洁方案
- **zhxhsign 算法修正**：经端到端调试发现，前端 2fd1 模块中 `u()` 的 `n = {}` 是 module-level 赋值（非 var 声明），`m()` 写的是 module-level n，data 和 params 实际合并到同一个 map 计算签名
- **抽 Scjx2ApiService 通用层**：把 race_service 里的 scjx2 通用逻辑（签名、cookie 同步、bootstrap、401 重试）抽到 `lib/scjx2/scjx2_api_service.dart`，让 race 和 course 等模块都能用。新建 `lib/scjx2/scjx2_signer.dart` 通用签名工具
- **课程表新增实验教学**：新建 `Course.fromExperimentJson` 工厂，调用 scjx2 `teach/stuTime/listStuTimePage` 接口获取实验课列表，合并到课程表。实验课显示「实验」橙色小标签和实验项目名
- **调课/未安排课程独立页面**：新建 `course_changes_page.dart`，全屏页面替代原底部弹窗面板
  - 页面自带学期选择器，切换学期自动加载对应学期数据
  - Tab 式布局：调课/停课 + 未安排课程独立 Tab 切换
  - 支持下拉刷新、错误重试、空状态展示
  - 调课卡片采用时间线式布局，原安排/新安排对比更清晰
  - 未安排课程卡片展示教师、学分、学时、周次等信息

### 🎯 优化
- **课程表页面重构**：AppBar 新增调课入口按钮，移除底部弹窗面板和相关状态管理
  - 删除 `_showCourseChanges`、`_showUnarranged` 等冗余状态变量
  - 删除 `_buildToggleChip`、`_buildExtraInfoPanel` 等底部面板代码
  - 周课表/学期课表切换栏更简洁
- **调课页面 AppBar 溢出修复**：`PreferredSize` 高度从 96 调整为 108，适配学期选择器 + Tab 栏实际高度

### 🎯 优化
- **应用页面切换动画优化**：底部 Tab 切换（首页/应用/设置）改用 `IndexedStack` 替代 `AnimatedSwitcher` + `FadeTransition`
  - 移除整个页面的淡入/弹入动画，切换即显示，减少视觉跳跃
  - 搜索框独立渐显动画：仅对搜索框应用 `TweenAnimationBuilder` 的 Opacity 动画（400ms），Tab 栏和应用网格直接渲染无入场动画
- 个人信息获取：首次登录获取后缓存，后续登录/cookie 失效均不再重复获取

### 🎯 优化
- 个人信息获取：首次登录获取后缓存，后续登录/cookie 失效均不再重复获取
- 个人信息获取：首次获取前增加 2 秒等待，确保 CAS session 和学工页面完全加载后再提取

### ✨ 新增
- 学业完成情况：AppBar 新增"重新计算"按钮，调用 `bysc.do` + 轮询 `byscjd.do` 完成学业数据重算
  - 含确认对话框 + 加载状态 + 完成后自动刷新

### 🐛 Bug 修复
- 学业完成情况：`SFTG_DISPLAY = "4"`（已选课）状态的课程成绩列显示"已选课"标签，橙色标识替代原 `-`
- 学业完成情况：解析 `cxxkxnxq.do` 返回的选课学年学期替代日期推算，确保 `XNXQDM` 参数值与已选课课程所在学期一致

## [1.0.4] - 2026-07-12

### ✨ 新增

- **自定义主题颜色**：外观页新增"主题颜色"选择器，支持 12 种预设主题色
  - 默认宜院蓝（`#191999`），另有中国红、翠绿、天蓝、紫罗兰等色板
  - 选中颜色带光晕高亮 + 白色勾选标记
  - 颜色通过 `ColorScheme.fromSeed` 全局传播到按钮、导航栏、输入框等组件
  - 设置即时生效，自动持久化到本地存储
  - **[修复]** 主题色硬编码问题：main_screen/settings_page/appearance_page/home_dashboard/login_page 等关键页面改用 `accentColorNotifier.value` 替代局部常量 `_yibinBlue`
  - 底部导航栏 `GlassTab.activeIcon`、设置页图标、首页卡片、登录按钮等最可见元素全部跟随主题色变化

- **自定义背景图片**：外观页新增"自定义背景"功能，支持从相册选择图片作为应用背景
  - 图片复制到应用持久目录，删除源文件不影响
  - 背景自动叠加 50% 半透明遮罩，确保内容可读性
  - 支持"恢复默认"回到纯色背景
  - 集成 `image_picker` 依赖
- **VR地图服务**（`lib/vrmap/`）：内置 WebView 加载 VR 全景，支持 A区 / 临港双校区一键切换
  - 使用 `flutter_inappwebview` 渲染 VR 页面
  - 首页应用网格「服务」分类新增「VR地图」入口

### 🎨 UI 优化

- **底部 Tab 切换动画**：首页/应用/设置三个页面切换新增 `AnimatedSwitcher` 300ms 淡入淡出过渡，替代原无动画的 `IndexedStack`
- **背景图片全局集成**：`GlassScaffold` 动态监听 `backgroundNotifier`，选择背景图后实时生效
- **设置页重构**：将浅色/深色/跟随系统三个主题选项从设置页内联展示迁移至独立的外观页面（`lib/settings/appearance_page.dart`）
  - 设置页「外观」区改为带图标的导航入口，点击进入新页面切换主题
  - 新增主题模式说明文字（跟随系统/浅色/深色对应描述）
- **主题选项切换动画**：外观页主题模式选择器使用 Flutter 原生动画实现全部过渡效果
  - 选中态切换：`AnimatedContainer` 弹性动画过渡背景色和边框色
  - 选中指示点：`AnimatedScale` + `AnimatedOpacity` 伸缩淡入淡出
  - 描述文字：`AnimatedSwitcher` 平滑淡入切换

### 🎯 优化

- **App 生命周期管理**：退出后台时立即保存 Cookie 并调用 `SystemNavigator.pop()` 灭活，应用不在后台持续运行
- **VR 地图 UI**：移除顶部 SegmentedButton，切换校区改为 AppBar 右侧「切换校区」文字按钮

### 🔧 重构

- **移除 cue 动画包，改用 page_transition 转场 + Flutter 原生动画**：删除全部 15 个文件中的 cue 依赖，用以下方式替代（涉及项目所有页面动画）：
  - **页面转场**：`lib/core/navigation.dart` 统一使用 `page_transition` 包驱动（保留淡入效果）
  - **入场动画**（原 `Cue.onMount` + `Actor`）：改用 `TweenAnimationBuilder`（淡入 + 上浮 20px），11 个文件
  - **切换动画**（原 `Cue.onChange`）：改用 `AnimatedSwitcher` + `FadeTransition`，4 个文件
  - **选中态动画**（原 `Cue.onToggle` + `Actor.decorate`）：改用 `AnimatedContainer`（背景色/边框过渡），2 个文件
  - **选中指示点**（原 `Cue.onToggle` + `.scale()`）：改用 `AnimatedScale` + `AnimatedOpacity`
  - **呼吸灯动画**（原 `CueController`）：改用标准 `AnimationController` + `CurvedAnimation`，2 个启动页

## [1.0.3] - 2026-07-11

### 🐛 Bug 修复

- **Cookie 持久化**：每次 HTTP 响应中的 `Set-Cookie` 现在会自动保存到本地存储，重启应用后会话不丢失，无需每次重新登录。

## [1.0.2] - 2026-07-11

### 🐛 Bug 修复

- **电费查询绑定改用完整链接**：首次使用需从微信小程序复制电费查询链接，自动提取 `wechatUserOpenid` 和 `meterId`，修复因参数不匹配导致无法支付的问题。
  - 新增 `dianfei_url` / `dianfei_wechatUserOpenid` 本地存储键
  - 设置页改为粘贴完整 URL 链接，不再仅输入电表号
  - 所有查询、订单生成、支付确认 URL 统一使用从链接提取的参数
  - 移除硬编码的 `wechatUserOpenid`，支持任意用户绑定

## [1.9.3] - 2026-07-11

### 🎨 UI 优化

- **全局动画引擎统一使用 cue**：移除所有 `TweenAnimationBuilder`、`AnimatedBuilder`、`AnimationController`、`AnimatedSwitcher`、`AnimatedContainer` 旧动画，全面改用 `cue` 包的 `Cue.onMount`、`Cue.onChange`、`Cue.onToggle`、`Actor`、`TweenActor` 驱动，覆盖 14 个页面共 30+ 处动画实例。
  - 列表卡片：`Cue.onMount` + `Actor`（`delay` 控制交错入场）
  - Tab 切换：`Cue.onChange`（`fromCurrentValue: true`）
  - 标签选中：`Cue.onToggle` + `Actor.decorate`
  - 启动页呼吸灯：`CueController.repeat(reverse: true)` + `ListenableBuilder`
  - 登录页入场：`Cue.onMount`（`.fadeIn() + .slideY()`）
  - 登录页背景流动：`CueController.repeat(reverse: true)` + `ListenableBuilder`
  - 电费充值选中：`TweenActor` 自定义属性动画

### 🐛 Bug 修复

- **学期课表下拉菜单溢出**：`SmoothSelect` 缺少 `menuMaxHeight` 限制，下拉选项列表无限展开超出屏幕底部。添加 `menuMaxHeight: 300`，超出高度自动滚动。

## [1.9.2] - 2026-07-11

### 🎨 UI 优化

- **全局转场动画改用 cue 引擎**：所有页面导航切换（push/replace/clear）统一使用 `cue` 包物理弹簧动画驱动，slideX + fadeIn 联合入场；移除重复的 `_SlideTransition` 自定义类。
- **导航工具集中化**：新增 `lib/core/navigation.dart`（`pushPage`/`replacePage`/`pushAndClear`），替代分散在各页面的 `Navigator.push + MaterialPageRoute` 调用。

## [1.9.1] - 2026-07-11

### 🎨 UI 优化

- **学期选择器改用 SmoothSelect**：课表页学期下拉菜单替换为 `smooth_dropdown` 的 `SmoothSelect`，支持弹性动画高亮、键盘无障碍导航，适配品牌色 `yibinBlue`
- **成绩页学期卡片折叠**：各学期成绩分组改用 `SmoothExpansionTile`，首个学期默认展开，其余折叠，减少信息噪音，点击标题可平滑展开/收起
- **主题解耦**：新增 `lib/core/smooth_styles.dart` 集中管理 `SmoothPalette`/`SmoothStyle`/`SmoothHighlight` 品牌配置，便于后续页面复用

## [1.9.0] - 2026-07-05

### ✨ 新增

- **资讯栏目新增两个来源**：
  - **媒体关注**（`columnId: mtgz`）：`https://www.yibinu.edu.cn/mtgz.htm`
  - **融媒广角**（`columnId: rmgj`）：`https://www.yibinu.edu.cn/rmgj.htm`
  - 通用外部链接匹配：自动检测无 `info/` 模式的页面，通过 `<a title>` + 日期提取
- **通用 WebView 页面**（`lib/news/webview_page.dart`）：外部链接自动用 App 内嵌浏览器打开
- **校历 API 集成**（`fetchSemesterCalendar`）：调用 `cxxljc.do` 获取学期起始日期

### 🐛 Bug 修复

- 课程表日期/星期错乱：`dqzc.do` 增加 `XN`/`XQ`/`RQ` 参数，`_getDateForWeekday` 改为动态推算
- 课程表默认加载最新学期而非当前学期：根据当前月份智能匹配学期代码
- 课程表底部/右侧溢出：改用 `Expanded` + `OverflowBox` 处理
- 媒体关注/融媒广角列表混入导航菜单项：增加关键词过滤 + 日期检测
- 媒体关注/融媒广角详情加载失败：外部链接自动走 WebView

### 🎨 UI 优化

- 成绩查询界面：删除个人信息栏，统一蓝色主题卡片风格
- 学业完成情况：统一蓝色主题卡片风格
- 底部导航栏通透度优化（`LiquidGlassSettings` 自定义）
- 课程表行高调整至 120px，课名/教室完整显示
- 课程表支持左右滑动切换周次

## [1.8.0] - 2026-07-05

### ✨ 新增

- **教材查询模块**（`lib/jiaocai/`）：
  - 通过 eHall frReport2 报表接口获取教材订购数据
  - 自动会话管理：entrance flow → BBWID → BBKEY → sessionID → page_content
  - 支持 GBK 编码解码（`gbk_codec` 包）
  - 个人信息卡片（学号/专业/班级）+ 分学期教材明细展示
- **数据缓存层**（`lib/core/data_cache.dart`）：
  - 内存缓存单例，TTL=1天
  - 为考试安排、成绩、课程表、学业完成、综合素质、电费、新闻 7 个模块添加缓存

### 🎨 UI 优化

- 应用页分类顺序调整：教务 → 服务 → 资讯
- 底部导航栏通透度优化（自定义 LiquidGlassSettings）
- 首页新闻卡片标题改为"校园新闻"
- 卡片标题字体调整防溢出

### 🐛 Bug 修复

- FineReport 报表 GBK 编码乱码问题修复
- POST 表单 302 重定向手动跟随
- 教材查询表头行被误解析为数据行
- 修复 frReport2 报表会话建立流程，支持完整的 BBKEY → sessionID 链

## [1.7.0] - 2026-07-04

### ✨ 新增

- **资讯栏目新增三个来源**：
  - **学校要闻**（`columnId: 1311`）：爬取 `https://www.yibinu.edu.cn/xxyw.htm`
  - **宜院大讲堂**（`columnId: 1351`）：爬取 `https://www.yibinu.edu.cn/yydjt.htm`
  - **学术看板**（`columnId: 1611`）：爬取 `https://www.yibinu.edu.cn/xskb.htm`
  - 应用「资讯」网格新增三个入口卡片，复用通用 `ColumnListPage` + `ColumnService`

## [1.6.0] - 2026-07-04

### ✨ 新增

- **校园新闻模块**：新增 `lib/news/` 目录，包含新闻列表、详情、服务
  - 爬取 `https://www.yibinu.edu.cn/zhxw.htm` 获取新闻列表
  - 进入详情页加载正文内容和图片
  - 首页 Tab 0 新增「最新新闻」卡片，显示第一条新闻
  - 首页菜单和应用网格新增「校园新闻」入口
- **学工系统内置浏览器（flutter_inappwebview）**：
  - 新增 CAS SSO Cookie 注入，自动登录学工系统
  - HeadlessInAppWebView 后台提取学生个人信息（含照片）
  - WebView 底部工具栏 + 桌面版 User-Agent
- **综合素质模块**：JSON API 查询学期测评分数和排名
- **临港电费查询**（`lib/dianfei/`）：
  - HeadlessInAppWebView + JS XHR 调用双 API
  - 本月电量/电费汇总 + 近7天/近30天切换
  - 平滑折线图（Catmull-Rom 插值）+ 渐变填充
  - 支持电表绑定/解绑，数据自动保存
- **设置页面**：顶部个人卡片（头像/姓名/学号/专业），点击查看详情
- **后台数据服务**：`lib/xuegong/student_info_manager.dart` + `xuegong_data_service.dart`
- **底部导航栏**：首页/应用双栏切换，`lib/home/main_screen.dart`
- **全局 UI 美化**：Material 3 主题、页面过渡动画、卡片交错出场
- **VPN 功能**（已删除）：EVPN 协议隧道 + Go 后端，因 noexec 兼容问题移除

### 🎨 UI 优化

- 应用页面上方留白，避免被状态栏遮挡
- 底部内边距增大，避免被导航栏遮挡
- 电费查询页面背景和状态栏与其他页面统一

### 🐛 Bug 修复

- **修复新闻列表无法获取**：修正正则表达式匹配真实 HTML 结构（`<p>`+`<span>` 嵌套）
- **修复 SharedHttpClient brotli/zstd 压缩兼容**：autoUncompress=false + 手动 gzip/deflate 解压
- **修复教材查询 FormatException**：硬编码 `sessionID` 问题
- **修复学工系统凭据 key 错误**：`saved_password` → `password`
- **修复 CustomPaint 折线图填充逻辑**：路径从底部开始正确闭合

### 🐛 Bug 修复

- **修复新闻列表无法获取**：修正正则表达式匹配真实 HTML 结构（`<p>`+`<span>` 嵌套）

## [1.5.0] - 2026-07-04

### 🎯 优化

- **统一蓝白配色**：主色改为 `rgb(25, 25, 153)`（校徽蓝），移除各模块的五彩色
  - 主题：主色/按钮/输入框/导航栏全部使用校徽蓝
  - 首页菜单：彩色图标改为蓝色系
  - 应用网格：彩色卡片统一蓝色
  - 课表课程色块：12色彩虹改为蓝色渐变
  - 登录页：渐变背景改为校徽蓝单色渐变
  - 底部导航：选中色改为校徽蓝
- **删除应用页顶部 Hero 和个人中心按钮**：统一简化导航栏和内容区

## [1.4.0] - 2026-07-04

### 🎨 UI 优化

- **全局主题重构**：Material 3 自定义主题，统一配色、圆角、按钮、输入框样式
- **页面过渡动画**：统一使用 FadeUpwardsPageTransitionsBuilder 页面过渡效果
- **登录页重构**：渐入 + 上浮交错动画，Logo 区域重新设计，按钮加载动画
- **首页菜单卡片**：交错出场动画（透明度 + 位移），更精致的卡片样式
- **底部导航**：选中标签高亮背景动画
- **应用网格**：交错入场动画，统一卡片圆角和间距
- **课表页**：切换周次时 AnimatedSwitcher 过渡动画，学期视图卡片交错进场
- **校历页**：列表条目交错动画（渐入 + 上浮）
- **登录成功跳转**：缩放 + 淡出过渡动画

## [1.3.0] - 2026-07-04

### ✨ 新增

- **校历服务模块**：新增 `lib/calendar/` 目录，包含校历数据模型、服务、页面
  - `CalendarService`：通过 HTML 解析获取宜宾学院官网校历列表及 PDF 链接
  - `CalendarPage`：校历列表页，从新到旧展示历年校历，点击可打开 PDF
  - 新增依赖 `url_launcher` 用于打开外部 PDF 链接

### 🎯 优化

- **加入校历入口**：首页菜单卡片 + 应用网格新增「校历服务」入口
- **移除 url_launcher 依赖**：改用 `dart:io` Process 打开链接，避免 Kotlin 编译冲突

## [1.2.2] - 2026-07-04

### ✨ 新增

- **课表支持周/学期双模式切换**：顶部 SegmentedButton 切换「周课表」和「学期课表」
  - 周课表：默认显示当前周，当天列高亮，可逐周切换，带「回到本周」按钮
  - 学期课表：按星期分组展示全部课程卡片，支持学期选择下拉框
- **新增调课/停课信息面板**：底部可展开显示课程调课/停课详情
- **新增未安排课程面板**：底部可展开显示无具体时间地点的课程
- **修正节次时间**：节次标签改为 API 实际时间（08:30-09:15等）

### 🎯 优化

- **课表模型扩展**：新增 `CourseChange`、`UnarrangedCourse`、`SemesterInfo` 数据模型
- **课表服务增强**：新增 `fetchCurrentWeek`、`fetchSemesters`、`fetchCourseChanges`、`fetchUnarrangedCourses` API 方法

## [1.2.1] - 2026-07-04

### 🐛 Bug 修复

- **移除「培养方案」功能**：删除 plan/ 目录及相关入口卡片和网格入口
- **修复「记住密码」不能自动登录**：加载已保存凭据后自动触发登录流程，无需手动点击"登 录"

### 🎨 UI 优化

- **底部导航栏**：新增「首页」「应用」双栏切换
  - 首页：直接显示课程表
  - 应用：网格入口展示成绩查询、考试安排、培养方案、学业完成、个人中心

## [1.4.1] - 2026-07-04

### ✨ 新增

- **个人培养方案查询**：培养方案总览（学分进度环）、课程组树结构（平台/课组/课程三级展开）、108门课程明细

## [1.4.0] - 2026-07-03

### ✨ 新增

- **自动验证码识别**：参考 login-java 实现
  - 新增 `CaptchaService`：needCaptcha 检测 → 下载验证码 → 二值化预处理（灰值阈值 115）→ ML Kit OCR → 校验重试（最多 10 次）
  - `CasLoginService` 集成：needCaptcha=true 时自动进入验证码识别流程
  - 新增依赖：`google_mlkit_text_recognition`、`image`、`path_provider`

### 🔧 重构

- **模块化项目结构**：按功能拆分目录
  - `core/`：共享基础设施（http_client、local_storage、version）
  - `auth/`：登录模块（login_page、auth_service、cas_login_service）
  - `home/`：首页（home_page）
  - `course/`：课表模块（course_page、course_service、course 模型）
  - `grade/`：成绩模块（score_page、score_service、score 模型）
  - `profile/`：个人中心（profile_page）

## [1.2.1] - 2026-07-03

### 🐛 Bug 修复

- **修复个人中心/成绩查询/课程表 HTTP 403 问题**：所有 ehall API 改用 `http://` 协议（参考 yibinu-score-crawler）
  - `CasLoginService`：登录 URL、needCaptcha URL、预热 URL 全部改用 `http://`
  - `ScoreService`：基础 URL 改为 `http://`，添加 Origin/Referer 请求头
  - `CourseService`：基础 URL 改为 `http://`
  - `ProfilePage`：个人信息 API URL 改为 `http://`，添加 Referer 请求头
- **新增 `SharedHttpClient` Cookie 域名隔离**：按域名存储 Cookie，避免 authserver 与 ehall 域名 Cookie 混用
- **修复 CAS 登录重定向跟随**：第一个重定向使用 POST 方法（参考 Java 实现），失败时回退到 GET
- **成绩查询服务**：学生信息获取改为可选，失败不影响成绩查询
- **个人信息页面**：添加 404 友好提示
- **修复课表 API**：端点从 `xskcb.do` 改为 `xsdkkc.do`（实际课表数据接口）
- **`Course.fromJson` 适配 xsdkkc 字段**：新增 `XSKJS`/`XJASMC`/`XSKXQ`/`XKSJC`/`XJSJC`/`XSKZC`/`XZCMC` 字段支持
- **`CourseService` 请求头**：Origin/Referer 改用 `https://`，默认使用 form-urlencoded Content-Type

## [1.2.0] - 2026-07-03

### ✨ 新增

- **首页**：登录后进入首页，两个功能入口卡片（课程表 + 成绩查询）
- **成绩查询**完整功能：
  - 参考 yibinu-score-crawler 实现成绩爬取流程
  - 角色选择 → 成绩查询页 → 查询 API
  - 学生信息展示（姓名/学号/学院/专业/班级）
  - 按学期分组展示成绩列表（课程名/类别/学分/成绩/绩点）
  - 总览统计（总学分/课程数/平均绩点）
  - 正确/错误颜色区分，下拉刷新
- 新增 `lib/models/score.dart`：Score + StudentInfo 数据模型
- 新增 `lib/services/score_service.dart`：成绩查询服务
- 新增 `lib/pages/score_page.dart`：成绩展示页面
- 新增 `lib/pages/home_page.dart`：功能选择首页

### 🔧 重构

- 登录成功导航改为首页 HomePage，而非直接进入课程表

## [1.1.1] - 2026-07-03

### 🐛 Bug 修复

- 参考 NIIT_getCourse 修复课表 API 403：先调用 `cxxsjbxx.do` 建立用户上下文再请求 `xskcb.do`
- `CourseService` 新增 `userId` 参数，登录时传递学号

## [1.0.7] - 2026-07-03

### 🐛 Bug 修复

- 修复课表 API 403 禁止访问：`xskcb.do` 改用 POST + `Content-Type: application/x-www-form-urlencoded`
- 调用课表 API 前先预热 ehall 会话（访问主页确保 Cookie 完整）

## [1.0.6] - 2026-07-03

### 🐛 Bug 修复

- 修复课表 API 返回 HTML 的问题：重写 CAS 登录重定向跟随逻辑
  - 手动追踪整条重定向链（最多 5 跳），捕获每跳的 Cookie
  - 进入 ehall 域后改用 GET 方法验证 CAS ticket
  - 使用 `Cookie.fromSetCookieValue()` 正确解析 Set-Cookie 头部
  - 处理 Expires 日期中逗号的歧义

## [1.0.5] - 2026-07-03

### 🐛 Bug 修复

- 修复 Android 9+ 无法连接 HTTP 的问题：`AndroidManifest.xml` 添加 `usesCleartextTraffic="true"`
- CAS 登录各阶段请求添加连接超时（10-15s），避免无限等待

### 🎯 优化

- 超时场景显示具体提示"网络请求超时，请检查网络连接"
- 去除 AuthService 多余的"登录失败："前缀

## [1.0.4] - 2026-07-03

### 🐛 Bug 修复

- 修正课表 API 端点：`cxxszhxqkb.do` → `xskcb.do`（原端点返回 302 重定向）
- 修正 `Course.fromJson` 周次解析：改用 `SKZC` 二进制字符串解析，兼容 `ZCMC` 文本回退

### ✨ 新增

- `fetchCourses` 支持按周次参数 `SKZC` 请求
- HTTP 302 场景输出重定向地址便于调试

## [1.0.3] - 2026-07-03

### ✨ 新增

- 登录成功后自动进入课程表页面，调用 ehall 课表 API 获取课程数据
- 新增 `course_table_page.dart`：周课表网格视图，支持周次切换滑块，课程卡片彩色区分
- 新增 `course_service.dart`：调用 `/jwapp/sys/wdkb/modules/xskcb/cxxszhxqkb.do` 接口
- 新增 `models/course.dart`：课程数据模型，支持周次范围解析与节次解析

### 🔧 重构

- 登录页导航改为跳转课程表页面，传递 Cookies
- 移除不再使用的 `home_page.dart`

## [1.0.2] - 2026-07-03

### ✨ 新增

- 将 Java CAS 登录流程完整移植到 Dart，无需外部后端
- 新增 `cas_login_service.dart`：AES-128-CBC 加密、HTML 表单解析、Cookie 管理、重定向跟随
- 新增 `encrypt`、`html` 依赖

### 🔧 重构

- 移除 `config/api_config.dart`，不再依赖 Java API 后端
- `auth_service.dart` 改用 Dart 原生 CAS 登录流程
- `home_page.dart` 支持 Map 格式 Cookies 展示

## [1.0.1] - 2026-07-03

### ✨ 新增

- 宜宾学院智慧校园登录页（蓝色渐变 UI）
- 登录成功结果页，展示 Cookies
- 添加 `http` 依赖、INTERNET 权限

### 🎯 优化

- 应用名称改为「宜宾学院智慧校园」
- widget test 适配新路由结构
