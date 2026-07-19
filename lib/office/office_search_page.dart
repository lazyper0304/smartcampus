import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/simple_page.dart';
import 'office_list_page.dart';

/// 办公网搜索结果页（独立全屏页面）
class OfficeSearchResultsPage extends StatefulWidget {
  final String keyword;

  const OfficeSearchResultsPage({super.key, required this.keyword});

  @override
  State<OfficeSearchResultsPage> createState() => _OfficeSearchResultsPageState();
}

class _OfficeSearchResultsPageState extends State<OfficeSearchResultsPage> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.keyword);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final kw = value.trim();
    if (kw.isEmpty || kw == widget.keyword) return;
    // 用新关键词重建结果页（替换当前，避免栈堆积）
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OfficeSearchResultsPage(keyword: kw),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: TextField(
            controller: _ctrl,
            autofocus: false,
            textInputAction: TextInputAction.search,
            onSubmitted: _submit,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: '搜索办公网',
              border: InputBorder.none,
              hintStyle: TextStyle(fontSize: 16, color: Colors.grey[400]),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: '搜索',
              onPressed: () => _submit(_ctrl.text),
            ),
          ],
        ),
        body: OfficeListPage(
          searchKeyword: widget.keyword,
          title: '搜索：${widget.keyword}',
        ),
      ),
    );
  }
}
