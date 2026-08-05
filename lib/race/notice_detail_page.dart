import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/http_client.dart';
import '../core/data_cache.dart';
import '../core/ios_kit.dart';
import '../core/navigation.dart';
import '../core/simple_page.dart';
import '../core/theme_utils.dart';
import 'notice.dart';
import 'race_service.dart';
import 'notice_pdf_page.dart';

/// 公示公告详情页（`/config/sys/baseNotice/getNoticeById`）
///
/// 展示标题/发布信息/正文（HTML 转纯文本）与附件列表；
/// PDF 附件进入应用内预览（带 cookie 下载），其余格式用系统浏览器打开。
class NoticeDetailPage extends StatefulWidget {
  final SharedHttpClient client;
  final String noticeId;
  final String noticeSubject;

  const NoticeDetailPage({
    super.key,
    required this.client,
    required this.noticeId,
    required this.noticeSubject,
  });

  @override
  State<NoticeDetailPage> createState() => _NoticeDetailPageState();
}

class _NoticeDetailPageState extends State<NoticeDetailPage> {
  late final RaceService _service;
  RaceNoticeDetail? _detail;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = RaceService(client: widget.client);
    _load();
  }

  Future<void> _load() async {
    // 缓存优先：有缓存先秒开，后台静默刷新
    final cached = _service.cachedNoticeDetail(widget.noticeId);
    if (cached != null) {
      setState(() {
        _detail = cached;
        _isLoading = false;
      });
      _refreshSilently();
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final detail = await _service.fetchNoticeDetail(widget.noticeId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    } catch (e) {
      final msg = e.toString();
      // 未登录时自动引导
      if (msg.contains('未登录 scjx2') || msg.contains('登录已过期')) {
        if (await _service.bootstrapLogin()) {
          await _load();
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        _error = msg.replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshSilently() async {
    try {
      final detail = await _service.fetchNoticeDetail(widget.noticeId);
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (_) {
      // 静默失败：保留缓存展示
    }
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_detail?.subject ?? widget.noticeSubject,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          centerTitle: true,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildErrorView();
    }
    final d = _detail!;
    return RefreshIndicator(
      onRefresh: () async {
        DataCache().invalidateAll();
        await _load();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildHeader(d),
          const SizedBox(height: 12),
          _buildContent(d),
          if (d.attaches.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildAttachGroup(d),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(RaceNoticeDetail d) {
    return IosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  d.subject,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold, height: 1.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: textHint(context)),
              const SizedBox(width: 4),
              Text(
                d.teacherName.isNotEmpty ? d.teacherName : '教务处',
                style: TextStyle(fontSize: 12, color: textHint(context)),
              ),
              const SizedBox(width: 12),
              Icon(Icons.schedule_rounded, size: 14, color: textHint(context)),
              const SizedBox(width: 4),
              Text(d.modifyTime,
                  style: TextStyle(fontSize: 12, color: textHint(context))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(RaceNoticeDetail d) {
    final text = raceNoticeHtmlToText(d.content);
    return IosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('公告内容',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (text.isEmpty)
            Text('暂无内容',
                style: TextStyle(fontSize: 13, color: textHint(context)))
          else
            SelectableText(
              text,
              style: const TextStyle(fontSize: 14, height: 1.7),
            ),
        ],
      ),
    );
  }

  Widget _buildAttachGroup(RaceNoticeDetail d) {
    return IosListGroup(
      header: '附件',
      children: [
        for (final attach in d.attaches)
          IosListTile(
            icon: Icons.picture_as_pdf_rounded,
            iconColor: Colors.redAccent.shade200,
            iconBackground: Colors.red.withValues(alpha: 0.08),
            title: attach.documentName,
            subtitle: attach.isPdf ? 'PDF 文档' : '点击用浏览器打开',
            onTap: () => _openAttach(attach),
          ),
      ],
    );
  }

  Future<void> _openAttach(RaceNoticeAttach attach) async {
    if (attach.documentName.isEmpty) return;
    if (attach.isPdf) {
      // PDF → 应用内预览（带 cookie 下载 + 右上角官方通道下载）
      pushPage(
        context,
        NoticePdfPage(
          client: widget.client,
          noticeId: attach.noticeId.isNotEmpty
              ? attach.noticeId
              : widget.noticeId,
          url: attach.fileUrl(),
          name: attach.documentName,
        ),
      );
      return;
    }
    // 非 PDF → 系统浏览器打开（服务端常见仅 PDF 附件）
    final ok = await launchUrl(Uri.parse(attach.fileUrl()),
        mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开附件，请稍后重试')),
      );
    }
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 12),
            Text('加载失败',
                style: TextStyle(fontSize: 16, color: textHint(context))),
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: textHint(context))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                DataCache().invalidateAll();
                _load();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
