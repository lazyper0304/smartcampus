import 'package:flutter/material.dart';

import '../core/http_client.dart';
import '../course/course_page.dart';
import '../exam/exam_page.dart';
import '../grade/score_page.dart';
import '../graduation/graduation_page.dart';
import '../plan/plan_page.dart';
import '../profile/profile_page.dart';

/// 主页面 - 底部导航栏
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
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Tab 0 - 首页（课程表）
          CourseTablePage(
            client: widget.client,
            userId: widget.userId,
          ),
          // Tab 1 - 应用
          _AppsPage(
            client: widget.client,
            userId: widget.userId,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apps),
            label: '应用',
          ),
        ],
      ),
    );
  }
}

/// 应用页 - 功能入口网格
class _AppsPage extends StatelessWidget {
  final SharedHttpClient client;
  final String userId;

  const _AppsPage({
    required this.client,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('宜宾学院智慧校园'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.person),
          tooltip: '个人中心',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfilePage(
                  client: client,
                  userId: userId,
                ),
              ),
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.school,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '宜宾学院',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '智慧校园',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _appCard(
                    context,
                    icon: Icons.assessment,
                    title: '成绩查询',
                    color: const Color(0xFF27AE60),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ScorePage(
                                  client: client,
                                  userId: userId,
                                )),
                      );
                    },
                  ),
                  _appCard(
                    context,
                    icon: Icons.event_note,
                    title: '考试安排',
                    color: const Color(0xFFE67E22),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ExamPage(
                                  client: client,
                                )),
                      );
                    },
                  ),
                  _appCard(
                    context,
                    icon: Icons.account_tree,
                    title: '培养方案',
                    color: const Color(0xFF2980B9),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PlanPage(
                                  client: client,
                                )),
                      );
                    },
                  ),
                  _appCard(
                    context,
                    icon: Icons.auto_stories,
                    title: '学业完成',
                    color: const Color(0xFF8E44AD),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => GraduationPage(
                                  client: client,
                                )),
                      );
                    },
                  ),
                  _appCard(
                    context,
                    icon: Icons.person,
                    title: '个人中心',
                    color: const Color(0xFF1A73E8),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ProfilePage(
                                  client: client,
                                  userId: userId,
                                )),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
