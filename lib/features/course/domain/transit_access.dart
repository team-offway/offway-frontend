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
    this.mode,
    this.fromPlace,
    this.toPlace,
    this.vehicleType,
    this.durationMinutes,
    this.distanceKm,
    this.alternatives = const [],
    this.departures = const [],
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
      mode: _text(raw['mode']),
      status: TransitStatus.parse(raw['status'] as String?),
      fromPlace: _text(raw['fromPlace']),
      toPlace: _text(raw['toPlace']),
      vehicleType: _text(raw['vehicleType']),
      durationMinutes: (raw['durationMinutes'] as num?)?.toInt(),
      distanceKm: (raw['distanceKm'] as num?)?.toInt(),
      alternatives: [
        for (final item in (raw['alternatives'] as List?) ?? const [])
          if (item is Map<String, dynamic>) ?TransitOption.tryParse(item),
      ],
      departures: TransitDeparture.parseList(raw['departures']),
    );
  }

  /// 화면에 쓸 한글 수단명 — `열차`·`고속버스`·`시외버스`·`여객선`.
  /// **서버가 정한다** — 앱에 한글을 박아두면 수단이 늘 때 함께 고쳐야 한다
  final String modeLabel;

  /// 수단을 가리키는 계약 키 — `TRAIN`·`EXPRESS_BUS`·`INTERCITY_BUS`·`FERRY`.
  ///
  /// [modeLabel]은 화면에 쓰는 말이라 서버가 문구를 다듬으면 바뀐다. 수단으로
  /// 갈래를 타야 할 때는 이쪽을 본다. 옛 서버는 안 실어 null일 수 있다
  final String? mode;

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

  /// 출발지에서 도착 지점까지의 **직선거리**(km) — 실제 주행거리가 아니다
  /// (core #380). 옛 서버는 안 실어 null일 수 있다
  final int? distanceKm;

  /// 이 지역에 닿는 다른 수단들. 없으면 빈 목록이다
  final List<TransitOption> alternatives;

  /// 집을 나서는 시각 이후로 탈 수 있는 편들 (core #420) — 최대 6편.
  ///
  /// **비어 있는 것이 정상이다.** 버스·여객선은 조회창(버스 +2일 · 여객선
  /// +7일) 밖이면 서버가 아예 묻지 않고, 그날 운행이 없거나 막차가 지났을
  /// 때도 빈다. 연차로 다음 달 코스를 짜는 서비스라 **대부분이 창 밖**이다.
  /// "가끔 안 나온다"가 아니라 "그 날짜엔 원래 없다"로 그려야 한다
  final List<TransitDeparture> departures;

  /// 안내를 그릴 만한 값이 있는가 — 내리는 곳조차 모르면 할 말이 없다
  bool get isPresentable => toPlace != null && toPlace!.isNotEmpty;

  /// `1시간 30분` · `50분` — 모르면 null
  String? get durationLabel => formatTransitDuration(durationMinutes);

  /// 대안 하나를 대표 자리에 올린 사본 — '시외버스로 보기'를 눌렀을 때.
  ///
  /// **출발지와 편명은 물려주지 않는다.** 서버가 대안에 그 둘을 싣지 않는데
  /// 지금 값을 그대로 두면, 고속버스로 갈아끼웠는데 '청량리에서 출발'이라고
  /// 말하게 된다 — 수단이 다르면 타는 곳도 다르다.
  ///
  /// 되돌아가는 길은 [TransitAccess] 원본을 들고 있는 화면이 맡는다. 대표를
  /// [TransitOption]으로 접어 목록에 넣으면 담지 못하는 항목(출발지·편명)이
  /// 그때 사라져, 두 번 눌러 돌아왔을 때 **첫 화면과 달라진다.**
  TransitAccess swappedWith(TransitOption option) {
    return TransitAccess(
      modeLabel: option.modeLabel,
      mode: option.mode,
      // 시간표는 대안이 제 것을 들고 온다 — 대표의 것을 남기면 시외버스로
      // 갈아꼈는데 무궁화호 시각이 뜬다
      departures: option.departures,
      // 갈아낀 수단의 시간표를 우리가 물어본 것은 아니다 — 상태는 그대로 둔다
      status: status,
      toPlace: option.toPlace ?? toPlace,
      durationMinutes: option.durationMinutes,
      // 거리도 물려주지 않는다 — 출발지→도착 지점의 값이라, 다른 터미널에
      // 내리는 수단으로 바꾸면 다른 거리다 (출발지와 같은 논리)
      // 갈아낀 뒤 남는 대안은 '원래 것'뿐이다. 화면이 원본을 들고 있으므로
      // 여기서는 목록을 비우고, 되돌리기는 그쪽이 판단한다
      alternatives: const [],
    );
  }
}

