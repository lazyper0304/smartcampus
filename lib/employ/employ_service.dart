import 'dart:convert';
import 'dart:io';

import '../core/data_cache.dart';

/// 招聘信息条目
class EmployJob {
  final String title;
  final String company;
  final String salary;
  final int views;
  final String detailUrl;

  EmployJob({
    required this.title,
    required this.company,
    required this.salary,
    required this.views,
    required this.detailUrl,
  });
}

/// 获取结果（含分页信息）
class EmployPageResult {
  final List<EmployJob> jobs;
  final int currentPage;
  final int totalPages;

  EmployPageResult({
    required this.jobs,
    required this.currentPage,
    required this.totalPages,
  });
}

/// 就业信息服务
class EmployService {
  static const String _baseUrl = 'https://zjc.yibinu.edu.cn';

  /// 获取一页招聘信息
  Future<EmployPageResult> fetchPage({int page = 1, bool forceRefresh = false}) async {
    final cacheKey = 'employ_page_$page';
    if (!forceRefresh) {
      final cached = DataCache().get<EmployPageResult>(cacheKey);
      if (cached != null) return cached;
    }

    final url = page <= 1
        ? '$_baseUrl/index/index/employjob.html'
        : '$_baseUrl/index/index/employjob.html?page=$page';

    final client = HttpClient()..badCertificateCallback = ((_, _, _) => true);
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36');
      final resp = await req.close().timeout(const Duration(seconds: 15));
      final body = await resp.transform(utf8.decoder).join();

      final jobs = <EmployJob>[];
      final seen = <String>{};

      // 匹配每个 item-group 内的招聘卡片
      final itemPattern = RegExp(
        r'''<div\s+class="item-group">\s*<a\s+href="([^"]*employjobdetail[^"]+)"[^>]*>.*?<h3>(.*?)</h3>.*?单位</span>\s*(.*?)</p>.*?薪资</span>\s*(.*?)</p>.*?浏览量\s*(\d+)''',
        dotAll: true,
      );

      for (final m in itemPattern.allMatches(body)) {
        var href = m.group(1)!;
        final title = m.group(2)!.trim();
        final company = m.group(3)!.trim();
        final salary = m.group(4)!.trim();
        final views = int.tryParse(m.group(5)?.trim() ?? '0') ?? 0;

        if (seen.contains(href)) continue;
        seen.add(href);

        // 补全 URL
        if (href.startsWith('/')) {
          href = '$_baseUrl$href';
        } else if (!href.startsWith('http')) {
          href = '$_baseUrl/$href';
        }

        jobs.add(EmployJob(
          title: title,
          company: company,
          salary: salary,
          views: views,
          detailUrl: href,
        ));
      }

      // 解析分页
      int totalPages = 1;
      final paginationMatch = RegExp(
        r'class="pagination"[^>]*>.*?</div>',
        dotAll: true,
      ).firstMatch(body);
      if (paginationMatch != null) {
        final paginationHtml = paginationMatch.group(0)!;
        final pageMatches = RegExp(r'page=(\d+)').allMatches(paginationHtml);
        for (final pm in pageMatches) {
          final n = int.tryParse(pm.group(1)!) ?? 0;
          if (n > totalPages) totalPages = n;
        }
      }

      final result = EmployPageResult(
        jobs: jobs,
        currentPage: page,
        totalPages: totalPages,
      );
      DataCache().set(cacheKey, result);
      return result;
    } finally {
      client.close(force: true);
    }
  }

  void dispose() {}
}
