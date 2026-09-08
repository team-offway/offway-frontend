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
    this.viaPlace,
    this.vehicleType,
    this.durationMinutes,
    this.distanceKm,
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
      mode: _text(raw['mode']),
      status: TransitStatus.parse(raw['status'] as String?),
      fromPlace: _text(raw['fromPlace']),
      toPlace: _text(raw['toPlace']),
      viaPlace: _text(raw['viaPlace']),
      vehicleType: _text(raw['vehicleType']),
      durationMinutes: (raw['durationMinutes'] as num?)?.toInt(),
      distanceKm: (raw['distanceKm'] as num?)?.toInt(),
      alternatives: [
        for (final item in (raw['alternatives'] as List?) ?? const [])
          if (item is Map<String, dynamic>) ?TransitOption.tryParse(item),
      ],
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

  /// 갈아타는 지점 — 직통이 없어 허브를 한 번 거칠 때만 온다 (core #508).
  ///
  /// 이때 [durationMinutes]는 두 구간의 합에 환승 대기(40분)를 더한 값이다.
  /// **null을 "직통"으로 읽으면 안 된다** (core #517) — 노선이 없거나
  /// 그날 차가 없을 때도 null이다. 직통 여부는 [status]가 말하고, 이 값은
  /// "경유가 붙었는가"만 말한다
  final String? viaPlace;

  /// `KTX`처럼 구체적인 편명 — 열차만 온다
  final String? vehicleType;

  /// 타고 가는 시간(분). **기다리는 시간은 안 들어 있다** —
  /// 버스·여객선은 시간표를 못 물어 다음 편까지의 대기를 모른다
  final int? durationMinutes;

  /// 출발지에서 도착 지점까지의 **직선거리**(km) — 실제 주행거리가 아니다
  /// (core #380). 옛 서버는 안 실어 null일 수 있다
  final int? distanceKm;

  /// 이 지역에 닿는 다른 수단들. 없으면 빈 목록이다.
  ///
  /// 서버가 `departures`(탈 수 있는 편들, core #420)도 함께 싣지만 앱은
  /// 읽지 않는다 — 내 코스의 시간표를 빼 달라는 요청으로 걷어냈다
  final List<TransitOption> alternatives;

  /// 안내를 그릴 만한 값이 있는가 — 내리는 곳조차 모르면 할 말이 없다
  bool get isPresentable => toPlace != null && toPlace!.isNotEmpty;

  /// `1시간 30분` · `50분` — 모르면 null
  String? get durationLabel => formatTransitDuration(durationMinutes);
}

/// 이 지역에 닿는 수단 하나 — 대표 말고 대안 쪽.
///
/// **서버가 다섯 가지만 준다** — `mode`·`modeLabel`·`toPlace`·`status`·
/// `durationMinutes`. 출발지와 편명은 일부러 뺐다(core `TransitOptionResponse`).
/// 수단이 다르면 타는 곳도 다르므로, 대표의 값을 물려받으면 **틀린
/// 터미널**을 말하게 된다.
class TransitOption {
  const TransitOption({
    required this.modeLabel,
    this.mode,
    this.toPlace,
    this.status = TransitStatus.pointOnly,
    this.durationMinutes,
  });

  static TransitOption? tryParse(Map<String, dynamic> json) {
    final label = (json['modeLabel'] as String?)?.trim();
    if (label == null || label.isEmpty) return null;
    return TransitOption(
      modeLabel: label,
      mode: _text(json['mode']),
      toPlace: _text(json['toPlace']),
      // 옛 서버는 안 실었다 — 그때는 "지점만 안다"로 본다. 노선이 없다고
      // 지레짐작해 버튼에서 빼면 멀쩡한 수단이 사라진다
      status: json['status'] == null
          ? TransitStatus.pointOnly
          : TransitStatus.parse(json['status'] as String?),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
    );
  }

  final String modeLabel;

  /// 이 수단의 상태 (core #513) — 소요시간이 비어 있는 **이유**를 여기서
  /// 읽는다. 아직 안 잰 것([TransitStatus.pointOnly])과 노선이 없는 것
  /// ([TransitStatus.noRoute])은 화면이 할 일이 다르다
  final TransitStatus status;

  /// 갈아탈 수 있는 수단인가 — 노선이 없는 수단은 버튼에 올리지 않는다.
  /// 눌러 보내면 서버가 없는 길로 코스를 다시 짜게 된다
  bool get isSelectable => mode != null && status != TransitStatus.noRoute;

  /// 수단 계약 키 — [TransitAccess.mode]와 같은 값 공간이다
  final String? mode;
  final String? toPlace;

  /// 잰 구간이면 온다 (core #513부터 버스도 실린다) — 안 잰 구간은 null
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

  /// 두 지점을 잇는 **노선 자체가 없다** (core #508·#513).
  ///
  /// [noServiceOnDate]와 갈라야 한다 — 그쪽은 "그날 차가 없다"라 날짜를
  /// 바꾸면 되고, 이쪽은 다른 수단을 봐야 한다. 예전엔 서버가 여기서도
  /// "아직 안 물었다"로 답해 서울에서 봉화까지 고속버스로 가라는 안내가
  /// 나갔다 — 봉화행 노선은 어디에도 없는데. **없는 길을 안내하는 것은
  /// 아무 안내도 안 하는 것보다 나쁘다.** 화면은 출발지·거리를 지우고
  /// 노선이 없다고 적는다
  noRoute('NO_ROUTE'),

  /// 출발지를 몰라 답할 수 없다 (core #423).
  ///
  /// 좌표 없이 저장된 옛 코스가 이 상태로 온다 — **외부나 노선의 사정이
  /// 아니라 우리 데이터가 빈 것**이라 [unavailable]과 구분한다. 서버가 이
  /// 상태를 만든 이유도 그것이다. 예전에는 필드가 통째로 빠져, 앱이 "이 값을
  /// 모르는 옛 서버"와 "서버가 답을 못 하는 코스"를 가릴 수 없었다.
  ///
  /// **화면은 그대로 접는다.** 수단도 내리는 곳도 없어 할 말이 없고, 원본
  /// 출발지가 사라져 되살릴 방법도 없다(core #423 — 복구 불가로 못박았다).
  /// 고칠 수 없는 사정을 안내로 띄우면 답답하기만 하다. 앱은 늘 좌표를 실으므로
  /// 새로 담는 코스에서는 이 상태가 나오지 않는다
  originUnknown('ORIGIN_UNKNOWN'),

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
