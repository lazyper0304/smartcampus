import '../core/responsive.dart';
import 'package:flutter/material.dart';
import '../core/liquid_background.dart';

import '../core/theme_utils.dart';
import '../core/http_client.dart';
import '../core/data_cache.dart';
import 'race.dart';
import 'race_service.dart';

/// 我的竞赛详情页（raceTeam/queryById）
class MyRaceDetailPage extends StatefulWidget {
  final SharedHttpClient client;

  /// 列表项：提供作品名 / 竞赛名 / 学年等首屏信息
  final MyRaceItem item;

  const MyRaceDetailPage({
    super.key,
    required this.client,
    required this.item,
  });

  @override
  State<MyRaceDetailPage> createState() => _MyRaceDetailPageState();
}

class _MyRaceDetailPageState extends State<MyRaceDetailPage> {
  late final RaceService _service;
  MyRaceDetail? _detail;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = RaceService(client: widget.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final detail = await _service.fetchMyRaceDetail(widget.item.teamId);
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
        title: Text(widget.item.name,
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
          if (d.teamStus.isNotEmpty) ...[
            _buildTeam(d),
            const SizedBox(height: 12),
          ],
          if (d.teamTchs.isNotEmpty) ...[
            _buildTeachers(d),
            const SizedBox(height: 12),
          ],
          if (d.opinions.isNotEmpty) ...[
            _buildOpinions(d),
            const SizedBox(height: 12),
          ],
          if (d.attachName.isNotEmpty) ...[
            _buildAttach(d),
            const SizedBox(height: 12),
          ],
          _buildContact(d),
        ],
      ),
    );
  }

  Widget _buildHeader(MyRaceDetail d) {
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
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.emoji_events_rounded,
                      color: Colors.amber.shade600, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.name.isNotEmpty ? d.name : widget.item.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(
                        d.raceSubName.isNotEmpty
                            ? d.raceSubName
                            : widget.item.raceSubName,
                        style: TextStyle(
                            fontSize: 12.5, color: textHint(context)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                _buildStateTag(
                    d.stateName.isNotEmpty ? d.stateName : widget.item.stateName),
                _buildTag(widget.item.yearterm.isNotEmpty
                    ? widget.item.yearterm
                    : (d.year.isNotEmpty ? d.year : ''), Colors.blue),
                if (d.isteam == 1) _buildTag('团队', Colors.purple),
                if (d.isteam == 0) _buildTag('个人', Colors.purple),
                if (d.time.isNotEmpty) _buildTag(d.time, Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeam(MyRaceDetail d) {
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
            if (d.teamStuText.isNotEmpty)
              Text('${d.teamStuText.split(',').length} 人参赛',
                  style: TextStyle(fontSize: 12, color: textHint(context))),
            const SizedBox(height: 10),
            ...d.teamStus.map((s) => _buildMemberRow(s)),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberRow(MyRaceTeamStu s) {
    final isLeader = s.isleader == '1';
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
                  ? Colors.amber.withValues(alpha: 0.18)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              s.rankname.isNotEmpty
                  ? s.rankname.replaceAll('第', '').replaceAll('名', '')
                  : s.rank,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isLeader ? Colors.amber.shade800 : textHint(context),
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
                      child: Text(s.name,
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
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('队长',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.amber.shade800,
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                    if (s.genderName.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(s.genderName,
                          style: TextStyle(
                              fontSize: 12, color: textHint(context))),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text('学号 ${s.stuNo}',
                    style:
                        TextStyle(fontSize: 12, color: textHint(context))),
                if (s.specName.isNotEmpty || s.className.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    [if (s.specName.isNotEmpty) s.specName, s.className]
                        .where((t) => t.isNotEmpty)
                        .join(' · '),
                    style: TextStyle(fontSize: 12, color: textHint(context)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeachers(MyRaceDetail d) {
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
            ...d.teamTchs.map((t) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 16, color: textHint(context)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(t.tchName,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      if (t.tchNo.isNotEmpty)
                        Text('工号 ${t.tchNo}',
                            style: TextStyle(
                                fontSize: 12, color: textHint(context))),
                      if (t.rankname.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(t.rankname,
                            style: TextStyle(
                                fontSize: 12, color: textHint(context))),
                      ],
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildOpinions(MyRaceDetail d) {
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
            const Text('审核意见',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...d.opinions.asMap().entries.map((e) =>
                _buildOpinionRow(e.key, d.opinions.length, e.value)),
          ],
        ),
      ),
    );
  }

  /// 审核意见时间线行（含竖线连接，最新一条在最上）
  Widget _buildOpinionRow(int index, int total, MyRaceOpinion o) {
    final isFirst = index == 0;
    final isLast = index == total - 1;
    final color = _stateColor(o.state);

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
                      Flexible(
                        child: Text(
                          o.teacherName.isNotEmpty ? o.teacherName : '审核教师',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(o.state,
                            style: TextStyle(
                                fontSize: 10,
                                color: color,
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  if (o.time.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(o.time,
                        style: TextStyle(
                            fontSize: 11, color: textHint(context))),
                  ],
                  if (o.opinion.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(o.opinion,
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

  Widget _buildAttach(MyRaceDetail d) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: dividerColor(context), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.attach_file, size: 18, color: textHint(context)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('报名附件',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(d.attachName,
                      style:
                          TextStyle(fontSize: 12.5, color: textHint(context)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContact(MyRaceDetail d) {
    final rows = <MapEntry<String, String>>[
      MapEntry('作品名称', d.name.isNotEmpty ? d.name : widget.item.name),
      MapEntry('承办学院', widget.item.raceDepName.isNotEmpty ? widget.item.raceDepName : '—'),
      MapEntry('竞赛名称', d.raceSubName.isNotEmpty ? d.raceSubName : widget.item.raceSubName),
      MapEntry('学年', widget.item.yearterm.isNotEmpty ? widget.item.yearterm : '—'),
      if (d.mobile.isNotEmpty) MapEntry('联系电话', d.mobile),
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
            const Text('报名信息',
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

  Widget _buildStateTag(String text) {
    final color = _stateColor(text);
    return _buildTag(text, color, useColorFg: true);
  }

  Widget _buildTag(String text, Color color, {bool useColorFg = false}) {
    if (text.isEmpty) return const SizedBox.shrink();
    final brightness = Theme.of(context).brightness;
    final fg = useColorFg
        ? (brightness == Brightness.dark
            ? color.withValues(alpha: 0.95)
            : color)
        : (brightness == Brightness.dark
            ? color.withValues(alpha: 0.95)
            : Colors.black87);
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

  /// 状态 → 颜色：通过=绿 / 驳回=红 / 审核中=橙 / 其他=蓝
  Color _stateColor(String stateName) {
    if (stateName.contains('通过')) return Colors.green;
    if (stateName.contains('驳回') ||
        stateName.contains('不通过') ||
        stateName.contains('未通过')) {
      return const Color(0xFFC2410C);
    }
    if (stateName.contains('待审') || stateName.contains('审核中')) {
      return Colors.orange;
    }
    return Colors.blue;
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
