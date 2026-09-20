import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../core/cas_webview.dart' as cas_webview;
import '../core/http_client.dart';
import '../auth/auth_service.dart';
import '../course/course_page.dart';
import '../course/all_class_schedule_page.dart';
import '../exam/exam_page.dart';
import '../grade/score_page.dart';
import '../graduation/graduation_page.dart';
import '../calendar/calendar_page.dart';
import '../jiaocai/jiaocai_page.dart';
import '../news/news_list_page.dart';
import '../news/column_list_page.dart';
import '../office/office_home_page.dart';
import '../office/office_widgets.dart';
import '../news/webview_page.dart';
import '../xuegong/zhsz_page.dart';
import '../dianfei/dianfei_page.dart';
import '../shuttle/shuttle_page.dart';
import '../units/units_page.dart';
import '../departments/departments_page.dart';
import '../employ/employ_page.dart';
import '../network/network_service_page.dart';
import '../safety/safety_page.dart';
import '../vrmap/vrmap_page.dart';
import '../race/race_page.dart';
import '../srtp/srtp_page.dart';
import '../second_classroom/erke_login_page.dart';
import '../kxjas/kxjas_page.dart';
import '../bohrium/bohrium_page.dart';
import '../kccx/kccx_page.dart';
import '../qxfacx/qxfacx_page.dart';
import '../wspj/wspj_page.dart';
import '../mail/mail_page.dart';
import '../leader_mail/leader_mail_page.dart';
import '../vpn/vpn_page.dart';

/// 应用分类
enum AppCategory { jiaowu, service, news }

/// 应用条目定义
class AppEntry {
  final IconData icon;
  final String name;
  final AppCategory category;
  final Widget Function(BuildContext, SharedHttpClient, String) pageBuilder;
  /// 可选角标（如「校园网」内网标识），显示在网格入口卡的右上角
  final Widget? badge;
  /// 是否需要登录才能使用（游客模式下拦截并引导登录）
  final bool requiresLogin;

  const AppEntry({
    required this.icon,
    required this.name,
    required this.category,
    required this.pageBuilder,
    this.badge,
    this.requiresLogin = false,
  });

  /// 模块专属色（彩色图标方案）：按名称查 [kModuleColors]，
  /// 未登记的条目回退中性灰（见 app_data.dart 末尾色表）。
  Color get color => kModuleColors[name] ?? _kModuleFallbackColor;
}

