import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/navigation.dart';
import '../core/simple_page.dart';
import '../core/theme_utils.dart';
import 'campus_network_service.dart';
import 'campus_network_service_service.dart';
import 'campus_network_service_viewer.dart';

/// 单页栏目（无列表，整页就是一篇文章，如网站服务 wzfw.htm）
///
/// 与列表栏目的区别：入口直接就是内容页，故本组件自行按 URL 抓取
/// 详情后复用 [CampusNetworkDetailPage] 渲染，避免重复实现图文/附件区。
class CampusNetworkArticlePage extends StatefulWidget {
  /// 文章页地址（如 https://nm.yibinu.edu.cn/wzfw.htm）
  final String url;

  /// AppBar 标题（栏目名，如「网站服务」）
  final String title;

  const CampusNetworkArticlePage({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<CampusNetworkArticlePage> createState() =>
      _CampusNetworkArticlePageState();
}

class _CampusNetworkArticlePageState extends State<CampusNetworkArticlePage> {
  CampusNetworkDetail? _detail;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _detail = null;
    });
    try {
      final d =
          await CampusNetworkService(listUrl: widget.url).fetchDetail(widget.url);
      if (!mounted) return;
      setState(() => _detail = d);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    if (detail != null) {
      return CampusNetworkDetailPage(detail: detail, appBarTitle: widget.title);
    }
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title), centerTitle: true),
        body: _error == null
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// 校园网服务详情页（图文内容 + 附件下载，不使用 WebView）
class CampusNetworkDetailPage extends StatelessWidget {
  final CampusNetworkDetail detail;

  /// AppBar 标题，默认「详情」；单页栏目传栏目名
  final String appBarTitle;

  const CampusNetworkDetailPage({
    super.key,
    required this.detail,
    this.appBarTitle = '详情',
  });

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(title: Text(appBarTitle), centerTitle: true),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              detail.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (detail.source.isNotEmpty) ...[
                  Icon(Icons.source, size: 14, color: textSecondary(context)),
                  const SizedBox(width: 4),
                  Text(detail.source,
                      style: TextStyle(fontSize: 12, color: textSecondary(context))),
                  const SizedBox(width: 16),
                ],
                Icon(Icons.calendar_today,
                    size: 14, color: textSecondary(context)),
                const SizedBox(width: 4),
                Text(detail.date,
                    style: TextStyle(fontSize: 12, color: textSecondary(context))),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            ...detail.blocks.map((block) {
              if (block.type == ContentBlockType.image) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: InteractiveViewer(
                      child: CachedNetworkImage(
                        imageUrl: block.data,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => Container(
                          height: 200,
                          color: Colors.grey.shade100,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          height: 180,
                          color: Colors.grey.shade100,
                          child: const Center(
                            child: Icon(Icons.broken_image,
                                size: 48, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '\u3000\u3000${block.data}',
                  style: const TextStyle(fontSize: 16, height: 1.8),
                ),
              );
            }),
            if (detail.attachments.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text('附件下载',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...detail.attachments
                  .map((att) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => pushPage(
                            context,
                            CampusNetworkAttachmentPage(
                                url: att.url, name: att.name),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color.fromRGBO(25, 25, 153, 1)
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.download_rounded,
                                    size: 22,
                                    color: Color.fromRGBO(25, 25, 153, 1),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    att.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    size: 18, color: textHint(context)),
                              ],
                            ),
                          ),
                        ),
                      )),
            ],
          ],
        ),
      ),
    );
  }
}
