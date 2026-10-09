import '../core/bingo/bingo_client.dart';
import 'score.dart';
import 'score_service.dart';

/// Bingo 成绩服务（`GET /grade`、`GET /grade/ranking`）。
///
/// 替代原 ehall `xscjcx.do` 直连。后端已聚合教务成绩并归一化字段
/// （兼容教务原始字段名 `XNXQDM`/`KCM`/`ZCJ`/`XFJD` 与标准字段名）。
///
/// 输出沿用既有 UI 模型（[Score] / [StudentInfo] / [ScoreResult]），
/// 成绩页无需改动。
class BingoScoreService {
  BingoScoreService._();

  static final BingoScoreService instance = BingoScoreService._();

  final BingoClient _client = BingoClient.instance;

  /// 拉取成绩。[semesterId] 为空表示全部学期。
  Future<ScoreResult> fetchScores({String? semesterId, bool forceRefresh = false}) async {
    final data = await _client.getMap('/grade', query: {
      if (semesterId != null && semesterId.isNotEmpty) 'semester_id': semesterId,
    });

    final rawItems = data['items'] as List<dynamic>? ?? const [];
    final scores = rawItems
        .map((e) => Score.fromBingoJson(
            e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)))
        .toList();

    // 学生信息来自登录时下发的 user（Bingo `/auth/login` 返回）
    final info = await _studentInfo();

    return ScoreResult(info: info, scores: scores);
  }

  /// 后台是否正在同步成绩（首页/成绩页可据此显示"同步中"）
  Future<bool> isSyncing() async {
    try {
      final data = await _client.getMap('/grade');
      return data['syncing'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 成绩排名（`/grade/ranking`）：班级 / 专业 / 学院 + 分类均分
  Future<BingoGradeRanking> fetchRanking({String? semester}) async {
    final data = await _client.getMap('/grade/ranking', query: {
      if (semester != null && semester.isNotEmpty) 'semester': semester,
    });
    return BingoGradeRanking.fromJson(data);
  }

  Future<StudentInfo> _studentInfo() async {
    final user = await BingoClient.loadUserInfo();
    if (user == null) return const StudentInfo.empty();
    return StudentInfo(
      studentId: user['school_id']?.toString() ?? '',
      name: user['real_name']?.toString() ?? user['nickname']?.toString() ?? '',
      className: user['class_name']?.toString() ?? '',
      grade: user['school_year']?.toString() ?? '',
      department: user['college']?.toString() ?? '',
      major: user['major']?.toString() ?? '',
      duration: user['edu_level']?.toString() ?? '',
    );
  }
}

/// 成绩排名数据
class BingoGradeRanking {
  final BingoRankInfo? classRank;
  final BingoRankInfo? majorRank;
  final BingoRankInfo? collegeRank;
  final List<BingoCategoryScore> categories;
  final String warning;

  const BingoGradeRanking({
    this.classRank,
    this.majorRank,
    this.collegeRank,
    this.categories = const [],
    this.warning = '',
  });

  factory BingoGradeRanking.fromJson(Map<String, dynamic> j) {
    List<BingoCategoryScore> parseCats(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .map((e) => BingoCategoryScore.fromJson(
              e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    BingoRankInfo? parseRank(dynamic raw) =>
        raw is Map ? BingoRankInfo.fromJson(Map<String, dynamic>.from(raw)) : null;

    return BingoGradeRanking(
      classRank: parseRank(j['class']),
      majorRank: parseRank(j['major']),
      collegeRank: parseRank(j['college']),
      categories: parseCats(j['categories']),
      warning: j['warning']?.toString() ?? '',
    );
  }
}

class BingoRankInfo {
  final int rank;
  final int total;
  final double gpa;

  const BingoRankInfo({this.rank = 0, this.total = 0, this.gpa = 0});

  factory BingoRankInfo.fromJson(Map<String, dynamic> j) => BingoRankInfo(
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        gpa: _dbl(j['gpa']),
      );
}

class BingoCategoryScore {
  final String category;
  final double avgGpa;
  final double peerAvg;
  final int count;

  const BingoCategoryScore({
    this.category = '',
    this.avgGpa = 0,
    this.peerAvg = 0,
    this.count = 0,
  });

  factory BingoCategoryScore.fromJson(Map<String, dynamic> j) => BingoCategoryScore(
        category: j['category']?.toString() ?? '',
        avgGpa: _dbl(j['avg_gpa']),
        peerAvg: _dbl(j['peer_avg']),
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

double _dbl(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}