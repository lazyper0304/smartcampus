import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/bingo/bingo_client.dart';
import '../core/bingo/bingo_config.dart';

/// 附件下载结果（路径供页面交给系统程序打开）
class BingoAttachmentDownload {
  final String path;
  final String fileName;
  const BingoAttachmentDownload({required this.path, required this.fileName});
}

/// Bingo 办公网（学校通知）服务（`/notices/*`）。
///
/// 替代原 `off.yibinu.edu.cn` 直连：老式 ASP + GBK 站点需自行处理编码、
/// 分页偏移与 `showdoc.asp` 二进制流；Bingo 后端已归一化为标准 JSON，
/// 附件统一走预签名 URL，两处易错点均消除。
class BingoOfficeService {
  BingoOfficeService._();

  static final BingoOfficeService instance = BingoOfficeService._();

  final BingoClient _client = BingoClient.instance;

  /// 通知列表。[page] 从 1 开始。
  Future<BingoNoticeList> fetchList({
    int page = 1,
    int size = 20,
    String? category,
    String? keyword,
  }) async {
    final q = keyword?.trim();
    final data = await _client.getMap('/notices', query: {
      'page': page,
      'size': size,
      if (category != null && category.isNotEmpty) 'category': category,
      if (q != null && q.isNotEmpty) ...{'q': q, 'scope': 'all'},
    });

    final items = (data['items'] as List<dynamic>? ?? const [])
        .map((e) => BingoNoticeItem.fromJson(
            e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)))
        .toList();
    final categories = (data['categories'] as List<dynamic>? ?? const [])
        .map((e) => BingoNoticeCategory.fromJson(
            e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)))
        .toList();

    return BingoNoticeList(
      items: items,
      total: (data['total'] as num?)?.toInt() ?? items.length,
      categories: categories,
    );
  }

  /// 通知详情（正文 + 附件清单）
  Future<BingoNoticeDetail> fetchDetail(int id) async {
    final data = await _client.getMap('/notices/$id');
    return BingoNoticeDetail.fromJson(data);
  }

  /// 下载附件到本地，返回文件路径（由页面用 `openFileWithSystem` 打开）。
  ///
  /// ⚠️ **两跳下载是必须的**：第一跳 `/notices/attachments/{id}/download`
  /// 只取 302 的 `Location`（预签名 OSS 地址），**不能**让客户端直接跟跳，
  /// 否则会把 `Authorization: Bearer` 带到 OSS，导致 OSS 返回 400。
  /// 第二跳单独请求预签名 URL，不带 Authorization、不带 Content-Type。
  Future<BingoAttachmentDownload> downloadAttachment(
    int attachmentId, {
    String? fallbackFileName,
  }) async {
    final dir = await getAttachmentDirectory();
    final fileName = sanitizeOfficeFileName(
      fallbackFileName?.trim().isNotEmpty == true
          ? fallbackFileName!.trim()
          : 'attachment',
    );
    final target = '$dir/$fileName';

    // 命中缓存则直接复用，避免重复下载
    final cached = File(target);
    if (await cached.exists() && await cached.length() > 0) {
      return BingoAttachmentDownload(path: target, fileName: fileName);
    }

    final stub = File('$dir/.office-dl-$attachmentId.part');
    if (await stub.exists()) await stub.delete();

    final first = await _client.download(
      '/notices/attachments/$attachmentId/download',
      noRedirect: true,
    );

    List<int> bytes;
    String? contentType;
    String? contentDisposition;

    if (first.isRedirect) {
      final location = first.location?.trim();
      if (location == null || location.isEmpty) {
        throw BingoException('附件下载未返回预签名地址');
      }
      final absolute = BingoConfig.uri('/').resolve(location).toString();
      final second = await _client.downloadDirect(absolute);
      if (!second.isSuccess) {
        throw BingoException('附件下载失败（HTTP ${second.statusCode}）');
      }
      bytes = second.bytes;
      contentType = second.contentType;
      contentDisposition = second.contentDisposition;
    } else {
      if (!first.isSuccess) {
        throw BingoException('附件下载失败（HTTP ${first.statusCode}）');
      }
      bytes = first.bytes;
      contentType = first.contentType;
      contentDisposition = first.contentDisposition;
    }

    if (bytes.isEmpty) {
      throw BingoException('附件内容为空');
    }

    await stub.writeAsBytes(bytes, flush: true);

    // 用响应头里的真实文件名覆盖兜底名
    final finalName = sanitizeOfficeFileName(
      resolveOfficeFileName(
        fallbackFileName: fileName,
        contentDisposition: contentDisposition,
        contentType: contentType,
      ),
    );
    final finalPath = '$dir/$finalName';
    if (stub.path != finalPath) {
      final target2 = File(finalPath);
      if (await target2.exists()) await target2.delete();
      await stub.rename(finalPath);
    }
    return BingoAttachmentDownload(path: finalPath, fileName: finalName);
  }

  /// 附件存放目录
  ///
  /// ⚠️ **必须用 `getApplicationSupportDirectory()`，不能用 `getApplicationDocumentsDirectory()`**。
  ///
  /// Android 上两者落点完全不同：
  /// - `getApplicationSupportDirectory()` → `context.getFilesDir()` → `/data/data/<pkg>/files/`
  /// - `getApplicationDocumentsDirectory()` → `context.getDir("flutter", MODE_PRIVATE)`
  ///   → `/data/data/<pkg>/app_flutter/`
  ///
  /// 关键在于**这两个目录是兄弟关系，不是父子**。而 `androidx.core.content.FileProvider`
  /// 的 `SimplePathStrategy` 只认 `getFilesDir`/`getCacheDir`/`getExternalFilesDir`/
  /// `getExternalCacheDir`/`getExternalStorageDirectory`/`getDataDirectory` 六类根，
  /// **没有任何标签能覆盖 `getDir()` 产生的目录**。因此文件落在 `app_flutter/` 下时，
  /// `FileProvider.getUriForFile()` 必然抛
  /// `IllegalArgumentException("Failed to find configured root that contains ...")`，
  /// 被 `MainActivity.openFile` catch 成 `OPEN_FAIL` → 界面提示「无法打开文件」。
  ///
  /// 曾误用 `<files-path>` 试图覆盖 `app_flutter/`，属方向性错误（兄弟目录无法被
  /// 兄弟根覆盖），详见 `office_file_paths.xml` 注释。
  Future<String> getAttachmentDirectory() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final officeDir = Directory('${dir.path}/office_attachments');
      if (!await officeDir.exists()) {
        await officeDir.create(recursive: true);
      }
      await _migrateLegacyAttachments(officeDir);
      return officeDir.path;
    } catch (e) {
      debugPrint('[Office] 附件目录创建失败，回退系统临时目录: $e');
      return Directory.systemTemp.path;
    }
  }

  /// 把旧版落在 `app_flutter/office_attachments` 的已下载附件搬到新目录，
  /// 避免用户升级后重复下载（下载走预签名 OSS，流量不可省）。
  ///
  /// 失败静默：新目录本身可正常下载，只是浪费一次流量，不该因此阻断打开。
  Future<void> _migrateLegacyAttachments(Directory target) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final legacyDir = Directory('${docs.path}/office_attachments');
      if (!await legacyDir.exists()) return;
      await for (final entity in legacyDir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (name.startsWith('.office-dl-')) continue;
        final dest = File('${target.path}/$name');
        if (await dest.exists()) continue;
        await entity.copy(dest.path);
        await entity.delete();
      }
      if (await legacyDir.list().isEmpty) await legacyDir.delete();
    } catch (e) {
      debugPrint('[Office] 旧附件目录迁移失败（可忽略）: $e');
    }
  }
}

