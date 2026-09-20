import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 欢迎首屏轮播（2026-09-20 新增，同日多轮迭代）
///
/// 版式参考用户提供的设计稿：满屏校园实景图 → 上方两行大标题 + 一行副标题
/// → 底部白色圆角面板内嵌墨色胶囊按钮「开始使用 →」。
///
/// 交互：
/// - **向上拉取入场**（用户要求）：在页面上**向上拖动**即可把整屏（图 + 文字 +
///   白色面板）一起拉出屏幕，松手超过阈值或快速上滑即完成入场；也可点
///   「开始使用」直达。入场完成回调 [onStart] 就地交接给目标页（无页面跳转）。
/// - **左右自动滚动**：每 [_autoInterval] 自动切下一页，循环播放；
/// - **手动滚动**：手指左右滑动切页；拖拽期间自动播放暂停，松手 3s 后恢复；
/// - **图文逐页变化**：每页独立的背景图 + 标题 + 副标题；翻页只淡入淡出**文字**，
///   图片恒定全亮（仅轻微缩放位移），避免"图片被压暗"；
/// - 底部面板与主按钮固定不动（不随页滚动），面板内圆点指示当前页。
///
/// 路由：由 welcome_gate.dart 接入，**每次启动都会展示**。
class WelcomePage extends StatefulWidget {
  /// 入场完成回调（由 WelcomeGate 就地切换到目标页）
  final VoidCallback? onStart;

  const WelcomePage({super.key, this.onStart});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

/// 单页内容（背景图 + 两行标题 + 副标题）
class _Slide {
  final String asset;
  final String title;
  final String subtitle;
  final Alignment alignment;

  const _Slide({
    required this.asset,
    required this.title,
    required this.subtitle,
    this.alignment = const Alignment(0, -0.15),
  });
}

class _WelcomePageState extends State<WelcomePage>
    with TickerProviderStateMixin {
  /// 自动滚动间隔
  static const Duration _autoInterval = Duration(seconds: 4);
  /// 手动操作后恢复自动滚动的延迟
  static const Duration _resumeDelay = Duration(seconds: 3);
  static const Duration _pageAnim = Duration(milliseconds: 700);
  /// 上滑入场动画时长
  static const Duration _exitAnim = Duration(milliseconds: 420);
  /// 拉出比例阈值（超过即判定为"已完成拉取"，松手直接入场）
  static const double _pullThreshold = 0.16;
  /// 快速上滑的判定速度（px/s）
  static const double _pullVelocity = 620;

  static const List<_Slide> _slides = [
    _Slide(
      asset: 'assets/images/welcome_1.jpg',
      title: '百川归海\n一处相逢',
      subtitle: '课表 · 评教 · 一卡通与更多应用，汇于应用中心',
    ),
    _Slide(
      asset: 'assets/images/welcome_2.jpg',
      title: '三江汇流\n一城书香',
      subtitle: '成绩 · 考试 · 教材 · 竞赛，教务事项随手可查',
    ),
    _Slide(
      asset: 'assets/images/welcome_3.jpg',
      title: '长江首城\n学在宜院',
      subtitle: '新闻 · 通知 · 校历 · 电费，校园生活一站直达',
      alignment: Alignment(0, -0.08),
    ),
    _Slide(
      asset: 'assets/images/welcome_4.jpg',
      title: '宜院宾果\n与你同行',
      subtitle: '登录后即可同步你的课表、成绩与校园卡信息',
      alignment: Alignment(0, -0.2),
    ),
  ];

  final PageController _pc = PageController();
  Timer? _autoTimer;
  Timer? _resumeTimer;
  int _index = 0;

  /// 手势拖拽中（自动播放暂停）
  bool _dragging = false;

  /// 单页入场动画（标题/面板首次淡入）
  late final AnimationController _intro;

  /// 上滑拉出进度 0..1（1 = 整屏完全拉出屏幕）
  late final AnimationController _pull;

  /// 是否已触发入场（防重复回调）
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _pull = AnimationController(
      vsync: this,
      duration: _exitAnim,
    );
    _startAuto();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _resumeTimer?.cancel();
    _pc.dispose();
    _intro.dispose();
    _pull.dispose();
    super.dispose();
  }

  // ── 向上拉取入场 ──

  void _onPullStart(DragStartDetails _) {
    _pull.stop();
  }

  void _onPullUpdate(DragUpdateDetails d) {
    final h = MediaQuery.of(context).size.height;
    if (h <= 0) return;
    // 向上拖动（dy<0）才增加拉出进度；向下拖动可回退
    _pull.value = (_pull.value - d.delta.dy / h).clamp(0.0, 1.0);
  }

