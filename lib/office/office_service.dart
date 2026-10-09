import 'bingo_office_service.dart';
import 'office_models.dart';

/// 办公网服务（数据源：Bingo 后端 `/notices/*`）。
///
/// ## 为什么不再直连 off.yibinu.edu.cn
/// 老站是 ASP + GBK 编码，客户端要自己处理编码、分页偏移，以及两类形态完全
/// 不同的附件（`wordfile/...pdf` 与 `showdoc.asp?id=N` 直返 PDF 字节流），
/// 其中「[阅读附件]」锚点还藏在标题区 `div` 而非 `td.content` 里，漏判就让
/// 整批公文附件消失。Bingo 后端已归一化为标准 JSON，附件统一走预签名 URL，
/// 这些坑全部消除。
///
/// ## 签名兼容性
/// 保留了原`fetchColumn(bId, offset:)` / `search(keyword, offset:)` /
/// `fetchDetail(url)` 的调用形态，列表页与详情页零改动：
/// - `bId` 改为按 [bIdToCategory] 映射到 Bingo `category`（数值语义保留）；
/// - `offset` 折算为页码（`offset / pageSize + 1`）；
/// - `fetchDetail` 的 `url` 改为传通知 ID（[fetchDetailById]），旧签名保留为
///   兼容入口。
class OfficeService {
  /// 四个栏目及其老站 `b_id`（保留供 UI 展示顺序与 Tab 数量）
  static const Map<int, String> columns = {
    14: '上级文件',
    15: '党委系统',
    16: '行政系统',
    17: '教学教辅',
  };

  /// 每页条数（与老站 `list_b.asp` 每页 20 条一致）
  static const int pageSize = 20;

  /// 老站 `b_id` → Bingo `category`
  static const Map<int, String> bIdToCategory = {
    14: 'sup_doc',
    15: 'party',
    16: 'admin',
    17: 'teaching',
  };

  /// Bingo `category` → 老站 `b_id`（反向，供详情页/搜索页定位栏目）
  static const Map<String, int> categoryToBId = {
    'sup_doc': 14,
    'party': 15,
    'admin': 16,
    'teaching': 17,
  };

  /// 默认栏目（首页 Tab 兜底；正常由服务端 `categories` 驱动）
  static List<OfficeColumn> get defaultColumns => const [
        OfficeColumn(key: 'sup_doc', label: '上级文件'),
        OfficeColumn(key: 'party', label: '党委系统'),
        OfficeColumn(key: 'admin', label: '行政系统'),
        OfficeColumn(key: 'teaching', label: '教学教辅'),
      ];

  BingoOfficeService get _bingo => BingoOfficeService.instance;

  /// 拉取某栏目列表（[offset] 每页 +20，保持老接口语义）
  Future<OfficeColumnResult> fetchColumn(int bId,
      {int offset = 0, bool forceRefresh = false}) {
    return _list(category: bIdToCategory[bId], offset: offset);
  }

  /// 按栏目 key 拉取列表（Bingo `category`）
  Future<OfficeColumnResult> fetchColumnByCategory(String category,
          {int offset = 0, bool forceRefresh = false}) =>
      _list(category: category, offset: offset);

  /// 搜索通知（[offset] 语义同 [fetchColumn]）
  Future<OfficeColumnResult> search(String keyword,
      {int offset = 0, bool forceRefresh = false}) =>
      _list(category: null, offset: offset, keyword: keyword);

  Future<OfficeColumnResult> _list({
    String? category,
    required int offset,
    String? keyword,
  }) async {
    final page = offset ~/ pageSize + 1;
    final res = await _bingo.fetchList(
      page: page,
      size: pageSize,
      category: category,
      keyword: keyword,
    );
    // 折算回 offset 语义：满页才可能有下一页
    final nextOffset = res.hasMore ? (page) * pageSize : null;
    return OfficeColumnResult(
      items: res.items.map(_toItem).toList(),
      nextOffset: nextOffset,
      columns: res.categories.isEmpty
          ? defaultColumns
          : res.categories
              .map((c) => OfficeColumn(key: c.key, label: c.label))
              .toList(),
    );
  }

  /// 通知详情。[id] 为 Bingo `/notices/{id}` 的通知 ID。
  Future<OfficeDetail> fetchDetailById(int id) async {
    final d = await _bingo.fetchDetail(id);
    return OfficeDetail(
      title: d.title,
      publishDate: formatOfficeDate(d.publishedAt),
      author: '',
      paragraphs: d.paragraphs,
      category: d.category,
      categoryLabel: d.categoryLabel,
      attachments: d.attachments
          .map((a) => OfficeAttachment(
                name: a.fileName.isEmpty ? '附件' : a.fileName,
                url: '',
                id: a.id,
                size: a.fileSize,
              ))
          .toList(),
    );
  }

  /// 兼容入口：[url] 传纯数字时按通知 ID 处理
  @Deprecated('请改用 fetchDetailById —— Bingo 端通知以 ID 定位，无 URL')
  Future<OfficeDetail> fetchDetail(String url,
      {bool forceRefresh = false}) {
    final id = int.tryParse(url.trim());
    if (id == null) {
      throw Exception('通知标识无效：$url');
    }
    return fetchDetailById(id);
  }

  /// 下载附件到本地，返回可交给 `openFileWithSystem` 的路径
  ///
  /// [BingoOfficeService.downloadAttachment] 内部已实现两跳下载
  /// （先取 302 预签名地址，再无 Authorization 单独取 OSS 对象），
  /// 必须整体复用，不要自己拼 URL。
  Future<String> downloadAttachment(OfficeAttachment a) async {
    if (a.id <= 0) throw Exception('附件缺少 ID，无法下载');
    final res = await _bingo.downloadAttachment(a.id,
        fallbackFileName: a.name);
    return res.path;
  }

  /// 附件下载后的规范文件名
  Future<String> attachmentFileName(OfficeAttachment a) async {
    if (a.id <= 0) return a.name;
    final res = await _bingo.downloadAttachment(a.id,
        fallbackFileName: a.name);
    return res.fileName;
  }

  /// 栏目列表（首页 Tab 用；服务端未下发时回退 [defaultColumns]）
  Future<List<OfficeColumn>> fetchColumns() async {
    try {
      final res = await _bingo.fetchList(page: 1, size: 1);
      if (res.categories.isEmpty) return defaultColumns;
      return res.categories
          .map((c) => OfficeColumn(key: c.key, label: c.label))
          .toList();
    } catch (_) {
      return defaultColumns;
    }
  }

  // ==================== 内部转换 ====================

  OfficeItem _toItem(BingoNoticeItem n) => OfficeItem(
        id: n.id,
        title: n.title,
        url: '',
        publishDate: formatOfficeDate(n.publishedAt),
        category: n.category,
        categoryLabel: n.categoryLabel,
        attachmentCount: n.attachmentCount,
      );
}

/// 归一化日期为 `YYYY-MM-DD`；无法解析时原样返回
String formatOfficeDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return '';
  final d = DateTime.tryParse(s);
  if (d == null) {
    // 兼容 `2026-7-14` / `2026/7/14` 这类无补零写法
    final m = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(s);
    if (m == null) return s;
    return '${m.group(1)}-${m.group(2)!.padLeft(2, '0')}-'
        '${m.group(3)!.padLeft(2, '0')}';
  }
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}