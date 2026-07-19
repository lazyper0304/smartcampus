import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/navigation.dart';
import '../core/simple_page.dart';
import 'office_list_page.dart';
import 'office_search_page.dart';
import 'office_service.dart';

/// 办公网首页：四个栏目以 Tab 形式呈现，全部原生解析渲染（无 WebView）
class OfficeHomePage extends StatelessWidget {
  const OfficeHomePage({super.key});

  /// 弹出搜索输入框，确认后进入搜索结果页
  void _openSearch(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('搜索办公网'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) {
            final kw = v.trim();
            if (kw.isNotEmpty) {
              Navigator.of(ctx).pop();
              pushPage(context, OfficeSearchResultsPage(keyword: kw));
            }
          },
          decoration: const InputDecoration(
            hintText: '输入关键词，如 张',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final kw = ctrl.text.trim();
              if (kw.isNotEmpty) {
                Navigator.of(ctx).pop();
                pushPage(context, OfficeSearchResultsPage(keyword: kw));
              }
            },
            child: const Text('搜索'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cols = OfficeService.columns.entries.toList();
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: DefaultTabController(
        length: cols.length,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('办公网'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: '搜索',
                onPressed: () => _openSearch(context),
              ),
            ],
            bottom: TabBar(
              isScrollable: false,
              tabs: [
                for (final e in cols) Tab(text: e.value),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              for (final e in cols)
                OfficeListPage(bId: e.key, title: e.value),
            ],
          ),
        ),
      ),
    );
  }
}
