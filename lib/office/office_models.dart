/// 办公网（= Bingo 后端「学校通知」`/notices`）数据模型
///
/// 数据源已从 `off.yibinu.edu.cn`（老式 ASP + GBK）切到 Bingo 代理，
/// 但**沿用原有 UI 模型**（`OfficeItem` / `OfficeDetail` / `OfficeAttachment`），
/// 使列表页/详情页/预览页的渲染代码零改动。
///
/// 栏目对应关系（Bingo `category` ⇄ 老站`b_id`）：
/// | Bingo category | 老站 b_id | 名称|
/// |---|---|---|
/// | `sup_doc` | 14 | 上级文件 |
/// | `party`   | 15 | 党委系统 |
/// | `admin`   | 16 | 行政系统 |
/// | `teaching`| 17 | 教学教辅 |
library;

/// 列表条目
class OfficeItem {
  /// 通知 ID（Bingo `/notices/{id}`），点击进详情用
  final int id;

  final String title;

  /// 老模型保留字段：Bingo 端无独立 URL，恒为空串
  final String url;

  /// 发布日期（已归一化为 `YYYY-MM-DD`）
  final String publishDate;

  /// 栏目 key（Bingo `category`）
  final String category;

  /// 栏目中文名（Bingo `category_label`）
  final String categoryLabel;

  /// 附件数量（> 0 时列表卡片显示附件角标）
  final int attachmentCount;

  /// 老模型保留字段：Bingo 端列表项不再区分「文件流 / 文章」
  bool get isFile => false;

  OfficeItem({
    required this.title,
    required this.url,
    required this.publishDate,
    this.id = 0,
    this.category = '',
    this.categoryLabel = '',
    this.attachmentCount = 0,
  });

  bool get hasAttachment => attachmentCount > 0;
}

/// 详情页中的附件
class OfficeAttachment {
  /// 附件 ID（Bingo `/notices/attachments/{id}/download`）
  final int id;

  final String name;

  /// 老模型保留字段：Bingo 附件走两跳预签名下载，无稳定直链
  final String url;

  /// 文件大小（字节，0 = 未知）
  final int size;

  OfficeAttachment({
    required this.name,
    required this.url,
    this.id = 0,
    this.size = 0,
  });

  String get displaySize {
    if (size <= 0) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

/// 文章详情
class OfficeDetail {
  final String title;
  final String publishDate;

  /// Bingo 通知无作者字段，恒为空串
  final String author;

  final List<String> paragraphs;
  final List<OfficeAttachment> attachments;

  /// 栏目 key / 中文名
  final String category;
  final String categoryLabel;

  OfficeDetail({
    required this.title,
    required this.publishDate,
    required this.author,
    required this.paragraphs,
    this.attachments = const [],
    this.category = '',
    this.categoryLabel = '',
  });
}

/// 栏目定义（Bingo `category`）
class OfficeColumn {
  final String key;
  final String label;
  const OfficeColumn({required this.key, required this.label});
}

/// 分页结果
///
/// 老模型用 `offset`（每页 +20）驱动翻页；Bingo 端为 `page`/`size` 页码制，
/// 这里把页码折算回 offset 语义，让列表页的 `_nextOffset == null` 判断逻辑不变。
class OfficeColumnResult {
  final List<OfficeItem> items;

  /// 下一页 offset；null 表示无更多页
  final int? nextOffset;

  /// 服务端可用栏目（首页 Tab 用）
  final List<OfficeColumn> columns;

  OfficeColumnResult({
    required this.items,
    this.nextOffset,
    this.columns = const [],
  });
}