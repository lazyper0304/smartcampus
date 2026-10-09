import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart' show FitPolicy;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassStatusBarStyle;

import '../core/open_file.dart';
import '../core/platform_pdf_view.dart';
import '../core/simple_page.dart';
import '../main.dart';
import 'office_models.dart';
import 'office_service.dart';

/// 办公网文件预览页
///
/// 数据源已切到 Bingo 后端：附件不再有稳定的直链，而是走**两跳下载**——
/// `/notices/attachments/{id}/download` 先返回 302 的预签名 OSS 地址，
/// 再单独请求该地址取字节流（第二跳绝不能带 `Authorization`，否则 OSS 400）。
/// 全部封装在 [BingoOfficeService.downloadAttachment] 内。
///
/// 交互形态沿用原设计：
///  - PDF：下载后用 [PlatformPdfView] 应用内渲染，支持翻页/缩放；
///  - DOCX / XLSX / PPT / ZIP 等：展示文件信息与「下载并用其他应用打开」
///    兜底入口（如 WPS）。
class OfficeFilePreviewPage extends StatefulWidget {
  /// 附件（提供下载所需的 ID 与兜底文件名）
  final OfficeAttachment? attachment;

  /// 仅文件名（当 [attachment] 为 null 时用于类型判定/展示）
  final String name;

  const OfficeFilePreviewPage({
    super.key,
    this.attachment,
    required this.name,
  }) : assert(attachment != null,
            '请通过 attachment 传入附件（Bingo 端无直链可用）');

  @override
  State<OfficeFilePreviewPage> createState() => _OfficeFilePreviewPageState();
}

class _OfficeFilePreviewPageState extends State<OfficeFilePreviewPage> {
  bool _isPdf = false;
  String _ext = '';

  bool _downloading = false;
  double? _progress;
  String? _localPath;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ext = _extensionOf(widget.name);
    // PDF 进入即自动下载并在应用内渲染；其余格式等用户点按钮
    _isPdf = _ext == 'pdf';
    if (_isPdf) {
      _download(inApp: true);
    }
  }

  static String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  String _typeLabel() {
    switch (_ext) {
      case 'pdf':
        return 'PDF 文档';
      case 'doc':
      case 'docx':
        return 'Word 文档';
      case 'xls':
      case 'xlsx':
        return 'Excel 表格';
      case 'ppt':
      case 'pptx':
        return 'PPT 演示文稿';
      case 'zip':
      case 'rar':
        return '压缩包';
      case 'txt':
        return '文本文件';
      default:
        return _ext.isNotEmpty ? '文件（.$_ext）' : '文件';
    }
  }

  IconData _typeIcon() {
    switch (_ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'zip':
      case 'rar':
        return Icons.folder_zip_rounded;
      case 'txt':
        return Icons.article_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  /// 下载附件（Bingo 两跳）到本地，然后按扩展名决定去留
  ///
  /// [inApp] = true 表示应用内渲染（PDF），否则下载完直接交给系统打开。
  Future<void> _download({required bool inApp}) async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _error = null;
      _progress = null;
    });
    try {
      final a = widget.attachment!;
      final path =
          await OfficeService().downloadAttachment(a);

      final file = File(path);
      final size = await file.length();
      if (size == 0) {
        throw Exception('下载的内容为空文件（链接可能已失效）');
      }

      if (!mounted) return;
      // 服务端已按真实文件名落盘，扩展名直接取落盘结果
      final finalExt = _extensionOf(file.path);
      setState(() {
        _localPath = file.path;
        _downloading = false;
        _ext = finalExt.isEmpty ? _ext : finalExt;
        // 应用内渲染仅当内容确为 PDF
        _isPdf = _ext == 'pdf';
        _progress = null;
      });

      if (!inApp) {
        await _openFileWithSystem(file.path);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }


  /// 通过系统默认应用打开本地文件（平台分发见 core/open_file.dart：
  /// Android 走 FileProvider content://，桌面端走 file:// + ShellExecute）
  Future<void> _openFileWithSystem(String path) =>
      openFileWithSystem(context, path);

  Future<void> _openExternal() async {
    if (_localPath != null) await _openFileWithSystem(_localPath!);
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.name,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          centerTitle: true,
          actions: [
            if (_localPath != null)
              IconButton(
                icon: const Icon(Icons.open_in_new_rounded),
                tooltip: '用其他应用打开',
                onPressed: _openExternal,
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) return _buildError();
    if (_isPdf) {
      if (_localPath != null) {
        return PlatformPdfView(
          filePath: _localPath!,
          pageSnap: true,
          fitPolicy: FitPolicy.BOTH,
          onError: (e) => setState(() => _error = e.toString()),
          onPageError: (page, e) =>
              debugPrint('PDF 第 $page 页渲染失败: $e'),
        );
      }
      return _buildDownloading();
    }
    return _buildOtherFile();
  }

  Widget _buildDownloading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_progress != null)
            SizedBox(
              width: 180,
              child: LinearProgressIndicator(value: _progress),
            )
          else
            const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(_progress != null
              ? '正在下载… ${(_progress! * 100).toInt()}%'
              : '正在下载文件…'),
        ],
      ),
    );
  }

  Widget _buildError() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    _isPdf ? _download(inApp: true) : _download(inApp: false),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtherFile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                  color: accentColorNotifier.value.withValues(alpha: 0.1)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: accentColorNotifier.value
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_typeIcon(),
                            color: accentColorNotifier.value, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.name,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(_typeLabel(),
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('来源',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[400])),
                  const SizedBox(height: 4),
                  Text(
                    '学校通知（办公网）· 附件 #${widget.attachment!.id}',
                    style: const TextStyle(fontSize: 12),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '当前平台暂不支持在应用内预览该格式文件，可下载到本地后使用其他应用（如 WPS）打开。',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: _downloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : (_localPath != null
                      ? const Icon(Icons.open_in_new_rounded)
                      : const Icon(Icons.download_rounded)),
              label: Text(_downloading
                  ? '正在下载…'
                  : _localPath != null
                      ? '用其他应用打开'
                      : '下载并用其他应用打开'),
              onPressed: _downloading
                  ? null
                  : () {
                      final path = _localPath;
                      if (path != null) {
                        _openFileWithSystem(path);
                      } else {
                        _download(inApp: false);
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }
}
