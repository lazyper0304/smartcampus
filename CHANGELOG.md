# CHANGELOG

## [1.0.6] - 2026-07-18

### 🎨 UI 优化
- **课程表实验课卡片简化**：实验课不再显示实验项目名（`exp_name`），只保留「实验」橙色小标签 + 课程名 + 教室，周课表卡片更紧凑易读

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
