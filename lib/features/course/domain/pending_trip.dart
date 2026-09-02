/// 홈에서 "다녀오셨나요?"라고 물어볼 지난 여행 하나
/// (`GET /courses/pending-trips`의 `trips[]`).
///
/// 모달을 그리는 데 필요한 값이 이 안에 다 있다 — 코스 상세를 다시 부르지 않는다.
class PendingTrip {
  const PendingTrip({
    required this.courseId,
    required this.regionName,
    required this.startDate,
    required this.endDate,
    required this.consumedLeaveDays,
  });

  /// 서버 응답 한 건을 읽는다. 날짜가 없는 코스는 애초에 오지 않지만,
  /// 그래도 비었으면 [DateTime.now]로 두지 않고 null을 돌려 걸러낸다 —
  /// 없는 날짜로 "N일 차감" 을 물으면 안 된다.
  static PendingTrip? tryParse(Map<String, dynamic> json) {
    final start = DateTime.tryParse(json['travelDate'] as String? ?? '');
    final end = DateTime.tryParse(json['travelEndDate'] as String? ?? '');
    final courseId = (json['courseId'] as num?)?.toInt();
    if (start == null || end == null || courseId == null) return null;

    return PendingTrip(
      courseId: courseId,
      // 지역을 못 찾으면 서버가 null을 준다. 문구가 '여행, 다녀오셨나요?'로
      // 어색해지므로 호출부가 [title]로 판단하게 둔다
      regionName: json['regionName'] as String?,
      startDate: start,
      endDate: end,
      consumedLeaveDays: (json['consumedLeaveDays'] as num?)?.toDouble() ?? 0,
    );
  }

  final int courseId;

  /// 시군구 이름 (`정선군`). 서버가 못 찾으면 null
  final String? regionName;

  final DateTime startDate;
  final DateTime endDate;

  /// 다녀왔다고 답하면 깎일 연차 — 서버가 평일−공휴일로 계산해 준다
  final double consumedLeaveDays;

  /// 서버가 "다녀오셨나요?" 알림을 보내는 시각 — 여행 다음 날 20시(KST,
  /// core `TripAfterNotifier`). 서버 시각이라 기기 시간대와 무관하게 UTC로 잰다
  static const _askHourUtc = 20 - 9;

  /// 이 여행을 물어봐도 되는 첫 순간.
  ///
  /// `pending-trips`는 날짜만 보므로 여행 다음 날 **자정**에 넘어온다. 그대로
  /// 띄우면 알림보다 20시간 먼저 묻는다 — 아침에 홈에 들어왔다가 질문을
  /// 받고, 저녁에 알림을 또 받는다. 알림과 같은 시각에 맞춘다
  DateTime get askableFrom =>
      DateTime.utc(endDate.year, endDate.month, endDate.day + 1, _askHourUtc);

  /// [now]에 물어봐도 되는가 — [askableFrom]을 지났는가
  bool isAskableAt(DateTime now) => !now.isBefore(askableFrom);

  /// 모달 제목 — `정선 여행, 다녀오셨나요?`
  String get title {
    final region = shortRegionName;
    return region == null ? '이 여행, 다녀오셨나요?' : '$region 여행, 다녀오셨나요?';
  }

  static const _suffixes = ['특별자치시', '특별자치도', '광역시', '특별시', '시', '군', '구'];

  /// 접미사를 떼고도 남아야 할 최소 글자 수.
  ///
  /// '중구'에서 '구'를 떼면 '중'만 남아 어느 지역인지 알아볼 수 없다.
  /// 두 글자 이상 남을 때만 뗀다.
  static const _minNameLength = 2;

  /// 행정구역 접미사를 뗀 지역명 (`정선군` → `정선`). 지역이 없으면 null.
  ///
  /// 시안이 '정선 여행'이고 '정선군 여행'은 말맛이 어색하다.
  /// 모달 제목과 기록 토스트가 함께 쓴다.
  String? get shortRegionName {
    final name = regionName?.trim();
    if (name == null || name.isEmpty) return null;
    for (final suffix in _suffixes) {
      if (!name.endsWith(suffix)) continue;
      final stem = name.substring(0, name.length - suffix.length);
      return stem.length >= _minNameLength ? stem : name;
    }
    return name;
  }
}
