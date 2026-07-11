import 'package:flutter/material.dart';
import 'package:cue/cue.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/http_client.dart';
import '../course/course_page.dart';
import '../grade/score_page.dart';
import '../exam/exam_page.dart';
import '../graduation/graduation_page.dart';
import '../calendar/calendar_page.dart';
import '../news/news_list_page.dart';
import '../settings/settings_page.dart';
import '../core/navigation.dart';

const Color _yibinBlue = Color.fromRGBO(25, 25, 153, 1);

class HomePage extends StatelessWidget {
  final SharedHttpClient client;
  final String userId;

  const HomePage({
    super.key,
    required this.client,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: GlassAppBar(
          title: const Text('宜院宾果'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            const SizedBox(height: 8),
            _buildMenuCard(
              context,
              icon: Icons.calendar_month_rounded,
              title: '课程表',
              subtitle: '查看本学期课程安排',
              onTap: () => pushPage(context, CourseTablePage(client: client, userId: userId)),
            ),
            const SizedBox(height: 14),
            _buildMenuCard(
              context,
              icon: Icons.assessment_rounded,
              title: '成绩查询',
              subtitle: '查看各学期课程成绩',
              onTap: () => pushPage(context, ScorePage(client: client, userId: userId)),
            ),
            const SizedBox(height: 14),
            _buildMenuCard(
              context,
              icon: Icons.event_note_rounded,
              title: '考试安排',
              subtitle: '查看期末考试时间地点',
              onTap: () => pushPage(context, ExamPage(client: client)),
            ),
            const SizedBox(height: 14),
            _buildMenuCard(
              context,
              icon: Icons.auto_stories_rounded,
              title: '学业完成',
              subtitle: '查看毕业要求完成进度',
              onTap: () => pushPage(context, GraduationPage(client: client)),
            ),
            const SizedBox(height: 14),
            _buildMenuCard(
              context,
              icon: Icons.newspaper_rounded,
              title: '校园新闻',
              subtitle: '查看最新新闻动态',
              onTap: () => pushPage(context, const NewsListPage()),
            ),
            const SizedBox(height: 14),
            _buildMenuCard(
              context,
              icon: Icons.calendar_view_month_rounded,
              title: '校历服务',
              subtitle: '查看学年校历与放假安排',
              onTap: () => pushPage(context, const CalendarPage()),
            ),
            const SizedBox(height: 14),
            _buildMenuCard(
              context,
              icon: Icons.settings_rounded,
              title: '设置',
              subtitle: '退出登录与应用信息',
              onTap: () => pushPage(context, const SettingsPage()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Cue.onMount(
      motion: .smooth(),
      acts: [.fadeIn(), .slideY(from: 0.08)],
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: _yibinBlue.withValues(alpha: 0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _yibinBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: _yibinBlue, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[500])),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: _yibinBlue.withValues(alpha: 0.3), size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
