# 宜宾学院智慧校园 · SmartCampus

<p align="center">
  <img src="https://img.shields.io/badge/version-1.1.0-blue" alt="version">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="license">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B" alt="flutter">
</p>

宜宾学院智慧校园**第三方非官方**移动客户端，基于 Flutter 跨平台开发，聚合校内教务、生活服务与校园资讯，方便师生在手机上一站式查询与使用。

> ⚠️ 本项目为个人学习交流用途的第三方客户端，与宜宾学院官方无任何隶属关系。详见 [开源声明.md](./开源声明.md)。

---

## ✨ 功能特性

应用内整合三大类功能入口：

### 📚 教务（需登录）
| 功能 | 说明 |
|---|---|
| 课程表 | 个人周课表查询 |
| 全校课表 | 按班级查询全校课程安排 |
| 成绩查询 | 历史学期成绩查询 |
| 考试安排 | 考试时间与地点 |
| 学业完成 | 培养方案完成情况 |
| 综合素质 | 综合素质测评 |
| 教材查询 | 教材选用情况 |
| 学科竞赛 | 学科竞赛报名 / 查询 |
| 第二课堂 | 第二课堂活动（校园网内网） |
| 校历服务 | 校历查看 |
| 教学单位 / 职能部门 | 校内单位信息 |

### 🛠 服务（无需登录）
- 临港电费查询
- 校车时间
- 就业信息
- 网络服务
- 校园安全
- VR 地图
- 办公网（校园网内网）
- **QQ 频道**：内置 WebView 打开官方 QQ 频道，点击「加入频道」自动拉起 QQ 客户端

### 📰 资讯（无需登录）
校园新闻、师生风采、科研动态、通知公告、学校要闻、宜院大讲堂、学术看板、媒体关注、融媒广角等学校官网栏目。

---

## 👤 游客模式

登录页支持**游客登录**：无需账号密码即可进入应用，浏览所有「服务」与「资讯」类公开内容。

- 涉及个人数据的教务功能（课程表、成绩、考试等）对游客**置灰并加锁角标**；
- 点击被锁功能会弹出提示，引导前往登录；
- 游客状态通过本地持久化，冷启动自动恢复；正常登录后自动退出游客态。

---

## 🧱 技术栈

- **Flutter / Dart** —— 跨平台 UI 与逻辑
- **flutter_inappwebview** —— 内置 WebView（QQ 频道、VR 地图等）
- **url_launcher** —— 拉起外部应用（QQ、`mqqapi://` 协议、电话等）
- **CAS 单点登录 + Cookie 会话管理** —— 统一认证登录
- **本地存储** —— 账号凭据、会话 Cookie、游客态标记均仅存于本机
- （Android）**深信服 aTrust VPN SDK** —— 校园内网访问

---

## 🚀 快速开始

### 环境要求
- Flutter SDK 3.x（与 `pubspec.yaml` 中声明的版本一致）
- Dart SDK
- Android SDK（构建 Android 包）
- 如需访问内网功能（办公网、第二课堂），需目标设备已接入校园网或配置 VPN

### 安装与运行
```bash
# 1. 获取依赖
flutter pub get

# 2. 运行（调试）
flutter run

# 3. 构建发布包（Android）
flutter build apk --release
```

> 注：项目中部分资源（如 `lib/vpn/SangforSDK.aar`、原生 so 库）需在 Android 端手动放置到对应目录，详见 `SDK2.6.10.1_0530/` 目录下的集成说明。

---

## 📁 项目结构（节选）
```
lib/
├── auth/          # 登录、CAS 认证
├── core/          # 通用能力：HTTP 客户端、本地存储、游客态、WebView 拦截
├── home/          # 首页网格、Dashboard、应用入口定义（app_data.dart）
├── course/        # 课程表 / 全校课表
├── grade/         # 成绩查询
├── exam/          # 考试安排
├── news/          # 资讯列表、通用 WebView 页面
├── office/        # 办公网
├── settings/      # 设置页
└── main.dart      # 启动入口（游客态恢复、会话校验）
```

---

## 📄 开源协议与声明

- 本项目以 **MIT 许可证** 开源，详见 [LICENSE](./LICENSE)。
- 使用条款、隐私与免责说明请阅读 [开源声明.md](./开源声明.md)。
- 更新记录见 [CHANGELOG.md](./CHANGELOG.md)。

> 账号与密码仅存储于本机，不会上传至任何第三方服务器。使用本项目所产生的任何风险由使用者自行承担。
