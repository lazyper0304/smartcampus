import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart' show FitPolicy;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassStatusBarStyle;
import 'package:path_provider/path_provider.dart';

import '../core/open_file.dart';
import '../core/platform_pdf_view.dart';
import '../core/simple_page.dart';
import '../main.dart';
import '../vpn/vpn_service.dart';

/// 办公网文件预览页
///
/// 老 ASP 站点的附件链接（showdoc.asp / filedown 类脚本）URL 以 .asp 结尾，
/// 扩展名不可信：下载后按文件头魔数嗅探真实类型并纠正扩展名。
///  - PDF（含 showdoc.asp 直接返回的二进制流）：先下载到本地临时目录，
///    再用 [PlatformPdfView] 在应用内渲染，支持翻页/缩放。
///  - DOCX / XLSX / PPT / ZIP 等：展示文件信息与「下载并用其他应用打开」
///    兜底入口（如 WPS）；嗅探到 HTML 报错页（校外网络 / 链接失效）直接报错。
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

  Future<void> _download({required bool inApp}) async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _error = null;
      _progress = null;
    });
    File? partFile;
    try {
      final dir = await getTemporaryDirectory();
      final base = 'office_${DateTime.now().microsecondsSinceEpoch}';
      partFile = File('${dir.path}/$base.part');

      final client = VpnService.createVpnAwareHttpClient();
      try {
        final req = await client.getUrl(Uri.parse(widget.url));
        req.headers.set(
          'User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
          ' (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        );
        // 老 ASP 站可能校验 Referer 防盗链，统一带上站内来源
        req.headers.set('Referer', 'http://off.yibinu.edu.cn/');
        final resp =
            await req.close().timeout(const Duration(seconds: 30));
        if (resp.statusCode != 200) {
          throw Exception('服务器返回状态 ${resp.statusCode}，'
              '该文件可能需校内网络访问或链接已失效');
        }
        final total = resp.contentLength;
        var received = 0;
        final sink = partFile.openWrite();
        await for (final chunk in resp) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0 && mounted) {
            setState(() => _progress = received / total);
          }
        }
        await sink.flush();
        await sink.close();
      } finally {
        client.close(force: true);
      }

      final size = await partFile.length();
      if (size == 0) {
        throw Exception('下载的内容为空文件（链接可能已失效）');
      }

      // 魔数嗅探：附件链接以 .asp 结尾，URL 扩展名不可信，按内容头字节纠正
      final head = <int>[];
      await for (final chunk in partFile.openRead(0, 4096)) {
        head.addAll(chunk);
      }
      final fallbackExt = _ext.isEmpty ? (_isPdf ? 'pdf' : '') : _ext;
      final sniffed = _sniffExtension(head, fallback: fallbackExt);
      if (sniffed == 'html') {
        throw Exception('下载的内容是网页报错页'
            '（可能需校内网络访问权限，或链接已失效）');
      }
      // .asp 脚本链接在嗅探不出已知魔数时也不允许落成 .asp：
      // showdoc.asp 的文档化行为是直接返回 PDF 流 → 兜底 pdf；其余脚本兜底 bin
      final resolvedFallback = fallbackExt == 'asp'
          ? (widget.url.toLowerCase().contains('showdoc.asp') ? 'pdf' : 'bin')
          : fallbackExt;
      final finalExt = sniffed.isNotEmpty
          ? sniffed
          : (resolvedFallback.isEmpty ? 'bin' : resolvedFallback);

      final file = File('${dir.path}/$base.$finalExt');
      await partFile.rename(file.path);
      partFile = null;

      if (!mounted) return;
      setState(() {
        _localPath = file.path;
        _downloading = false;
        _ext = finalExt;
        // 应用内渲染仅当内容确为 PDF；嗅探出其他类型时退回「系统打开」模式
        _isPdf = finalExt == 'pdf';
        _progress = null;
      });

      if (!inApp) {
        await _openFileWithSystem(file.path);
      }
    } catch (e) {
      // 清理半成品，避免残留 .part 垃圾文件
      try {
        if (partFile != null && await partFile.exists()) {
          await partFile.delete();
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// 魔数嗅探真实文件类型。
  /// 返回小写扩展名；'html' 表示内容为网页报错页；'' 表示未知（维持 fallback）。
  String _sniffExtension(List<int> head, {required String fallback}) {
    // 跳过 UTF-8 BOM 与前置空白后取首个有效字节
    var i = 0;
    if (head.length >= 3 &&
        head[0] == 0xEF &&
        head[1] == 0xBB &&
        head[2] == 0xBF) {
      i = 3;
    }
    while (i < head.length &&
        (head[i] == 0x20 ||
            head[i] == 0x0D ||
            head[i] == 0x0A ||
            head[i] == 0x09)) {
      i++;
    }

    bool startsWith(List<int> magic) {
      if (head.length - i < magic.length) return false;
      for (var k = 0; k < magic.length; k++) {
        if (head[i + k] != magic[k]) return false;
      }
      return true;
    }

    // '<' 开头 → HTML 报错页（txt 本就是文本类型，放行）
    if (i < head.length && head[i] == 0x3C) {
      return fallback == 'txt' ? 'txt' : 'html';
    }
    if (startsWith([0x25, 0x50, 0x44, 0x46])) return 'pdf'; // %PDF
    if (startsWith([0x50, 0x4B])) {
      // PK → ZIP 容器：优先按附件名细分 docx/xlsx/pptx，否则按内容特征猜测
      final nameExt = _extensionOf(widget.name);
      if (nameExt == 'docx' ||
          nameExt == 'xlsx' ||
          nameExt == 'pptx' ||
          nameExt == 'zip') {
        return nameExt;
      }
      final s = String.fromCharCodes(head);
      if (s.contains('word/')) return 'docx';
      if (s.contains('xl/')) return 'xlsx';
      if (s.contains('ppt/')) return 'pptx';
      return 'zip';
    }
    if (startsWith([0xD0, 0xCF, 0x11, 0xE0])) {
      // OLE2 复合文档（doc/xls/ppt）：按附件名细分，默认 doc
      final nameExt = _extensionOf(widget.name);
      if (nameExt == 'doc' || nameExt == 'xls' || nameExt == 'ppt') {
        return nameExt;
      }
      return 'doc';
    }
    if (startsWith([0x52, 0x61, 0x72, 0x21])) return 'rar'; // Rar!
    // 兜底：头 1KB 内任一位置出现 %PDF（服务器可能在 PDF 前附加了杂字节）
    if (String.fromCharCodes(head.take(1024)).contains('%PDF')) {
      return 'pdf';
    }
    return fallback;
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
