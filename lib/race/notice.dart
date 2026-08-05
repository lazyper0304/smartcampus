import 'package:html/parser.dart' as html_parser;

/// 公示公告模型（scjx2 `/config/sys/baseNotice/*`）
///
/// 学科竞赛学生端首页的「公示公告」栏目接口：
/// - 列表：`POST /config/sys/baseNotice/listNoticeStuPage`
/// - 详情：`POST /config/sys/baseNotice/getNoticeById?notice_id=xxx`
/// - 附件：`https://scjx2.yibinu.edu.cn/uploadfile/config/notice/{notice_id}/{文件名}`

/// HTML 富文本 → 纯文本（公告正文展示用）
///
/// 服务端 content 为富文本（`<p>...<span>...`），可能混有纯文本形态，
/// 统一处理：含 '<' 走 HTML DOM 解析取 text，否则原样 trim。
String raceNoticeHtmlToText(String? s) {
  if (s == null || s.isEmpty) return '';
  if (!s.contains('<')) {
    return s.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
  try {
    final doc = html_parser.parse(s);
    final text = doc.body?.text ?? '';
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  } catch (_) {
    return s.replaceAll(RegExp(r'<[^>]+>'), '').trim();
  }
}

/// 公告列表项（`listNoticeStuPage` list 元素）
class RaceNotice {
  /// 公告 ID（详情接口 notice_id 参数）
  final String id;

  /// 标题
  final String subject;

  /// 正文摘要（HTML 富文本，列表页不展示，保留原始值）
  final String content;

  /// 是否置顶（1=置顶）
  final int top;

  /// 发布教师
  final String teacherName;

  /// 发布时间
  final String modifyTime;

  /// 可见对象（如 "学生,教师,管理角色"）
  final String form;

  /// 开始时间
  final String? startTime;

  /// 结束时间
  final String? endTime;

  const RaceNotice({
    required this.id,
    required this.subject,
    required this.content,
    required this.top,
    required this.teacherName,
    required this.modifyTime,
    required this.form,
    this.startTime,
    this.endTime,
  });

  factory RaceNotice.fromJson(Map<String, dynamic> json) {
    return RaceNotice(
      id: json['id']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      top: int.tryParse(json['top']?.toString() ?? '0') ?? 0,
      teacherName: json['teacher_name']?.toString() ?? '',
      modifyTime: json['modify_time']?.toString() ?? '',
      form: json['form']?.toString() ?? '',
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
    );
  }

  bool get isTop => top == 1;
}

/// 公告列表分页结果
class RaceNoticePageResult {
  final List<RaceNotice> list;
  final int totalCount;
  final int totalPage;
  final int currPage;
  final int pageSize;

  const RaceNoticePageResult({
    required this.list,
    required this.totalCount,
    required this.totalPage,
    required this.currPage,
    required this.pageSize,
  });

  factory RaceNoticePageResult.fromJson(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>? ?? {};
    final rows = result['list'] as List? ?? [];
    return RaceNoticePageResult(
      list: rows
          .map((r) => RaceNotice.fromJson(r as Map<String, dynamic>))
          .toList(),
      totalCount: (result['totalCount'] as num?)?.toInt() ?? 0,
      totalPage: (result['totalPage'] as num?)?.toInt() ?? 0,
      currPage: (result['currPage'] as num?)?.toInt() ?? 1,
      pageSize: (result['pageSize'] as num?)?.toInt() ?? 15,
    );
  }
}

/// 公告附件（详情 `baseNoticeAttachList` 元素）
class RaceNoticeAttach {
  /// 附件 ID
  final String id;

  /// 所属公告 ID
  final String noticeId;

  /// 文件名（含扩展名，如 `xxx.pdf`）
  final String documentName;

  const RaceNoticeAttach({
    required this.id,
    required this.noticeId,
    required this.documentName,
  });

  factory RaceNoticeAttach.fromJson(Map<String, dynamic> json) {
    return RaceNoticeAttach(
      id: json['id']?.toString() ?? '',
      noticeId: json['notice_id']?.toString() ?? '',
      documentName: json['document_name']?.toString() ?? '',
    );
  }

  bool get isPdf => documentName.toLowerCase().endsWith('.pdf');

  /// 附件下载/预览 URL
  ///
  /// 前端预览走 `#/CommonPreviewOpen?filetype=pdf&filepath=<双重URL编码>`，
  /// 真实文件地址即静态目录：`/uploadfile/config/notice/{notice_id}/{文件名}`。
  String fileUrl() {
    final encoded = Uri.encodeComponent(documentName);
    return 'https://scjx2.yibinu.edu.cn'
        '/uploadfile/config/notice/$noticeId/$encoded';
  }
}

/// 公告详情（`getNoticeById` result）
class RaceNoticeDetail {
  final String id;

  /// 标题
  final String subject;

  /// 正文（HTML 富文本）
  final String content;

  /// 是否置顶
  final int top;

  /// 发布教师
  final String teacherName;

  /// 发布时间
  final String modifyTime;

  /// 可见对象
  final String form;

  final String? startTime;
  final String? endTime;

  /// 附件列表
  final List<RaceNoticeAttach> attaches;

  const RaceNoticeDetail({
    required this.id,
    required this.subject,
    required this.content,
    required this.top,
    required this.teacherName,
    required this.modifyTime,
    required this.form,
    this.startTime,
    this.endTime,
    required this.attaches,
  });

  factory RaceNoticeDetail.fromJson(Map<String, dynamic> json) {
    final data = (json['result'] as Map<String, dynamic>?) ?? json;
    final attaches = (data['baseNoticeAttachList'] as List? ?? [])
        .map((e) => RaceNoticeAttach.fromJson(e as Map<String, dynamic>))
        .toList();
    return RaceNoticeDetail(
      id: data['id']?.toString() ?? '',
      subject: data['subject']?.toString() ?? '',
      content: data['content']?.toString() ?? '',
      top: int.tryParse(data['top']?.toString() ?? '0') ?? 0,
      teacherName: data['teacher_name']?.toString() ?? '',
      modifyTime: data['modify_time']?.toString() ?? '',
      form: data['form']?.toString() ?? '',
      startTime: data['start_time']?.toString(),
      endTime: data['end_time']?.toString(),
      attaches: attaches,
    );
  }

  bool get isTop => top == 1;
}
