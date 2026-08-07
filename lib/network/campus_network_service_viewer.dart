import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../core/open_file.dart';
import '../core/platform_pdf_view.dart';
import '../core/simple_page.dart';
import '../core/theme_utils.dart';
import 'campus_network_service_service.dart';

/// 附件查看/下载页
///
/// 与 race 公示公告 PDF 预览同范式：先下载字节到本地临时文件
/// （ASCII 文件名，避免中文路径被原生 PDF 引擎拒绝），再做：
/// - PDF：应用内 [PDFView] 渲染（翻页/缩放）；
/// - 其它类型（doc/xlsx/zip/图片等）：经原生 FileProvider
///   交给系统应用打开（可保存/分享），Android 7+ 禁止 file:// 直曝。
class CampusNetworkAttachmentPage extends StatefulWidget {
  final String url;
  final String name;

  const CampusNetworkAttachmentPage({
    super.key,
    required this.url,
    required this.name,
  });

  @override
  State<CampusNetworkAttachmentPage> createState() =>
      _CampusNetworkAttachmentPageState();
}

class _CampusNetworkAttachmentPageState
    extends State<CampusNetworkAttachmentPage> {
  String? _localPath;
  String? _error;
  bool _isPdf = false;

  /// 下载进度：0~1；总长未知时为 null（仅显示已下载体积）
  double? _progress;
  int _received = 0;
  int _lastTickMs = 0;

  @override
  void initState() {
    super.initState();
    _download();
  }

  String _safeExt() {
    final dot = widget.name.lastIndexOf('.');
    if (dot > 0 && widget.name.length - dot <= 5) {
      return widget.name.substring(dot + 1).toLowerCase();
    }
    // 退而从 URL 取扩展名
    final u = Uri.parse(widget.url);
    final seg = u.pathSegments.isEmpty ? '' : u.pathSegments.last;
    final d = seg.lastIndexOf('.');
    if (d > 0) return seg.substring(d + 1).toLowerCase();
    return 'bin';
  }

  Future<void> _download() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/cns_${DateTime.now().microsecondsSinceEpoch}.${_safeExt()}');

      // 流式落盘（本站存在 70MB 级安装包附件，不能整包读进内存）
      final head = await CampusNetworkService.downloadToFile(
        widget.url,
        file,
        onProgress: (received, total) {
          if (!mounted) return;
          // 限流：最多每 120ms 刷新一次，避免大文件高频 setState 掉帧
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - _lastTickMs < 120 && (total < 0 || received < total)) {
            return;
          }
          _lastTickMs = now;
          setState(() {
            _received = received;
            _progress = total > 0 ? received / total : null;
          });
        },
      );

      if (await file.length() == 0) {
        throw Exception('下载内容为空，可能需校内网络访问或链接已失效');
      }

      if (!mounted) return;
      final validPdf = head.length >= 4 &&
          head[0] == 0x25 && // %
          head[1] == 0x50 && // P
          head[2] == 0x44 && // D
          head[3] == 0x46; // F
      setState(() {
        _isPdf = validPdf;
        _localPath = file.path;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  static String _fmtSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  Future<void> _openWithSystem() async {
    if (_localPath == null) return;
    await openFileWithSystem(context, _localPath!);
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.name,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          centerTitle: true,
          actions: [
            if (_localPath != null && !_isPdf)
              IconButton(
                icon: const Icon(Icons.open_in_new_rounded),
                tooltip: '用其他应用打开',
                onPressed: _openWithSystem,
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
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
            ],
          ),
        ),
      );
    }
    if (_localPath == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                  strokeWidth: 3, value: _progress),
            ),
            const SizedBox(height: 16),
            Text(
              _progress != null
                  ? '正在下载 ${(_progress! * 100).toStringAsFixed(0)}%'
                  : (_received > 0
                      ? '正在下载 ${_fmtSize(_received)}'
                      : '正在下载…'),
              style: TextStyle(fontSize: 13, color: textSecondary(context)),
            ),
          ],
        ),
      );
    }
    if (_isPdf) {
      return PlatformPdfView(
        filePath: _localPath!,
        onError: (msg) => ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF 打开失败：$msg'))),
      );
    }
    // 非 PDF：已保存本地，引导用系统应用打开
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.file_download_done_rounded,
                size: 56, color: Colors.green),
            const SizedBox(height: 16),
            const Text('文件已下载到本地', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(widget.name,
                style: TextStyle(fontSize: 13, color: textSecondary(context)),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('用其他应用打开'),
              onPressed: _openWithSystem,
            ),
          ],
        ),
      ),
    );
  }
}
