/// 지역의 방문 지표 (core #438) — 관광빅데이터 일별 방문자에서 낸 값.
///
/// **여러 화면이 같은 모양으로 받는다.** 지역 상세·코스 확정·내 코스 상세가
/// 같은 응답 조각을 물고, 화면은 같은 위젯으로 그린다.
///
/// 둘 다 **없을 수 있다**. 서버가 재료가 모자라면 지어내지 않고 비운다 —
/// 요일당 40일 미만이거나, 요일 격차가 10% 미만이거나, 작년 치가 없을 때다.
/// 그때는 화면이 그 줄을 지운다.
class RegionVisitMetrics {
  const RegionVisitMetrics({this.quietestDay, this.trend});

  static const empty = RegionVisitMetrics();

  /// 응답의 `visitMetrics` → 화면이 읽는 형태. 없으면 빈 지표다
  static RegionVisitMetrics parse(Object? raw) {
    if (raw is! Map<String, dynamic>) return empty;
    return RegionVisitMetrics(
      quietestDay: QuietestDay.tryParse(raw['quietestDay']),
      trend: PopularityTrend.tryParse(raw['trend']),
    );
  }

  /// 가장 한산한 요일 — 모르면 null
  final QuietestDay? quietestDay;

  /// 작년 같은 기간 대비 증감 — 모르면 null
  final PopularityTrend? trend;

  /// 그릴 것이 하나라도 있는가
  bool get isEmpty => quietestDay == null && trend == null;
}

/// 가장 한산한 요일 — "화요일에 가장 한산해요".
class QuietestDay {
  const QuietestDay({
    required this.label,
    this.percentLessThanOtherDays,
    this.dayOfWeek,
  });

  static QuietestDay? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final label = (raw['label'] as String?)?.trim();
    // 라벨이 없으면 화면에 쓸 말이 없다 — 요일 코드로 한글을 짓지 않는다.
    // 서버가 한글을 든다(`TransitMode.label()`과 같은 방식)
    if (label == null || label.isEmpty) return null;
    return QuietestDay(
      label: label,
      // **없으면 0으로 채우지 않는다.** 0을 넣으면 안내에 "약 0% 적어요"가
      // 측정값처럼 뜬다 — 요일은 알지만 격차를 모르는 것이 사실이다.
      // 숫자가 아닌 값이 와도 같은 자리로 떨어진다(as num?는 던진다)
      percentLessThanOtherDays: switch (raw['percentLessThanOtherDays']) {
        final num n => n.toInt(),
        _ => null,
      },
      dayOfWeek: (raw['dayOfWeek'] as String?)?.trim(),
    );
  }

  /// 화면에 그대로 쓰는 한글 — `화요일`. **서버가 든다**
  final String label;

  /// 나머지 요일들보다 몇 % 적은가 — 안내 문구의 그 숫자다.
  /// **모르면 null**이고, 그때는 그 문장을 통째로 뺀다
  final int? percentLessThanOtherDays;

  /// 요일 코드(`TUESDAY`). 앱이 자체 표기를 쓸 때를 위해 함께 온다
  final String? dayOfWeek;
}

/// 인기 추세 — "추세 +40% · 요즘 사람이 늘고 있어요".
///
/// **작년 같은 기간과 견준 값**이다. 직전 기간과 견주면 계절이 증감으로
/// 둔갑해, 바다를 낀 지역이 여름마다 전부 급등으로 나온다.
class PopularityTrend {
  const PopularityTrend({required this.percent, required this.rising});

  static PopularityTrend? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final percent = (raw['percent'] as num?)?.toInt();
    if (percent == null) return null;
    return PopularityTrend(
      percent: percent,
      // **rising이 거짓인 것과 trend가 없는 것은 다르다**(서버 주석) —
      // 앞은 "재 보니 안 늘었다", 뒤는 "아직 잴 수 없다"
      rising: raw['rising'] as bool? ?? percent > 0,
    );
  }

  /// 작년 같은 기간 대비 증감률 — 줄었으면 음수다
  final int percent;

  /// 늘고 있다고 말할 만한가 — 목록의 '최근 인기 상승' 칩이 이 값을 쓴다
  final bool rising;

  /// `+40%` · `-12%` — 부호를 붙여 방향이 숫자에서 바로 읽히게 한다
  String get percentLabel => '${percent > 0 ? '+' : ''}$percent%';

  /// `요즘 사람이 늘고 있어요` — 시안 문구다
  String get description => rising ? '요즘 사람이 늘고 있어요' : '요즘 사람이 줄고 있어요';
}
