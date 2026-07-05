import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/data_cache.dart';
import 'news.dart';

class NewsService {
  static const String _baseUrl = 'https://www.yibinu.edu.cn';
  static const String _firstPageUrl = '$_baseUrl/zhxw.htm';

  final http.Client _client;

  NewsService({http.Client? client}) : _client = client ?? http.Client();

  /// 解析一页新闻，返回条目列表和下一页 URL（null 表示无更多）
  Future<NewsPageResult> fetchNewsPage({String? url, bool forceRefresh = false}) async {
    final targetUrl = url ?? _firstPageUrl;
    final cacheKey = 'news_page_$targetUrl';
    if (!forceRefresh) {
      final cached = DataCache().get<NewsPageResult>(cacheKey);
      if (cached != null) return cached;
    }
    final resp = await _client.get(Uri.parse(targetUrl));
    if (resp.statusCode != 200) {
      throw Exception('获取新闻失败：HTTP ${resp.statusCode}');
    }

    final body = utf8.decode(resp.bodyBytes);
    final items = <NewsItem>[];
    final seen = <String>{};

    // 提取新闻条目
    final pattern = RegExp(
      r'<li><a href="([^"]*info/1321[^"]*)"[^>]*>.*?<p[^>]*>(.*?)</p><span>(\d{4}-\d{2}-\d{2})</span>',
      dotAll: true,
    );

    for (final m in pattern.allMatches(body)) {
      final href = m.group(1)!;
      if (seen.contains(href)) continue;
      seen.add(href);

      final title = m.group(2)!.trim();
      final date = m.group(3)!;

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

    final result = NewsPageResult(items: items, nextPageUrl: nextPageUrl);
    DataCache().set(cacheKey, result);
    return result;
  }

  /// 将相对路径解析为绝对 URL
  String _resolveUrl(String href, String currentPageUrl) {
    if (href.startsWith('http')) return href;
    if (href.startsWith('/')) return '$_baseUrl$href';

    // 相对路径：基于当前页面的目录解析
    final uri = Uri.parse(currentPageUrl);
    final base = uri.resolve(href);
    return base.toString();
  }

  /// 获取新闻详情
  Future<NewsDetail> fetchNewsDetail(String url, {bool forceRefresh = false}) async {
    final cacheKey = 'news_detail_$url';
    if (!forceRefresh) {
      final cached = DataCache().get<NewsDetail>(cacheKey);
      if (cached != null) return cached;
    }
    final resp = await _client.get(Uri.parse(url));
    if (resp.statusCode != 200) {
      throw Exception('获取新闻详情失败：HTTP ${resp.statusCode}');
    }

    final body = utf8.decode(resp.bodyBytes);

    final titleMatch = RegExp(r'<title>(.*?)</title>').firstMatch(body);
    final title = titleMatch?.group(1)?.replaceAll('-宜宾学院', '').trim() ?? '';

    final dateMatch =
        RegExp(r'发布日期[：:]\s*(\d{4}/\d{2}/\d{2})').firstMatch(body);
    final publishDate = dateMatch?.group(1)?.replaceAll('/', '-') ?? '';

    final sourceMatch = RegExp(r'来源[：:]\s*([^<|]+)').firstMatch(body);
    final source = sourceMatch?.group(1)?.trim() ?? '';

    final marker = 'class="v_news_content"';
    final contentMarkerIdx = body.indexOf(marker);
    if (contentMarkerIdx < 0) {
      throw Exception('未找到新闻内容');
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

    // ── 解析正文内容中的图文和附件 ──
    void parseContent(String html) {
      for (final m in RegExp(r'<p[^>]*>(.*?)</p>', dotAll: true)
          .allMatches(html)) {
        final fullMatch = m.group(0)!;
        final inner = m.group(1)!;

        if (fullMatch.contains('vsbcontent_end')) continue;
        if (fullMatch.contains('<style')) continue;

        // 提取图片
        if (fullMatch.contains('vsbcontent_img') || fullMatch.contains('<img')) {
          for (final imgM in RegExp(r'<img[^>]*src="([^"]+)"')
              .allMatches(fullMatch)) {
            var src = imgM.group(1)!;
            if (!src.startsWith('http')) {
              src = src.startsWith('/')
                  ? '$_baseUrl$src'
                  : '$_baseUrl/$src';
            }
            blocks.add(ContentBlock(type: ContentBlockType.image, data: src));
          }
          continue;
        }

        // 提取附件
        bool hasAttachment = false;
        for (final aM in RegExp(r'<a\s+[^>]*href="([^"]+)"[^>]*>(.*?)</a>',
                dotAll: true)
            .allMatches(inner)) {
          final aHref = aM.group(1)!;
          final aText = aM.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
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
          blocks.add(ContentBlock(type: ContentBlockType.paragraph, data: text));
        }
      }
    }

    // 依次解析 v_news_content 内和其后的内容
    parseContent(contentHtml);
    final afterContent = body.substring(contentEnd);
    for (final aM in RegExp(r'<a\s+[^>]*href="([^"]+)"[^>]*>(.*?)</a>',
            dotAll: true)
        .allMatches(afterContent)) {
      final aHref = aM.group(1)!;
      final aText = aM.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      if (aText.isEmpty) continue;
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

    final detail = NewsDetail(
      title: title,
      publishDate: publishDate,
      source: source,
      blocks: blocks,
      attachments: attachments,
    );
    DataCache().set(cacheKey, detail);
    return detail;
  }

  void dispose() {
    _client.close();
  }
}

/// 一页新闻的解析结果
class NewsPageResult {
  final List<NewsItem> items;
  final String? nextPageUrl;

  NewsPageResult({required this.items, this.nextPageUrl});
}
