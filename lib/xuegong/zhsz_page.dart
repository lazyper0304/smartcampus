import 'package:flutter/material.dart';

import '../core/http_client.dart';
import '../core/data_cache.dart';
import 'zhsz_api_service.dart';
import '../main.dart';
import '../core/simple_page.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';


/// 综合素质测评页面
class ZhszPage extends StatefulWidget {
  final SharedHttpClient client;

  const ZhszPage({super.key, required this.client});

  @override
  State<ZhszPage> createState() => _ZhszPageState();
}

class _ZhszPageState extends State<ZhszPage> {
  List<ZhszRecord>? _records;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final records = await ZhszService(widget.client).fetchRecords();
      if (mounted) setState(() { _records = records; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('综合素质'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: () { DataCache().invalidateAll(); _fetch(); },
              tooltip: '刷新',
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
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text('获取失败', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重试'),
                onPressed: () { DataCache().invalidateAll(); _fetch(); },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColorNotifier.value,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_records == null || _records!.isEmpty) {
      return Center(
        child: Text('暂无数据', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _records!.length,
      itemBuilder: (ctx, i) => _buildRecordCard(_records![i]),
    );
  }

  Widget _buildRecordCard(ZhszRecord record) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: accentColorNotifier.value.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 学期标题栏
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
            ),
            child: Row(children: [
              Container(
                width: 4, height: 16,
                decoration: BoxDecoration(color: accentColorNotifier.value, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Text(record.semester,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: record.grade == '合格' ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(record.grade,
                    style: TextStyle(fontSize: 11, color: record.grade == '合格' ? Colors.green[700] : Colors.orange[700])),
              ),
            ]),
          ),
          // 分数
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Text(record.score.toStringAsFixed(2),
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: accentColorNotifier.value)),
                const SizedBox(width: 6),
                Text('分', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
              ],
            ),
          ),
          // 排名
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _rankChip('班级', '${record.classRank}', record.classRankPct),
                _rankChip('专业', '${record.majorRank}', record.majorRankPct),
                _rankChip('年级', '${record.gradeRank}', record.gradeRankPct),
                _rankChip('全校', '${record.schoolRank}', record.schoolRankPct),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankChip(String label, String rank, double pct) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accentColorNotifier.value.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColorNotifier.value.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ',
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          Text(rank,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: accentColorNotifier.value)),
          Text(' (${pct.toStringAsFixed(1)}%)',
              style: TextStyle(fontSize: 10, color: Colors.grey[400])),
        ],
      ),
    );
  }
}
