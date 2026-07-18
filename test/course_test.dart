import 'package:flutter_test/flutter_test.dart';

import 'package:smartcampus/course/course.dart';

void main() {
  group('Course.fromExperimentJson', () {
    test('parses scjx2 stuTime row to Course', () {
      final json = {
        'jc_start': '09',
        'room_name': 'LG28- 临港二期8号楼8C203',
        'exp_name': 'Spring 原理及应用',
        'teacher_name': '宋小玲',
        'week': 2,
        'jc_end': '10',
        'form': 2,
        'course_name': 'Java EE企业级应用与开发',
        'week_day': 4,
      };
      final course = Course.fromExperimentJson(json, colorIndex: 0);
      expect(course.name, 'Java EE企业级应用与开发');
      expect(course.teacher, '宋小玲');
      expect(course.position, 'LG28- 临港二期8号楼8C203');
      expect(course.day, 4);
      expect(course.weeks, [2]);
      expect(course.sections, [9, 10]);
      expect(course.tag, '实验');
      expect(course.remark, 'Spring 原理及应用');
    });

    test('handles missing fields gracefully', () {
      final course = Course.fromExperimentJson({});
      expect(course.name, '实验课程');
      expect(course.teacher, '');
      expect(course.weeks, isEmpty);
      expect(course.day, 0);
      expect(course.tag, '实验');
    });
  });
}
