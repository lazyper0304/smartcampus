import '../core/responsive.dart';
import 'package:flutter/material.dart';
import '../core/liquid_background.dart';

import '../core/theme_utils.dart';
import '../core/http_client.dart';
import '../core/data_cache.dart';
import 'srtp.dart';
import 'srtp_service.dart';

/// 大学生创新创业训练计划 —— 项目详情（common/stuProjectShow）
class SrtpDetailPage extends StatefulWidget {
  final SharedHttpClient client;

  /// 项目 ID（详情接口参数）
  final String projectId;

  /// 项目名称（首屏 AppBar 标题 / 兜底展示）
  final String projectName;

  /// 计划名称（首屏兜底，可为空）
  final String planName;

  /// 阶段（首屏标签，0=申报/1=中期/4=结题，可为空）
  final int? stage;

  /// 状态（首屏标签，-1=终止/0=申报中/4=已结题，可为空）
  final int? state;

  /// 详情请求的 currentRoutePath（"我参与"页与"我申请"页不同）
  final String routePath;

  const SrtpDetailPage({
    super.key,
    required this.client,
    required this.projectId,
    required this.projectName,
    this.planName = '',
    this.stage,
    this.state,
    this.routePath = SrtpService.currentRoutePath,
  });

  @override
  State<SrtpDetailPage> createState() => _SrtpDetailPageState();
}

