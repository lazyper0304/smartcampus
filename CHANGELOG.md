# CHANGELOG

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
