import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/version.dart';
import 'update_models.dart';

const String _repoOwner = 'lazyper0304';
const String _repoName = 'smartcampus';
const String _apiBase = 'https://api.github.com/repos/$_repoOwner/$_repoName';

/// 更新相关网络请求与版本比较逻辑。
///
/// 纯逻辑、无 UI 依赖，便于单测，也可在设置页以外的位置复用。
class UpdateService {
  static const String _acceptHeader = 'application/vnd.github+json';

  /// 比较版本号 [a] 与 [b]。
  /// 返回 >0 表示 [a] 更新，<0 表示 [b] 更新，0 表示相等。
  /// 支持不等长版本号（如 1.1 与 1.1.0 视为相等）。
  static int compareVersion(String a, String b) {
    final partsA = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final partsB = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = partsA.length > partsB.length ? partsA.length : partsB.length;
    for (int i = 0; i < len; i++) {
      final va = i < partsA.length ? partsA[i] : 0;
      final vb = i < partsB.length ? partsB[i] : 0;
      if (va != vb) return va - vb;
    }
    return 0;
  }

  /// 查询最新 release，判断是否需要更新。失败时抛出 [UpdateException]。
  static Future<UpdateCheckResult> checkForUpdate() async {
    final resp = await http.get(
      Uri.parse('$_apiBase/releases/latest'),
      headers: {'Accept': _acceptHeader},
    );

    if (resp.statusCode != 200) {
      throw const UpdateException('无法连接到 GitHub');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final latestTag = (json['tag_name'] as String?)?.trim() ?? '';
    if (latestTag.isEmpty) {
      throw const UpdateException('获取版本信息失败');
    }

    final releaseBody = (json['body'] as String?) ?? '';

    String downloadUrl =
        'https://github.com/$_repoOwner/$_repoName/releases/latest';
    if (latestTag.isNotEmpty) {
      final assets = json['assets'] as List?;
      if (assets != null && assets.isNotEmpty) {
        final apkAsset = assets.cast<Map<String, dynamic>>().firstWhere(
          (a) => (a['name'] as String? ?? '').endsWith('.apk'),
          orElse: () => <String, dynamic>{},
        );
        final assetUrl = apkAsset['browser_download_url'] as String?;
        if (assetUrl != null && assetUrl.isNotEmpty) {
          downloadUrl = assetUrl;
        } else {
          downloadUrl =
              'https://github.com/$_repoOwner/$_repoName/releases/download/$latestTag/$latestTag.apk';
        }
      } else {
        downloadUrl =
            'https://github.com/$_repoOwner/$_repoName/releases/download/$latestTag/$latestTag.apk';
      }
    }

    final latestVer =
        latestTag.startsWith('v') ? latestTag.substring(1) : latestTag;

    return UpdateCheckResult(
      hasUpdate: compareVersion(latestVer, appVersion) > 0,
      latestTag: latestTag,
      latestVersion: latestVer,
      releaseNotes: releaseBody,
      downloadUrl: downloadUrl,
    );
  }

  /// 获取最近 [perPage] 个 release，用于更新日志。失败时抛出 [UpdateException]。
  static Future<List<ReleaseInfo>> fetchReleases({int perPage = 20}) async {
    final resp = await http.get(
      Uri.parse('$_apiBase/releases?per_page=$perPage'),
      headers: {'Accept': _acceptHeader},
    );
    if (resp.statusCode != 200) {
      throw const UpdateException('加载更新日志失败');
    }

    final list = jsonDecode(resp.body) as List;
    return list.map((e) {
      final r = e as Map<String, dynamic>;
      return ReleaseInfo(
        tagName: (r['tag_name'] as String?) ?? '',
        body: (r['body'] as String?) ?? '',
        publishedAt: (r['published_at'] as String?) ?? '',
      );
    }).toList();
  }
}

/// 更新模块统一异常类型。
class UpdateException implements Exception {
  final String message;
  const UpdateException(this.message);
  @override
  String toString() => message;
}
