import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:gbk_codec/gbk_codec.dart';

/// 原始 HTTP 响应
class RawHttpResponse {
  final int statusCode;
  final Map<String, String> headers;
  final String body;
  final List<int>? bodyBytes;

  RawHttpResponse(this.statusCode, this.headers, this.body, {this.bodyBytes});

  String? header(String name) {
    return headers[name.toLowerCase()];
  }
}

/// 底层 HTTP 客户端
/// 使用 SecureSocket/Socket 直接发送 HTTP 请求，
/// 不受 dart:io HttpClient 100-599 状态码限制（可处理 1001）
class RawHttpClient {
  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Safari/537.36';

  /// 执行 HTTP 请求
  Future<RawHttpResponse> request(
    String method,
    String url, {
    Map<String, String>? headers,
    String? body,
  }) async {
    final uri = Uri.parse(url);
    final isHttps = uri.scheme == 'https';
    final port = uri.port > 0 ? uri.port : (isHttps ? 443 : 80);

    // 建立连接
    Socket? socket;
    if (isHttps) {
      socket = await SecureSocket.connect(
        uri.host,
        port,
        onBadCertificate: (_) => true,
      );
    } else {
      socket = await Socket.connect(uri.host, port);
    }

    try {
      // 构建请求
      var path = uri.path +
          (uri.query.isNotEmpty ? '?${uri.query}' : '');
      if (path.isEmpty) path = '/';

      final buf = StringBuffer();
      buf.writeln('$method $path HTTP/1.1');
      buf.writeln('Host: ${uri.host}');
      buf.writeln('User-Agent: $_ua');
      buf.writeln('Accept: text/html,application/xhtml+xml,application/xml;q=0.9,'
          'image/webp,image/apng,*/*;q=0.8');
      buf.writeln('Accept-Language: zh-CN,zh;q=0.9');
      buf.writeln('Connection: close');

      if (headers != null) {
        for (final entry in headers.entries) {
          buf.writeln('${entry.key}: ${entry.value}');
        }
      }
      if (body != null) {
        buf.writeln('Content-Length: ${body.length}');
        buf.writeln();
        buf.write(body);
      } else {
        buf.writeln();
      }

      socket!.write(buf.toString());

      // 读取响应（先读原始字节，再解析头 + 解码正文）
      final byteCompleter = Completer<List<int>>();
      final allBytes = <int>[];
      socket.listen(
        (data) => allBytes.addAll(data),
        onDone: () => byteCompleter.complete(allBytes),
        onError: (e) => byteCompleter.completeError(e),
        cancelOnError: true,
      );

      final rawBytes =
          await byteCompleter.future.timeout(const Duration(seconds: 30));
      return _parseResponseBytes(rawBytes);
    } finally {
      socket.close();
    }
  }

  /// GET 请求
  Future<RawHttpResponse> get(
    String url, {
    Map<String, String>? cookies,
    Map<String, String>? extraHeaders,
  }) {
    final allHeaders = <String, String>{};
    if (cookies != null && cookies.isNotEmpty) {
      allHeaders['Cookie'] =
          cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    }
    if (extraHeaders != null) allHeaders.addAll(extraHeaders);
    return request('GET', url, headers: allHeaders);
  }

  /// GET 请求返回原始字节（用于图片等二进制数据）
  Future<RawHttpResponse> getBytes(
    String url, {
    Map<String, String>? cookies,
    Map<String, String>? extraHeaders,
  }) {
    final allHeaders = <String, String>{};
    if (cookies != null && cookies.isNotEmpty) {
      allHeaders['Cookie'] =
          cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    }
    if (extraHeaders != null) allHeaders.addAll(extraHeaders);
    return _requestBytes('GET', url, headers: allHeaders);
  }

  /// POST form 请求
  Future<RawHttpResponse> postForm(
    String url, {
    Map<String, String>? cookies,
    Map<String, String>? formBody,
    Map<String, String>? extraHeaders,
  }) {
    final allHeaders = <String, String>{};
    if (cookies != null && cookies.isNotEmpty) {
      allHeaders['Cookie'] =
          cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    }
    allHeaders['Content-Type'] = 'application/x-www-form-urlencoded; charset=UTF-8';
    if (extraHeaders != null) allHeaders.addAll(extraHeaders);
    final encodedBody = formBody?.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return request('POST', url, headers: allHeaders, body: encodedBody);
  }

