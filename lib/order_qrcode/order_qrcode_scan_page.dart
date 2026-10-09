import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// 当前平台是否支持相机扫码。
///
/// `mobile_scanner` 7.x 仅声明 android / ios / macos / web 四个平台，
/// Windows / Linux **无原生实现**（调用会抛 MissingPluginException），
/// 因此桌面端必须降级为「手动输入二维码内容」。
bool get supportsQrScan =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

/// 扫码页：识别成功后 `pop` 返回二维码字符串。
///
/// ⚠️ `mobile_scanner` 只提供 android / ios / macos / web 实现，
/// **Windows 与 Linux 没有实现**（会抛 MissingPluginException）。
/// 因此调用方必须先用 [supportsQrScan] 判断，桌面端改走「手动输入」。
class OrderQrcodeScanPage extends StatefulWidget {
  const OrderQrcodeScanPage({super.key});

  @override
  State<OrderQrcodeScanPage> createState() => _OrderQrcodeScanPageState();
}

class _OrderQrcodeScanPageState extends State<OrderQrcodeScanPage> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_handled) return;
              for (final code in capture.barcodes) {
                final v = code.rawValue?.trim();
                if (v != null && v.isNotEmpty) {
                  _handled = true;
                  Navigator.of(context).pop(v);
                  return;
                }
              }
            },
          ),
          const IgnorePointer(
            child: Center(
              child: SizedBox(
                width: 260,
                height: 260,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.fromBorderSide(
                      BorderSide(color: Color(0xD9FFFFFF), width: 2),
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.viewPaddingOf(context).top + 20,
            child: Row(
              children: [
                const SizedBox(width: 12),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Icon(CupertinoIcons.back, color: Colors.white),
                ),
                const Spacer(),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: const Text(
              '将商家点餐码放入取景框',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xD9FFFFFF),
                fontSize: 15,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