  void _onPullEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dy;
    final shouldEnter = _pull.value >= _pullThreshold || v < -_pullVelocity;
    if (shouldEnter) {
      _completeEnter();
    } else {
      _pull.animateBack(0, curve: Curves.easeOutCubic);
    }
  }

  /// 完成入场：整屏继续上滑出屏 → 回调 onStart 交接目标页
  Future<void> _completeEnter() async {
    if (_entered) return;
    _entered = true;
    _autoTimer?.cancel();
    await _pull.animateTo(1, curve: Curves.easeOutCubic);
    if (!mounted) return;
    widget.onStart?.call();
  }

  // ── 自动滚动 ──
  void _startAuto() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(_autoInterval, (_) {
      if (!mounted || _dragging || !_pc.hasClients) return;
      final next = (_index + 1) % _slides.length;
      _pc.animateToPage(next,
          duration: _pageAnim, curve: Curves.easeInOutCubic);
    });
  }

  void _pauseAuto() {
    _dragging = true;
    _resumeTimer?.cancel();
  }

  void _resumeAuto() {
    _dragging = false;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_resumeDelay, () {
      if (mounted) _startAuto();
    });
  }

  /// 文字/图片的交叉淡入：以"页偏移量"为准（0=当前页居中，1=完全滑出）
  double _fadeFor(double page) {
    final delta = (page - _index).abs().clamp(0.0, 1.0);
    return (1 - delta).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final h = MediaQuery.of(context).size.height;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 图片背景无任何压暗遮罩：4 张校园图顶部亮度 136~237（偏亮），
      // 故状态栏用**深色图标**保证可读（此前白色图标在亮天空上几乎不可见）。
      value: SystemUiOverlayStyle.dark,
      // 向上拉取：垂直拖动作用于整屏（横向滑动仍由内部 PageView 处理），
      // 整屏随手指 1:1 上移（纯位移，不做透明度衰减 —— 避免"图片被压暗"）
      child: GestureDetector(
        onVerticalDragStart: _onPullStart,
        onVerticalDragUpdate: _onPullUpdate,
        onVerticalDragEnd: _onPullEnd,
        child: AnimatedBuilder(
          animation: _pull,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, -_pull.value * (h + 80)),
            child: child,
          ),
          child: Scaffold(
            backgroundColor: const Color(0xFF0B0B0D),
            body: Stack(
              fit: StackFit.expand,
              children: [
            // ── 1. 可左右滑动的图片+文字分页 ──
            NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollStartNotification &&
                    n.dragDetails != null) {
                  _pauseAuto();
                } else if (n is ScrollEndNotification && _dragging) {
                  _resumeAuto();
                }
                return false;
              },
              child: PageView.builder(
                controller: _pc,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _buildSlide(i),
              ),
            ),

            // ── 2. 无任何压暗遮罩 ──
            // 2026-09-20：按要求"不要渐变"，且此前遮罩压暗了图片 —— 现已整体移除。
            // 可读性改由两部分保证：① 状态栏图标用深色（4 张校园图顶部亮度
            // 136~237，底色都偏亮）；② 标题/副标题自带白色描边式投影（见下）。

            // ── 3. 底部白色圆角面板（固定不动）+ 圆点 + 主按钮 ──
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _intro,
                  curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  padding: EdgeInsets.fromLTRB(22, 18, 22, bottomInset + 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDots(),
                      const SizedBox(height: 16),
                      // 点击「开始使用」= 直接完成上滑入场
                      _StartButton(onTap: _completeEnter),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  /// 单页：背景图 + 标题/副标题（按页偏移交叉淡入 + 轻微上移）
  Widget _buildSlide(int i) {
    final slide = _slides[i];
    return AnimatedBuilder(
      animation: _pc,
      builder: (context, _) {
        double page = _index.toDouble();
        if (_pc.hasClients && _pc.position.haveDimensions) {
          page = _pc.page ?? _index.toDouble();
        }
        final t = _fadeFor(page);
        return Stack(
          fit: StackFit.expand,
          children: [
            // 背景图：**始终全亮**（2026-09-20 修复"图片被压暗"——原先按页偏移
            // 做透明度交叉淡化，非当前页被压到 35%，过渡中当前页也一起变暗）；
            // 现在翻页只淡入淡出文字，图片仅保留轻微缩放位移作为动效。
            Transform.scale(
              scale: 1.04 - 0.04 * t,
              child: Image.asset(
                slide.asset,
                fit: BoxFit.cover,
                alignment: slide.alignment,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Color(0xFF1B2436),
                ),
              ),
            ),
            // 标题区（左对齐，距顶约 17% 屏高）
            Positioned(
              left: 24,
              right: 24,
              top: MediaQuery.of(context).size.height * 0.17,
              child: Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 18 * (1 - t)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slide.title,
                        style: const TextStyle(
                          fontSize: 36,
                          height: 1.24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1.5,
                          // 无压暗遮罩 → 用"紧贴投影 + 柔化投影"两层保证白字可读
                          shadows: [
                            Shadow(
                              color: Color(0xCC000000),
                              blurRadius: 6,
                              offset: Offset(0, 1),
                            ),
                            Shadow(
                              color: Color(0x8A000000),
                              blurRadius: 20,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        slide.subtitle,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: Colors.white.withValues(alpha: 0.94),
                          letterSpacing: 0.4,
                          shadows: const [
                            Shadow(
                              color: Color(0xCC000000),
                              blurRadius: 5,
                              offset: Offset(0, 1),
                            ),
                            Shadow(color: Color(0x73000000), blurRadius: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 页指示圆点（当前页加宽为墨色胶囊）
  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _slides.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _index ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == _index
                  ? const Color(0xFF111114)
                  : const Color(0xFF111114).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

/// 墨色胶囊按钮「开始使用 →」（白底面板上的主行动点）
class _StartButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _StartButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF111114),
      borderRadius: BorderRadius.circular(29),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(29),
        child: const SizedBox(
          height: 58,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '开始使用',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(width: 10),
              Icon(
                Icons.arrow_forward_rounded,
                size: 20,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