/// 이 지역에 닿는 수단 하나 — 대표 말고 대안 쪽.
///
/// **서버가 네 가지만 준다** — `mode`·`modeLabel`·`toPlace`·`durationMinutes`.
/// 출발지와 편명은 일부러 뺐다(core `TransitOptionResponse`). 수단이 다르면
/// 타는 곳도 다르므로, 대표의 값을 물려받으면 **틀린 터미널**을 말하게 된다.
class TransitOption {
  const TransitOption({
    required this.modeLabel,
    this.mode,
    this.toPlace,
    this.durationMinutes,
    this.departures = const [],
  });

  static TransitOption? tryParse(Map<String, dynamic> json) {
    final label = (json['modeLabel'] as String?)?.trim();
    if (label == null || label.isEmpty) return null;
    return TransitOption(
      modeLabel: label,
      mode: _text(json['mode']),
      toPlace: _text(json['toPlace']),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      departures: TransitDeparture.parseList(json['departures']),
    );
  }

  final String modeLabel;

  /// 수단 계약 키 — [TransitAccess.mode]와 같은 값 공간이다
  final String? mode;
  final String? toPlace;

  /// **대개 비어 있다.** 서버는 대안의 구간을 재지 않는다 — 열차 대안만
  /// 값이 오고 버스·여객선은 null로 고정이다(`RegionAccessService.alternativesTo`)
  final int? durationMinutes;

  /// 이 수단으로 탈 수 있는 편들 (core #420). 대표와 같은 이유로 빌 수 있다.
  ///
  /// **대안에도 싣는 이유**는 고르는 근거가 되기 때문이다 — 시외버스가 40분
  /// 더 걸려도 지금 바로 타는 편이 있으면 그쪽을 고른다
  final List<TransitDeparture> departures;

  String? get durationLabel => formatTransitDuration(durationMinutes);
}

/// 탈 수 있는 편 하나 — 몇 시 차가 있는가 (core #420).
///
/// **시각을 문자열로 받지 않는다.** 서버가 `2026-09-05T07:20:00` 꼴로 내리고
/// 오전/오후·24시간 표기는 화면이 정한다.
class TransitDeparture {
  const TransitDeparture({
    required this.departAt,
    this.vehicleType,
    this.arriveAt,
    this.durationMinutes,
  });

  static List<TransitDeparture> parseList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map<String, dynamic>) ?tryParse(item),
    ];
  }

  /// 출발 시각이 없으면 편이 아니다 — 이 카드가 답하는 질문이 "몇 시 차인가"다
  static TransitDeparture? tryParse(Map<String, dynamic> json) {
    final departAt = _dateTime(json['departAt']);
    if (departAt == null) return null;
    return TransitDeparture(
      departAt: departAt,
      vehicleType: _text(json['vehicleType']),
      arriveAt: _dateTime(json['arriveAt']),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
    );
  }

  /// 출발 시각
  final DateTime departAt;

  /// `무궁화호`·`우등` — 같은 구간에 여러 등급이 섞인다
  final String? vehicleType;

  /// 도착 시각 — 모르면 null
  final DateTime? arriveAt;

  /// 이 편의 소요시간(분). **카드 위쪽 값과 다를 수 있다** — 위쪽은 가장 빨리
  /// 닿는 편 기준이라, 무궁화와 KTX가 같은 구간에 섞이면 갈린다
  final int? durationMinutes;

  /// `07:20` — 24시간 표기. 시간표는 여러 줄이 세로로 붙어 자릿수가 같아야
  /// 눈으로 훑을 수 있다. 오전/오후를 앞에 붙이면 줄마다 폭이 달라진다
  String get departLabel => _hhmm(departAt);

  /// `07:20 → 09:49` — 도착을 모르면 출발만
  String get rangeLabel =>
      arriveAt == null ? departLabel : '$departLabel → ${_hhmm(arriveAt!)}';

  String? get durationLabel => formatTransitDuration(durationMinutes);

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
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

/// 서버가 주는 `2026-09-05T07:20:00` — 못 읽으면 null이라 그 편을 버린다.
///
/// **타임존 없는 값이다.** 서버가 한국 시각으로 내리고 사용자도 한국에서
/// 보므로 그대로 로컬로 읽는다 — `toLocal()`을 태우면 UTC로 오해해 9시간이
/// 밀린다
DateTime? _dateTime(Object? value) {
  final s = (value as String?)?.trim();
  if (s == null || s.isEmpty) return null;
  return DateTime.tryParse(s);
}

String? _text(Object? value) {
  final s = (value as String?)?.trim();
  return (s == null || s.isEmpty) ? null : s;
}
