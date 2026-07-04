import 'package:url_launcher/url_launcher.dart';

/// 学工系统服务 - 浏览器打开方式
class XuegongService {

  XuegongService();

  /// 在外部浏览器打开学工系统
  Future<bool> openInBrowser() async {
    final url = 'https://ybxyxsglxt.yibinu.edu.cn/wiseduIndex.jsp';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 获取可分享的学工系统链接
  String get portalUrl =>
      'https://ybxyxsglxt.yibinu.edu.cn/wiseduIndex.jsp';

  void dispose() {}
}
