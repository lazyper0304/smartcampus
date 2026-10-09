import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smooth_dropdown/smooth_dropdown.dart';

import '../core/bingo/bingo_client.dart';
import '../core/glass_action_button.dart';
import '../core/navigation.dart';
import '../core/simple_page.dart';
import '../core/smooth_styles.dart';
import '../core/theme_utils.dart';
import '../auth/login_page.dart';
import '../main.dart';
import 'erke_models.dart';
import 'erke_service.dart';

/// 第二课堂主页。
///
/// 数据源为 Bingo 后端 `/erke/*`，复用双下放登录下发的 Bearer凭证，
/// 因此不再需要 erke 独立的账号密码登录（该站仅校园内网可访问）。
class ErkePage extends StatefulWidget {
  const ErkePage({super.key});

  @override
  State<ErkePage> createState() => _ErkePageState();
}

class _ErkePageState extends State<ErkePage> {
  bool _loading = true;
  bool _needsLogin = false;
  String? _error;
  ErkeTranscript? _data;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });

    // 数据源为 Bingo 后端，复用双下放登录的凭证；
    // 未登录时走全局登录守卫（与其它模块一致），不再有独立登录页。
    if (!BingoClient.isLoggedIn) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _needsLogin = true;
      });
      return;
    }

    try {
      final data = await ErkeService.instance.fetchTranscript();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _needsLogin = false;
      });
    } on BingoException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  /// 未登录时引导至全局登录页（与其它模块一致的统一登录入口）
  void _openLogin() {
    replacePage(context, const LoginPage());
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('第二课堂'),
          centerTitle: true,
          actions: [
            if (!_loading && !_needsLogin)
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: '刷新',
                onPressed: _init,
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_needsLogin) return _buildLoginCta();
    if (_error != null) return _buildError();
    return _buildContent();
  }

  Widget _buildLoginCta() {
    final accent = accentColorNotifier.value;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.assignment_ind_rounded,
                  color: accent, size: 36),
            ),
            const SizedBox(height: 20),
            Text('未登录第二课堂',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('该账号与智慧校园相互独立，请使用第二课堂账号密码登录',
                style: TextStyle(fontSize: 13, color: textSecondary(context)),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            // 登录按钮：玻璃操作按钮（GlassActionButton）
            GlassActionButton(
              label: '登录第二课堂',
              icon: Icons.login_rounded,
              onPressed: _openLogin,
              fullWidth: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: textHint(context)),
            const SizedBox(height: 16),
            Text('加载失败',
                style: TextStyle(fontSize: 16, color: textPrimary(context))),
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(fontSize: 12, color: textSecondary(context)),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            GlassActionButton(
              label: '重试',
              icon: Icons.refresh,
              onPressed: _init,
              secondary: true,
              fullWidth: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final d = _data!;
    final accent = accentColorNotifier.value;
    return RefreshIndicator(
      onRefresh: _init,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          // 学生信息卡
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: accent.withValues(alpha: 0.08)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.person_rounded,
                            color: accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.profile.nickName,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                                '${d.profile.unitName} · ${d.profile.classNo}',
                                style: TextStyle(
                                    fontSize: 13, color: textSecondary(context))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            Text(d.totalScore.toStringAsFixed(1),
                                style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: accent)),
                            const SizedBox(height: 2),
                            Text('第二课堂学分',
                                style: TextStyle(
                                    fontSize: 12, color: textHint(context))),
                          ],
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          margin: const EdgeInsets.symmetric(horizontal: 28),
                          color: accent.withValues(alpha: 0.15),
                        ),
                        Column(
                          children: [
                            Text('${d.items.length}',
                                style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: accent)),
                            const SizedBox(height: 2),
                            Text('活动记录',
                                style: TextStyle(
                                    fontSize: 12, color: textHint(context))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 分类学分
          Text('分类学分',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textPrimary(context))),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.0,
            children: d.report
                .map((r) => _reportCard(r, accent))
                .toList(),
          ),
          const SizedBox(height: 16),
          // 活动明细（按分类折叠）
          Text('活动明细',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textPrimary(context))),
          const SizedBox(height: 10),
          for (final entry in d.groupedByType.entries) ...[
            _buildTypeTile(entry.key, entry.value, accent),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _reportCard(ErkeReportItem r, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(r.name,
              style: TextStyle(fontSize: 12, color: textSecondary(context)),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          // 分数随格子宽度自适应缩放，避免长数字溢出容器
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(r.value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTile(
      String type, List<ErkeTranscriptItem> items, Color accent) {
    final sum = items.fold<double>(
        0, (s, e) => s + (double.tryParse(e.score) ?? 0));
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: accent, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(type,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          Text('$sum 分 · ${items.length}项',
              style: TextStyle(fontSize: 12, color: textHint(context))),
        ],
      ),
    );
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accent.withValues(alpha: 0.08)),
      ),
      child: SmoothExpansionTile(
        initiallyExpanded: false,
        // 玻璃化：背景同色填充（公共 smoothGlassStyle）
        style: smoothGlassStyle(context),
        headerBuilder: (ctx, expand, controller) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => controller.toggle(),
          child: header,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1, indent: 16, endIndent: 16),
            for (final it in items) _buildItemRow(it),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(ErkeTranscriptItem it) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.itemName,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(it.itemTime,
                    style: TextStyle(
                        fontSize: 11, color: textHint(context))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accentColorNotifier.value.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${it.score} 分',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accentColorNotifier.value)),
          ),
        ],
      ),
    );
  }
}
