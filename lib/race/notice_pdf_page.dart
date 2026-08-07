import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';

import '../core/http_client.dart';
import '../core/open_file.dart';
import '../core/simple_page.dart';
import '../core/theme_utils.dart';
import 'race_service.dart';

/// 公示公告附件 PDF 预览页
///
/// 与办公网文件预览不同：scjx2 附件静态目录 `/uploadfile/` 可能要求登录态，
/// 因此用 [SharedHttpClient.getBytes]（自动携带 scjx2 域 cookie）下载，
/// 落到本地临时文件后交给 [PDFView] 应用内渲染，支持翻页/缩放。
///
/// 右上角「下载」走官方下载通道
/// （`GET /config/sys/download/downNotice?id=<公告id>&name=<文件名>`，
/// 带签名头），下载后经 FileProvider 交给系统应用打开（可保存/分享）。
class NoticePdfPage extends StatefulWidget {
  final SharedHttpClient client;

  /// 公告 ID（官方下载接口 `downNotice?id=` 参数）
  final String noticeId;

  /// 附件直链（/uploadfile/ 静态路径，预览用）
  final String url;

  /// 附件文件名
  final String name;

  const NoticePdfPage({
    super.key,
    required this.client,
    required this.noticeId,
    required this.url,
    required this.name,
  });

  @override
  State<NoticePdfPage> createState() => _NoticePdfPageState();
}

class _NoticePdfPageState extends State<NoticePdfPage> {

  late final RaceService _service;
  String? _localPath;
  String? _error;

  /// 官方通道下载中（右上角按钮转圈）
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _service = RaceService(client: widget.client);
    _download();
  }

  /// 生成本地临时文件名：ASCII 时间戳，避免中文路径被原生 PDF 引擎拒绝
  String _safeName() =>
      'notice_${DateTime.now().microsecondsSinceEpoch}.pdf';

  Future<void> _download() async {
    if (mounted) {
      setState(() {
        _error = null;
      });
    }
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${_safeName()}');

      // SharedHttpClient 自动携带 scjx2 域 cookie（含 HttpOnly，bootstrap 后已同步）
      final bytes =
          await widget.client.getBytes(Uri.parse(widget.url));
      if (bytes.isEmpty) {
        throw Exception('下载内容为空，可能需校内网络访问或链接已失效');
      }

      // PDF 有效性预检：避免把非 PDF / 空文件丢给 PDFView 引发原生崩溃
      final validPdf = bytes.length >= 4 &&
          bytes[0] == 0x25 && // %
          bytes[1] == 0x50 && // P
          bytes[2] == 0x44 && // D
          bytes[3] == 0x46; // F
      if (!validPdf) {
        throw Exception('下载的内容不是有效的 PDF 文件'
            '（可能需校内网络访问权限，或链接已失效）');
      }

      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      setState(() {
        _localPath = file.path;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// 官方下载通道下载附件并交给系统应用打开（可保存/分享）
  Future<void> _downloadToSystem() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final bytes = await _service.downloadNoticeFile(
        noticeId: widget.noticeId,
        fileName: widget.name,
      );
      // PDF 有效性预检
      final validPdf = bytes.length >= 4 &&
          bytes[0] == 0x25 && // %
          bytes[1] == 0x50 && // P
          bytes[2] == 0x44 && // D
          bytes[3] == 0x46; // F
      if (!validPdf) {
        throw Exception('下载的内容不是有效的 PDF 文件');
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${_safeName()}');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      await _openFileWithSystem(file.path);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下载失败：$msg')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 通过系统默认应用打开本地文件（平台分发见 core/open_file.dart：
  /// Android 走 FileProvider content://，桌面端走 file:// + ShellExecute）
  Future<void> _openFileWithSystem(String path) =>
      openFileWithSystem(context, path);

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.name,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          centerTitle: true,
          actions: [
            // 官方下载通道（独立于预览直链，预览失败时仍可用）
            IconButton(
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
              tooltip: '下载并用其他应用打开',
              onPressed: _saving ? null : _downloadToSystem,
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
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _download,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

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

    // 下载中
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('正在下载附件…',
              style: TextStyle(fontSize: 13, color: textHint(context))),
        ],
      ),
    );
  }
}
