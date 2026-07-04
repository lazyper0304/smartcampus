/// 新闻条目
class NewsItem {
  final String title;
  final String url;
  final String publishDate;

  NewsItem({
    required this.title,
    required this.url,
    required this.publishDate,
  });
}

/// 内容块类型
enum ContentBlockType { paragraph, image, attachment }

/// 有序内容块（保持图文原始顺序）
class ContentBlock {
  final ContentBlockType type;
  final String data; // 段落文本、图片URL 或 附件描述

  ContentBlock({required this.type, required this.data});
}

/// 附件信息
class AttachmentInfo {
  final String name;
  final String url;

  AttachmentInfo({required this.name, required this.url});
}

/// 新闻详情
class NewsDetail {
  final String title;
  final String publishDate;
  final String source;
  final List<ContentBlock> blocks;
  final List<AttachmentInfo> attachments;

  NewsDetail({
    required this.title,
    required this.publishDate,
    required this.source,
    required this.blocks,
    this.attachments = const [],
  });
}