/// 通知分类
class BingoNoticeCategory {
  final String key;
  final String label;
  const BingoNoticeCategory({this.key = '', this.label = ''});

  factory BingoNoticeCategory.fromJson(Map<String, dynamic> j) =>
      BingoNoticeCategory(
        key: j['key']?.toString() ?? '',
        label: j['label']?.toString() ?? '',
      );
}

/// 通知列表项
class BingoNoticeItem {
  final int id;
  final String category;
  final String categoryLabel;
  final String title;
  final String publishedAt;
  final int attachmentCount;
  final String? snippet;

  const BingoNoticeItem({
    this.id = 0,
    this.category = '',
    this.categoryLabel = '',
    this.title = '',
    this.publishedAt = '',
    this.attachmentCount = 0,
    this.snippet,
  });

  factory BingoNoticeItem.fromJson(Map<String, dynamic> j) => BingoNoticeItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        category: j['category']?.toString() ?? '',
        categoryLabel: j['category_label']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        publishedAt: j['published_at']?.toString() ?? '',
        attachmentCount: (j['attachment_count'] as num?)?.toInt() ?? 0,
        snippet: j['snippet'] as String?,
      );

  /// 是否含附件（列表页可显示附件角标）
  bool get hasAttachment => attachmentCount > 0;
}

/// 通知详情附件
class BingoNoticeAttachment {
  final int id;
  final String fileName;
  final int fileSize;

  const BingoNoticeAttachment({
    this.id = 0,
    this.fileName = '',
    this.fileSize = 0,
  });

  factory BingoNoticeAttachment.fromJson(Map<String, dynamic> j) =>
      BingoNoticeAttachment(
        id: (j['id'] as num?)?.toInt() ?? 0,
        fileName: j['file_name']?.toString() ?? '',
        fileSize: (j['file_size'] as num?)?.toInt() ?? 0,
      );

