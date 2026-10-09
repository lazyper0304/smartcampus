import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/bingo/bingo_client.dart';
import '../core/local_storage.dart';
import 'ecard_model.dart';

/// 一卡通服务（经 Bingo 后端代理 `/ecard/*`）。
///
/// 参考实现：`E:/project/YibinApp/Flutter/lib/features/apps/ecard/data/`
/// 该工程用 dio + Hive，本项目改用既有 [BingoClient]（自动注入 Bearer token、
/// 401 单飞刷新）与 [LocalStorage]（JSON 文件），故不引入 dio / hive，
/// 避免与项目现有 HTTP 栈并存导致 Cookie 与 token 各自为政。
class EcardService {
  EcardService._();
  static final EcardService instance = EcardService._();

  final BingoClient _client = BingoClient.instance;
  static const String _snapshotKey = 'ecard_snapshot_v1';
  static const int _pageSize = 20;

  // ── 接口 ──

  /// 首页概览。[refresh] = true 时强制穿透本地缓存重新同步。
  Future<EcardOverview> fetchOverview({bool refresh = false}) async {
    final data = await _client.getMap(
      '/ecard/overview',
      query: refresh ? {'refresh': '1'} : null,
    );
    return EcardOverview.fromJson(data);
  }

  /// 交易流水（分页）。
  ///
  /// [type] 沿用参考工程默认值 `consume`；注意参考工程 UI 实际未使用该筛选，
  /// 仅列表接口保留此参数。
  Future<EcardTransactionPage> fetchTransactions({
    int page = 1,
    int size = _pageSize,
    String type = 'consume',
    bool refresh = false,
  }) async {
    final data = await _client.getMap('/ecard', query: {
      'type': type,
      'page': page,
      'size': size,
      if (refresh) 'refresh': '1',
    });
    return EcardTransactionPage.fromJson(data);
  }

  /// 卡面目录：服务端下发的可选卡面 + 当前选择。
  Future<EcardCardFaceCatalog> fetchCardFaceCatalog() async {
    final data = await _client.getMap('/ecard/card-faces/catalog');
    return EcardCardFaceCatalog.fromJson(data);
  }

  /// 选定卡面。
  Future<void> selectCardFace(int faceId) =>
      _client.putMap('/ecard/card-faces/selection', body: {'face_id': faceId});

  /// 消费「待生效」的服务端推送卡面（成功后该卡面才真正落为当前卡面）。
  Future<void> consumeAutoCardFace(int faceId) => _client.postMap(
        '/ecard/card-faces/consume-auto',
        body: {'face_id': faceId},
      );

  /// 下载卡面图片字节。
  ///
  /// 走 [BingoClient.download]（自动带 Bearer）。卡面图是普通受保护资源、
  /// 不涉及预签名跳转，故直接取 [BingoBinaryResponse.bytes]。
  Future<Uint8List> downloadCardFace(int faceId) async {
    final res = await _client.download('/ecard/card-faces/$faceId/image');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw BingoException('卡面下载失败：HTTP ${res.statusCode}');
    }
    if (res.bytes.isEmpty) {
      throw BingoException('卡面内容为空');
    }
    return Uint8List.fromList(res.bytes);
  }

  // ── 本地缓存 ──

  /// 读取本地快照（进出场免白屏）
  Future<EcardSnapshot> readSnapshot() async {
    try {
      final raw = await LocalStorage.getString(_snapshotKey);
      if (raw == null || raw.isEmpty) return const EcardSnapshot();
      final j = jsonDecode(raw);
      if (j is! Map) return const EcardSnapshot();
      return EcardSnapshot.fromJson(Map<String, dynamic>.from(j));
    } catch (_) {
      return const EcardSnapshot();
    }
  }

  /// 写回本地快照
  Future<void> writeSnapshot(EcardSnapshot snap) async {
    try {
      await LocalStorage.setString(_snapshotKey, jsonEncode(snap.toJson()));
    } catch (e) {
      debugPrint('[Ecard] 快照写入失败（可忽略）: $e');
    }
  }

  // ── 卡面本地文件 ──

  /// 卡面图片缓存目录。
  ///
  /// ⚠️ 用 `getApplicationSupportDirectory()`（= `getFilesDir()`）而非
  /// `getApplicationDocumentsDirectory()`：后者 Android 上落到
  /// `app_flutter/`，是 `files/` 的**兄弟**目录，而 `FileProvider` 的
  /// 任何 `<*-path>` 都覆盖不到（详见 CHANGELOG 中办公网附件那次修复）。
  /// 虽然本模块只在应用内 `Image.file` 读取、不经外部应用，但保持
  /// 全项目落盘目录规范一致，避免将来「分享卡面」时重蹈覆辙。
  Future<Directory> cardFaceDir() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final d = Directory('${dir.path}/ecard_faces');
      if (!await d.exists()) await d.create(recursive: true);
      return d;
    } catch (e) {
      debugPrint('[Ecard] 卡面目录创建失败: $e');
      return Directory.systemTemp;
    }
  }

  /// 卡面文件名：`<id>_<md5前8位>.png`。
  /// md5 变化即换名，天然完成缓存失效，无需额外清理逻辑。
  static String cardFaceFileName(int faceId, String md5) =>
      'face_${faceId}_${md5.isEmpty ? 'default' : md5.substring(0, md5.length >= 8 ? 8 : md5.length)}.png';
}

