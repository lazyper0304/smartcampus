import 'dart:convert';
import 'dart:io';

import 'campus_network_service.dart';

/// 校园网服务栏目服务（nm.yibinu.edu.cn/xywfw.htm）
///
/// 与新闻 ColumnService 独立：本站列表/详情 HTML 结构不同，
/// 且附件走 download.jsp?wbfileid= 通道（无需登录态，可直接 GET 下载）。
class CampusNetworkService {
  static const String _baseUrl = 'https://nm.yibinu.edu.cn';

  /// 列表页地址（不同子栏目不同 URL：xywfw.htm=校园网服务 / dmtjsfw.htm=多媒体服务）
  final String listUrl;

  CampusNetworkService({this.listUrl = '$_baseUrl/xywfw.htm'});

  /// 抓取列表
  Future<List<CampusNetworkItem>> fetchList({bool forceRefresh = false}) async {
    final client = _newClient();
    try {
      final body = await _getBody(client, listUrl);

      final items = <CampusNetworkItem>[];
      final seen = <String>{};

      // 每个条目：<li ...><a href="info/1020/xxx.htm" title="...">...</li>
      for (final liM in RegExp(r'<li[^>]*>', dotAll: true).allMatches(body)) {
        final liStart = liM.start;
        final liEnd = body.indexOf('</li>', liStart);
        if (liEnd < 0) continue;
        final li = body.substring(liStart, liEnd + 5);

        // 仅处理本栏目（info/<栏目ID>/，如 1020 / 1022）
        final hrefM = RegExp(r'href="([^"]*info/\d+/[^"]*)"').firstMatch(li);
        if (hrefM == null) continue;
        final href = hrefM.group(1)!;
        if (seen.contains(href)) continue;
        seen.add(href);

        // 标题：优先 <a title>，否则取 <p> 文本
        String title = '';
        final titleM = RegExp(r'<a[^>]*title="([^"]+)"').firstMatch(li);
        if (titleM != null) {
          title = titleM.group(1)!.trim();
        }
        if (title.isEmpty) {
          final pM = RegExp(r'<p[^>]*>(.*?)</p>', dotAll: true).firstMatch(li);
          if (pM != null) {
            title = pM.group(1)!
                .replaceAll(RegExp(r'<[^>]+>'), '')
                .trim();
          }
        }
        if (title.isEmpty) continue;

        // 日期：<span class="clock-ico">日期：yyyy-MM-dd</span>
        String date = '';
        final dateM =
            RegExp(r'日期[:：]\s*(\d{4}-\d{2}-\d{2})').firstMatch(li);
        if (dateM != null) date = dateM.group(1)!;

        items.add(CampusNetworkItem(
          title: title,
          url: _resolveUrl(href, listUrl),
          date: date,
        ));
      }

      // 按日期倒序（最新在前）
      items.sort((a, b) => b.date.compareTo(a.date));
      return items;
    } finally {
      client.close(force: true);
    }
  }

  /// 抓取详情
  Future<CampusNetworkDetail> fetchDetail(String url) async {
    final client = _newClient();
    try {
      final body = await _getBody(client, url);

      // 标题：优先正文区 <div class="nry-tit"><h1>，兜底 <title>
      // （单页栏目如 wzfw.htm 的 <title> 是栏目名「网站服务」而非文章标题）
      String title = '';
      final h1M = RegExp(r'class="nry-tit"[\s\S]*?<h1[^>]*>([\s\S]*?)</h1>')
          .firstMatch(body);
      if (h1M != null) {
        title = h1M.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      }
      if (title.isEmpty) {
        final titleM = RegExp(r'<title>(.*?)</title>').firstMatch(body);
        title = (titleM?.group(1) ?? '')
            .replaceAll('-宜宾学院信息中心', '')
            .replaceAll('-宜宾学院', '')
            .trim();
      }

      // 详情日期：日期：yyyy年MM月dd日 HH:mm（info 详情页）
      // 或 日期： yyyy-MM-dd（单页栏目如 wzfw.htm）
      String date = '';
      final dM = RegExp(r'日期[:：]\s*(\d{4})年(\d{2})月(\d{2})日').firstMatch(body);
      if (dM != null) {
        date = '${dM.group(1)}-${dM.group(2)}-${dM.group(3)}';
      } else {
        final dM2 =
            RegExp(r'日期[:：]\s*(\d{4}-\d{2}-\d{2})').firstMatch(body);
        if (dM2 != null) date = dM2.group(1)!;
      }

      final sourceM = RegExp(r'来源[:：]\s*([^<\s][^<]*)').firstMatch(body);
      final source = sourceM?.group(1)?.trim() ?? '';

      // 正文容器：info 详情页为 class="v_news_content"；
      // 单页栏目（wzfw.htm）无该 class，退回 id="vsb_content"
      final blocks = <ContentBlock>[];
      int contentIdx = body.indexOf('class="v_news_content"');
      if (contentIdx < 0) contentIdx = body.indexOf('id="vsb_content"');
      String? contentHtml;
      if (contentIdx >= 0) {
        final divStart = body.indexOf('>', contentIdx);
        if (divStart >= 0) {
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
          if (contentEnd >= 0) {
            contentHtml = body.substring(divStart + 1, contentEnd);
          }
        }
      }
      if (contentHtml != null) _parseContent(contentHtml, blocks);

      // 附件：扫描全文 <a href> 含文件特征 / download.jsp / virtual_attach
      final attachments = <CampusNetworkAttachment>[];
      final seenAtt = <String>{};
      final attPattern = RegExp(
        r'\.(pdf|doc|docx|xls|xlsx|zip|rar|ppt|pptx|txt|jpg|jpeg|png|gif)',
        caseSensitive: false,
      );
      for (final aM in RegExp(r'<a\s+[^>]*href="([^"]+)"[^>]*>(.*?)</a>',
              dotAll: true)
          .allMatches(body)) {
        final aHref = aM.group(1)!;
        final aText =
            aM.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        if (aText.isEmpty) continue;
        final isAttach = attPattern.hasMatch(aHref) ||
            aHref.contains('download.jsp') ||
            aHref.contains('virtual_attach') ||
            aHref.contains('system_attach');
        if (!isAttach) continue;
        final full = _resolveUrl(aHref, url);
        if (seenAtt.contains(full)) continue;
        seenAtt.add(full);
        attachments.add(CampusNetworkAttachment(name: aText, url: full));
      }

      // vsb 内嵌 PDF 本体：只存在于 showVsbpdfIframe("<url>",...) 脚本参数
      // 或 <iframe src="...e=.pdf"> 中，页面上没有对应 <a> 标签，
      // 上面的扫描拿不到（如 VPN 管理办法 1023/7867 附件数为 0）。
      // 不做内容级去重：即使与 download.jsp 指向同一份文件也照常列出。
      for (final m in [
        RegExp(r'showVsbpdfIframe\("([^"]+)"').firstMatch(body),
        RegExp(r'<iframe[^>]*src="([^"]*e=\.pdf[^"]*)"').firstMatch(body),
      ]) {
        if (m == null) continue;
        final pdfUrl = _absolute(m.group(1)!);
        if (seenAtt.contains(pdfUrl)) continue;
        seenAtt.add(pdfUrl);
        attachments.add(CampusNetworkAttachment(
          name: '${title.isNotEmpty ? title : '文档'}.pdf',
          url: pdfUrl,
        ));
      }

      return CampusNetworkDetail(
        title: title,
        date: date,
        source: source,
        blocks: blocks,
        attachments: attachments,
      );
    } finally {
      client.close(force: true);
    }
  }

