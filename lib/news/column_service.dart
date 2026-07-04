import 'dart:convert';
import 'dart:io';

import 'news.dart';

/// 通用栏目服务，支持校园新闻/师生风采/科研动态/通知公告等
class ColumnService {
  static const String _baseUrl = 'https://www.yibinu.edu.cn';

  final String _firstPageUrl;
  final String _columnId;

  ColumnService({required String columnId, String? firstPageUrl})
      : _columnId = columnId,
        _firstPageUrl = firstPageUrl ?? '$_baseUrl/zhxw.htm';

  /// 解析一页条目，返回条目列表和下一页 URL
  Future<ColumnPageResult> fetchPage({String? url}) async {
    final targetUrl = url ?? _firstPageUrl;
    final client = HttpClient()..badCertificateCallback = ((_, _, _) => true);
    try {
      final req = await client.getUrl(Uri.parse(targetUrl));
      req.headers.set(
          'User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
          ' (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      final resp = await req.close().timeout(const Duration(seconds: 15));
      final body = await resp.transform(utf8.decoder).join();

      final items = <NewsItem>[];
      final seen = <String>{};

      // 通用匹配：所有 info/{columnId} 链接
      final linkPattern = RegExp(
        r'<a[^>]*href="([^"]*info/' + _columnId + r'/[^"]*)"[^>]*>',
        dotAll: true,
      );

      for (final m in linkPattern.allMatches(body)) {
        final href = m.group(1)!;
        if (seen.contains(href)) continue;
        seen.add(href);

        // 提取整条 li 内容
        final liStart = body.lastIndexOf('<li', m.start);
        final liEnd = body.indexOf('</li>', m.start);
        final liContent = liStart >= 0 && liEnd > 0
            ? body.substring(liStart, liEnd + 5)
            : body.substring(m.start, m.start + 500);

        // 提取标题
        String title = '';
        final titleMatch = RegExp(r'title="([^"]+)"').firstMatch(m.group(0)!);
        if (titleMatch != null) {
          title = titleMatch.group(1)!.trim();
        }
        if (title.isEmpty) {
          // 尝试从 a 标签内容提取
          final aContent = m.group(0)!;
          final closeTag = aContent.indexOf('</a>');
          if (closeTag > 0) {
            final inner = aContent.substring(aContent.indexOf('>', aContent.indexOf('href=')) + 1, aContent.length - 4);
            title = inner.replaceAll(RegExp(r'<[^>]+>'), '').trim();
          }
        }
        // 如果 title 包含日期或换行，截取第一行
        if (title.contains('\n')) {
          title = title.split('\n').first.trim();
        }
        if (title.isEmpty) continue;

        // 提取日期
        String date = _extractDate(liContent);

        final fullUrl = _resolveUrl(href, targetUrl);
        items.add(NewsItem(
          title: title,
          url: fullUrl,
          publishDate: date,
        ));
      }

      // 提取「下页」链接
      String? nextPageUrl;
      final nextMatch = RegExp(
        r'<span class="p_next[^"]*"[^>]*><a href="([^"]+)"[^>]*>下页</a>',
        dotAll: true,
      ).firstMatch(body);
      if (nextMatch != null) {
        nextPageUrl = _resolveUrl(nextMatch.group(1)!, targetUrl);
      }

      return ColumnPageResult(items: items, nextPageUrl: nextPageUrl);
    } finally {
      client.close(force: true);
    }
  }

  /// 从 HTML 片段中提取日期
  String _extractDate(String html) {
    // 匹配 yyyy-MM-dd
    final m1 = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(html);
    if (m1 != null) return m1.group(0)!;

    // 匹配 MM.dd 格式 + 附近的 yyyy（通知公告格式）
    final m2 = RegExp(r'(\d{2})\.(\d{2})\s*(\d{4})').firstMatch(html);
    if (m2 != null) return '${m2.group(3)}-${m2.group(1)}-${m2.group(2)}';

    // 匹配 yyyy.MM 格式（科研动态格式）
    final m3 = RegExp(r'(\d{4})\.(\d{2})').firstMatch(html);
    if (m3 != null) return '${m3.group(1)}-${m3.group(2)}';

    return '';
  }

  /// 获取详情
  Future<NewsDetail> fetchDetail(String url) async {
    final client = HttpClient()..badCertificateCallback = ((_, _, _) => true);
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set(
          'User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
          ' (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      final resp = await req.close().timeout(const Duration(seconds: 15));
      final body = await resp.transform(utf8.decoder).join();

      final titleMatch = RegExp(r'<title>(.*?)</title>').firstMatch(body);
      final title = titleMatch?.group(1)?.replaceAll('-宜宾学院', '').trim() ?? '';

      final dateMatch =
          RegExp(r'发布[日期]\s*[：:]\s*(\d{4}/\d{2}/\d{2})').firstMatch(body);
      final publishDate = dateMatch?.group(1)?.replaceAll('/', '-') ?? '';

      final sourceMatch = RegExp(r'来源[：:]\s*([^<\|]+)').firstMatch(body);
      final source = sourceMatch?.group(1)?.trim() ?? '';

      final marker = 'class="v_news_content"';
      final contentMarkerIdx = body.indexOf(marker);
      if (contentMarkerIdx < 0) {
        throw Exception('未找到内容');
      }

      final divStart = body.indexOf('>', contentMarkerIdx);
      if (divStart < 0) throw Exception('内容区格式错误');

      // 正确处理嵌套 <div>，找到与 v_news_content 匹配的 </div>
      int depth = 0;
      int pos = divStart + 1;
      int contentEnd = -1;
      while (pos < body.length) {
        final nextOpen = body.indexOf('<div', pos);
        final nextClose = body.indexOf('</div>', pos);
        if (nextClose < 0) break;
        if (nextOpen >= 0 && nextOpen < nextClose) {
          depth++;
          pos = body.indexOf('>', nextOpen) + 1;
          if (pos <= 0) break;
        } else {
          if (depth == 0) {
            contentEnd = nextClose;
            break;
          }
          depth--;
          pos = nextClose + 6;
        }
      }
      if (contentEnd < 0) throw Exception('内容区未闭合');

      final contentHtml = body.substring(divStart + 1, contentEnd);

      final blocks = <ContentBlock>[];
      final attachments = <AttachmentInfo>[];
      final attachmentPattern = RegExp(
        r'\.(pdf|doc|docx|xls|xlsx|zip|rar|ppt|pptx|txt)',
        caseSensitive: false,
      );

      // ── 解析正文内容中的图文 ──
      void parseContent(String html) {
        for (final m in RegExp(r'<p[^>]*>(.*?)</p>', dotAll: true)
            .allMatches(html)) {
          final fullMatch = m.group(0)!;
          final inner = m.group(1)!;

          // 跳过结束标记和 CSS 样式块
          if (fullMatch.contains('vsbcontent_end')) continue;
          if (fullMatch.contains('<style')) continue;

          // 提取图片（vsbcontent_img 或普通 <img>）
          if (fullMatch.contains('vsbcontent_img') || fullMatch.contains('<img')) {
            for (final imgM in RegExp(r'<img[^>]*src="([^"]+)"')
                .allMatches(fullMatch)) {
              var src = imgM.group(1)!;
              if (!src.startsWith('http')) {
                src = src.startsWith('/') ? '$_baseUrl$src' : '$_baseUrl/$src';
              }
              blocks.add(ContentBlock(type: ContentBlockType.image, data: src));
            }
            continue;
          }

          // 提取附件链接
          bool hasAttachment = false;
          for (final aM in RegExp(r'<a\s+[^>]*href="([^"]+)"[^>]*>(.*?)</a>',
                  dotAll: true)
              .allMatches(inner)) {
            final aHref = aM.group(1)!;
            final aText =
                aM.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
            if (aText.isEmpty) continue;
            if (attachmentPattern.hasMatch(aHref) ||
                aHref.contains('download') ||
                aHref.contains('filedown') ||
                aHref.contains('annex') ||
                aHref.contains('virtual_attach')) {
              final fullUrl = aHref.startsWith('http')
                  ? aHref
                  : aHref.startsWith('/')
                      ? '$_baseUrl$aHref'
                      : '$_baseUrl/$aHref';
              attachments.add(AttachmentInfo(name: aText, url: fullUrl));
              hasAttachment = true;
            }
          }
          if (hasAttachment) continue;

          final text = inner
              .replaceAll(RegExp(r'<[^>]+>'), '')
              .replaceAll('&nbsp;', ' ')
              .replaceAll('&ensp;', ' ')
              .replaceAll('&emsp;', ' ')
              .trim();
          if (text.isNotEmpty) {
            blocks.add(
                ContentBlock(type: ContentBlockType.paragraph, data: text));
          }
        }
      }

      parseContent(contentHtml);

      // ── 扫描 v_news_content 之后的附件链接 ──
      final afterContent = body.substring(contentEnd);
      for (final aM in RegExp(r'<a\s+[^>]*href="([^"]+)"[^>]*>(.*?)</a>',
              dotAll: true)
          .allMatches(afterContent)) {
        final aHref = aM.group(1)!;
        final aText = aM.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        if (aText.isEmpty) continue;
        // 只匹配有文件扩展名或下载关键词的链接
        if (attachmentPattern.hasMatch(aHref) ||
            aHref.contains('download') ||
            aHref.contains('filedown') ||
            aHref.contains('virtual_attach')) {
          final fullUrl = aHref.startsWith('http')
              ? aHref
              : aHref.startsWith('/')
                  ? '$_baseUrl$aHref'
                  : '$_baseUrl/$aHref';
          attachments.add(AttachmentInfo(name: aText, url: fullUrl));
        }
      }

      return NewsDetail(
        title: title,
        publishDate: publishDate,
        source: source,
        blocks: blocks,
        attachments: attachments,
      );
    } finally {
      client.close(force: true);
    }
  }

  String _resolveUrl(String href, String currentPageUrl) {
    if (href.startsWith('http')) return href;
    if (href.startsWith('/')) return '$_baseUrl$href';
    final uri = Uri.parse(currentPageUrl);
    return uri.resolve(href).toString();
  }

  void dispose() {}
}

class ColumnPageResult {
  final List<NewsItem> items;
  final String? nextPageUrl;

  ColumnPageResult({required this.items, this.nextPageUrl});
}
