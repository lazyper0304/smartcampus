/// 办公网（off.yibinu.edu.cn）数据模型
///
/// 该站为老式 ASP + GBK 编码系统，无 CAS、无登录。
/// 栏目列表项分两类：
///  - detail.asp?n_id=NN  → HTML 文章详情（原生解析渲染）
///  - showdoc.asp?id=NN    → 直接返回 PDF 二进制流（视为文件，外部打开）
library;

/// 列表条目
class OfficeItem {
  final String title;
  final String url;
  final String publishDate; // 形如 2026-7-14（无前导零）
  final bool isFile; // true 表示 showdoc.asp（PDF 文件流，外部打开）

  OfficeItem({
    required this.title,
    required this.url,
    required this.publishDate,
    this.isFile = false,
  });
}

/// 详情页中的附件
class OfficeAttachment {
  final String name;
  final String url;

  OfficeAttachment({required this.name, required this.url});
}

/// 文章详情（detail.asp 解析结果）
class OfficeDetail {
  final String title;
  final String publishDate;
  final String author;
  final List<String> paragraphs;
  final List<OfficeAttachment> attachments;

  OfficeDetail({
    required this.title,
    required this.publishDate,
    required this.author,
    required this.paragraphs,
    this.attachments = const [],
  });
}
