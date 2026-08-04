import 'package:flutter/material.dart';

import '../core/http_client.dart';
import '../core/theme_utils.dart';
import '../core/simple_page.dart';
import '../main.dart';
import 'qxfacx.dart';
import 'qxfacx_service.dart';

/// 培养方案详情页
///
/// - 方案基本信息/培养目标等来自列表接口（[QxFacxPlan] 已含全字段，无需二次请求）
/// - 「课程设置」区通过 `kzcx.do`（课程组）+ `kzkccx.do`（课组课程）加载，
///   按 FKZH↔KZH 构建课程组树，点击组展开/收起组内课程
class QxFacxDetailPage extends StatefulWidget {
  final SharedHttpClient client;
  final QxFacxPlan plan;

  const QxFacxDetailPage({
    super.key,
    required this.client,
    required this.plan,
  });

  @override
  State<QxFacxDetailPage> createState() => _QxFacxDetailPageState();
}

class _QxFacxDetailPageState extends State<QxFacxDetailPage> {
  late final QxFacxService _service;

  List<QxFacxKz> _kzList = [];
  Map<String, List<QxFacxKzCourse>> _coursesByKzh = {};
  bool _loadingGroups = true;
  String? _groupsError;

  /// 已展开的课组号（点击组标题切换）
  final Set<String> _expanded = {};

  QxFacxPlan get plan => widget.plan;

  @override
  void initState() {
    super.initState();
    _service = QxFacxService(client: widget.client);
    _loadGroups();
  }

  /// 并行加载课程组 + 课组课程
  Future<void> _loadGroups() async {
    setState(() {
      _loadingGroups = true;
      _groupsError = null;
    });
    try {
      final results = await Future.wait([
        _service.fetchKzcx(plan.pyfadm),
        _service.fetchKzkccx(plan.pyfadm),
      ]);
      if (!mounted) return;
      final kzList = results[0] as List<QxFacxKz>;
      final courseList = results[1] as List<QxFacxKzCourse>;

      // 课程按所属课组号分组
      final byKzh = <String, List<QxFacxKzCourse>>{};
      for (final c in courseList) {
        byKzh.putIfAbsent(c.kzh, () => []).add(c);
      }
      // 默认展开顶级平台（FKZH=-1）
      final topIds = kzList.where((g) => g.isTop).map((g) => g.kzh).toSet();
      setState(() {
        _kzList = kzList;
        _coursesByKzh = byKzh;
        _expanded.addAll(topIds);
        _loadingGroups = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _groupsError = e.toString().replaceFirst('Exception: ', '');
        _loadingGroups = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            plan.name.length > 15
                ? '${plan.name.substring(0, 15)}…'
                : plan.name,
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _buildHeaderCard(context),
            const SizedBox(height: 12),
            _buildInfoCard(context, '基本信息', [
              ('方案代码', plan.pyfadm),
              ('年级', plan.njdDisplay.isNotEmpty ? plan.njdDisplay : plan.njd),
              ('院系', plan.dwdmDisplay),
              ('专业', plan.zydmDisplay),
              ('专业方向', plan.zyfxdDisplay),
              ('修读类型', plan.xdlxdmDisplay),
              ('学期类型', plan.xqlxdmDisplay),
              ('学制', plan.xznx > 0 ? '${plan.xznx} 年' : ''),
              ('学位', plan.xwdmDisplay),
              ('开始学年', plan.ksxndmDisplay),
              ('开始学期', plan.ksxqdmDisplay),
              ('最少要求学分',
                  plan.zsyqxf > 0 ? '${_numText(plan.zsyqxf)} 学分' : ''),
            ]),
            if (plan.pymbText.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildTextCard(context, '培养目标', plan.pymbText),
            ],
            if (plan.xdyqText.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildTextCard(context, '修读要求', plan.xdyqText),
            ],
            if (plan.zgxkText.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildTextCard(context, '主干学科', plan.zgxkText),
            ],
            if (plan.zgkcText.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildTextCard(context, '主干课程', plan.zgkcText),
            ],
            if (plan.zyzysyText.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildTextCard(context, '主要专业实验', plan.zyzysyText),
            ],
            if (plan.fatsText.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildTextCard(context, '方案特色', plan.fatsText),
            ],
            const SizedBox(height: 12),
            _buildGroupsCard(context),
            if (plan.shyj.isNotEmpty ||
                plan.czrxm.isNotEmpty ||
                plan.czsj.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoCard(context, '审核信息', [
                ('审核意见', plan.shyj),
                ('操作人', plan.czrxm),
                ('操作时间', plan.czsj),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== 课程设置（课程组树 + 组内课程） ====================

  Widget _buildGroupsCard(BuildContext context) {
    if (_loadingGroups) {
      return Card(
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: dividerColor(context), width: 0.5),
        ),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
              child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      );
    }
    if (_groupsError != null) {
      return Card(
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: dividerColor(context), width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text('课程设置加载失败',
                  style: TextStyle(fontSize: 13, color: textHint(context))),
              const SizedBox(height: 8),
              Text(_groupsError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: textHint(context))),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loadGroups,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    if (_kzList.isEmpty) {
      return const SizedBox.shrink();
    }

    // 按 FKZH↔KZH 构建树：children[parentKzh] = [子组]
    final childrenByParent = <String, List<QxFacxKz>>{};
    for (final g in _kzList) {
      childrenByParent.putIfAbsent(g.fkzh, () => []).add(g);
    }
    final tops = childrenByParent['-1'] ?? <QxFacxKz>[];
    // 组数统计（含子组）
    var totalGroups = _kzList.length;

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
                _sectionTitle(context, '课程设置'),
                const Spacer(),
                Text('$totalGroups 个课组',
                    style:
                        TextStyle(fontSize: 11, color: textHint(context))),
              ],
            ),
            const SizedBox(height: 4),
            for (final top in tops) _buildGroupNode(context, top, childrenByParent, 0),
          ],
        ),
      ),
    );
  }

