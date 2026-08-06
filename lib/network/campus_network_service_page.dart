import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/data_cache.dart';
import '../core/ios_kit.dart';
import '../core/navigation.dart';
import '../core/simple_page.dart';
import '../main.dart';
import 'campus_network_service.dart';
import 'campus_network_service_detail_page.dart';
import 'campus_network_service_service.dart';

/// 校园网服务 / 多媒体服务 等 nm 站点栏目列表页
/// （抓取 HTML，不使用 WebView；service 决定列表地址，title 为栏目名）
class CampusNetworkServicePage extends StatefulWidget {
  final CampusNetworkService service;
  final String title;

  const CampusNetworkServicePage({
    super.key,
    required this.service,
    required this.title,
  });

  @override
  State<CampusNetworkServicePage> createState() =>
      _CampusNetworkServicePageState();
}

class _CampusNetworkServicePageState extends State<CampusNetworkServicePage> {
  late final CampusNetworkService _service;

  @override
  void initState() {
    super.initState();
    _service = widget.service;
    _load();
  }
  final List<CampusNetworkItem> _items = [];
  bool _loading = true;
  String? _error;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
    });
    try {
      final items = await _service.fetchList();
      if (!mounted) return;
      setState(() {
        _items.addAll(items);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _openDetail(CampusNetworkItem item) async {
    showGlassLoadingDialog(context, message: '加载中...');
    try {
      final detail = await _service.fetchDetail(item.url);
      if (!mounted) return;
      Navigator.of(context).pop();
      pushPage(context, CampusNetworkDetailPage(detail: detail));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title), centerTitle: true),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: _load, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('暂无内容'));
    }
    return RefreshIndicator(
      onRefresh: () {
        DataCache().invalidateAll();
        return _load();
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = _items[index];
          return Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                  color: accentColorNotifier.value.withValues(alpha: 0.08)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openDetail(item),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 52,
                      decoration: BoxDecoration(
                        color: accentColorNotifier.value,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.date.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 12, color: Colors.grey[400]),
                                const SizedBox(width: 4),
                                Text(item.date,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[400])),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: Colors.grey[300]),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
