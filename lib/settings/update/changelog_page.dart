import 'package:flutter/material.dart';

import '../../core/ios_kit.dart';
import '../../core/responsive.dart';
import '../../core/simple_page.dart';
import '../../core/theme_utils.dart';
import 'update_models.dart';
import 'update_service.dart';

/// 更新日志独立页面（替代弹窗）：iOS 大标题 + 静态玻璃版本卡片列表，
/// 自带 加载中 / 失败重试 / 空 / 列表 四态。
class ChangelogPage extends StatefulWidget {
  const ChangelogPage({super.key});

  @override
  State<ChangelogPage> createState() => _ChangelogPageState();
}

class _ChangelogPageState extends State<ChangelogPage> {
  List<ReleaseInfo>? _releases;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final releases = await UpdateService.fetchReleases();
      if (mounted) {
        setState(() {
          _releases = releases;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = '加载失败，请检查网络后重试';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // 顶部标题参考隐私协议页：AppBar 导航栏标题（非大标题）
        appBar: AppBar(title: const Text('更新日志')),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
                kIosPageHPadding, 10, kIosPageHPadding,
                bottomBarSafePadding(context)),
            children: [
              MaxWidthContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 80),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_error != null)
                        _buildError()
                      else if (_releases == null || _releases!.isEmpty)
                        _buildEmpty()
                      else
                        ..._releases!.map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildReleaseCard(r),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ),
    );
  }

  /// 单个版本卡片（静态玻璃，与主界面同款）
  Widget _buildReleaseCard(ReleaseInfo r) {
    final date =
        r.publishedAt.length >= 10 ? r.publishedAt.substring(0, 10) : '';
    return IosCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accentOf(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  r.tagName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accentOf(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (date.isNotEmpty)
                Text(date,
                    style:
                        TextStyle(fontSize: 11, color: textHint(context))),
            ],
          ),
          const SizedBox(height: 10),
          Text(r.body, style: const TextStyle(fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded, size: 40, color: textHint(context)),
          const SizedBox(height: 12),
          Text(_error!,
              style: TextStyle(fontSize: 13, color: textHint(context))),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('重试'),
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Text('暂无更新记录',
            style: TextStyle(fontSize: 13, color: textHint(context))),
      ),
    );
  }
}