  static String _absolute(String src) {
    if (src.startsWith('http')) return src;
    return src.startsWith('/') ? '$_baseUrl$src' : '$_baseUrl/$src';
  }

  void _parseContent(String html, List<ContentBlock> blocks) {
    for (final m
        in RegExp(r'<p[^>]*>(.*?)</p>', dotAll: true).allMatches(html)) {
      final full = m.group(0)!;
      final inner = m.group(1)!;

      if (full.contains('vsbcontent_end')) continue;

      // vsb 内嵌 PDF 预览：脚本里的 vsb_pdf_image_data 是该 PDF 的
      // 逐页 JPG（网页端就是靠它渲染预览）。此前脚本被整体剔除，
      // 导致这类页面正文全空（如 VPN 管理办法 1023/7867），
      // 故先把逐页图提取为图片块内联展示。
      if (full.contains('vsb_pdf_image_data')) {
        final arrM =
            RegExp(r'vsb_pdf_image_data\s*=\s*\[(.*?)\]', dotAll: true)
                .firstMatch(full);
        if (arrM != null) {
          for (final s
              in RegExp(r'"([^"]+)"').allMatches(arrM.group(1)!)) {
            blocks.add(ContentBlock(
              type: ContentBlockType.image,
              data: _absolute(s.group(1)!),
            ));
          }
        }
        continue;
      }

      // 图片（含 vsb 图片占位）
      if (full.contains('vsbcontent_img') || full.contains('<img')) {
        for (final imgM
            in RegExp(r'<img[^>]*src="([^"]+)"').allMatches(full)) {
          blocks.add(ContentBlock(
              type: ContentBlockType.image, data: _absolute(imgM.group(1)!)));
        }
        continue;
      }

      // 去掉内联脚本 / 样式（vsb 内嵌 PDF 预览 showVsbpdfIframe 等），
      // 否则脚本源码会被当作正文渲染成乱码
      final text = inner
          .replaceAll(
              RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
          .replaceAll(
              RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '')
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

  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      ' (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// 流式下载附件到本地文件（无需登录态，直接 GET）
  ///
  /// 不把整包读进内存：本站附件存在超大文件（如网站服务的
  /// VSBBrowserHelperSetup.zip 约 70MB），全量 `List<int>` 累积会
  /// 因 int 装箱放大数倍内存，移动端极易 OOM。
  ///
  /// [onProgress] 回调 (已接收字节, 总字节)，总字节未知时为 -1。
  /// 返回文件头 4 字节，供调用方判定 PDF magic。
  static Future<List<int>> downloadToFile(
    String url,
    File target, {
    void Function(int received, int total)? onProgress,
  }) async {
    final client = HttpClient()..badCertificateCallback = (_, _, _) => true;
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', _ua);
      final resp = await req.close().timeout(const Duration(seconds: 30));
      final total = resp.contentLength;
      final sink = target.openWrite();
      final head = <int>[];
      int received = 0;
      try {
        await for (final chunk in resp) {
          sink.add(chunk);
          if (head.length < 4) {
            head.addAll(chunk.take(4 - head.length));
          }
          received += chunk.length;
          onProgress?.call(received, total);
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      return head;
    } finally {
      client.close(force: true);
    }
  }

  HttpClient _newClient() {
    final client = HttpClient()..badCertificateCallback = (_, _, _) => true;
    return client;
  }

  Future<String> _getBody(HttpClient client, String url) async {
    final req = await client.getUrl(Uri.parse(url));
    req.headers.set('User-Agent', _ua);
    final resp = await req.close().timeout(const Duration(seconds: 15));
    return await resp.transform(utf8.decoder).join();
  }

  String _resolveUrl(String href, String currentPageUrl) {
    if (href.startsWith('http')) return href;
    if (href.startsWith('/')) return '$_baseUrl$href';
    final uri = Uri.parse(currentPageUrl);
    return uri.resolve(href).toString();
  }
}