/// 卡面目录（服务端下发）
class EcardCardFaceCatalog {
  const EcardCardFaceCatalog({
    required this.faces,
    required this.selectedId,
    required this.displayId,
    this.autoApply,
  });

  /// 可选卡面
  final List<EcardCardFaceMeta> faces;

  /// 用户主动选中的 id
  final int selectedId;

  /// 当前应展示的 id。
  ///
  /// 与 [selectedId] 分离：服务端刚推送了一张卡面但用户还没「消费」时，
  /// [autoApply] 非空且 [displayId] 指向新卡面，此时应立即展示，
  /// 而 [selectedId] 仍是旧值 —— 参考工程刻意做了这个区分。
  final int displayId;

  /// 待消费的推送卡面（消费后服务端才落库）
  final EcardCardFaceMeta? autoApply;

  factory EcardCardFaceCatalog.fromJson(Map<String, dynamic> j) {
    final faces = <EcardCardFaceMeta>[];

    // ⚠️ `default_face` 是**独立的第一个可选项**（id=0「默认」），
    // 服务端与 `faces` 数组**并列**下发。若只解析 faces，用户永远看不到默认卡面，
    // 导致「明明有 2 个卡面却只能选 1 个」。
    final rawDefault = j['default_face'] ?? j['defaultFace'];
    if (rawDefault is Map) {
      faces.add(EcardCardFaceMeta.fromJson(
          Map<String, dynamic>.from(rawDefault)));
    } else {
      // 服务端未下发时补一个本地默认项，保证「恢复默认」始终可选
      faces.add(const EcardCardFaceMeta(id: 0, name: '', md5: ''));
    }

    final rawFaces = j['faces'];
    if (rawFaces is List) {
      for (final e in rawFaces) {
        faces.add(EcardCardFaceMeta.fromJson(e is Map<String, dynamic>
            ? e
            : Map<String, dynamic>.from(e as Map)));
      }
    }

    final rawAuto = j['auto_apply'] ?? j['autoApply'];
    final selected = j['selected_id'] ?? j['selectedId'];
    final display = j['display_id'] ?? j['displayId'];
    return EcardCardFaceCatalog(
      faces: faces,
      selectedId: selected is num ? selected.toInt() : 0,
      displayId:
          display is num ? display.toInt() : (selected is num ? selected.toInt() : 0),
      autoApply: rawAuto is Map
          ? EcardCardFaceMeta.fromJson(
              Map<String, dynamic>.from(rawAuto))
          : null,
    );
  }

  /// 应展示的卡面元信息（含默认卡面 id=0）
  EcardCardFaceMeta? get displayMeta {
    for (final f in faces) {
      if (f.id == displayId) return f;
    }
    return null;
  }
}

/// 单张卡面
class EcardCardFaceMeta {
  const EcardCardFaceMeta({required this.id, required this.name, required this.md5});

  final int id;
  final String name;

  /// 图片内容 md5 —— 用于本地文件缓存失效与光晕缓存 key
  final String md5;

  factory EcardCardFaceMeta.fromJson(Map<String, dynamic> j) => EcardCardFaceMeta(
        id: j['id'] is num ? (j['id'] as num).toInt() : 0,
        name: j['name']?.toString() ?? '',
        md5: j['md5']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'md5': md5};
}