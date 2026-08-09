import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'qxfacx.dart';

/// 培养方案 PDF 生成器
///
/// 用 `pdf` 包将 [QxFacxPlan]（基本信息/培养目标/修读要求/课程组树）排版为
/// A4 PDF。pdf 包默认字体无中文字形，**内置字体优先**：
/// 优先加载 assets/fonts/simhei.ttf（标准 TTF，跨平台一致）；
/// 失败才回退系统字体（Windows simhei/msyh；Android DroidSansFallback —
/// 注意 Android 现代系统多为 .ttc，ttf_parser 不支持会报
/// "Unable to find the head table"，因此必须内置字体兜底，2026-08-09）。
///
/// 找不到可用字体时抛异常，由调用方提示用户。
class QxFacxPdfGenerator {
  /// 内置字体 asset 路径（pubspec 已注册）
  static const String _assetFontPath = 'assets/fonts/simhei.ttf';

  /// 生成 PDF 字节（内存，不落盘）
  static Future<Uint8List> generate({
    required QxFacxPlan plan,
    required List<QxFacxKz> kzList,
    required Map<String, List<QxFacxKzCourse>> coursesByKzh,
  }) async {
    final font = await _loadFont();

    // 构建课程组树（FKZH ↔ KZH）
    final childrenByParent = <String, List<QxFacxKz>>{};
    for (final g in kzList) {
      childrenByParent.putIfAbsent(g.fkzh, () => []).add(g);
    }
    final tops = childrenByParent['-1'] ?? <QxFacxKz>[];

    final doc = pw.Document();
    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 40),
      theme: pw.ThemeData.withFont(
        base: font,
        bold: font,
        fontFallback: [font],
      ),
    );

    // 全内容放一个 MultiPage：自动分页
    // ⚠️ maxPages 默认仅 20，培养方案课程组树 + 全部课程很容易超过
    // （报 PdfTooBigPage）；调大上限，保留防布局死循环断言
    doc.addPage(
      pw.MultiPage(
        maxPages: 500,
        pageTheme: pageTheme,
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                '第 ${ctx.pageNumber} 页 / 共 ${ctx.pagesCount} 页',
                style: pw.TextStyle(
                    fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
        build: (ctx) => [
          // ── 标题 ──
          pw.Center(
            child: pw.Text('宜宾学院培养方案',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(plan.name,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 12),
          pw.Divider(color: PdfColors.grey400, thickness: 0.8),

          // ── 基本信息表 ──
          pw.SizedBox(height: 8),
          _sectionTitle('基本信息'),
          _infoTableForPlan(plan),

          // ── 文本区块 ──
          if (plan.pymbText.isNotEmpty) ...[
            _sectionTitle('培养目标'),
            _paragraph(plan.pymbText),
          ],
          if (plan.xdyqText.isNotEmpty) ...[
            _sectionTitle('修读要求'),
            _paragraph(plan.xdyqText),
          ],
          if (plan.zgxkText.isNotEmpty) ...[
            _sectionTitle('主干学科'),
            _paragraph(plan.zgxkText),
          ],
          if (plan.zgkcText.isNotEmpty) ...[
            _sectionTitle('主干课程'),
            _paragraph(plan.zgkcText),
          ],
          if (plan.zyzysyText.isNotEmpty) ...[
            _sectionTitle('主要专业实验'),
            _paragraph(plan.zyzysyText),
          ],
          if (plan.fatsText.isNotEmpty) ...[
            _sectionTitle('方案特色'),
            _paragraph(plan.fatsText),
          ],

          // ── 课程设置 ──
          if (kzList.isNotEmpty) ...[
            _sectionTitle('课程设置（${kzList.length} 个课组）'),
            pw.SizedBox(height: 2),
            // 扁平化为行级元素（MultiPage 逐行分页，避免超大 Column 死循环）
            for (final top in tops)
              ..._flattenGroup(top, childrenByParent, coursesByKzh, 0),
          ],

          // ── 审核信息 ──
          if (plan.shyj.isNotEmpty ||
              plan.czrxm.isNotEmpty ||
              plan.czsj.isNotEmpty) ...[
            _sectionTitle('审核信息'),
            _infoTable([
              if (plan.shyj.isNotEmpty) ('审核意见', plan.shyj),
              if (plan.czrxm.isNotEmpty) ('操作人', plan.czrxm),
              if (plan.czsj.isNotEmpty) ('操作时间', plan.czsj),
            ]),
          ],
        ],
      ),
    );

    return doc.save();
  }

  // ==================== 排版组件 ====================

  static pw.Widget _sectionTitle(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: PdfColors.blueGrey700, width: 3),
        ),
      ),
      child: pw.Padding(
        padding: const pw.EdgeInsets.only(left: 8),
        child: pw.Text(title,
            style: pw.TextStyle(
                fontSize: 13, fontWeight: pw.FontWeight.bold)),
      ),
    );
  }

  static pw.Widget _paragraph(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 10.5, height: 1.6)),
    );
  }

  static pw.Widget _infoTable(List<(String, String)> entries) {
    final valid = entries.where((e) => e.$2.isNotEmpty).toList();
    if (valid.isEmpty) return pw.SizedBox.shrink();
    return pw.TableHelper.fromTextArray(
      headers: const ['项目', '内容'],
      data: [
        for (final e in valid) [e.$1, e.$2],
      ],
      headerStyle: pw.TextStyle(
          fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: pw.BoxDecoration(color: PdfColors.blueGrey700),
      cellStyle: pw.TextStyle(fontSize: 9.5, height: 1.4),
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(90),
        1: const pw.FlexColumnWidth(),
      },
    );
  }

  static pw.Widget _infoTableForPlan(QxFacxPlan plan) {
    return _infoTable([
      ('方案代码', plan.pyfadm),
      ('年级', plan.njdDisplay.isNotEmpty ? plan.njdDisplay : plan.njd),
      ('院系', plan.dwdmDisplay),
      ('专业', plan.zydmDisplay),
      ('专业方向', plan.zyfxdDisplay),
      ('修读类型', plan.xdlxdmDisplay),
      ('学期类型', plan.xqlxdmDisplay),
      ('学制', plan.xznx > 0 ? '${plan.xznx} 年' : ''),
      ('学位', plan.xwdmDisplay),
      ('开始学年', plan.ksxndmDisplay),
      ('开始学期', plan.ksxqdmDisplay),
      ('最少要求学分', plan.zsyqxf > 0 ? '${_numText(plan.zsyqxf)} 学分' : ''),
    ]);
  }

  /// 递归扁平化课组为**行级可分页元素列表**（MultiPage 逐项分页）
  ///
  /// ⚠️ 不能把整个课组树包成单个 Column：顶级平台（如通识教育平台）下
  /// 几十课组 + 几百门课程的总高度远超一页，MultiPage 无法拆分单个 child，
  /// 会在同一页反复尝试直到 maxPages 上限（PdfTooBigPage，2026-08-09）。
  /// 因此每个课组标题、每条元信息、每门课程行都是独立 child。
  static List<pw.Widget> _flattenGroup(
    QxFacxKz g,
    Map<String, List<QxFacxKz>> childrenByParent,
    Map<String, List<QxFacxKzCourse>> coursesByKzh,
    int depth,
  ) {
    final children = childrenByParent[g.kzh] ?? const <QxFacxKz>[];
    final groupCourses = coursesByKzh[g.kzh] ?? const <QxFacxKzCourse>[];

    final out = <pw.Widget>[];

    // 组标题行（独立 child）
    out.add(
      pw.Container(
        margin: pw.EdgeInsets.only(left: (depth * 14).toDouble(), top: 4),
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        decoration: pw.BoxDecoration(
          color: g.isTop ? PdfColors.blueGrey100 : PdfColors.grey200,
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6),
          child: pw.Row(
            children: [
              pw.Text('[${g.typeLabel}]',
                  style: pw.TextStyle(
                      fontSize: 9, color: PdfColors.blueGrey800,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Text(g.kzm,
                    style: pw.TextStyle(
                        fontSize: 10.5,
                        fontWeight: g.isTop
                            ? pw.FontWeight.bold
                            : pw.FontWeight.normal)),
              ),
              if (g.zsxdxf > 0)
                pw.Text('≥${_numText(g.zsxdxf)}学分',
                    style: pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey700)),
            ],
          ),
        ),
      ),
    );

    // 组元信息（每条独立 child）
    final meta = <String>[
      if (g.kcxF > 0 || g.kcxS > 0 || g.kczms > 0)
        '组内 ${_numText(g.kcxF)} 学分 · ${_numText(g.kcxS)} 学时 · ${_numText(g.kczms)} 门',
      if (g.kcxzdmDisplay.isNotEmpty) '课程性质：${g.kcxzdmDisplay}',
      if (g.xdyq.isNotEmpty) '修读要求：${g.xdyq}',
    ];
    for (final line in meta) {
      out.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(left: (depth * 14 + 8).toDouble(), top: 2),
          child: pw.Text(line,
              style: pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey700, height: 1.4)),
        ),
      );
    }

    // 组内课程：表头 + 每门课程独立一行 Table
    if (groupCourses.isNotEmpty) {
      out.add(_courseHeader(depth));
      for (final c in groupCourses) {
        out.add(_courseRow(c, depth));
      }
    }

    // 子组（递归）
    for (final child in children) {
      out.addAll(
          _flattenGroup(child, childrenByParent, coursesByKzh, depth + 1));
    }
    return out;
  }

  /// 课程表头（独立 child，可跨页重复表头）
  static pw.Widget _courseHeader(int depth) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(left: (depth * 14 + 8).toDouble(), top: 4),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
        columnWidths: _courseColWidths(),
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColors.blueGrey600),
            children: [
              for (final h in const ['课程', '课程号', '学分', '学时', '性质', '考试', '学期'])
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 3, vertical: 2),
                  child: pw.Text(h,
                      style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 单门课程行（独立 child：单行 Table 高度远小于一页，MultiPage 可安全分页）
  static pw.Widget _courseRow(QxFacxKzCourse c, int depth) {
    String cell(String s) =>
        s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return pw.Padding(
      padding: pw.EdgeInsets.only(left: (depth * 14 + 8).toDouble(), top: 1),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
        columnWidths: _courseColWidths(),
        children: [
          pw.TableRow(
            children: [
              pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                child: pw.Text(cell(c.kcm),
                    style: pw.TextStyle(fontSize: 8.5, height: 1.3)),
              ),
              _courseCell(cell(c.kch)),
              _courseCell(cell(c.xf)),
              _courseCell(cell(c.xs)),
              _courseCell(cell(c.kcxzdmDisplay)),
              _courseCell(cell(c.kslxdmDisplay)),
              _courseCell(
                  cell(c.xnxqDisplay.replaceFirst('学年', '').replaceFirst(' 第', ' · 第'))),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _courseCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 8.5, height: 1.3)),
    );
  }

  static Map<int, pw.TableColumnWidth> _courseColWidths() => {
        0: const pw.FlexColumnWidth(),
        1: const pw.FixedColumnWidth(70),
        2: const pw.FixedColumnWidth(34),
        3: const pw.FixedColumnWidth(34),
        4: const pw.FixedColumnWidth(40),
        5: const pw.FixedColumnWidth(40),
        6: const pw.FixedColumnWidth(70),
      };

  // ==================== 字体加载 ====================

  /// 加载中文字体：**优先内置 asset（标准 TTF）**，失败回退系统候选
  static Future<pw.Font> _loadFont() async {
    final errors = <String>[];

    // 1. 内置字体（跨平台一致，已注册 pubspec assets）
    try {
      final data = await rootBundle.load(_assetFontPath);
      return pw.Font.ttf(data);
    } catch (e) {
      errors.add('asset $_assetFontPath: $e');
    }

    // 2. 系统字体回退
    for (final path in _fontCandidates()) {
      try {
        final f = File(path);
        if (!f.existsSync()) continue;
        final bytes = await f.readAsBytes();
        // 尝试解析为 TTF；TTC（ttcf 头）解析失败会抛异常 → 回退下一个候选
        return pw.Font.ttf(ByteData.view(bytes.buffer));
      } catch (e) {
        errors.add('$path: $e');
      }
    }
    throw Exception('未找到可用的中文字体，无法生成 PDF。\n已尝试: $errors');
  }

  static List<String> _fontCandidates() {
    if (Platform.isWindows) {
      return [
        r'C:\Windows\Fonts\simhei.ttf', // 黑体（单 TTF）
        r'C:\Windows\Fonts\msyh.ttc', // 微软雅黑（TTC，可能解析失败）
        r'C:\Windows\Fonts\simsun.ttc',
      ];
    }
    if (Platform.isAndroid) {
      return [
        '/system/fonts/DroidSansFallback.ttf',
        '/system/fonts/NotoSansCJK-Regular.ttc',
        '/system/fonts/NotoSansSC-Regular.otf',
      ];
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return [
        '/System/Library/Fonts/PingFang.ttc',
        '/System/Library/Fonts/STHeiti Light.ttc',
        '/System/Library/Fonts/Hiragino Sans GB.ttc',
      ];
    }
    // Linux
    return [
      '/usr/share/fonts/truetype/wqy/wqy-microhei.ttc',
      '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    ];
  }

  static String _numText(double v) {
    return v == v.truncateToDouble() ? '${v.toInt()}' : '$v';
  }
}
