import 'package:flutter/material.dart';

import '../core/http_client.dart';
import '../core/theme_utils.dart';
import '../core/simple_page.dart';
import '../core/ios_kit.dart';
import '../core/glass_filter_chip.dart';
import '../core/glass_action_button.dart';
import '../main.dart';
import 'wspj.dart';
import 'wspj_service.dart';

/// 网上评教页面
///
/// 数据来自 ehall jwapp「网上评教」（jwwspj 模块，appId=5077744448763966）：
/// - 顶部信息卡：当前评教学期 + 评教时间窗口（cxcssz.do 系统参数）
/// - 学年学期切换（xnxqcx.do）
/// - 学生评教问卷列表（cxxspjwjlb.do），点击卡片查看问卷说明
class WspjPage extends StatefulWidget {
  final SharedHttpClient client;
  final String userId;

  const WspjPage({super.key, required this.client, required this.userId});

  @override
  State<WspjPage> createState() => _WspjPageState();
}

class _WspjPageState extends State<WspjPage> {
  late final WspjService _service;

  // ---- 数据 ----
  List<WspjConfigItem> _configs = [];
  List<WspjSemester> _semesters = [];
  List<WspjQuestionnaire> _questionnaires = [];
  String _xnxqdm = '';
  bool _isLoading = true;
  String? _error;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _service = WspjService(client: widget.client);
    _loadAll();
  }

  // ==================== 数据加载 ====================

  /// 首次进入 / 下拉刷新：拉系统参数 + 学年学期 + 问卷列表
  Future<void> _loadAll() async {
    if (!_refreshing) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      // 1. 系统参数（当前评教学期 + 时间窗口）
      final configs = await _service.fetchConfig();
      // 2. 学年学期列表
      final semesters = await _service.fetchSemesters();
      if (!mounted) return;
      // 默认学期：优先取系统参数 PJXNXQ，其次学期列表第一项
      var xnxq = _configValue(configs, 'PJXNXQ');
      if (xnxq.isEmpty && semesters.isNotEmpty) {
        xnxq = semesters.first.dm;
      }
      // 3. 学生评教问卷列表
      final questionnaires = await _service.fetchQuestionnaires(
        cpr: widget.userId,
        xnxqdm: xnxq,
      );
      if (!mounted) return;
      setState(() {
        _configs = configs;
        _semesters = semesters;
        _xnxqdm = xnxq;
        _questionnaires = questionnaires;
        _isLoading = false;
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
        _refreshing = false;
      });
    }
  }

  /// 切换学年学期后仅重新拉问卷列表
  Future<void> _switchSemester(String dm) async {
    if (dm == _xnxqdm) return;
    setState(() {
      _xnxqdm = dm;
      _questionnaires = [];
      _isLoading = true;
    });
    try {
      final questionnaires = await _service.fetchQuestionnaires(
        cpr: widget.userId,
        xnxqdm: dm,
      );
      if (!mounted) return;
      setState(() {
        _questionnaires = questionnaires;
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

  /// 从系统参数列表取指定代码的参数值
  String _configValue(List<WspjConfigItem> configs, String zcsdm) {
    for (final c in configs) {
      if (c.zcsdm == zcsdm) return c.csza;
    }
    return '';
  }

  String get _startTime => _configValue(_configs, 'PJKSSJ');
  String get _endTime => _configValue(_configs, 'PJJSSJ');
  String get _sfsy => _configValue(_configs, 'SFSY');

  /// 评教状态：进行中 / 未开始 / 已结束 / 未启用
  String get _periodStatus {
    if (_sfsy != '1') return '未启用';
    final now = DateTime.now();
    final start = DateTime.tryParse(_startTime);
    final end = DateTime.tryParse(_endTime);
    if (start == null || end == null) return '评教设置中';
    if (now.isBefore(start)) return '未开始';
    if (now.isAfter(end)) return '已结束';
    return '进行中';
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('网上评教'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _loadAll,
              tooltip: '刷新',
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _questionnaires.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _questionnaires.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 56, color: accentColorNotifier.value),
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
                onPressed: _loadAll,
                secondary: true,
                fullWidth: false,
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _buildInfoCard(),
          if (_semesters.length > 1) ...[
            const SizedBox(height: 18),
            _buildSemesterSelector(),
          ],
          const SizedBox(height: 18),
          _buildSectionTitle(),
          const SizedBox(height: 10),
          ..._buildQuestionnaireList(),
        ],
      ),
    );
  }

  // ==================== 信息卡 ====================

  Widget _buildInfoCard() {
    final status = _periodStatus;
    final statusColor = status == '进行中'
        ? accentColorNotifier.value
        : const Color(0xFFC2410C);
    final xnq = _configValue(_configs, 'PJXNXQ');
    return IosCard(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accentColorNotifier.value.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.rate_review_rounded,
                    color: accentColorNotifier.value, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('评教时间窗口',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(status,
                    style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow('评教学期', xnq.isEmpty ? '—' : xnq),
          const SizedBox(height: 6),
          _infoRow('开始时间', _startTime.isEmpty ? '—' : _startTime),
          const SizedBox(height: 6),
          _infoRow('结束时间', _endTime.isEmpty ? '—' : _endTime),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(label,
              style:
                  TextStyle(fontSize: 13, color: textSecondary(context))),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 13,
                  color: textPrimary(context),
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  // ==================== 学年学期切换 ====================

  Widget _buildSemesterSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in _semesters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GlassFilterChip(
                label: s.mc,
                selected: _xnxqdm == s.dm,
                onTap: () => _switchSemester(s.dm),
                radius: 14,
              ),
            ),
        ],
      ),
    );
  }

  // ==================== 问卷列表 ====================

  Widget _buildSectionTitle() {
    return Row(
      children: [
        const Expanded(
          child: Text('学生评教问卷',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        Text('共 ${_questionnaires.length} 份',
            style: TextStyle(fontSize: 12, color: textHint(context))),
      ],
    );
  }

  List<Widget> _buildQuestionnaireList() {
    if (_isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ];
    }
    if (_error != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text('加载失败：$_error',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: textHint(context))),
          ),
        ),
      ];
    }
    if (_questionnaires.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Icon(Icons.task_alt_rounded,
                  size: 56,
                  color: textHint(context).withValues(alpha: 0.6)),
              const SizedBox(height: 12),
              Text('当前学期暂无待评教问卷',
                  style: TextStyle(fontSize: 14, color: textHint(context))),
              const SizedBox(height: 4),
              Text('或评教时间窗口已关闭',
                  style: TextStyle(fontSize: 12, color: textHint(context))),
            ],
          ),
        ),
      ];
    }
    return [for (final q in _questionnaires) _buildQuestionnaireCard(q)];
  }

  Widget _buildQuestionnaireCard(WspjQuestionnaire q) {
    final done = q.isDone;
    final statusColor =
        done ? accentColorNotifier.value : const Color(0xFFC2410C);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: IosCard(
        padding: const EdgeInsets.all(14),
        onTap: () => _showQuestionnaireDetail(q),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(q.wjmc,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(done ? '已完成' : '待评教',
                      style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _tag('${q.zfz} 分'),
                if (q.pglxDisplay.isNotEmpty) _tag(q.pglxDisplay),
                if (q.pglbDisplay.isNotEmpty && q.pglbDisplay != q.pglxDisplay)
                  _tag(q.pglbDisplay),
              ],
            ),
            if (q.wjsm.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(q.wjsm,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: textSecondary(context))),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(q.xnxqDisplay.isEmpty ? q.xnxqdm : q.xnxqDisplay,
                      style:
                          TextStyle(fontSize: 12, color: textHint(context))),
                ),
                Text('查看说明',
                    style: TextStyle(
                        fontSize: 12,
                        color: accentColorNotifier.value,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: accentColorNotifier.value.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              color: accentColorNotifier.value,
              fontWeight: FontWeight.w600)),
    );
  }

  // ==================== 问卷说明弹窗 ====================

  void _showQuestionnaireDetail(WspjQuestionnaire q) {
    final done = q.isDone;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: glassDialog(
          context: ctx,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(q.wjmc,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: textSecondary(ctx)),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _tag('${q.zfz} 分'),
                    _tag(done ? '已完成' : '待评教'),
                    if (q.pglxDisplay.isNotEmpty) _tag(q.pglxDisplay),
                  ],
                ),
                const SizedBox(height: 12),
                if (q.wjsm.isNotEmpty)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.4,
                    ),
                    child: SingleChildScrollView(
                      child: Text(q.wjsm,
                          style: TextStyle(
                              fontSize: 13,
                              height: 1.6,
                              color: textPrimary(ctx))),
                    ),
                  )
                else
                  Text('该问卷暂无说明',
                      style: TextStyle(
                          fontSize: 13, color: textHint(ctx))),
                const SizedBox(height: 16),
                GlassActionButton(
                  label: done ? '好的' : '知道了',
                  onPressed: () => Navigator.of(ctx).pop(),
                  secondary: true,
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
