// 校园网服务（nm.yibinu.edu.cn/xywfw.htm）数据模型
//
// 与资讯栏目（lib/news）相互独立：该站点列表/详情 HTML 结构不同
// （列表日期在 <span class="clock-ico">日期：yyyy-MM-dd</span>，
// 详情日期为「yyyy年MM月dd日」，附件走 download.jsp?wbfileid= 通道），
// 故单独建模块，不复用 ColumnService。

/// 列表条目
class CampusNetworkItem {
  final String title;
  final String url;
  final String date;

  const CampusNetworkItem({
    required this.title,
    required this.url,
    required this.date,
  });
}

/// 附件
class CampusNetworkAttachment {
  final String name;
  final String url;

  const CampusNetworkAttachment({required this.name, required this.url});
}

/// 详情
class CampusNetworkDetail {
  final String title;
  final String date;
  final String source;
  final List<ContentBlock> blocks;
  final List<CampusNetworkAttachment> attachments;

  const CampusNetworkDetail({
    required this.title,
    required this.date,
    required this.source,
    required this.blocks,
    this.attachments = const [],
  });
}

/// 内容块类型（与 news.dart 共用，保证渲染一致）
enum ContentBlockType { paragraph, image }

/// 有序内容块（保持图文原始顺序）
class ContentBlock {
  final ContentBlockType type;
  final String data;

  const ContentBlock({required this.type, required this.data});
}