  /// 从原始响应字节解析，支持 gzip/deflate 解压
  RawHttpResponse _parseResponseBytes(List<int> rawBytes) {
    // 解析头
    final rawStr = utf8.decode(rawBytes.take(4096).toList(), allowMalformed: true);
    final headerEnd = rawStr.indexOf('\r\n\r\n');
    if (headerEnd < 0) {
      return RawHttpResponse(0, {}, utf8.decode(rawBytes, allowMalformed: true));
    }

    final headerLines = rawStr.substring(0, headerEnd).split('\r\n');
    final statusLine = headerLines.isNotEmpty ? headerLines[0] : '';
    final statusParts = statusLine.split(' ');
    final statusCode =
        int.tryParse(statusParts.length > 1 ? statusParts[1] : '0') ?? 0;

    final responseHeaders = <String, String>{};
    for (int i = 1; i < headerLines.length; i++) {
      final colonIdx = headerLines[i].indexOf(':');
      if (colonIdx > 0) {
        responseHeaders[
            headerLines[i].substring(0, colonIdx).trim().toLowerCase()] =
            headerLines[i].substring(colonIdx + 1).trim();
      }
    }

    // 提取正文字节
    final bodyStart = headerEnd + 4;
    List<int> bodyBytes =
        bodyStart < rawBytes.length ? rawBytes.sublist(bodyStart) : [];

    // 解压
    final encoding = responseHeaders['content-encoding'] ?? '';
    if (encoding.contains('gzip')) {
      bodyBytes = gzip.decode(bodyBytes);
    } else if (encoding.contains('deflate')) {
      bodyBytes = zlib.decode(bodyBytes);
    }
    // br / zstd: 不处理，保留原始字节

    // 检测编码并解码
    String body;
    final contentType = responseHeaders['content-type'] ?? '';
    final charsetMatch = RegExp(r'charset\s*=\s*([^\s;]+)').firstMatch(contentType);

    if (charsetMatch != null) {
      final charset = charsetMatch.group(1)!.toLowerCase();
      if (charset == 'gbk' || charset == 'gb2312' || charset == 'gb18030') {
        body = gbk_bytes.decode(bodyBytes);
      } else {
        body = utf8.decode(bodyBytes, allowMalformed: true);
      }
    } else {
      // 无 charset 时先用 UTF-8，如果包含太多替换字符则尝试 GBK
      body = utf8.decode(bodyBytes, allowMalformed: true);
      if (body.contains('�') && body.length > 10) {
        final ratio = '�'.allMatches(body).length / body.length;
        if (ratio > 0.02) {
          body = gbk_bytes.decode(bodyBytes);
        }
      }
    }
    return RawHttpResponse(statusCode, responseHeaders, body);
  }

  /// 请求并返回原始字节（用于图片等二进制数据）
  Future<RawHttpResponse> _requestBytes(
    String method,
    String url, {
    Map<String, String>? headers,
    String? body,
  }) async {
    final uri = Uri.parse(url);
    final isHttps = uri.scheme == 'https';
    final port = uri.port > 0 ? uri.port : (isHttps ? 443 : 80);

    Socket? socket;
    if (isHttps) {
      socket = await SecureSocket.connect(
        uri.host, port,
        onBadCertificate: (_) => true,
      );
    } else {
      socket = await Socket.connect(uri.host, port);
    }

    try {
      var path = uri.path + (uri.query.isNotEmpty ? '?${uri.query}' : '');
      if (path.isEmpty) path = '/';

      final buf = StringBuffer();
      buf.writeln('$method $path HTTP/1.1');
      buf.writeln('Host: ${uri.host}');
      buf.writeln('User-Agent: $_ua');
      buf.writeln('Accept: */*');
      buf.writeln('Connection: close');
      if (headers != null) {
        for (final entry in headers.entries) {
          buf.writeln('${entry.key}: ${entry.value}');
        }
      }
      buf.writeln();

      socket!.write(buf.toString());

      // 读取原始字节
      final completer = Completer<List<int>>();
      final bytes = <int>[];
      socket.listen(
        (data) => bytes.addAll(data),
        onDone: () => completer.complete(bytes),
        onError: (e) => completer.completeError(e),
        cancelOnError: true,
      );

      final raw = await completer.future.timeout(const Duration(seconds: 30));

      // 解析头
      final headerStr = utf8.decode(raw, allowMalformed: true);
      final headerEnd = headerStr.indexOf('\r\n\r\n');
      if (headerEnd < 0) {
        return RawHttpResponse(0, {}, '', bodyBytes: raw);
      }

      final headerLines = headerStr.substring(0, headerEnd).split('\r\n');
      final statusLine = headerLines.isNotEmpty ? headerLines[0] : '';
      final statusParts = statusLine.split(' ');
      final statusCode =
          int.tryParse(statusParts.length > 1 ? statusParts[1] : '0') ?? 0;

      final responseHeaders = <String, String>{};
      for (int i = 1; i < headerLines.length; i++) {
        final colonIdx = headerLines[i].indexOf(':');
        if (colonIdx > 0) {
          responseHeaders[headerLines[i].substring(0, colonIdx).trim().toLowerCase()] =
              headerLines[i].substring(colonIdx + 1).trim();
        }
      }

      final bodyStart = headerEnd + 4;
      final bodyBytes = bodyStart < raw.length ? raw.sublist(bodyStart) : <int>[];
      return RawHttpResponse(statusCode, responseHeaders, '', bodyBytes: bodyBytes);
    } finally {
      socket?.close();
    }
  }
}
