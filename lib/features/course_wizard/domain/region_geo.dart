/// 인구감소지역 89곳의 대표 좌표 (군청·구청 소재지 기준, 소수 셋째 자리).
///
/// 랜덤 지역 선택 지도에 칩을 놓는 데 쓴다. **서버가 좌표를 아직 안 준다** —
/// `Region` 엔티티에는 lat·lng가 있지만 추천·목록·상세 응답 어디에도 실리지
/// 않는다(core 요청 예정). 응답에 `lat`·`lng`가 실리면 그 값이 이 표보다
/// 우선한다([regionGeoFor] 호출부 참고).
///
/// 이름이 겹치는 곳이 있다 — 고성군(강원·경남), 동구·서구(부산·대구) —
/// 그래서 시도까지 본다. 서버 시도 이름은 `강원특별자치도`·`전남광주통합특별시`처럼
/// 길게 오므로 앞 두 글자(경상남·경상북 등은 세 글자)로 맞춘다.
class RegionGeo {
  const RegionGeo(this.sido, this.name, this.lat, this.lng);

  /// 시도 약칭 — `강원`·`경남`·`부산`
  final String sido;

  /// 시군구 이름 — `정선군`·`동구`
  final String name;
  final double lat;
  final double lng;
}

const kRegionGeos = <RegionGeo>[
  // 부산 (3)
  RegionGeo('부산', '동구', 35.129, 129.045),
  RegionGeo('부산', '서구', 35.098, 129.024),
  RegionGeo('부산', '영도구', 35.082, 129.070),
  // 대구 (2)
  RegionGeo('대구', '남구', 35.846, 128.597),
  RegionGeo('대구', '서구', 35.872, 128.559),
  // 인천 (2)
  RegionGeo('인천', '강화군', 37.747, 126.488),
  // 군청은 인천 본토(미추홀구)에 있다 — 지도에는 섬(덕적도)에 놓아야 맞다
  RegionGeo('인천', '옹진군', 37.226, 126.143),
  // 경기 (2)
  RegionGeo('경기', '가평군', 37.831, 127.510),
  RegionGeo('경기', '연천군', 38.096, 127.075),
  // 강원 (12)
  RegionGeo('강원', '고성군', 38.381, 128.468),
  RegionGeo('강원', '삼척시', 37.450, 129.165),
  RegionGeo('강원', '양구군', 38.110, 127.990),
  RegionGeo('강원', '양양군', 38.075, 128.619),
  RegionGeo('강원', '영월군', 37.184, 128.462),
  RegionGeo('강원', '정선군', 37.381, 128.661),
  RegionGeo('강원', '철원군', 38.147, 127.313),
  RegionGeo('강원', '태백시', 37.164, 128.986),
  RegionGeo('강원', '평창군', 37.371, 128.390),
  RegionGeo('강원', '홍천군', 37.697, 127.889),
  RegionGeo('강원', '화천군', 38.106, 127.708),
  RegionGeo('강원', '횡성군', 37.492, 127.985),
  // 충북 (6)
  RegionGeo('충북', '괴산군', 36.815, 127.787),
  RegionGeo('충북', '단양군', 36.985, 128.366),
  RegionGeo('충북', '보은군', 36.489, 127.729),
  RegionGeo('충북', '영동군', 36.175, 127.783),
  RegionGeo('충북', '옥천군', 36.306, 127.571),
  RegionGeo('충북', '제천시', 37.133, 128.191),
  // 충남 (9)
  RegionGeo('충남', '공주시', 36.447, 127.119),
  RegionGeo('충남', '금산군', 36.109, 127.488),
  RegionGeo('충남', '논산시', 36.187, 127.099),
  RegionGeo('충남', '보령시', 36.333, 126.613),
  RegionGeo('충남', '부여군', 36.276, 126.910),
  RegionGeo('충남', '서천군', 36.080, 126.692),
  RegionGeo('충남', '예산군', 36.682, 126.845),
  RegionGeo('충남', '청양군', 36.459, 126.802),
  RegionGeo('충남', '태안군', 36.746, 126.298),
  // 전북 (10)
  RegionGeo('전북', '고창군', 35.436, 126.702),
  RegionGeo('전북', '김제시', 35.804, 126.880),
  RegionGeo('전북', '남원시', 35.416, 127.390),
  RegionGeo('전북', '무주군', 36.007, 127.661),
  RegionGeo('전북', '부안군', 35.732, 126.733),
  RegionGeo('전북', '순창군', 35.374, 127.138),
  RegionGeo('전북', '임실군', 35.618, 127.289),
  RegionGeo('전북', '장수군', 35.647, 127.521),
  RegionGeo('전북', '정읍시', 35.570, 126.856),
  RegionGeo('전북', '진안군', 35.792, 127.425),
  // 전남 (16)
  RegionGeo('전남', '강진군', 34.642, 126.767),
  RegionGeo('전남', '고흥군', 34.611, 127.285),
  RegionGeo('전남', '곡성군', 35.282, 127.292),
  RegionGeo('전남', '구례군', 35.202, 127.463),
  RegionGeo('전남', '담양군', 35.321, 126.988),
  RegionGeo('전남', '보성군', 34.771, 127.080),
  RegionGeo('전남', '신안군', 34.833, 126.351),
  RegionGeo('전남', '영광군', 35.277, 126.512),
  RegionGeo('전남', '영암군', 34.800, 126.697),
  RegionGeo('전남', '완도군', 34.311, 126.755),
  RegionGeo('전남', '장성군', 35.302, 126.785),
  RegionGeo('전남', '장흥군', 34.682, 126.907),
  RegionGeo('전남', '진도군', 34.487, 126.263),
  RegionGeo('전남', '함평군', 35.066, 126.517),
  RegionGeo('전남', '해남군', 34.573, 126.599),
  RegionGeo('전남', '화순군', 35.064, 126.987),
  // 경북 (16)
  RegionGeo('경북', '고령군', 35.726, 128.263),
  RegionGeo('경북', '군위군', 36.243, 128.573),
  RegionGeo('경북', '문경시', 36.587, 128.187),
  RegionGeo('경북', '봉화군', 36.893, 128.733),
  RegionGeo('경북', '상주시', 36.411, 128.159),
  RegionGeo('경북', '성주군', 35.919, 128.283),
  RegionGeo('경북', '안동시', 36.568, 128.730),
  RegionGeo('경북', '영덕군', 36.415, 129.366),
  RegionGeo('경북', '영양군', 36.667, 129.112),
  RegionGeo('경북', '영주시', 36.806, 128.624),
  RegionGeo('경북', '영천시', 35.973, 128.939),
  RegionGeo('경북', '울릉군', 37.484, 130.906),
  RegionGeo('경북', '울진군', 36.993, 129.401),
  RegionGeo('경북', '의성군', 36.353, 128.697),
  RegionGeo('경북', '청도군', 35.647, 128.734),
  RegionGeo('경북', '청송군', 36.436, 129.057),
  // 경남 (11)
  RegionGeo('경남', '거창군', 35.687, 127.910),
  RegionGeo('경남', '고성군', 34.973, 128.322),
  RegionGeo('경남', '남해군', 34.838, 127.892),
  RegionGeo('경남', '밀양시', 35.504, 128.747),
  RegionGeo('경남', '산청군', 35.416, 127.874),
  RegionGeo('경남', '의령군', 35.322, 128.262),
  RegionGeo('경남', '창녕군', 35.545, 128.492),
  RegionGeo('경남', '하동군', 35.067, 127.751),
  RegionGeo('경남', '함안군', 35.273, 128.407),
  RegionGeo('경남', '함양군', 35.520, 127.725),
  RegionGeo('경남', '합천군', 35.567, 128.166),
];

