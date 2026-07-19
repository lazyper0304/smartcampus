import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/navigation.dart';
import '../core/simple_page.dart';
import '../main.dart';
import 'office_file_preview_page.dart';
import 'office_models.dart';

/// 办公网文章详情（detail.asp 原生解析结果）
class OfficeDetailPage extends StatelessWidget {
  final OfficeDetail detail;
  final String title;

  const OfficeDetailPage({
    super.key,
    required this.detail,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final hasMeta =
        detail.publishDate.isNotEmpty || detail.author.isNotEmpty;
    final isEmpty = detail.paragraphs.isEmpty &&
        detail.attachments.isEmpty;

    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            detail.title.isNotEmpty ? detail.title : title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (hasMeta)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (detail.publishDate.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today,
                              size: 12, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(detail.publishDate,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[400])),
                        ],
                      ),
                    if (detail.author.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person,
                              size: 12, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(detail.author,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[400])),
                        ],
                      ),
                  ],
                ),
              ),
            if (isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('该文件仅包含附件，请点击下方附件查看。',
                      style: TextStyle(color: Colors.grey)),
                ),
              ),
            ...detail.paragraphs.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  p,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.7,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            if (detail.attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('附件',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...detail.attachments.map((a) => _buildAttachment(context, a)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttachment(BuildContext context, OfficeAttachment a) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: accentColorNotifier.value.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          // 统一走文件预览页：PDF 应用内渲染，其他格式提供系统打开兜底
          pushPage(
            context,
            OfficeFilePreviewPage(url: a.url, name: a.name),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.attachment_rounded,
                  size: 18, color: accentColorNotifier.value),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  a.name,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.open_in_new_rounded,
                  size: 16, color: Colors.grey[300]),
            ],
          ),
        ),
      ),
    );
  }
}