  /// 递归渲染课组节点（含缩进层级与组内课程展开）
  Widget _buildGroupNode(
    BuildContext context,
    QxFacxKz g,
    Map<String, List<QxFacxKz>> childrenByParent,
    int depth,
  ) {
    final children = childrenByParent[g.kzh] ?? const <QxFacxKz>[];
    final expanded = _expanded.contains(g.kzh);
    final groupCourses = _coursesByKzh[g.kzh] ?? const <QxFacxKzCourse>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (expanded) {
                _expanded.remove(g.kzh);
              } else {
                _expanded.add(g.kzh);
              }
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.only(
                left: (depth * 16).toDouble(), top: 8, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  expanded
                      ? Icons.expand_more_rounded
                      : Icons.chevron_right_rounded,
                  size: 18,
                  color: textHint(context),
                ),
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: g.isTop
                        ? accentColorNotifier.value.withValues(alpha: 0.1)
                        : Colors.blueGrey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(g.typeLabel,
                      style: TextStyle(
                          fontSize: 10,
                          color: g.isTop
                              ? accentColorNotifier.value
                              : Colors.blueGrey)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(g.kzm,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: g.isTop ? FontWeight.w600 : FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
                if (g.kcxF > 0 || g.zsxdxf > 0)
                  Text(
                    g.zsxdxf > 0 ? '≥${_numText(g.zsxdxf)}学分' : '${_numText(g.kcxF)}学分',
                    style: TextStyle(
                        fontSize: 12, color: textHint(context)),
                  ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          // 组信息明细 + 修读要求
          Padding(
            padding: EdgeInsets.only(left: (depth * 16 + 28).toDouble()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (g.kcxF > 0 || g.kcxS > 0 || g.kczms > 0)
                  _metaLine(context,
                      '组内 ${_numText(g.kcxF)} 学分 · ${_numText(g.kcxS)} 学时 · ${_numText(g.kczms)} 门'),
                if (g.kcxzdmDisplay.isNotEmpty)
                  _metaLine(context, '课程性质：${g.kcxzdmDisplay}'),
                if (g.kclbdmDisplay.isNotEmpty)
                  _metaLine(context, '课程类别：${g.kclbdmDisplay}'),
                if (g.xgxklbdmDisplay.isNotEmpty)
                  _metaLine(context, '校公选类别：${g.xgxklbdmDisplay}'),
                if (g.sfxgxkzDisplay.isNotEmpty)
                  _metaLine(context, '校公选课组：${g.sfxgxkzDisplay}'),
                if (g.zsxdms > 0)
                  _metaLine(context, '最少修读 ${_numText(g.zsxdms)} 门'),
                if (g.xdyq.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text('修读要求：${g.xdyq}',
                        style: TextStyle(
                            fontSize: 12,
                            color: textHint(context),
                            height: 1.5)),
                  ),
              ],
            ),
          ),
          // 组内课程
          for (final c in groupCourses)
            Padding(
              padding: EdgeInsets.only(left: (depth * 16 + 28).toDouble()),
              child: _buildCourseRow(context, c),
            ),
          // 子组
          for (final child in children)
            _buildGroupNode(context, child, childrenByParent, depth + 1),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  /// 组内课程行
  Widget _buildCourseRow(BuildContext context, QxFacxKzCourse c) {
    final semester = c.xnxqDisplay.isNotEmpty
        ? (c.xnxqDisplay.contains('学年')
            ? c.xnxqDisplay
                .replaceFirst('学年', '')
                .replaceFirst(' 第', ' · 第')
            : c.xnxqDisplay)
        : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.menu_book_outlined, size: 14, color: textHint(context)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.kcm,
                    style: const TextStyle(fontSize: 12.5, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  [
                    if (c.kch.isNotEmpty) c.kch,
                    if (c.xf.isNotEmpty) '${c.xf} 学分',
                    if (c.xs.isNotEmpty) '${c.xs} 学时',
                    if (c.kcxzdmDisplay.isNotEmpty) c.kcxzdmDisplay,
                    if (c.kslxdmDisplay.isNotEmpty) c.kslxdmDisplay,
                    if (c.sfzgkcDisplay == '是') '主干',
                  ].join(' · '),
                  style: TextStyle(fontSize: 11, color: textHint(context)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (semester.isNotEmpty)
                  Text(semester,
                      style: TextStyle(
                          fontSize: 11, color: textHint(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaLine(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(text,
          style: TextStyle(fontSize: 12, color: textHint(context))),
    );
  }

  // ==================== 通用组件 ====================

  /// 头部卡片：方案名 + 状态/年级
  Widget _buildHeaderCard(BuildContext context) {
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
            Text(plan.name,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('已发布',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w600)),
                ),
                if (plan.njdDisplay.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColorNotifier.value.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(plan.njdDisplay,
                        style: TextStyle(
                            fontSize: 12,
                            color: accentColorNotifier.value,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 信息卡片：label-value 行
  Widget _buildInfoCard(
      BuildContext context, String title, List<(String, String)> entries) {
    final valid = entries.where((e) => e.$2.isNotEmpty).toList();
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
            _sectionTitle(context, title),
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
                          style: const TextStyle(fontSize: 13, height: 1.4)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 富文本卡片：区块标题 + 段落正文
  Widget _buildTextCard(BuildContext context, String title, String body) {
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
            _sectionTitle(context, title),
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(fontSize: 13, height: 1.6)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Row(
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
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _numText(double v) {
    return v == v.truncateToDouble() ? '${v.toInt()}' : '$v';
  }
}
