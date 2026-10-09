import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/ios_kit.dart';
import '../core/simple_page.dart';
import '../core/theme_utils.dart';
import 'ecard_controller.dart';
import 'ecard_service.dart';

/// 卡片信息页：卡片信息 / 卡面管理 / 账户三段。
///
/// 参考实现：
/// `E:/project/YibinApp/Flutter/.../ecard_card_detail_page.dart`
/// 差异：本项目无 Riverpod，改为由 [EcardController] 注入并在页内自建实例
/// （数据与主页面共享缓存，但生命周期独立，避免主页 dispose 影响本页）。
class EcardCardDetailPage extends StatefulWidget {
  /// 由主页面传入的共享 Controller（含同一份 state）；
  /// 为 null 时自建（独立使用）。
  final EcardController? controller;

  const EcardCardDetailPage({super.key, this.controller});

  @override
  State<EcardCardDetailPage> createState() => _EcardCardDetailPageState();
}

class _EcardCardDetailPageState extends State<EcardCardDetailPage> {
  late final EcardController _controller =
      widget.controller ?? EcardController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.loadCardFaces();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SimplePage(
      // ⚠️ 文字装饰兜底：无 Material 祖先时可能继承带下划线的DefaultTextStyle
      // （详见 ecard_page.dart 同处注释）
      child: DefaultTextStyle(
        style: TextStyle(
          decoration: TextDecoration.none,
          color: textPrimary(context),
        ),
        child: SafeArea(
        top: false,
        bottom: false,
        child: ListenableBuilder(
          listenable: _controller.state,
          builder: (context, _) {
            final s = _controller.state;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _section(context, '卡片', [
                  _row(context, '卡名称', '校园一卡通'),
                  _row(context, '发卡机构', '宜宾学院后勤管理处'),
                ]),
                const SizedBox(height: 20),
                _section(context, '账户', [
                  _row(context, '今日消费',
                      s.overview == null ? '-' : s.overview!.todaySpent.toStringAsFixed(2)),
                  _row(context, '本月消费',
                      s.overview == null ? '-' : s.overview!.monthSpent.toStringAsFixed(2)),
                  _row(context, '余额',
                      s.overview == null ? '-' : s.overview!.balance.toStringAsFixed(2)),
                  _row(context, '数据更新时间',
                      (s.overview?.lastUpdated.isNotEmpty ?? false)
                          ? s.overview!.lastUpdated
                          : '-'),
                ]),
                const SizedBox(height: 20),
                _buildFaceSection(context, s),
              ],
            );
          },
          ),
        ),
      ),
    );
  }

  Widget _buildFaceSection(BuildContext context, EcardState s) {
    final faces = s.cardFaces.faces;
    if (faces.isEmpty) {
      return _section(context, '卡面管理', [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(s.cardFaceLoading ? '加载中...' : '暂无可选卡面',
                style: TextStyle(fontSize: 14, color: textSecondary(context))),
          ),
        ),
      ]);
    }
    return _section(context, '卡面管理', [
      for (final f in faces)
        _faceRow(
          context,
          f,
          s.cardFaces.displayId,
          s.cardFacePaths[f.id],
          s.cardFaceLoading,
        ),
    ]);
  }

  Widget _faceRow(
    BuildContext context,
    EcardCardFaceMeta face,
    int displayId,
    String? filePath,
    bool loading,
  ) {
    final primary = textPrimary(context);
    final secondary = textSecondary(context);
    final selected = face.id == displayId;
    final file = filePath == null ? null : File(filePath);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: loading
          ? null
          : () async {
              final ok = await _controller.selectCardFace(face.id);
              if (!context.mounted) return;
              if (!ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('卡面切换失败，请稍后重试')),
                );
              }
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 72,
                height: 45,
                child: (file != null && file.existsSync())
                    ? Image.file(file, fit: BoxFit.cover)
                    : Image.asset(
                        'assets/images/ecard/default_card_face.webp',
                        fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                face.name.isEmpty ? '默认卡面' : face.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, color: primary),
              ),
            ),
            if (selected) ...[
              Text('已选择',
                  style: TextStyle(fontSize: 13, color: secondary)),
              const SizedBox(width: 8),
              Icon(Icons.check_rounded, size: 20, color: primary),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: TextStyle(fontSize: 13, color: textSecondary(context))),
        ),
        IosCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final primary = textPrimary(context);
    final secondary = textSecondary(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontSize: 15, color: secondary)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(fontSize: 15, color: primary)),
          ),
        ],
      ),
    );
  }
}