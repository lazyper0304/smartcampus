import 'package:flutter/material.dart';

import '../core/http_client.dart';
import '../course/course_page.dart';
import '../exam/exam_page.dart';
import '../grade/score_page.dart';
import '../graduation/graduation_page.dart';
import '../calendar/calendar_page.dart';
import '../jiaocai/jiaocai_page.dart';
import '../news/news_list_page.dart';
import '../news/column_list_page.dart';
import '../xuegong/zhsz_page.dart';
import '../dianfei/dianfei_page.dart';
import '../shuttle/shuttle_page.dart';
import '../units/units_page.dart';
import '../departments/departments_page.dart';
import '../employ/employ_page.dart';
import '../network/network_service_page.dart';
import '../safety/safety_page.dart';

/// 应用分类
enum AppCategory { jiaowu, service, news }

/// 应用条目定义
class AppEntry {
  final IconData icon;
  final String name;
  final AppCategory category;
  final Widget Function(BuildContext, SharedHttpClient, String) pageBuilder;

  const AppEntry({
    required this.icon,
    required this.name,
    required this.category,
    required this.pageBuilder,
  });
}

/// 所有应用列表
final List<AppEntry> allApps = [
  // ── 教务 ──
  AppEntry(icon: Icons.calendar_month_rounded, name: '课程表', category: AppCategory.jiaowu,
    pageBuilder: (ctx, c, uid) => CourseTablePage(client: c, userId: uid)),
  AppEntry(icon: Icons.assessment_rounded, name: '成绩查询', category: AppCategory.jiaowu,
    pageBuilder: (ctx, c, uid) => ScorePage(client: c, userId: uid)),
  AppEntry(icon: Icons.event_note_rounded, name: '考试安排', category: AppCategory.jiaowu,
    pageBuilder: (ctx, c, uid) => ExamPage(client: c)),
  AppEntry(icon: Icons.auto_stories_rounded, name: '学业完成', category: AppCategory.jiaowu,
    pageBuilder: (ctx, c, uid) => GraduationPage(client: c)),
  AppEntry(icon: Icons.calendar_view_month_rounded, name: '校历服务', category: AppCategory.jiaowu,
    pageBuilder: (ctx, c, uid) => const CalendarPage()),
  AppEntry(icon: Icons.school_rounded, name: '综合素质', category: AppCategory.jiaowu,
    pageBuilder: (ctx, c, uid) => ZhszPage(client: c)),
  AppEntry(icon: Icons.menu_book_rounded, name: '教材查询', category: AppCategory.jiaowu,
    pageBuilder: (ctx, c, uid) => JiaocaiPage(client: c, userId: uid)),
  AppEntry(icon: Icons.account_tree_rounded, name: '教学单位', category: AppCategory.jiaowu,
    pageBuilder: (ctx, c, uid) => const UnitsPage()),
  AppEntry(icon: Icons.domain_rounded, name: '职能部门', category: AppCategory.jiaowu,
    pageBuilder: (ctx, c, uid) => const DepartmentsPage()),

  // ── 服务 ──
  AppEntry(icon: Icons.electrical_services_rounded, name: '临港电费', category: AppCategory.service,
    pageBuilder: (ctx, c, uid) => const DianfeiPage()),
  AppEntry(icon: Icons.directions_bus_rounded, name: '校车时间', category: AppCategory.service,
    pageBuilder: (ctx, c, uid) => const ShuttlePage()),
  AppEntry(icon: Icons.work_rounded, name: '就业信息', category: AppCategory.service,
    pageBuilder: (ctx, c, uid) => const EmployPage()),
  AppEntry(icon: Icons.lan_rounded, name: '网络服务', category: AppCategory.service,
    pageBuilder: (ctx, c, uid) => const NetworkServicePage()),
  AppEntry(icon: Icons.shield_rounded, name: '校园安全', category: AppCategory.service,
    pageBuilder: (ctx, c, uid) => const SafetyPage()),

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
