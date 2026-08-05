import 'package:flutter/material.dart';

import '../core/http_client.dart';
import '../core/theme_utils.dart';
import '../core/glass_action_button.dart';
import '../core/simple_page.dart';
import '../main.dart';
import 'kccx.dart';
import 'kccx_service.dart';

/// 课程详情页
///
/// 按课程号 KCH 调用 kccx 详情接口（initKcdg.do）获取完整课程信息。
class KccxDetailPage extends StatefulWidget {
  final SharedHttpClient client;
  final String kch;
  final String initialTitle;

  const KccxDetailPage({
    super.key,
    required this.client,
    required this.kch,
    this.initialTitle = '课程详情',
  });

  @override
  State<KccxDetailPage> createState() => _KccxDetailPageState();
}

class _KccxDetailPageState extends State<KccxDetailPage> {
  late final KccxService _service;
  KccxCourse? _course;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = KccxService(client: widget.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final course = await _service.fetchCourseDetail(widget.kch);
      if (!mounted) return;
      setState(() {
        _course = course;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _course?.kcm.isNotEmpty == true
                ? (_course!.kcm.length > 15
                    ? '${_course!.kcm.substring(0, 15)}…'
                    : _course!.kcm)
                : widget.initialTitle,
          ),
          centerTitle: true,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Colors.red),
              const SizedBox(height: 12),
              Text('加载失败',
                  style: TextStyle(fontSize: 16, color: textHint(context))),
              const SizedBox(height: 8),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: textHint(context))),
              const SizedBox(height: 16),
              GlassActionButton(
                label: '重试',
                icon: Icons.refresh,
                onPressed: _load,
                secondary: true,
                fullWidth: false,
              ),
            ],
          ),
        ),
      );
    }
    final c = _course!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _buildHeaderCard(c),
        const SizedBox(height: 12),
        _buildInfoCard('基本信息', [
          ('课程名', c.kcm),
          ('课程号', c.kch),
          ('学分', c.xfText),
          ('总学时', c.xsText),
          ('课程状态', c.kcztdmDisplay),
        ]),
        const SizedBox(height: 12),
        _buildInfoCard('单位信息', [
          ('开课单位', c.kkdwDisplay),
          ('课程类别', c.kcfldmDisplay),
          ('课程分类', c.kcfl1Display),
          ('课程层次', c.kcccdmDisplay),
          ('课程水平', c.kcspDisplay),
          ('课程版本', c.kcbbDisplay),
          ('课程级别', c.kcjbDisplay),
          ('系室', c.jysDisplay),
          ('负责人', c.kcfzr),
        ]),
        const SizedBox(height: 12),
        _buildInfoCard('教学信息', [
          ('教学方式', c.jxfsDisplay),
          ('授课语种', c.skyzDisplay),
          ('考试类型', c.kslxDisplay),
          ('课内周学时', _numText(c.knzxs)),
          ('课堂讲授学时', _numText(c.ktjsxs)),
          ('实验学时', _numText(c.syxs)),
          ('上机学时', _numText(c.sjxs)),
          ('课程实践学时', _numText(c.kcsjxs)),
          ('适用院系或专业', c.syyxDisplay),
          ('适用范围', c.syfwDisplay),
        ]),
        if (c.ywkcm.isNotEmpty || c.bz.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildInfoCard('其他', [
            if (c.ywkcm.isNotEmpty) ('英文课程名', c.ywkcm),
            if (c.bz.isNotEmpty) ('备注', c.bz),
          ]),
        ],
      ],
    );
  }

  /// 头部卡片：课程名 + 课程号 + 学分/学时
  Widget _buildHeaderCard(KccxCourse c) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: dividerColor(context), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(c.kcm,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColorNotifier.value.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(c.kcztdmDisplay.isEmpty ? '启用' : c.kcztdmDisplay,
                      style: TextStyle(
                          fontSize: 12,
                          color: accentColorNotifier.value,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (c.kch.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.tag_rounded,
                      size: 14, color: textHint(context)),
                  const SizedBox(width: 4),
                  Text(c.kch,
                      style: TextStyle(
                          fontSize: 12,
                          color: textHint(context),
                          fontFamily: 'monospace')),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip(Icons.stars_rounded, c.xfText),
                const SizedBox(width: 8),
                _chip(Icons.schedule_rounded, c.xsText),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accentColorNotifier.value.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accentColorNotifier.value),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 12, color: accentColorNotifier.value)),
        ],
      ),
    );
  }

  /// 信息卡片：label-value 行
  Widget _buildInfoCard(String title, List<(String, String)> entries) {
    final valid = entries
        .where((e) => e.$2.isNotEmpty)
        .toList();
    if (valid.isEmpty) return const SizedBox.shrink();
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: dividerColor(context), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: accentColorNotifier.value,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            for (final e in valid)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(e.$1,
                          style: TextStyle(
                              fontSize: 13, color: textHint(context))),
                    ),
                    Expanded(
                      child: Text(e.$2,
                          style: const TextStyle(
                              fontSize: 13, height: 1.4)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _numText(double v) {
    if (v == 0) return '';
    return v == v.truncateToDouble() ? '${v.toInt()} 学时' : '$v 学时';
  }
}
