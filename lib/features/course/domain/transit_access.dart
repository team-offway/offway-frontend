/// 이 지역에 **무엇을 타고 어디에 내리는가** (core #97).
///
/// 예전에는 열차만 봤다(`trainAccess`). 역이 없거나 먼 지역은 도착 지점을
/// 못 찾아 코스가 출발지 좌표부터 이어졌고, 서울에서 출발하면 완도 장소들이
/// **서울에서 가까운 순**으로 붙어 동선이 지역 반대편부터 짜였다.
///
/// 이제 역·터미널·항구를 함께 본다. 89곳 중 88곳이 버스로 닿고, 울릉군은
/// 여객선이다.
class TransitAccess {
  const TransitAccess({
    required this.modeLabel,
    required this.status,
    this.fromPlace,
    this.toPlace,
    this.vehicleType,
    this.durationMinutes,
    this.alternatives = const [],
  });

  /// 응답의 `transitAccess` → 화면이 읽는 형태.
  ///
  /// 자차 코스와 저장된 코스는 이 값이 없다(null). 옛 서버도 마찬가지라
  /// 그때는 안내를 통째로 접는다.
  static TransitAccess? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final label = (raw['modeLabel'] as String?)?.trim();
    // 수단 이름이 없으면 "무엇을 타는지"를 말할 수 없다 — 그리지 않는다
    if (label == null || label.isEmpty) return null;
    return TransitAccess(
      modeLabel: label,
      status: TransitStatus.parse(raw['status'] as String?),
      fromPlace: _text(raw['fromPlace']),
      toPlace: _text(raw['toPlace']),
      vehicleType: _text(raw['vehicleType']),
      durationMinutes: (raw['durationMinutes'] as num?)?.toInt(),
      alternatives: [
        for (final item in (raw['alternatives'] as List?) ?? const [])
          if (item is Map<String, dynamic>) ?TransitOption.tryParse(item),
      ],
    );
  }

  /// 화면에 쓸 한글 수단명 — `열차`·`고속버스`·`시외버스`·`여객선`.
  /// **서버가 정한다** — 앱에 한글을 박아두면 수단이 늘 때 함께 고쳐야 한다
  final String modeLabel;

  final TransitStatus status;

  /// 어디서 타는지 — 모르면 null
  final String? fromPlace;

  /// 어디에 내리는지 (역·터미널·항구) — 모르면 null
  final String? toPlace;

  /// `KTX`처럼 구체적인 편명 — 열차만 온다
  final String? vehicleType;

  /// 타고 가는 시간(분). **기다리는 시간은 안 들어 있다** —
  /// 버스·여객선은 시간표를 못 물어 다음 편까지의 대기를 모른다
  final int? durationMinutes;

  /// 이 지역에 닿는 다른 수단들. 없으면 빈 목록이다
  final List<TransitOption> alternatives;

  /// 안내를 그릴 만한 값이 있는가 — 내리는 곳조차 모르면 할 말이 없다
  bool get isPresentable => toPlace != null && toPlace!.isNotEmpty;

  /// `1시간 30분` · `50분` — 모르면 null
  String? get durationLabel => formatTransitDuration(durationMinutes);
}

/// 이 지역에 닿는 수단 하나 — 대표 말고 대안 쪽.
class TransitOption {
  const TransitOption({
    required this.modeLabel,
    this.toPlace,
    this.durationMinutes,
  });

  static TransitOption? tryParse(Map<String, dynamic> json) {
    final label = (json['modeLabel'] as String?)?.trim();
    if (label == null || label.isEmpty) return null;
    return TransitOption(
      modeLabel: label,
      toPlace: _text(json['toPlace']),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
    );
  }

  final String modeLabel;
  final String? toPlace;
  final int? durationMinutes;

  String? get durationLabel => formatTransitDuration(durationMinutes);
}

/// 도착 정보를 얼마나 아는가.
///
/// **`POINT_ONLY`와 `NO_SERVICE_ON_DATE`는 다르다.** 앞은 "아직 안 물었다"
/// (버스·여객선은 요청 시점에 시간표를 못 묻는다), 뒤는 "물어봤더니 없다"다.
/// 섞으면 화면이 "그날 차가 없다"고 잘못 말한다.
enum TransitStatus {
  /// 운행 편을 찾았다 — 도착 **시각**까지 안다 (지금은 열차만)
  available('AVAILABLE'),

  /// 내리는 곳만 안다 — 시간표는 아직 못 물었다
  pointOnly('POINT_ONLY'),

  /// 그날 갈 수 있는 편이 없다
  noServiceOnDate('NO_SERVICE_ON_DATE'),

  /// 조회하지 못했다 (역이 없거나 외부 장애)
  unavailable('');

  const TransitStatus(this.wireName);

  final String wireName;

  /// 모르는 값은 [unavailable]로 받는다 — 서버가 상태를 늘려도 화면이
  /// 통째로 안 뜨는 일은 없어야 한다
  static TransitStatus parse(String? raw) {
    for (final s in values) {
      if (s != unavailable && s.wireName == raw) return s;
    }
    return unavailable;
  }
}

/// 분을 사람이 읽는 말로 — `1시간 30분` · `50분`.
String? formatTransitDuration(int? minutes) {
  if (minutes == null || minutes <= 0) return null;
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest분';
  if (rest == 0) return '$hours시간';
  return '$hours시간 $rest분';
}

String? _text(Object? value) {
  final s = (value as String?)?.trim();
  return (s == null || s.isEmpty) ? null : s;
}
