import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:gbk_codec/gbk_codec.dart';

import '../core/data_cache.dart';
import 'office_models.dart';

/// 办公网栏目服务（ASP + GBK 编码，原生解析，不使用 WebView）
class OfficeService {
  static const String _baseUrl = 'http://off.yibinu.edu.cn';

  /// 四个栏目及其 b_id
  static const Map<int, String> columns = {
    14: '上级文件',
    15: '党委系统',
    16: '行政系统',
    17: '教学教辅',
  };

  /// 拉取某栏目列表（分页：offset 每页 +20）
  /// URL 显式携带 god=offset+1，完全贴合站点自身生成的链接格式
  /// （经实测 god 对内容无影响，但补齐可消除一切歧义）。
  Future<OfficeColumnResult> fetchColumn(int bId,
      {int offset = 0, bool forceRefresh = false}) async {
    final url =
        '$_baseUrl/list_b.asp?b_id=$bId&offset=$offset&god=${offset + 1}';
    final cacheKey = 'office_col_${bId}_$offset';
    if (!forceRefresh) {
      final cached = DataCache().get<OfficeColumnResult>(cacheKey);
      if (cached != null) return cached;
    }

    final client = HttpClient()..badCertificateCallback = ((_, _, _) => true);
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        ' (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );
      final resp = await req.close().timeout(const Duration(seconds: 15));
      final bytes = await _readBytes(resp);
      final body = _decodeGbk(bytes);

      final items = <OfficeItem>[];
      // 列表项结构：[YYYY-M-D] <A HREF="detail.asp?n_id=NN" ...>标题</A>
      // 或            [YYYY-M-D] <A HREF="showdoc.asp?id=NN" ...>标题</A>
      final pattern = RegExp(
        r'\[(\d{4})-(\d{1,2})-(\d{1,2})\]\s*'
        r'<A\s+HREF="([^"]+)"[^>]*>\s*(.*?)\s*</A>',
        dotAll: true,
        caseSensitive: false,
      );
      for (final m in pattern.allMatches(body)) {
        final year = m.group(1)!;
        final month = m.group(2)!;
        final day = m.group(3)!;
        final href = m.group(4)!;
        final title = m.group(5)!
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .replaceAll('&nbsp;', ' ')
            .trim();
        if (title.isEmpty) continue;

        final isFile = href.toLowerCase().contains('showdoc.asp');
        final fullUrl = _resolve(href);
        items.add(OfficeItem(
          title: title,
          url: fullUrl,
          publishDate: '$year-$month-$day',
          isFile: isFile,
        ));
      }

      final nextOffset = _parseNextOffset(body, offset);
      final result = OfficeColumnResult(items: items, nextOffset: nextOffset);
      DataCache().set(cacheKey, result);
      return result;
    } finally {
      client.close(force: true);
    }
  }

  /// 站内搜索（search.asp）。
  /// 关键点：查询词必须按 **GBK 字节** 做百分号编码（张 → %D5%C5），
  /// 而非 UTF-8；否则服务端无法识别（站点自身生成的链接即如此）。
  /// 分页步长为 offset +15（与栏目列表的 +20 不同）。
  Future<OfficeColumnResult> search(String keyword,
      {int offset = 0, bool forceRefresh = false}) async {
    // GBK 编码查询词 → 逐字节百分号化
    final gbk = gbk_bytes.encode(keyword); // List<int>
    final sss = gbk
        .map((b) => '%${b.toRadixString(16).toUpperCase().padLeft(2, '0')}')
        .join();
    const submit = '%CB%D1'; // “查” 的 GBK 编码
    final url =
        '$_baseUrl/search.asp?xxx=n_title&sss=$sss&Submit=$submit'
        '&offset=$offset&god=${offset + 1}';
    final cacheKey = 'office_search_${Uri.encodeComponent(keyword)}_$offset';
    if (!forceRefresh) {
      final cached = DataCache().get<OfficeColumnResult>(cacheKey);
      if (cached != null) return cached;
    }

    final client = HttpClient()..badCertificateCallback = ((_, _, _) => true);
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        ' (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );
      final resp = await req.close().timeout(const Duration(seconds: 15));
      final bytes = await _readBytes(resp);
      final body = _decodeGbk(bytes);

      final items = <OfficeItem>[];
      // 搜索结果结构与栏目列表不同：
      //   <A HREF="detail.asp?n_id=NN" ...>标题（可能含 <font color=red><b>词</b></font>）</A>
      //   其后紧跟 <font color="#999999">[YYYY-M-D]</font>
      final itemPat = RegExp(
        r'<A\s+HREF="(detail\.asp\?n_id=\d+|showdoc\.asp\?id=\d+)"'
        r'[^>]*>(.*?)</A>',
        dotAll: true,
        caseSensitive: false,
      );
      final datePat = RegExp(r'\[(\d{4})-(\d{1,2})-(\d{1,2})\]');
      for (final m in itemPat.allMatches(body)) {
        final href = m.group(1)!;
        final rawTitle = m.group(2)!;
        final title = rawTitle
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .replaceAll('&nbsp;', ' ')
            .trim();
        if (title.isEmpty) continue;
        // 日期紧跟在链接之后
        final dm = datePat.firstMatch(body.substring(m.end));
        final date = dm != null
            ? '${dm.group(1)}-${dm.group(2)}-${dm.group(3)}'
            : '';
        final isFile = href.toLowerCase().contains('showdoc.asp');
        items.add(OfficeItem(
          title: title,
          url: _resolve(href),
          publishDate: date,
          isFile: isFile,
        ));
      }

      final nextOffset = _parseNextOffset(body, offset);
      final result = OfficeColumnResult(items: items, nextOffset: nextOffset);
      DataCache().set(cacheKey, result);
      return result;
    } finally {
      client.close(force: true);
    }
  }

  /// 拉取文章详情（detail.asp）
  Future<OfficeDetail> fetchDetail(String url,
      {bool forceRefresh = false}) async {
    final cacheKey = 'office_detail_$url';
    if (!forceRefresh) {
      final cached = DataCache().get<OfficeDetail>(cacheKey);
      if (cached != null) return cached;
    }

    final client = HttpClient()..badCertificateCallback = ((_, _, _) => true);
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        ' (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );
      final resp = await req.close().timeout(const Duration(seconds: 15));
      final bytes = await _readBytes(resp);
      final body = _decodeGbk(bytes);

      // 标题：<b class="big">...</b>
      String title = '';
      final titleM = RegExp(r'<b[^>]*class="big"[^>]*>(.*?)</b>',
              dotAll: true, caseSensitive: false)
          .firstMatch(body);
      if (titleM != null) {
        title = titleM.group(1)!
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .replaceAll('&nbsp;', ' ')
            .trim();
      }

      // 日期：日期:<font ...>[2026-7-16]</font>
      String publishDate = '';
      final dateM = RegExp(r'日期:\s*<font[^>]*>\[?(\d{4}-\d{1,2}-\d{1,2})\]?',
              dotAll: true, caseSensitive: false)
          .firstMatch(body);
      if (dateM != null) publishDate = dateM.group(1)!;

      // 作者：文件作者:<font ...>院团委</font>
      String author = '';
      final authorM = RegExp(r'文件作者:\s*<font[^>]*>(.*?)</font>',
              dotAll: true, caseSensitive: false)
          .firstMatch(body);
      if (authorM != null) {
        author = authorM.group(1)!
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .trim();
      }

      // 正文：<td class="content" ...>...</td>
      final paragraphs = <String>[];
      final attachments = <OfficeAttachment>[];
      final contentIdx = body.indexOf('class="content"');
      if (contentIdx >= 0) {
        final tagStart = body.indexOf('>', contentIdx);
        if (tagStart >= 0) {
          final contentEnd = body.indexOf('</td>', tagStart);
          final contentHtml = body.substring(
              tagStart + 1, contentEnd < 0 ? body.length : contentEnd);

          // 附件链接可能直接位于 content td 内（不包在 <P> 中，
          // 如 <td class="content"><A href="wordfile/.../关于…pdf">…</A></td>），
          // 故先全量扫描整个 contentHtml，按 href 去重后加入附件列表。
          final attachHrefs = <String, String>{};
          for (final aM in RegExp(
                  r'<A\s+[^>]*HREF="([^"]+)"[^>]*>(.*?)</A>',
                  dotAll: true,
                  caseSensitive: false)
              .allMatches(contentHtml)) {
            final aHref = aM.group(1)!;
            final aText = aM.group(2)!
                .replaceAll(RegExp(r'<[^>]+>'), '')
                .trim();
            if (aText.isEmpty) continue;
            if (_isAttachment(aHref) || _isAttachment(aText)) {
              attachHrefs[aHref] = aText;
            }
          }
          for (final e in attachHrefs.entries) {
            attachments.add(OfficeAttachment(
              name: e.value,
              url: _resolve(e.key),
            ));
          }

          for (final p in RegExp(r'<P[^>]*>(.*?)</P>',
                  dotAll: true, caseSensitive: false)
              .allMatches(contentHtml)) {
            final inner = p.group(1)!;
            // 解析附件链接
            var hasAttachment = false;
            for (final aM in RegExp(
                    r'<A\s+[^>]*HREF="([^"]+)"[^>]*>(.*?)</A>',
                    dotAll: true, caseSensitive: false)
                .allMatches(inner)) {
              final aHref = aM.group(1)!;
              final aText = aM.group(2)!
                  .replaceAll(RegExp(r'<[^>]+>'), '')
                  .trim();
              if (aText.isEmpty) continue;
              if (_isAttachment(aHref) || _isAttachment(aText)) {
                hasAttachment = true;
              }
            }
            if (hasAttachment) continue;
            final text = inner
                .replaceAll(RegExp(r'<[^>]+>'), '')
                .replaceAll('&nbsp;', ' ')
                .replaceAll('&amp;', '&')
                .replaceAll('&quot;', '"')
                .trim();
            if (text.isNotEmpty) paragraphs.add(text);
          }
        }
      }

      final detail = OfficeDetail(
        title: title,
        publishDate: publishDate,
        author: author,
        paragraphs: paragraphs,
        attachments: attachments,
      );
      DataCache().set(cacheKey, detail);
      return detail;
    } finally {
      client.close(force: true);
    }
  }

  bool _isAttachment(String s) {
    return RegExp(r'\.(pdf|doc|docx|xls|xlsx|zip|rar|ppt|pptx|txt)$',
            caseSensitive: false)
        .hasMatch(s) ||
        s.contains('download') ||
        s.contains('filedown') ||
        s.contains('virtual_attach');
  }

  String _resolve(String href) {
    final full = href.startsWith('http')
        ? href
        : (href.startsWith('/') ? '$_baseUrl$href' : '$_baseUrl/$href');
    return _encodeUrl(full);
  }

  /// 对 URL 路径中的非 ASCII（如中文文件名）做百分号编码，
  /// 否则外部浏览器/下载器无法打开 wordfile/关于…pdf 这类含中文的附件。
  /// 已编码的段（含 %XX）跳过，避免二次编码。
  String _encodeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final encoded = uri.pathSegments.map((s) {
        if (RegExp(r'%[0-9A-Fa-f]{2}').hasMatch(s)) return s;
        return Uri.encodeComponent(s);
      }).join('/');
      return uri.replace(path: encoded).toString();
    } catch (_) {
      return url;
    }
  }

  Future<List<int>> _readBytes(HttpClientResponse resp) async {
    final chunks = <int>[];
    await for (final chunk in resp) {
      chunks.addAll(chunk);
    }
    return chunks;
  }

  String _decodeGbk(List<int> bytes) {
    try {
      return gbk_bytes.decode(bytes);
    } catch (_) {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  /// 从分页栏判断是否存在下一页，并返回下一页的**真实** offset。
  /// 机制（已实测）：
  ///  - 栏目列表 list_b.asp?b_id=XX&offset=N：每页 +20
  ///  - 站内搜索 search.asp?xxx=n_title&sss=..&offset=N：每页 +15
  ///  - god=offset+1 为站点模板冗余参数（服务端忽略）。
  /// 直接取分页栏中「大于当前 offset 的最小前向链接」作为下一页——
  /// 该链接在栏目列表场景 == current+20、在搜索场景 == current+15，无需写死步长。
  /// 无前向链接（已达末页，含 search 的 尾页 offset=-1 被 \d+ 忽略）即返回 null。
  int? _parseNextOffset(String body, int currentOffset) {
    final pager = RegExp(
      r'(?:list_b\.asp\?b_id=\d+|search\.asp\?xxx=[^"]*?)'
      r'&(amp;)?offset=(\d+)',
      caseSensitive: false,
    );
    var next = -1;
    for (final m in pager.allMatches(body)) {
      final off = int.tryParse(m.group(2)!) ?? -1;
      if (off > currentOffset && (next < 0 || off < next)) next = off;
    }
    return next < 0 ? null : next;
  }
}

class OfficeColumnResult {
  final List<OfficeItem> items;
  final int? nextOffset; // 下一页 offset；null 表示无更多页

  OfficeColumnResult({required this.items, this.nextOffset});
}
