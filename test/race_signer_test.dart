import 'package:flutter_test/flutter_test.dart';

import 'package:smartcampus/race/race_signer.dart';
import 'package:smartcampus/race/race.dart';

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
      expect(sig.length, 64);
      expect(sig, matches(RegExp(r'^[0-9A-F]{64}$')));
    });

    test('empty data/params with authToken - use Authorization fallback', () {
      final sig = signer.generateZhxhSign(
        null,
        null,
        authToken: 'eyJtest',
      );
      expect(sig.length, 64);
      expect(sig, matches(RegExp(r'^[0-9A-F]{64}$')));
    });
  });

  group('RaceDetail.fromJson', () {
    test('parses full toRaceApply response (with result wrapper)', () {
      final json = {
        'code': 200,
        'msg': '操作成功！',
        'result': {
          'teacher_name': '张亚娟',
          'type_name': 'B类',
          'year': '2024',
          'subs': [
            {
              'isteam': '1',
              'entryfee': 0,
              'race_id': '0554ec6268814919b1f55906d2937eac',
              'name': '2025川渝师范生教学能力大赛',
              'id': '38830b8c416b482989af5730cb2409d6',
              'isteam_name': '不限',
              'is_pay': null,
            }
          ],
          'outlay': 0,
          'name': '2024川渝师范生教学能力大赛',
          'id': '0554ec6268814919b1f55906d2937eac',
          'dep_name': '教师教育学院/教育科学学院',
          'dep_code': 'XB033',
          'content': '详情内容...',
          'havesub': '否',
          'ispublish_name': '终审通过',
          'level_h_name': '省级',
          'yearterm': '2024-2025',
          'host_dep': '教育厅',
        },
      };

      final detail = RaceDetail.fromJson(json);
      expect(detail.id, '0554ec6268814919b1f55906d2937eac');
      expect(detail.name, '2024川渝师范生教学能力大赛');
      expect(detail.teacherName, '张亚娟');
      expect(detail.typeName, 'B类');
      expect(detail.year, '2024');
      expect(detail.depName, '教师教育学院/教育科学学院');
      expect(detail.depCode, 'XB033');
      expect(detail.content, '详情内容...');
      expect(detail.havesub, '否');
      expect(detail.ispublishName, '终审通过');
      expect(detail.subs.length, 1);
      expect(detail.subs[0].id, '38830b8c416b482989af5730cb2409d6');
      expect(detail.subs[0].isteamName, '不限');
    });

    test('parses direct data (no result wrapper)', () {
      final json = {
        'id': 'abc',
        'name': 'Test Race',
        'teacher_name': 'Test Teacher',
      };
      final detail = RaceDetail.fromJson(json);
      expect(detail.id, 'abc');
      expect(detail.name, 'Test Race');
      expect(detail.teacherName, 'Test Teacher');
    });
  });
}