/// 所有应用列表
final List<AppEntry> allApps = [
  // ── 教务 ──
  AppEntry(icon: Icons.calendar_month_rounded, name: '我的课表', category: AppCategory.jiaowu,
    requiresLogin: true,
    pageBuilder: (ctx, c, uid) => CourseTablePage(client: c, userId: uid)),
  AppEntry(icon: Icons.groups_rounded, name: '全校课表', category: AppCategory.jiaowu,
    requiresLogin: true,
    pageBuilder: (ctx, c, uid) => AllClassSchedulePage(client: c, userId: uid)),
  AppEntry(icon: Icons.assessment_rounded, name: '成绩查询', category: AppCategory.jiaowu,
    requiresLogin: true,
    pageBuilder: (ctx, c, uid) => ScorePage(client: c, userId: uid)),
  AppEntry(icon: Icons.event_note_rounded, name: '考试安排', category: AppCategory.jiaowu,
    requiresLogin: true,
    pageBuilder: (ctx, c, uid) => ExamPage(client: c)),
  AppEntry(icon: Icons.auto_stories_rounded, name: '学业完成', category: AppCategory.jiaowu,
    requiresLogin: true,
    pageBuilder: (ctx, c, uid) => GraduationPage(client: c)),
  AppEntry(icon: Icons.calendar_view_month_rounded, name: '校历服务', category: AppCategory.jiaowu,
    pageBuilder: (ctx, c, uid) => const CalendarPage()),
  AppEntry(icon: Icons.school_rounded, name: '综合素质', category: AppCategory.jiaowu,
    requiresLogin: true,
    pageBuilder: (ctx, c, uid) => ZhszPage(client: c)),
  AppEntry(icon: Icons.menu_book_rounded, name: '已购教材', category: AppCategory.jiaowu,
    requiresLogin: true,
    pageBuilder: (ctx, c, uid) => JiaocaiPage(client: c, userId: uid)),
  AppEntry(icon: Icons.account_tree_rounded, name: '教学单位', category: AppCategory.jiaowu,
    pageBuilder: (ctx, c, uid) => const UnitsPage()),
  AppEntry(icon: Icons.domain_rounded, name: '职能部门', category: AppCategory.jiaowu,
    pageBuilder: (ctx, c, uid) => const DepartmentsPage()),
  AppEntry(icon: Icons.emoji_events_rounded, name: '学科竞赛', category: AppCategory.jiaowu,
    requiresLogin: true,
    pageBuilder: (ctx, c, uid) => RacePage(client: c)),
  AppEntry(icon: Icons.rocket_launch_rounded, name: '创新创业', category: AppCategory.jiaowu,
    requiresLogin: true,
    pageBuilder: (ctx, c, uid) => SrtpPage(client: c)),
  AppEntry(icon: Icons.assignment_ind_rounded, name: '第二课堂', category: AppCategory.jiaowu,
    badge: const OfficeCampusCornerBadge(),
    requiresLogin: true,
    pageBuilder: (ctx, c, uid) => const ErkeLoginPage()),
  AppEntry(icon: Icons.meeting_room_rounded, name: '空闲教室', category: AppCategory.jiaowu,
    requiresLogin: true,
    pageBuilder: (ctx, c, uid) => KxjasPage(client: c)),
  AppEntry(icon: Icons.biotech_rounded, name: '玻尔科研', category: AppCategory.jiaowu,
    requiresLogin: true,
    pageBuilder: (ctx, c, uid) => BohriumPage(client: c)),
  AppEntry(icon: Icons.local_library_rounded, name: '课程查询', category: AppCategory.jiaowu,
    requiresLogin: true,
    pageBuilder: (ctx, c, uid) => KccxPage(client: c)),
  AppEntry(icon: Icons.menu_book_rounded, name: '全校方案', category: AppCategory.jiaowu,
    requiresLogin: true,
    pageBuilder: (ctx, c, uid) => QxFacxPage(client: c)),
  AppEntry(icon: Icons.rate_review_rounded, name: '网上评教', category: AppCategory.jiaowu,
    requiresLogin: true,
    pageBuilder: (ctx, c, uid) => WspjPage(client: c, userId: uid)),

  // ── 服务 ──
  AppEntry(icon: Icons.electrical_services_rounded, name: '临港电费', category: AppCategory.service,
    pageBuilder: (ctx, c, uid) => const DianfeiPage()),
  AppEntry(icon: Icons.directions_bus_rounded, name: '校车时间', category: AppCategory.service,
    pageBuilder: (ctx, c, uid) => const ShuttlePage()),
  AppEntry(icon: Icons.work_rounded, name: '就业信息', category: AppCategory.service,
    pageBuilder: (ctx, c, uid) => const EmployPage()),
  AppEntry(icon: Icons.lan_rounded, name: '网络服务', category: AppCategory.service,
    pageBuilder: (ctx, c, uid) => const NetworkServicePage()),
  AppEntry(icon: Icons.vpn_lock_rounded, name: '校园VPN', category: AppCategory.service,
    requiresLogin: true,
    pageBuilder: (ctx, c, uid) => VpnPage(initialUsername: uid)),
  AppEntry(icon: Icons.shield_rounded, name: '校园安全', category: AppCategory.service,
    pageBuilder: (ctx, c, uid) => const SafetyPage()),
  AppEntry(icon: Icons.map_rounded, name: 'VR地图', category: AppCategory.service,
    pageBuilder: (ctx, c, uid) => const VrmapPage()),
  AppEntry(icon: Icons.business_center_rounded, name: '办公网', category: AppCategory.service,
    badge: const OfficeCampusCornerBadge(),
    pageBuilder: (ctx, c, uid) => const OfficeHomePage()),
  AppEntry(icon: Icons.mail_rounded, name: '邮件系统', category: AppCategory.service,
    requiresLogin: true,
    pageBuilder: (ctx, c, uid) => MailPage(client: c)),
  AppEntry(icon: Icons.mark_email_unread_rounded, name: '领导信箱', category: AppCategory.service,
    pageBuilder: (ctx, c, uid) => const LeaderMailPage()),
  AppEntry(icon: Icons.forum_rounded, name: 'QQ频道', category: AppCategory.service,
    pageBuilder: (ctx, c, uid) => const WebViewPage(
      url: 'https://pd.qq.com/s/bq4dam2kg',
      title: 'QQ频道',
    )),
  AppEntry(icon: Icons.cloud_rounded, name: 'CARSI', category: AppCategory.service,
    requiresLogin: true,
    // ⚠️ 不能 const：需要 onWebViewReady 做会话预热 + cookie 注入
    pageBuilder: (ctx, c, uid) => WebViewPage(
      url: 'https://ds.carsi.edu.cn/Shibboleth.sso/Login?entityID=https://idp.yibinu.edu.cn/idp/shibboleth&target=https%3A%2F%2Fds.carsi.edu.cn%2Fwxds',
      title: 'CARSI',
      // 桌面 UA：CARSI 联盟资源站（知网等）对移动/WebView UA 返回精简
      // 页面甚至拒绝服务（「来源应用不正确」），整页伪装桌面浏览器
      desktopUserAgent: true,
      // 提示：部分资源（如知网）在线阅读/下载在 App 内无法通过来源校验
      notice: '部分资源（如知网）不支持在线阅读和下载',
      onWebViewReady: (controller) async {
        // 会话预热 + 注入：CARSI 跳学校 IdP（idp.yibinu.edu.cn）时凭
        // .yibinu.edu.cn 父域 CASTGC 自动放行（不再依赖学科竞赛 bootstrap
        // 先刷新的副作用；App 运行期间 TGC 过期时这里会自动重登刷新）
        await AuthService(sharedClient: c).ensureFreshSession();
        await cas_webview.injectCasCookiesToWebView(
            c, CookieManager.instance());
      },
    )),

  // ── 资讯 ──
  AppEntry(icon: Icons.newspaper_rounded, name: '校园新闻', category: AppCategory.news,
    pageBuilder: (ctx, c, uid) => const NewsListPage()),
  AppEntry(icon: Icons.people_rounded, name: '师生风采', category: AppCategory.news,
    pageBuilder: (ctx, c, uid) => const ColumnListPage(title: '师生风采', columnId: '1331', firstPageUrl: 'https://www.yibinu.edu.cn/ssfc.htm')),
  AppEntry(icon: Icons.science_rounded, name: '科研动态', category: AppCategory.news,
    pageBuilder: (ctx, c, uid) => const ColumnListPage(title: '科研动态', columnId: '1341', firstPageUrl: 'https://www.yibinu.edu.cn/kydt.htm')),
  AppEntry(icon: Icons.campaign_rounded, name: '通知公告', category: AppCategory.news,
    pageBuilder: (ctx, c, uid) => const ColumnListPage(title: '通知公告', columnId: '1361', firstPageUrl: 'https://www.yibinu.edu.cn/tzgg.htm')),
  AppEntry(icon: Icons.menu_book_rounded, name: '学校要闻', category: AppCategory.news,
    pageBuilder: (ctx, c, uid) => const ColumnListPage(title: '学校要闻', columnId: '1311', firstPageUrl: 'https://www.yibinu.edu.cn/xxyw.htm')),
  AppEntry(icon: Icons.mic_rounded, name: '宜院大讲堂', category: AppCategory.news,
    pageBuilder: (ctx, c, uid) => const ColumnListPage(title: '宜院大讲堂', columnId: '1351', firstPageUrl: 'https://www.yibinu.edu.cn/yydjt.htm')),
  AppEntry(icon: Icons.dashboard_rounded, name: '学术看板', category: AppCategory.news,
    pageBuilder: (ctx, c, uid) => const ColumnListPage(title: '学术看板', columnId: '1611', firstPageUrl: 'https://www.yibinu.edu.cn/xskb.htm')),
  AppEntry(icon: Icons.public_rounded, name: '媒体关注', category: AppCategory.news,
    pageBuilder: (ctx, c, uid) => const ColumnListPage(title: '媒体关注', columnId: 'mtgz', firstPageUrl: 'https://www.yibinu.edu.cn/mtgz.htm')),
  AppEntry(icon: Icons.videocam_rounded, name: '融媒广角', category: AppCategory.news,
    pageBuilder: (ctx, c, uid) => const ColumnListPage(title: '融媒广角', columnId: 'rmgj', firstPageUrl: 'https://www.yibinu.edu.cn/rmgj.htm')),
];