/// 서버 시군구·시도 이름으로 좌표를 찾는다. 모르는 곳이면 null.
///
/// [name]은 `정선군`·`정선`·`동구` 어느 쪽이든 받는다 — 접미가 붙었든
/// 아니든 같은 곳이다. 이름이 하나뿐이면 시도를 안 봐도 된다(대부분).
/// 겹치면 [sido]로 가른다. 시도까지 없으면 첫 번째로 둔다 — 아예
/// 못 놓는 것보다 낫다.
RegionGeo? regionGeoFor({required String name, String? sido}) {
  final stem = _stem(name);
  final matches = kRegionGeos.where((g) => _stem(g.name) == stem).toList();
  if (matches.isEmpty) return null;
  if (matches.length == 1) return matches.first;

  final key = sido == null ? null : sidoKey(sido);
  for (final g in matches) {
    if (g.sido == key) return g;
  }
  return matches.first;
}

/// `강원특별자치도` → `강원`, `경상남도` → `경남`, `전남광주통합특별시` → `전남`.
///
/// 앞 두 글자로 충분한데 `경상남·경상북`, `전라남·전라북`, `충청남·충청북`만
/// 셋째 글자까지 봐야 갈린다.
String sidoKey(String sido) {
  final s = sido.trim();
  for (final (long, short) in const [
    ('경상남', '경남'),
    ('경상북', '경북'),
    ('전라남', '전남'),
    ('전라북', '전북'),
    ('충청남', '충남'),
    ('충청북', '충북'),
  ]) {
    if (s.startsWith(long)) return short;
  }
  return s.length >= 2 ? s.substring(0, 2) : s;
}

/// `정선군` → `정선`. 접미를 떼면 한 글자만 남는 `동구`·`남구`는 그대로다
String _stem(String name) {
  final n = name.trim();
  if (n.length >= 3 && const ['시', '군', '구'].contains(n[n.length - 1])) {
    return n.substring(0, n.length - 1);
  }
  return n;
}

/// 지도 칩에 쓸 짧은 이름 — [regionGeoFor]와 같은 규칙으로 접미를 뗀다
String regionChipLabel(String name) => _stem(name);
