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
    this.courseId,
    this.courseName,
  });

  /// 서버가 매긴 내역 id — 되돌릴 때 쓴다
  final int id;
  final DateTime usedOn;

  /// 증감 — 사용은 양수, 되돌림은 음수
  final double days;
  final String? reason;

  /// 코스에서 차감된 건이면 그 코스 id
  final int? courseId;

  /// 목록에 보여줄 코스 이름. 서버 내역에는 없어 코스 목록에서 이어붙인다
  final String? courseName;

  /// 코스 때문에 깎인 건지 — 화면 배경색과 펼침 여부를 이 값이 정한다
  bool get fromCourse => courseId != null;

  LeaveUsage copyWith({String? courseName}) => LeaveUsage(
    id: id,
    usedOn: usedOn,
    days: days,
    reason: reason,
    courseId: courseId,
    courseName: courseName ?? this.courseName,
  );

  static LeaveUsage fromJson(Map<String, dynamic> json) => LeaveUsage(
    id: (json['id'] as num).toInt(),
    usedOn: DateTime.parse(json['usedOn'] as String),
    days: (json['days'] as num).toDouble(),
    reason: json['reason'] as String?,
    courseId: (json['courseId'] as num?)?.toInt(),
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
