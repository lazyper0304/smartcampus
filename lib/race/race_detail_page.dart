import 'package:flutter/material.dart';

import '../core/theme_utils.dart';
import '../core/http_client.dart';
import '../core/data_cache.dart';
import 'race.dart';
import 'race_service.dart';

/// 学科竞赛详情页
class RaceDetailPage extends StatefulWidget {
  final SharedHttpClient client;
  final String raceId;
  final String raceName;

  const RaceDetailPage({
    super.key,
    required this.client,
    required this.raceId,
    required this.raceName,
  });

  @override
  State<RaceDetailPage> createState() => _RaceDetailPageState();
}

class _RaceDetailPageState extends State<RaceDetailPage> {
  late final RaceService _service;
  RaceDetail? _detail;
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
      final detail = await _service.fetchRaceDetail(widget.raceId);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_detail?.name ?? widget.raceName,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
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
          _buildBasicInfo(d),
          const SizedBox(height: 12),
          if (d.subs.isNotEmpty) ...[
            _buildSubs(d),
            const SizedBox(height: 12),
          ],
          _buildContent(d),
        ],
      ),
    );
  }

  Widget _buildHeader(RaceDetail d) {
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
                      Text(d.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (d.typeName.isNotEmpty)
                            _buildTag(d.typeName, Colors.blue),
                          if (d.levelHName.isNotEmpty)
                            _buildTag(d.levelHName, Colors.purple),
                          _buildTag(d.ispublishName.isNotEmpty
                              ? d.ispublishName
                              : '正常', Colors.green),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    final brightness = Theme.of(context).brightness;
    final fg = brightness == Brightness.dark
        ? color.withValues(alpha: 0.95)
        : Colors.black87;
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

  Widget _buildBasicInfo(RaceDetail d) {
    final info = <MapEntry<String, String>>[
      MapEntry('指导教师', d.teacherName.isNotEmpty ? d.teacherName : '—'),
      if (d.teacherNo.isNotEmpty) MapEntry('教师工号', d.teacherNo),
      if (d.mobile.isNotEmpty) MapEntry('联系电话', d.mobile),
      MapEntry('所属学院', d.depName.isNotEmpty ? d.depName : '—'),
      if (d.hostDep.isNotEmpty) MapEntry('主办单位', d.hostDep),
      MapEntry('学年', d.yearterm.isNotEmpty ? d.yearterm : '—'),
      MapEntry('是否分组', d.havesub),
      if (d.outlay > 0)
        MapEntry('所需经费', '¥${d.outlay.toStringAsFixed(2)}'),
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
            ...info.map((e) => Padding(
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

  Widget _buildSubs(RaceDetail d) {
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
            const Text('竞赛子项',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...d.subs.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.workspaces_outline,
                          size: 16, color: textHint(context)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s.name,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      if (s.isteamName.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(s.isteamName,
                              style: TextStyle(
                                  fontSize: 11, color: textHint(context))),
                        ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(RaceDetail d) {
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
            const Text('竞赛详情',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (d.content.isEmpty)
              Text('暂无详情',
                  style: TextStyle(fontSize: 13, color: textHint(context)))
            else
              Text(d.content,
                  style: const TextStyle(fontSize: 13, height: 1.6)),
          ],
        ),
      ),
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
