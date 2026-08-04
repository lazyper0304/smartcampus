import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/http_client.dart';
import '../core/data_cache.dart';
import '../core/guest_mode.dart';
import '../core/guest_guard.dart';
import '../course/course.dart';
import '../course/course_service.dart';
import '../course/course_page.dart';
import '../news/news.dart';
import '../news/news_service.dart';
import '../news/news_detail_page.dart';
import '../news/news_list_page.dart';
import '../core/navigation.dart';
import '../core/theme_utils.dart';
import '../core/responsive.dart';
import '../core/simple_page.dart';
import '../core/ios_kit.dart';
import '../xuegong/student_info_manager.dart';
import '../main.dart';

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
  int _currentWeek = 0;

  /// 学生姓名（用于问候语），游客或未获取到为空
  String? _studentName;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadStudentName();
  }

  Future<void> _loadStudentName() async {
    final info = await StudentInfoManager.getCached();
    if (!mounted) return;
    setState(() => _studentName = info?.name);
  }

  Future<void> _loadData() async {
    // 并行加载课程和新闻
    await Future.wait([
      _loadTodayCourses(),
      _loadNews(),
    ]);
  }

  Future<void> _loadTodayCourses() async {
    // 游客模式：课程数据需登录，直接跳过加载
    if (GuestMode.active) {
      if (mounted) setState(() => _isLoadingCourses = false);
      return;
    }
    try {
      // 复用主 client 的 cookie
      final service = CourseService(
        client: widget.client,
        userId: widget.userId,
      );
      // 先获取真实当前教学周（来自 dqzc.do），用于按周次过滤。
      // 注意：必须是「教学周次」而非「星期几」（DateTime.weekday 是 1-7）。
      int currentWeek = 0;
      try {
        currentWeek = (await service.fetchCurrentWeek()).week;
      } catch (_) {
        currentWeek = 0;
      }
      final courses = await service.fetchCourses();
      if (!mounted) return;

      final today = DateTime.now().weekday; // 1=Mon, 7=Sun
      final todayCourses = courses.where((c) {
        // 先按星期几过滤
        if (c.day != today) return false;
        // 无法确定周次时回退为只按星期过滤（避免误显示空）；
        // 否则必须命中当前教学周才显示。学期结束后的第 21 周不会命中，
        // 从而正确显示「今天没有课程」。
        if (currentWeek == 0) return true;
        return c.weeks.contains(currentWeek);
      }).toList();

      setState(() {
        _todayCourses = todayCourses;
        _currentWeek = currentWeek;
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

  /// 顶部问候语：上午好 / 下午好 / 晚上好 + 姓名
  String get _greeting {
    final hour = DateTime.now().hour;
    final base = hour < 12
        ? '早上好'
        : hour < 18
            ? '下午好'
            : '晚上好';
    if (GuestMode.active) return '欢迎使用宜院宾果';
    return _studentName != null && _studentName!.isNotEmpty
        ? '$base，$_studentName'
        : '宜院宾果';
  }

  String get _dateLabel {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final now = DateTime.now();
    return '${now.month}月${now.day}日 · 周${weekdays[now.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      // MainScreen GlassScaffold 已提供背景，不重复叠加
      background: false,
      // 透明背景：透出 GlassScaffold 的渐变+光斑（液态玻璃背景源），
      // 否则 Scaffold 默认纯色背景会盖住渐变。
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          // 底部浮动玻璃导航栏为浮层，由 ListView 的 bottom padding 统一避让。
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () {
              DataCache().invalidateAll();
              return _loadData();
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  kIosPageHPadding, 10, kIosPageHPadding,
                  bottomBarSafePadding(context)),
              children: [
                MaxWidthContent(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IosLargeTitle(
                        title: _greeting,
                        eyebrow: _dateLabel,
                      ),
                      const SizedBox(height: 10),
                      // ── 自定义常用功能（可增删 / 拖拽排序） ──
                      QuickAppsSection(
                        client: widget.client,
                        userId: widget.userId ?? '',
                      ),
                      const SizedBox(height: 8),
                      _buildTodayCoursesCard(context),
                      const SizedBox(height: 16),
                      _buildNewsCard(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayCoursesCard(BuildContext context) {
    return _FadeSlideIn(
      child: IosCard(
        onTap: () => pushPage(
          context,
          CourseTablePage(
            client: widget.client,
            userId: widget.userId,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _cardHeaderIcon(Icons.calendar_month_rounded),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('今日课程',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                ),
                Builder(builder: (context) {
                  // 右上角只显示周次（不显示星期）
                  if (_currentWeek <= 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentOf(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('第$_currentWeek周',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: accentOf(context))),
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),
            if (GuestMode.active)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          size: 40, color: textHint(context)),
                      const SizedBox(height: 8),
                      Text('游客模式下无法查看课程',
                          style: TextStyle(color: textHint(context))),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.login_rounded, size: 18),
                        label: const Text('去登录'),
                        onPressed: () => showGuestLoginDialog(
                            context, featureName: '课程表'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_isLoadingCourses)
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
                      Icon(Icons.event_busy, size: 40, color: textHint(context)),
                      const SizedBox(height: 8),
                      Text('今天没有课程',
                          style: TextStyle(color: textHint(context))),
                    ],
                  ),
                ),
              )
            else
              ...(_todayCourses!.map((c) => _buildCourseRow(c))),
          ],
        ),
      ),
    );
  }

  Widget _cardHeaderIcon(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: accentColorNotifier.value.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: accentColorNotifier.value, size: 21),
    );
  }

  Widget _buildCourseRow(Course course) {
    final blue = accentColorNotifier.value;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(kIosTileRadius),
        border: Border.all(color: blue.withValues(alpha: 0.12)),
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
                    Icon(Icons.access_time, size: 13, color: textSecondary(context)),
                    const SizedBox(width: 4),
                    Text(course.sectionRange,
                        style: TextStyle(fontSize: 12, color: textSecondary(context))),
                    const SizedBox(width: 12),
                    Icon(Icons.room, size: 13, color: textSecondary(context)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(course.position,
                          style: TextStyle(fontSize: 12, color: textSecondary(context)),
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
    return _FadeSlideIn(
      child: IosCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _cardHeaderIcon(Icons.newspaper_rounded),
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
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: accentOf(context))),
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
                      Icon(Icons.article_outlined, size: 40, color: textHint(context)),
                      const SizedBox(height: 8),
                      Text('暂无新闻',
                          style: TextStyle(color: textHint(context))),
                    ],
                  ),
                ),
              )
            else
              _buildFirstNews(context),
          ],
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
          color: accentColorNotifier.value.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(kIosTileRadius),
          border: Border.all(
              color: accentColorNotifier.value.withValues(alpha: 0.12)),
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
                          size: 12, color: textHint(context)),
                      const SizedBox(width: 4),
                      Text(news.publishDate,
                          style:
                              TextStyle(fontSize: 11, color: textHint(context))),
                      const Spacer(),
                      Icon(Icons.chevron_right,
                          size: 18, color: textHint(context)),
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
    showGlassLoadingDialog(context, message: '加载中...');

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

/// 渐显 + 上移进入动画（iOS 页面元素入场节奏）
class _FadeSlideIn extends StatelessWidget {
  final Widget child;

  const _FadeSlideIn({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
