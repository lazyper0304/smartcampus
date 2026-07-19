import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassStatusBarStyle;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show MethodChannel, PlatformException;

import '../core/simple_page.dart';
import '../main.dart';

/// 办公网文件预览页
///
/// 两类文件的不同处理策略：
///  - PDF（含 showdoc.asp 直接返回的二进制流）：先下载到本地临时目录，
///    再用 [PDFView] 在应用内渲染，支持翻页/缩放。
///  - DOCX / XLSX / PPT / ZIP 等：移动端无可靠的应用内渲染器，
///    故展示文件信息与「下载并用其他应用打开」兜底入口（如 WPS）。
///
/// 所有列表文件项（showdoc.asp）与详情页附件共用本页作为统一预览入口，
/// 满足「所有文件都可以点击预览」的需求。
class OfficeFilePreviewPage extends StatefulWidget {
  final String url;
  final String name;

  const OfficeFilePreviewPage({
    super.key,
    required this.url,
    required this.name,
  });

  @override
  State<OfficeFilePreviewPage> createState() => _OfficeFilePreviewPageState();
}

class _OfficeFilePreviewPageState extends State<OfficeFilePreviewPage> {
  static const _channel = MethodChannel('com.smartcampus.smartcampus/file');

  bool _isPdf = false;
  String _ext = '';

  bool _downloading = false;
  double? _progress;
  String? _localPath;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ext = _extensionOf(widget.url);
    // showdoc.asp 始终返回 PDF 二进制流；其余按扩展名判定
    _isPdf = widget.url.toLowerCase().contains('showdoc.asp') ||
        _ext == 'pdf';
    if (_isPdf) {
      // PDF 进入即自动下载并在应用内渲染
      _download(inApp: true);
    }
  }

  String _extensionOf(String url) {
    String lastSeg;
    try {
      final uri = Uri.parse(url);
      lastSeg =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    } catch (_) {
      lastSeg = url;
    }
    final dot = lastSeg.lastIndexOf('.');
    return dot >= 0 ? lastSeg.substring(dot + 1).toLowerCase() : '';
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

  /// 生成本地临时文件名：用 ASCII 时间戳，避免中文路径被原生 PDF 引擎拒绝。
  /// 显示名仍用 [widget.name]，仅磁盘文件名取 ASCII。
  String _safeName(String raw, String ext) {
    return 'office_${DateTime.now().microsecondsSinceEpoch}.$ext';
  }

  Future<void> _download({required bool inApp}) async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _error = null;
      _progress = null;
    });
    try {
      final dir = await getTemporaryDirectory();
      final ext = _ext.isEmpty ? (_isPdf ? 'pdf' : 'bin') : _ext;
      final file = File('${dir.path}/${_safeName(widget.name, ext)}');

      if (!await file.exists()) {
        final client = HttpClient()
          ..badCertificateCallback = (_, _, _) => true;
        try {
          final req = await client.getUrl(Uri.parse(widget.url));
          req.headers.set(
            'User-Agent',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            ' (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          );
          final resp =
              await req.close().timeout(const Duration(seconds: 30));
          if (resp.statusCode != 200) {
            throw Exception('服务器返回状态 ${resp.statusCode}，'
                '该文件可能需校内网络访问或链接已失效');
          }
          final total = resp.contentLength;
          var received = 0;
          final sink = file.openWrite();
          await for (final chunk in resp) {
            sink.add(chunk);
            received += chunk.length;
            if (total > 0 && mounted) {
              setState(() => _progress = received / total);
            }
          }
          await sink.flush();
          await sink.close();

          // PDF 有效性预检：避免把非 PDF / 空文件丢给 PDFView 引发原生崩溃
          if (_isPdf) {
            final head = await file.openRead(0, 4).first;
            final validPdf = head.length >= 4 &&
                head[0] == 0x25 && // %
                head[1] == 0x50 && // P
                head[2] == 0x44 && // D
                head[3] == 0x46; // F
            final size = await file.length();
            if (!validPdf || size == 0) {
              throw Exception('下载的内容不是有效的 PDF 文件'
                  '（可能需校内网络访问权限，或链接已失效）');
            }
          }
        } finally {
          client.close(force: true);
        }
      }

      if (!mounted) return;
      setState(() {
        _localPath = file.path;
        _downloading = false;
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

  /// 通过原生 FileProvider 把本地文件安全地交给其它应用打开。
  /// 必须走 MethodChannel：Android 7+ 禁止用 file:// 直接暴露给外部应用
  /// （FileUriExposedException），原生侧会用 content:// + 授权临时解决。
  Future<void> _openFileWithSystem(String path) async {
    try {
      await _channel.invokeMethod<bool>('openFile', {'path': path});
    } on PlatformException catch (e) {
      if (!mounted) return;
      final msg = switch (e.code) {
        'NO_APP' => '未找到可打开该文件的应用（建议安装 WPS）',
        'NO_FILE' => '文件不存在或已失效',
        _ => '无法打开文件：${e.message ?? e.code}',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

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
        return PDFView(
          filePath: _localPath!,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: true,
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
                  Text(widget.url,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
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
                  : const Icon(Icons.download_rounded),
              label: Text(_downloading ? '正在下载…' : '下载并用其他应用打开'),
              onPressed: _downloading
                  ? null
                  : () => _download(inApp: false),
            ),
          ),
        ],
      ),
    );
  }
}