/// ---------------------------------------------------------------------------
/// 模块专属色表（彩色图标）：一个模块一个色相，色相只用于该模块图标自身，
/// 不再作为界面主题色使用（界面主色统一为中性的「墨色」，见 theme_utils.dart）。
///
/// 取值参考 iOS 系统色系：饱和度适中、明度高，白底与深色底上均清晰；
/// 同类模块（教务/服务/资讯）内部刻意错开色相，便于宫格中快速定位。
/// ---------------------------------------------------------------------------
const Color _kModuleFallbackColor = Color(0xFF78849E);

const Map<String, Color> kModuleColors = {
  // ── 教务 ──
  '我的课表': Color(0xFF3B6BFF), // 蓝：课表主入口
  '全校课表': Color(0xFF6C5CE7), // 靛紫
  '成绩查询': Color(0xFFFF8A3D), // 橙：成绩
  '考试安排': Color(0xFFF2545B), // 红：考试
  '学业完成': Color(0xFF9B59F6), // 紫：学业进度
  '校历服务': Color(0xFF22B8E6), // 亮蓝
  '综合素质': Color(0xFFE056A0), // 品红
  '已购教材': Color(0xFF7CB342), // 草绿：书本
  '教学单位': Color(0xFF78849E), // 石板灰：组织
  '职能部门': Color(0xFF8D6E63), // 棕：行政
  '学科竞赛': Color(0xFFF5A623), // 金：奖杯
  '创新创业': Color(0xFF14B8A6), // 青绿：火箭
  '第二课堂': Color(0xFFC05CF0), // 洋紫
  '空闲教室': Color(0xFF2D9CDB), // 天蓝：教室
  '玻尔科研': Color(0xFF00A6A6), // 科研青
  '课程查询': Color(0xFF5C6BC0), // 灰蓝
  '全校方案': Color(0xFFAB47BC), // 紫罗兰
  '网上评教': Color(0xFFFF7043), // 朱橙：评教

  // ── 服务 ──
  '临港电费': Color(0xFFFFB020), // 琥珀：电
  '校车时间': Color(0xFF3B6BFF), // 蓝：班车
  '就业信息': Color(0xFF6C5CE7), // 靛紫：就业
  '网络服务': Color(0xFF22B8E6), // 亮蓝：网络
  '校园VPN': Color(0xFF2FB344), // 绿：隧道
  '校园安全': Color(0xFFF2545B), // 红：安全
  'VR地图': Color(0xFF14B8A6), // 青绿：地图
  '办公网': Color(0xFF8D6E63), // 棕：办公
  '邮件系统': Color(0xFF2D9CDB), // 天蓝：邮件
  '领导信箱': Color(0xFFE056A0), // 品红：信箱
  'QQ频道': Color(0xFF4C8DFF), // QQ 蓝
  'CARSI': Color(0xFF9B59F6), // 紫：联盟资源

  // ── 资讯 ──
  '校园新闻': Color(0xFF3B6BFF),
  '师生风采': Color(0xFFFF8A3D),
  '科研动态': Color(0xFF00A6A6),
  '通知公告': Color(0xFFF2545B),
  '学校要闻': Color(0xFF6C5CE7),
  '宜院大讲堂': Color(0xFFE056A0),
  '学术看板': Color(0xFF22B8E6),
  '媒体关注': Color(0xFF7CB342),
  '融媒广角': Color(0xFFF5A623),
};
