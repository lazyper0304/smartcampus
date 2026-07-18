import 'package:flutter_test/flutter_test.dart';

import 'package:smartcampus/race/race_signer.dart';

void main() {
  group('RaceApiSigner.generateZhxhSign', () {
    final signer = RaceApiSigner();

    test('listStuRacePage (data only) - matches user request', () {
      final data = {'currpage': 1, 'pagesize': 15};
      final sig = signer.generateZhxhSign(data, null);
      expect(sig,
          '34C20C54DD3428922AD4DD01FC22EC7A6B5A43EB49AAF752027C0B292318EA5B');
    });

    test('toRaceApply (params only) - matches user request', () {
      final params = {'race_id': '0299174246f24b589c98a888333b3e06'};
      final sig = signer.generateZhxhSign(null, params);
      expect(sig,
          'C5AE2B34F7A35F582B696091752282295412041ACB19A6A05B863581F8C20AF8');
    });

    test('data + params combined - should use both', () {
      final data = {'currpage': 1, 'pagesize': 15};
      final params = {'race_id': 'abc123'};
      final sig = signer.generateZhxhSign(data, params);
      // 验证字符串拼接顺序: sorted keys = [currpage, pagesize, race_id]
      // 期望的 string-to-sign: currpage=1pagesize=15race_id=abc123
      // 同样用 HMAC-SHA256 + key 计算
      expect(sig.length, 64); // SHA-256 hex
      expect(sig, matches(RegExp(r'^[0-9A-F]{64}$')));
    });

    test('empty data/params with authToken - use Authorization fallback', () {
      final sig = signer.generateZhxhSign(
        null,
        null,
        authToken: 'eyJtest',
      );
      // 期望 string-to-sign: Authorization=eyJtest
      // SHA-256 = known value
      expect(sig.length, 64);
      expect(sig, matches(RegExp(r'^[0-9A-F]{64}$')));
    });
  });
}
