import '../../../core/utils/date_format.dart';

/// 연차 사용 내역 한 건.
///
/// 코스에서 차감된 건([courseId]가 있음)과 직접 등록한 건은 화면에서 다르게
/// 보인다 — 코스 건은 파란 카드에 코스명을, 직접 등록은 사유를 보여준다.
class LeaveUsage {
  const LeaveUsage({
    required this.id,
    required this.usedOn,
    required this.days,
    this.reason,
    this.memo,
    this.courseId,
    this.courseName,
    this.createdAt,
  });

  /// 서버가 매긴 내역 id — 되돌릴 때 쓴다
  final int id;
  final DateTime usedOn;

  /// 증감 — 사용은 양수, 되돌림은 음수
  final double days;

  /// 한 줄 사유 (칩 라벨 — 여행·개인 사유·…)
  final String? reason;

  /// 풀어 쓰는 상세 메모 (core #323). 코스 확정 내역에는 없다 —
  /// 그 행은 서버가 만들어 채울 사람이 없다
  final String? memo;

  /// 코스에서 차감된 건이면 그 코스 id
  final int? courseId;

  /// 목록에 보여줄 코스 이름. 서버 내역에는 없어 코스 목록에서 이어붙인다
  final String? courseName;

  /// 이 내역을 **등록한** 시각 (core #384). KST, 오프셋 없는 `2026-09-01T14:03:22`.
  ///
  /// [usedOn]과 다르다 — 지난주에 쓴 연차를 오늘 등록하면 usedOn은 지난주,
  /// 이건 오늘이다. 컬럼이 생기기 전 내역은 null이다 (서버가 백필하지 않았다
  /// — 채울 진실이 없다)
  final DateTime? createdAt;

  /// 코스 때문에 깎인 건지 — 화면 배경색과 펼침 여부를 이 값이 정한다
  bool get fromCourse => courseId != null;

  /// 'New' 칩을 띄울 만큼 갓 등록한 것인가 — 시안: 등록 시점 기준 24시간.
  ///
  /// 등록 시각을 모르는 옛 내역은 새 것으로 보지 않는다. 미래 시각(기기
  /// 시계가 어긋난 경우)도 24시간 안으로 본다 — 방금 등록했는데 칩이 안
  /// 뜨는 쪽이 더 이상하다
  bool isNewAt(DateTime now) {
    final created = createdAt;
    if (created == null) return false;
    return now.difference(created) < const Duration(hours: 24);
  }

  LeaveUsage copyWith({String? courseName}) => LeaveUsage(
    id: id,
    usedOn: usedOn,
    days: days,
    reason: reason,
    memo: memo,
    courseId: courseId,
    courseName: courseName ?? this.courseName,
    createdAt: createdAt,
  );

  static LeaveUsage fromJson(Map<String, dynamic> json) => LeaveUsage(
    id: (json['id'] as num).toInt(),
    usedOn: DateTime.parse(json['usedOn'] as String),
    days: (json['days'] as num).toDouble(),
    reason: json['reason'] as String?,
    memo: json['memo'] as String?,
    courseId: (json['courseId'] as num?)?.toInt(),
    // 오프셋 없는 KST다 — 알림과 같은 파서로 읽는다. 없거나 못 읽으면 null
    createdAt: parseServerDateTime(json['createdAt'] as String?),
  );
}

/// 내 연차 전체 — 잔여 일수와 사용 내역
class MyLeave {
  const MyLeave({
    required this.totalDays,
    required this.usedDays,
    required this.remainingDays,
    required this.usages,
  });

  final double totalDays;
  final double usedDays;

  /// 초과 사용하면 음수가 될 수 있다
  final double remainingDays;
  final List<LeaveUsage> usages;

  static MyLeave fromJson(Map<String, dynamic> json) => MyLeave(
    totalDays: (json['totalDays'] as num).toDouble(),
    usedDays: (json['usedDays'] as num).toDouble(),
    remainingDays: (json['remainingDays'] as num).toDouble(),
    usages: ((json['usages'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(LeaveUsage.fromJson)
        .toList(),
  );
}