  String get displaySize {
    if (fileSize <= 0) return '';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

/// 通知详情
class BingoNoticeDetail {
  final int id;
  final String category;
  final String categoryLabel;
  final String title;
  final String content;
  final String publishedAt;
  final List<BingoNoticeAttachment> attachments;

  const BingoNoticeDetail({
    this.id = 0,
    this.category = '',
    this.categoryLabel = '',
    this.title = '',
    this.content = '',
    this.publishedAt = '',
    this.attachments = const [],
  });

  factory BingoNoticeDetail.fromJson(Map<String, dynamic> j) {
    // 后端可能把通知主体包在 notice 里，也可能直接平铺
    final notice = j['notice'] is Map<String, dynamic>
        ? j['notice'] as Map<String, dynamic>
        : j;
    final rawAtts = j['attachments'] as List<dynamic>? ?? const [];
    return BingoNoticeDetail(
      id: (notice['id'] as num?)?.toInt() ?? 0,
      category: notice['category']?.toString() ?? '',
      categoryLabel: j['category_label']?.toString() ?? '',
      title: notice['title']?.toString() ?? '',
      content: notice['content']?.toString() ?? '',
      publishedAt: notice['published_at']?.toString() ?? '',
      attachments: rawAtts
          .map((e) => BingoNoticeAttachment.fromJson(
              e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  /// 正文按空行拆段，便于详情页逐段渲染
  List<String> get paragraphs => content
      .split(RegExp(r'\n{2,}'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

class BingoNoticeList {
  final List<BingoNoticeItem> items;
  final int total;
  final List<BingoNoticeCategory> categories;
  const BingoNoticeList({
    this.items = const [],
    this.total = 0,
    this.categories = const [],
  });

  bool get hasMore => items.length < total;
}

// ==================== 文件名处理 ====================

/// 依据扩展名推断 MIME
String? officeMimeForName(String fileName) {
  final ext = officeExtension(fileName);
  switch (ext) {
    case '.pdf':
      return 'application/pdf';
    case '.doc':
      return 'application/msword';
    case '.docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case '.xls':
      return 'application/vnd.ms-excel';
    case '.xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case '.ppt':
      return 'application/vnd.ms-powerpoint';
    case '.pptx':
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case '.zip':
      return 'application/zip';
    case '.rar':
      return 'application/vnd.rar';
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.png':
      return 'image/png';
    case '.gif':
      return 'image/gif';
    case '.txt':
      return 'text/plain';
    case '.html':
    case '.htm':
      return 'text/html';
    default:
      return null;
  }
}

String officeExtension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return '';
  return fileName.substring(dot).toLowerCase();
}

/// 解析最终文件名：优先 `Content-Disposition` → 扩展名推断 → 兜底
String resolveOfficeFileName({
  String? fallbackFileName,
  String? contentDisposition,
  String? contentType,
}) {
  String? fromHeader;
  final cd = contentDisposition?.trim();
  if (cd != null && cd.isNotEmpty) {
    // filename*=UTF-8''xxx 优先（RFC 5987）
    final star = RegExp(r"filename\*\s*=\s*[^']*''([^;]+)", caseSensitive: false)
        .firstMatch(cd);
    if (star != null) {
      try {
        fromHeader = Uri.decodeComponent(star.group(1)!.trim());
      } catch (_) {
        fromHeader = star.group(1)!.trim();
      }
    } else {
      final plain = RegExp(r'filename\s*=\s*"?([^";]+)"?', caseSensitive: false)
          .firstMatch(cd);
      if (plain != null) fromHeader = plain.group(1)!.trim();
    }
  }
  if (fromHeader != null && fromHeader.isNotEmpty) return fromHeader;

  // 无文件名头：沿用兜底名，或按 MIME 造一个
  if (fallbackFileName != null && fallbackFileName.trim().isNotEmpty) {
    return fallbackFileName.trim();
  }
  final mime = contentType?.split(';').first.trim().toLowerCase();
  if (mime != null && mime.isNotEmpty) {
    for (final entry in {
      'application/pdf': 'document.pdf',
      'application/msword': 'document.doc',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
          'document.docx',
      'application/vnd.ms-excel': 'document.xls',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
          'document.xlsx',
      'application/vnd.ms-powerpoint': 'document.ppt',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation':
          'document.pptx',
      'application/zip': 'archive.zip',
      'image/jpeg': 'image.jpg',
      'image/png': 'image.png',
      'text/plain': 'document.txt',
    }.entries) {
      if (entry.key == mime) return entry.value;
    }
  }
  return 'attachment';
}

/// 清洗文件名：去除路径分隔符与控制字符
String sanitizeOfficeFileName(String name) {
  var cleaned = name.trim();
  cleaned = cleaned.replaceAll(RegExp(r'[\\/]+'), '_');
  cleaned = cleaned.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  cleaned = cleaned.replaceAll(RegExp(r'^\.+'), '');
  if (cleaned.isEmpty) cleaned = 'attachment';
  return cleaned;
}