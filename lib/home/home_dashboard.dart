import 'package:flutter/material.dart';
import 'package:cue/cue.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/http_client.dart';
import '../core/data_cache.dart';
import '../course/course.dart';
import '../course/course_service.dart';
import '../course/course_page.dart';
import '../news/news.dart';
import '../news/news_service.dart';
import '../news/news_detail_page.dart';
import '../news/news_list_page.dart';
import '../core/navigation.dart';

class HomeDashboard extends StatefulWidget {
  final SharedHttpClient client;
  final String? userId;

  const HomeDashboard({
    super.key,
    required this.client,
    this.userId,
  });

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final NewsService _newsService = NewsService();

  List<Course>? _todayCourses;
  List<NewsItem>? _newsItems;
  bool _isLoadingCourses = true;
  bool _isLoadingNews = true;
  int _todayWeek = 0;

  @override
  void initState() {
    super.initState();
    _todayWeek = DateTime.now().weekday;
    _loadData();
  }

  Future<void> _loadData() async {
    // 并行加载课程和新闻
    await Future.wait([
      _loadTodayCourses(),
      _loadNews(),
    ]);
  }

  Future<void> _loadTodayCourses() async {
    try {
      // 复用主 client 的 cookie
      final service = CourseService(
        client: widget.client,
        userId: widget.userId,
      );
      final courses = await service.fetchCourses();
      if (!mounted) return;

      final today = DateTime.now().weekday; // 1=Mon, 7=Sun
      final todayCourses =
          courses.where((c) => c.day == today && c.weeks.contains(_todayWeek)).toList();

      setState(() {
        _todayCourses = todayCourses;
        _isLoadingCourses = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingCourses = false);
    }
  }

  Future<void> _loadNews() async {
    try {
      final result = await _newsService.fetchNewsPage();
      if (!mounted) return;
      setState(() {
        _newsItems = result.items.take(1).toList();
        _isLoadingNews = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingNews = false);
    }
  }

  @override
  void dispose() {
    _newsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () { DataCache().invalidateAll(); return _loadData(); },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _buildTodayCoursesCard(context),
                const SizedBox(height: 16),
                _buildNewsCard(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayCoursesCard(BuildContext context) {
    return Cue.onMount(
      motion: .smooth(),
      acts: [.fadeIn(), .slideY(from: 0.08)],
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(25, 25, 153, 1).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calendar_month_rounded,
                        color: Color.fromRGBO(25, 25, 153, 1), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('今日课程',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                  Text('周${['', '一', '二', '三', '四', '五', '六', '日'][DateTime.now().weekday]}',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[500])),
                ],
              ),
              const SizedBox(height: 16),
              if (_isLoadingCourses)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_todayCourses == null || _todayCourses!.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.event_busy, size: 40, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('今天没有课程',
                            style: TextStyle(color: Colors.grey[400])),
                      ],
                    ),
                  ),
                )
              else
                ...(_todayCourses!.map((c) => _buildCourseRow(c))),
              if (_todayCourses != null && _todayCourses!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('查看完整课表',
                          style: TextStyle(fontSize: 13)),
                      onPressed: () => pushPage(
                        context,
                        CourseTablePage(
                          client: widget.client,
                          userId: widget.userId,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseRow(Course course) {
    const blue = Color.fromRGBO(25, 25, 153, 1);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: blue.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: blue.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: blue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(course.sectionRange,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    const SizedBox(width: 12),
                    Icon(Icons.room, size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(course.position,
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsCard(BuildContext context) {
    return Cue.onMount(
      motion: .smooth(),
      acts: [.fadeIn(), .slideY(from: 0.08)],
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(25, 25, 153, 1).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.newspaper_rounded,
                        color: Color.fromRGBO(25, 25, 153, 1), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('校园新闻',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                  GestureDetector(
                    onTap: () => pushPage(context, const NewsListPage()),
                    child: Text('查看全部 ›',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[500])),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isLoadingNews)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_newsItems == null || _newsItems!.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.article_outlined, size: 40, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('暂无新闻',
                            style: TextStyle(color: Colors.grey[400])),
                      ],
                    ),
                  ),
                )
              else
                _buildFirstNews(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFirstNews(BuildContext context) {
    final news = _newsItems!.first;
    return GestureDetector(
      onTap: () => _openNewsDetail(news),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(25, 25, 153, 1).withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color.fromRGBO(25, 25, 153, 1).withValues(alpha: 0.1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    news.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(news.publishDate,
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[400])),
                      const Spacer(),
                      Icon(Icons.chevron_right,
                          size: 18, color: Colors.grey[400]),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openNewsDetail(NewsItem news) async {
    // 显示加载
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('加载中...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final detail = await _newsService.fetchNewsDetail(news.url);
      if (!mounted) return;
      Navigator.of(context).pop();

      pushPage(context, NewsDetailPage(detail: detail));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载失败: $e')),
      );
    }
  }
}