class _SrtpDetailPageState extends State<SrtpDetailPage> {
  late final SrtpService _service;
  SrtpProjectDetail? _detail;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = SrtpService(client: widget.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final detail = await _service.fetchProjectDetail(
        widget.projectId,
        routePath: widget.routePath,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    } catch (e) {
      final msg = e.toString();
      // 未登录时自动引导
      if (msg.contains('未登录 scjx2') || msg.contains('登录已过期')) {
        if (await _service.bootstrapLogin()) {
          await _load();
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        _error = msg.replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LiquidBackground(
      child: Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: true,
      ),
      body: _buildBody(),
    
    ));
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildErrorView();
    }
    final d = _detail!;
    return RefreshIndicator(
      onRefresh: () async {
        DataCache().invalidateAll();
        await _load();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildHeader(d),
          const SizedBox(height: 12),
          if (d.summary.isNotEmpty) ...[
            _buildSummary(d),
            const SizedBox(height: 12),
          ],
          if (d.stus.isNotEmpty) ...[
            _buildMembers(d),
            const SizedBox(height: 12),
          ],
          if (d.teas.isNotEmpty) ...[
            _buildTeachers(d),
            const SizedBox(height: 12),
          ],
          _buildFunding(d),
          const SizedBox(height: 12),
          if (d.audits.isNotEmpty) ...[
            _buildAudits(d),
            const SizedBox(height: 12),
          ],
          if (d.results.isNotEmpty) ...[
            _buildResults(d),
            const SizedBox(height: 12),
          ],
          if (d.applyFile.isNotEmpty || d.finalFile.isNotEmpty) ...[
            _buildFiles(d),
            const SizedBox(height: 12),
          ],
          _buildBasicInfo(d),
        ],
      ),
    );
  }

  Widget _buildHeader(SrtpProjectDetail d) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
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
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.rocket_launch_rounded,
                      color: Colors.indigo.shade400, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.name.isNotEmpty ? d.name : widget.projectName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(
                        d.planName.isNotEmpty
                            ? d.planName
                            : widget.planName,
                        style: TextStyle(
                            fontSize: 12.5, color: textHint(context)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (d.projectNo.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(d.projectNo,
                            style: TextStyle(
                                fontSize: 12, color: textHint(context))),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildStageTag(d.stage != 0 ? d.stage : (widget.stage ?? d.stage)),
                _buildStateTag(d.state != 0 ? d.state : (widget.state ?? d.state)),
                if (d.depName.isNotEmpty)
                  _buildTag(d.depName, Colors.blueGrey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(SrtpProjectDetail d) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: dividerColor(context), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('项目简介',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(d.summary,
                style: const TextStyle(fontSize: 13, height: 1.6)),
          ],
        ),
      ),
    );
  }

  Widget _buildMembers(SrtpProjectDetail d) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: dividerColor(context), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('团队成员',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('共 ${d.stus.length} 人',
                style: TextStyle(fontSize: 12, color: textHint(context))),
            const SizedBox(height: 10),
            ...d.stus.map((s) => _buildMemberRow(s)),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberRow(SrtpStu s) {
    final isLeader = s.isPri == '1';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 排名徽标
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isLeader
                  ? Colors.indigo.withValues(alpha: 0.18)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${s.rank}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isLeader ? Colors.indigo.shade700 : textHint(context),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(s.stuName,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (isLeader) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('负责人',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.indigo.shade700,
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text('学号 ${s.stuNo}',
                    style: TextStyle(fontSize: 12, color: textHint(context))),
                if (s.className.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(s.className,
                      style:
                          TextStyle(fontSize: 12, color: textHint(context)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                if (s.duty.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text('分工：${s.duty}',
                      style: TextStyle(fontSize: 12, color: textHint(context)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeachers(SrtpProjectDetail d) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: dividerColor(context), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('指导教师',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...d.teas.map((t) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 16, color: textHint(context)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(t.teaName,
                                      style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis),
                                ),
                                if (t.isPri == '1') ...[
                                  const SizedBox(width: 6),
                                  Text('第一导师',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: textHint(context))),
                                ],
                              ],
                            ),
                            if (t.depName.isNotEmpty)
                              Text(t.depName,
                                  style: TextStyle(
                                      fontSize: 11, color: textHint(context)),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      if (t.mobile.isNotEmpty)
                        Text(t.mobile,
                            style: TextStyle(
                                fontSize: 12, color: textHint(context))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildFunding(SrtpProjectDetail d) {
    final items = <MapEntry<String, String>>[
      if (d.cost > 0)
        MapEntry('预算总额',
            d.cost == d.cost.roundToDouble()
                ? '¥${d.cost.toStringAsFixed(0)}'
                : '¥${d.cost.toStringAsFixed(2)}'),
      if (d.confirmCost > 0) MapEntry('确认经费', '¥${d.confirmCost.toStringAsFixed(0)}'),
    ];
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: dividerColor(context), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('经费情况',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Text('暂无经费信息',
                  style: TextStyle(fontSize: 13, color: textHint(context)))
            else ...[
              ...items.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 90,
                          child: Text(e.key,
                              style: TextStyle(
                                  fontSize: 13, color: textHint(context))),
                        ),
                        Expanded(
                          child: Text(e.value,
                              style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  )),
              if (d.budget.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('预算明细',
                    style:
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                ...d.budget.map((b) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                                b.summary.isNotEmpty ? b.summary : '—',
                                style: const TextStyle(fontSize: 12.5)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                              '¥${b.cost == b.cost.roundToDouble() ? b.cost.toStringAsFixed(0) : b.cost.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    )),
              ],
              if (d.spend.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('支出明细',
                    style:
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                ...d.spend.map((b) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                                b.summary.isNotEmpty ? b.summary : '—',
                                style: const TextStyle(fontSize: 12.5)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                              '¥${b.cost == b.cost.roundToDouble() ? b.cost.toStringAsFixed(0) : b.cost.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    )),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAudits(SrtpProjectDetail d) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: dividerColor(context), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('审核记录',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...d.audits.asMap().entries.map(
                (e) => _buildAuditRow(e.key, d.audits.length, e.value)),
          ],
        ),
      ),
    );
  }

  /// 审核记录时间线行（含竖线连接，最新一条在最上）
  Widget _buildAuditRow(int index, int total, SrtpAudit a) {
    final isFirst = index == 0;
    final isLast = index == total - 1;
    final pass = a.state.contains('通过');
    final reject = a.state.contains('驳回') || a.state.contains('不通过');
    final color = reject ? const Color(0xFFC2410C) : (pass ? Colors.green : Colors.orange);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 时间线竖线 + 圆点
          SizedBox(
            width: 20,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(width: 2, color: dividerColor(context)),
                  ),
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFirst ? color : textHint(context),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: dividerColor(context)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (a.stage.isNotEmpty) ...[
                        Flexible(
                          child: Text(a.stage,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (a.rule.isNotEmpty)
                        Text(a.rule,
                            style: TextStyle(
                                fontSize: 11, color: textHint(context))),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(a.state.isNotEmpty ? a.state : '—',
                            style: TextStyle(
                                fontSize: 10,
                                color: color,
                                fontWeight: FontWeight.w500)),
                      ),
                      const Spacer(),
                      Text(a.addDate,
                          style: TextStyle(
                              fontSize: 11, color: textHint(context))),
                    ],
                  ),
                  if (a.addUser.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('审核人：${a.addUser}',
                        style: TextStyle(
                            fontSize: 11, color: textHint(context))),
                  ],
                  if (a.advice.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(a.advice,
                        style: const TextStyle(fontSize: 12.5, height: 1.5)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(SrtpProjectDetail d) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: dividerColor(context), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('项目成果',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('共 ${d.results.length} 项',
                style: TextStyle(fontSize: 12, color: textHint(context))),
            const SizedBox(height: 10),
            ...d.results.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.emoji_events_outlined,
                              size: 16, color: Colors.amber.shade600),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(r.name.isNotEmpty ? r.name : '成果',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const Spacer(),
                          if (r.getDate.isNotEmpty)
                            Text(r.getDate,
                                style: TextStyle(
                                    fontSize: 11, color: textHint(context))),
                        ],
                      ),
                      if (r.awardName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('获奖：${r.awardName}'
                            '${r.awardDep.isNotEmpty ? "（${r.awardDep}）" : ""}',
                            style: TextStyle(
                                fontSize: 12, color: textHint(context))),
                      ],
                      if (r.owner.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('成果人：${r.owner}',
                            style: TextStyle(
                                fontSize: 12, color: textHint(context))),
                      ],
                      if (r.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(r.description,
                            style:
                                const TextStyle(fontSize: 12.5, height: 1.5)),
                      ],
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildFiles(SrtpProjectDetail d) {
    final files = <String>[
      if (d.applyFile.isNotEmpty) '申报书：${d.applyFile}',
      if (d.finalFile.isNotEmpty) '结题报告：${d.finalFile}',
    ];
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: dividerColor(context), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('项目文件',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...files.map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(Icons.attach_file,
                          size: 16, color: textHint(context)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(f,
                            style:
                                TextStyle(fontSize: 12.5, color: textHint(context)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfo(SrtpProjectDetail d) {
    final rows = <MapEntry<String, String>>[
      MapEntry('项目名称',
          d.name.isNotEmpty ? d.name : widget.projectName),
      MapEntry('计划名称',
          d.planName.isNotEmpty ? d.planName : widget.planName),
      if (d.projectNo.isNotEmpty) MapEntry('项目编号', d.projectNo),
      MapEntry('所属学院', d.depName.isNotEmpty ? d.depName : '—'),
      if (d.applyDate.isNotEmpty) MapEntry('申请时间', d.applyDate),
    ];
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: dividerColor(context), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('基本信息',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...rows.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(e.key,
                            style: TextStyle(
                                fontSize: 13, color: textHint(context))),
                      ),
                      Expanded(
                        child: Text(e.value,
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  /// 阶段标签：0=申报 / 1=中期 / 4=结题
  Widget _buildStageTag(int stage) {
    final (text, color) = switch (stage) {
      0 => ('申报', Colors.blue),
      1 => ('中期', Colors.orange),
      4 => ('结题', Colors.green),
      _ => ('阶段 $stage', Colors.blueGrey),
    };
    return _buildTag(text, color);
  }

  /// 状态标签：-1=终止(红) / 0=申报中(橙) / 4=已结题(绿)
  Widget _buildStateTag(int state) {
    final (text, color) = switch (state) {
      -1 => ('已终止', const Color(0xFFC2410C)),
      0 => ('申报中', Colors.orange),
      4 => ('已结题', Colors.green),
      _ => ('状态 $state', Colors.blue),
    };
    return _buildTag(text, color);
  }

  Widget _buildTag(String text, Color color) {
    if (text.isEmpty) return const SizedBox.shrink();
    final brightness = Theme.of(context).brightness;
    final fg = brightness == Brightness.dark
        ? color.withValues(alpha: 0.95)
        : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, color: fg, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildErrorView() {
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
            ElevatedButton.icon(
              onPressed: () {
                DataCache().invalidateAll();
                _load();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
