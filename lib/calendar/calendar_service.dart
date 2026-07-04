import 'dart:convert';

import 'package:http/http.dart' as http;

import 'calendar.dart';

class CalendarService {
  static const String _baseUrl = 'https://www.yibinu.edu.cn';
  static const String _listUrl = '$_baseUrl/ggfw/xlfw.htm';

  final http.Client _client;

  CalendarService({http.Client? client}) : _client = client ?? http.Client();

  /// 获取校历列表
  Future<List<CalendarEntry>> fetchCalendarList() async {
    final resp = await _client.get(Uri.parse(_listUrl));

    String debugInfo = 'HTTP ${resp.statusCode}, bodyLen=${resp.bodyBytes.length}';
    
    if (resp.statusCode != 200) {
      throw Exception('获取校历列表失败：$debugInfo');
    }

    // 手动用 UTF-8 解码（http 包的自动解码可能使用错误编码）
    final body = utf8.decode(resp.bodyBytes);
    
    // 调试：检查响应内容是否包含预期内容
    if (!body.contains('info/1841')) {
      throw Exception('未找到校历数据：响应中无 info/1841 引用 ($debugInfo)');
    }
    if (!body.contains('校历')) {
      throw Exception('未找到校历数据：响应中无"校历"关键字 ($debugInfo)');
    }

    final entries = <CalendarEntry>[];
    final seen = <String>{};

    // 正则匹配：提取包含 info/1841 的链接及其内容
    // raw string r'...' 中 " 不需要转义
    final linkPattern = RegExp(
      r'<a[^>]*href="([^"]*info/1841[^"]*)"[^>]*>'
      r'(.*?)</a>',
      dotAll: true,
    );

    for (final m in linkPattern.allMatches(body)) {
      final href = m.group(1)!;
      if (seen.contains(href)) continue;
      seen.add(href);

      // 提取纯文本（去掉 HTML 标签）
      final innerHtml = m.group(2)!;
      final text = innerHtml
          .replaceAll(RegExp(r'<[^>]+>'), '') // 去掉标签
          .replaceAll(RegExp(r'\s+'), ' ')    // 合并空白
          .trim();

      if (!text.contains('校历')) continue;

      // 提取日期
      final dateMatch =
          RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
      if (dateMatch == null) continue;
      final publishDate = dateMatch.group(0)!;

      // 清理标题（去掉日期）
      final cleanTitle =
          text.replaceAll(RegExp(r'\d{4}-\d{2}-\d{2}'), '').trim();

      // 提取学年
      final yearMatch = RegExp(r'(\d{4})-(\d{4})').firstMatch(text);
      final academicYear = yearMatch?.group(0) ?? '';

      // 判断上下期
      final isFirst = text.contains('上期');

      // 构造完整 URL
      String fullUrl;
      if (href.startsWith('http')) {
        fullUrl = href;
      } else if (href.startsWith('..')) {
        fullUrl = '$_baseUrl${href.substring(2)}';
      } else if (href.startsWith('/')) {
        fullUrl = '$_baseUrl$href';
      } else {
        fullUrl = '$_baseUrl/$href';
      }

      entries.add(CalendarEntry(
        title: cleanTitle,
        url: fullUrl,
        publishDate: publishDate,
        academicYear: academicYear,
        isFirstSemester: !isFirst,
      ));
    }

    if (entries.isEmpty) {
      throw Exception('未找到校历数据：正则匹配到 ${seen.length} 个链接，均不符合条件 ($debugInfo)');
    }

    // 按日期降序排列（最新的在前）
    entries.sort((a, b) => b.publishDate.compareTo(a.publishDate));
    return entries;
  }

  /// 获取校历详情（PDF 链接）
  Future<CalendarDetail> fetchCalendarDetail(CalendarEntry entry) async {
    final resp = await _client.get(Uri.parse(entry.url));
    if (resp.statusCode != 200) {
      throw Exception('获取校历详情失败：HTTP ${resp.statusCode}');
    }

    final body = utf8.decode(resp.bodyBytes);
    final pdfUrl = _extractPdfUrl(body);
    if (pdfUrl == null) {
      throw Exception('未找到校历 PDF 文件');
    }

    final previewUrl = _extractPreviewImageUrl(body);

    return CalendarDetail(
      entry: entry,
      pdfUrl: pdfUrl,
      previewImageUrl: previewUrl,
    );
  }

  String? _extractPdfUrl(String html) {
    const marker = 'showVsbpdfIframe(';
    final idx = html.indexOf(marker);
    if (idx < 0) return null;

    final after = html.substring(idx + marker.length);
    final trimmed = after.trimLeft();
    if (trimmed.isEmpty) return null;
    final quote = trimmed[0];
    if (quote != "'" && quote != '"') return null;

    final endQuote = trimmed.indexOf(quote, 1);
    if (endQuote < 0) return null;

    var pdfPath = trimmed.substring(1, endQuote);
    if (!pdfPath.startsWith('http')) {
      if (pdfPath.startsWith('/')) {
        pdfPath = '$_baseUrl$pdfPath';
      } else {
        pdfPath = '$_baseUrl/$pdfPath';
      }
    }
    return pdfPath;
  }

  String? _extractPreviewImageUrl(String html) {
    const marker = 'vsb_pdf_image_data';
    final idx = html.indexOf(marker);
    if (idx < 0) return null;

    final after = html.substring(idx + marker.length);
    final bracketStart = after.indexOf('[');
    if (bracketStart < 0) return null;

    final bracketEnd = after.indexOf(']', bracketStart);
    if (bracketEnd < 0) return null;

    final dataStr = after.substring(bracketStart + 1, bracketEnd).trim();
    var url = dataStr.trim();
    if (url.startsWith("'") || url.startsWith('"')) url = url.substring(1);
    if (url.endsWith("'") || url.endsWith('"')) url = url.substring(0, url.length - 1);
    url = url.trim();
    if (url.isEmpty) return null;

    return url.startsWith('http') ? url : '$_baseUrl$url';
  }

  void dispose() {
    _client.close();
  }

  static String get baseUrl => _baseUrl;
}
