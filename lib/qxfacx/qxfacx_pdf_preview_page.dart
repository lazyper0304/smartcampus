import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../core/open_file.dart';
import '../core/platform_pdf_view.dart';
import '../core/simple_page.dart';

/// 培养方案 PDF 预览导出页
///
/// - 顶部：PDF 应用内预览（Android/iOS 用 [PlatformPdfView] 渲染；
///   Windows 等桌面端引导"用系统应用打开"）
/// - 底部：导出操作
///   - **保存/分享**：移动端调系统分享（printing.sharePdf，可存文件/发邮件/
///     传 WPS 等）；桌面端保存到应用文档目录 `smartcampus_exports/`
///   - **用系统应用打开**：唤起系统默认 PDF 查看器（桌面端主路径）
class QxFacxPdfPreviewPage extends StatefulWidget {
  /// 已生成的 PDF 文件路径（应用内预览 + 系统打开用）
  final String filePath;

  /// PDF 字节（分享/保存用）
  final Uint8List bytes;

  /// 文件名（如 "2026级体育教育主修培养方案.pdf"）
  final String fileName;

  const QxFacxPdfPreviewPage({
    super.key,
    required this.filePath,
    required this.bytes,
    required this.fileName,
  });

  @override
  State<QxFacxPdfPreviewPage> createState() => _QxFacxPdfPreviewPageState();
}

class _QxFacxPdfPreviewPageState extends State<QxFacxPdfPreviewPage> {
  bool _saving = false;

  bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> _saveOrShare() async {
    setState(() => _saving = true);
    try {
      if (_isMobile) {
        // 移动端：系统分享（可存文件/发邮件/打开 WPS 等）
        await Printing.sharePdf(
          bytes: widget.bytes,
          filename: widget.fileName,
        );
      } else {
        // 桌面端：保存到应用文档目录
        final dir = await getApplicationDocumentsDirectory();
        final exportDir = Directory('${dir.path}/smartcampus_exports');
        if (!await exportDir.exists()) {
          await exportDir.create(recursive: true);
        }
        final out = File('${exportDir.path}/${widget.fileName}');
        await out.writeAsBytes(widget.bytes, flush: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已保存：${out.path}'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: '打开',
              onPressed: () => openFileWithSystem(context, out.path),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('方案预览'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: '用系统应用打开',
              onPressed: () => openFileWithSystem(context, widget.filePath),
            ),
          ],
        ),
        body: Column(
          children: [
            // PDF 预览（Android/iOS 内嵌渲染；桌面端引导系统打开）
            Expanded(
              child: PlatformPdfView(filePath: widget.filePath),
            ),
            // 导出操作条
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context)
                          .dividerColor
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveOrShare,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : Icon(_isMobile
                                ? Icons.share_rounded
                                : Icons.save_alt_rounded),
                        label: Text(_saving
                            ? '处理中…'
                            : (_isMobile ? '保存 / 分享' : '保存到设备')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () =>
                              openFileWithSystem(context, widget.filePath),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('系统打开'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
