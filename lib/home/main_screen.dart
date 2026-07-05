import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/http_client.dart';
import '../course/course_page.dart';
import '../exam/exam_page.dart';
import '../grade/score_page.dart';
import '../graduation/graduation_page.dart';
import '../calendar/calendar_page.dart';
import '../jiaocai/jiaocai_page.dart';
import '../news/news_list_page.dart';
import '../news/column_list_page.dart';
import '../xuegong/xuegong_page.dart';
import '../xuegong/zhsz_page.dart';
import '../dianfei/dianfei_page.dart';
import '../settings/settings_page.dart';
import 'home_dashboard.dart';

const Color _yibinBlue = Color.fromRGBO(25, 25, 153, 1);

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

class MainScreen extends StatefulWidget {
  final SharedHttpClient client;
  final String userId;

  const MainScreen({
    super.key,
    required this.client,
    required this.userId,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      background: Container(
        color: _isDark(context) ? const Color(0xFF1A1A2E) : const Color(0xFFF0F4FF),
      ),
      statusBarStyle: GlassStatusBarStyle.auto,
      contentAwareBrightness: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.12, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        child: [
          HomeDashboard(
            key: const ValueKey('home'),
            client: widget.client,
            userId: widget.userId,
          ),
          _AppsPage(
            key: const ValueKey('apps'),
            client: widget.client,
            userId: widget.userId,
          ),
          SettingsPage(key: const ValueKey('settings'), client: widget.client),
        ][_currentIndex],
      ),
      bottomBar: Theme(
        data: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: _yibinBlue,
            primary: _yibinBlue,
          ),
        ),
        child: GlassTabBar.bottom(
          settings: const LiquidGlassSettings(
            thickness: 32,
            blur: 1,
            glowIntensity: 1,
            refractiveIndex: 2.5,
            standardOpacityMultiplier: 1,
          ),
          selectedIndex: _currentIndex,
          onTabSelected: (i) => setState(() => _currentIndex = i),
          tabs: [
            GlassTab(
              icon: Icon(Icons.home_rounded),
              activeIcon: Icon(Icons.home_rounded, color: _yibinBlue),
              label: '首页',
            ),
            GlassTab(
              icon: Icon(Icons.apps_rounded),
              activeIcon: Icon(Icons.apps_rounded, color: _yibinBlue),
              label: '应用',
            ),
            GlassTab(
              icon: Icon(Icons.settings_rounded),
              activeIcon: Icon(Icons.settings_rounded, color: _yibinBlue),
              label: '设置',
            ),
          ],
        ),
      ),
    );
  }
}

class _AppsPage extends StatelessWidget {
  final SharedHttpClient client;
  final String userId;

  const _AppsPage({
    super.key,
    required this.client,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              // ── 教务 ──
              _buildSectionHeader(context, Icons.school_rounded, '教务'),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildAppCard(Icons.calendar_month_rounded, '课程表', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => CourseTablePage(
                                client: client,
                                userId: userId,
                              )),
                    );
                  }),
                  _buildAppCard(Icons.assessment_rounded, '成绩查询', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ScorePage(
                                client: client,
                                userId: userId,
                              )),
                    );
                  }),
                  _buildAppCard(Icons.event_note_rounded, '考试安排', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ExamPage(client: client)),
                    );
                  }),
                  _buildAppCard(Icons.auto_stories_rounded, '学业完成', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => GraduationPage(client: client)),
                    );
                  }),
                  _buildAppCard(
                      Icons.calendar_view_month_rounded, '校历服务', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CalendarPage()),
                    );
                  }),
                  _buildAppCard(Icons.school_rounded, '综合素质', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ZhszPage(client: client)),
                    );
                  }),
                  _buildAppCard(Icons.menu_book_rounded, '教材查询', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              JiaocaiPage(client: client, userId: userId)),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 28),
              // ── 服务 ──
              _buildSectionHeader(context, Icons.miscellaneous_services_rounded, '服务'),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildAppCard(Icons.electrical_services_rounded, '临港电费', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const DianfeiPage()),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 28),
              // ── 资讯 ──
              _buildSectionHeader(context, Icons.rss_feed_rounded, '资讯'),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildAppCard(Icons.newspaper_rounded, '校园新闻', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NewsListPage()),
                    );
                  }),
                  _buildAppCard(Icons.people_rounded, '师生风采', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ColumnListPage(
                                title: '师生风采',
                                columnId: '1331',
                                firstPageUrl: 'https://www.yibinu.edu.cn/ssfc.htm',
                              )),
                    );
                  }),
                  _buildAppCard(Icons.science_rounded, '科研动态', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ColumnListPage(
                                title: '科研动态',
                                columnId: '1341',
                                firstPageUrl: 'https://www.yibinu.edu.cn/kydt.htm',
                              )),
                    );
                  }),
                  _buildAppCard(Icons.campaign_rounded, '通知公告', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ColumnListPage(
                                title: '通知公告',
                                columnId: '1361',
                                firstPageUrl: 'https://www.yibinu.edu.cn/tzgg.htm',
                              )),
                    );
                  }),
                  _buildAppCard(Icons.menu_book_rounded, '学校要闻', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ColumnListPage(
                                title: '学校要闻',
                                columnId: '1311',
                                firstPageUrl: 'https://www.yibinu.edu.cn/xxyw.htm',
                              )),
                    );
                  }),
                  _buildAppCard(Icons.mic_rounded, '宜院大讲堂', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ColumnListPage(
                                title: '宜院大讲堂',
                                columnId: '1351',
                                firstPageUrl: 'https://www.yibinu.edu.cn/yydjt.htm',
                              )),
                    );
                  }),
                  _buildAppCard(Icons.dashboard_rounded, '学术看板', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ColumnListPage(
                                title: '学术看板',
                                columnId: '1611',
                                firstPageUrl: 'https://www.yibinu.edu.cn/xskb.htm',
                              )),
                    );
                  }),
                ],
              ),
            ],
          ),
        );
      }

  Widget _buildSectionHeader(BuildContext context, IconData icon, String title) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _yibinBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _yibinBlue, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _yibinBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildAppCard(IconData icon, String title, VoidCallback onTap) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: _yibinBlue.withValues(alpha: 0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _yibinBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: _yibinBlue, size: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
