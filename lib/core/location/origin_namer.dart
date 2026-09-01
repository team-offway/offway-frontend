import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:geocoding/geocoding.dart';

/// 출발 좌표를 사람이 부르는 이름으로 — `서울`·`성남`·`정선`.
///
/// 코스를 담을 때 한 번 불러 서버에 실어 보내고(core #382), 서버가 자차
/// 도착 안내의 `fromPlace`로 되돌려준다 — 코스를 나중에 열 때는 앱 손에
/// 좌표가 없어 그 자리에서 변환할 수 없기 때문이다.
///
/// iOS 내장 역지오코딩(CLGeocoder)이라 키·콘솔 등록이 없다. **실패하면
/// null이다** — 이름 없이 시간·거리만 그리는 화면이 폴백으로 이미 서 있어,
/// 여기서 버티거나 되풀이할 이유가 없다.
Future<String?> resolveOriginName(double lat, double lng) async {
  try {
    final placemarks = await Geocoding()
        .placemarkFromCoordinates(
          lat,
          lng,
          // 영어 기기에서 'Seoul'이 오면 안 된다 — 화면도 서버 값도 한글이다
          locale: const Locale('ko', 'KR'),
        )
        // 담기 요청을 붙들 값이 아니다 — 늦으면 이름 없이 보낸다
        .timeout(const Duration(seconds: 2));
    final place = placemarks.firstOrNull;
    if (place == null) return null;
    return shortOriginName(
      locality: place.locality,
      subAdministrativeArea: place.subAdministrativeArea,
      administrativeArea: place.administrativeArea,
    );
  } on Object catch (e) {
    // 곁가지 값이다 — 지오코딩이 죽어도 담기는 그대로 간다
    debugPrint('출발지 이름 변환 실패: $e');
    return null;
  }
}

/// 행정구역명을 부르는 이름으로 다듬는다.
///
/// macOS CLGeocoder 실측(2026-09-01, ko_KR)으로 iOS가 주는 모양을 확인했다 —
/// `test/origin_namer_test.dart`에 28곳이 표로 있다. 요점 셋:
///
/// - **광역시·특별시·세종은 locality에도 같은 이름**이 온다 (`서울특별시`)
/// - **군은 locality가 비고 `subAdministrativeArea`에 온다** (`정선군`)
/// - 시는 locality에 온다 (`성남시`·`제주시`), 도는 administrativeArea뿐
///
/// | 들어옴 | 나감 |
/// |---|---|
/// | locality `서울특별시` | `서울` |
/// | locality `성남시` / `제주시` | `성남` / `제주` |
/// | subAdministrativeArea `정선군` (locality 없음) | `정선` |
/// | locality `인천광역시` + subAdministrativeArea `옹진군` | `인천` — 시가 군보다 먼저 |
/// | administrativeArea `강원특별자치도`만 | `강원` |
/// | administrativeArea `경기도`만 | `경기도` — '경기'는 어색하다 |
///
/// 시 → 군 → 시·도 순으로 고르고, **어느 필드에서 왔든 같은 규칙으로
/// 다듬는다** — 광역시 접미는 locality에도 붙어 오므로 한쪽에만 걸면
/// `서울특별시`가 `서울특별`로 남는다. 구·읍·면·동은 부르는 단위가 아니라
/// 건너뛴다.
@visibleForTesting
String? shortOriginName({
  String? locality,
  String? subAdministrativeArea,
  String? administrativeArea,
}) {
  for (final candidate in [locality, subAdministrativeArea]) {
    final name = _clean(candidate);
    if (name != null && !_isSubUnit(name)) return _shorten(name);
  }
  final area = _clean(administrativeArea);
  return area == null ? null : _shorten(area);
}

/// `강남구`·`정선읍`처럼 시·군 아래 단위인가
bool _isSubUnit(String name) =>
    name.length >= 2 &&
    const ['구', '읍', '면', '동'].contains(name[name.length - 1]);

/// 접미를 뗀 부르는 이름.
///
/// 긴 접미부터 본다 — '특별시'가 '특별자치시'를 먼저 물면 `세종특별자치시`가
/// `세종특별자치`로 남는다. 그 다음이 시·군 한 글자다.
String _shorten(String name) {
  for (final suffix in const ['특별자치시', '특별자치도', '특별시', '광역시']) {
    if (name.endsWith(suffix) && name.length > suffix.length) {
      return name.substring(0, name.length - suffix.length);
    }
  }
  // `성남시` → `성남`. 두 글자 이름(`시흥`의 `시`처럼 이름 일부인 경우)은
  // 애초에 접미가 아니므로 세 글자부터만 뗀다
  if (name.length >= 3 && (name.endsWith('시') || name.endsWith('군'))) {
    return name.substring(0, name.length - 1);
  }
  return name;
}

String? _clean(String? raw) {
  final s = raw?.trim();
  return (s == null || s.isEmpty) ? null : s;
}
