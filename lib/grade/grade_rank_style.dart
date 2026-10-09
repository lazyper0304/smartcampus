import 'package:flutter/material.dart';

import '../course/course.dart';
import 'bingo_score_service.dart';
import 'score.dart';

/// 排名展示的纯计算 / 配色（无 UI 依赖，便于复用与测试）。
///
/// 数据源为 Bingo `GET /grade/ranking`，返回三档范围排名
/// （班级 / 专业 / 学院）与课程类别均分对比。

/// 排名百分比文本：`rank / total` → 「前 12%」（≤1% 统一显示「前 1%」）
String rankTopPercentText(BingoRankInfo info) {
  if (info.total <= 0 || info.rank <= 0) return '--';
  final pct = info.rank / info.total * 100;
  if (pct <= 1) return '前 1%';
  return '前 ${pct.round()}%';
}

/// 排名徽章配色：按名次占比分四档（青 → 绿 → 橙 → 红）
///
/// 与成绩页 `_scoreText` 的绿/深橙语义一致；深色模式整体提亮，
/// 避免暗底上色彩发闷。
Color rankHighlightColor(BingoRankInfo? info, {required bool isDark}) {
  if (!isRankValid(info)) return const Color(0xFF8E8E93);
  final pct = info!.rank / info.total;
  if (pct <= 0.1) return isDark ? const Color(0xFF4FD1E8) : const Color(0xFF30B0C7);
  if (pct <= 0.3) return isDark ? const Color(0xFF5AD87F) : const Color(0xFF34C759);
  if (pct <= 0.6) return isDark ? const Color(0xFFFFA83D) : const Color(0xFFFF9500);
  return isDark ? const Color(0xFFFF6B63) : const Color(0xFFFF3B30);
}

/// 名次是否有效（有排名且总人数 > 0）
bool isRankValid(BingoRankInfo? info) =>
    info != null && info.rank > 0 && info.total > 0;

/// 从成绩列表提取学期代码列表（降序，最新在前）
List<String> semestersOf(List<Score> scores) {
  final set = <String>{};
  for (final s in scores) {
    if (s.semester.isNotEmpty) set.add(s.semester);
  }
  final list = set.toList()..sort((a, b) => b.compareTo(a));
  return list;
}

/// 某学期内**有课程级排名**的成绩条目
List<Score> rankedScoresOf(List<Score> scores, String semester) {
  return scores
      .where((s) =>
          s.semester == semester && s.rank > 0 && s.rankTotal > 0)
      .toList();
}

/// 学期代码（`2025-2026-2`）→「2025-2026学年 第2学期」
///
/// 与 [Score.semesterDisplay] 语义一致，但接受任意学期代码（成绩列表可能为空）。
String semesterLabel(String semester) => formatSemesterLabel(semester);

/// 学期代码 → 紧凑标签（「2025-2026-2」→「2025-2026 第2学期」）
///
/// 供宽度受限的胶囊选择器使用。
String semesterShortLabel(String semester) {
  final parts = semester.split('-');
  if (parts.length == 3) {
    return '${parts[0]}-${parts[1]} 第${parts[2]}学期';
  }
  return semester;
}