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
/// | 들어옴 | 나감 |
/// |---|---|
/// | locality `성남시` | `성남` |
/// | locality `정선군` | `정선` |
/// | administrativeArea `서울특별시` (locality 없음) | `서울` |
/// | administrativeArea `경기도` (locality 없음) | `경기도` — '경기'는 어색하다 |
///
/// 시·군이 있으면 그것이 부르는 이름이고, 없을 때만 시·도로 물러난다
/// (서울·부산 같은 광역시는 iOS가 locality를 비워 보내는 일이 있다).
@visibleForTesting
String? shortOriginName({String? locality, String? administrativeArea}) {
  final city = _clean(locality);
  if (city != null) return _dropCitySuffix(city);
  final area = _clean(administrativeArea);
  if (area == null) return null;
  // '서울특별시' → '서울'. 긴 접미부터 본다 — '특별시'가 '특별자치시'를 먼저
  // 물면 '세종특별자치시'가 '세종특별자치'로 남는다
  for (final suffix in const ['특별자치시', '특별자치도', '특별시', '광역시']) {
    if (area.endsWith(suffix) && area.length > suffix.length) {
      return area.substring(0, area.length - suffix.length);
    }
  }
  return area;
}

/// `성남시` → `성남`. 두 글자 이름(`시흥`의 `시`처럼 이름 일부인 경우)은
/// 애초에 접미가 아니므로 세 글자부터만 뗀다
String _dropCitySuffix(String name) {
  if (name.length >= 3 && (name.endsWith('시') || name.endsWith('군'))) {
    return name.substring(0, name.length - 1);
  }
  return name;
}

String? _clean(String? raw) {
  final s = raw?.trim();
  return (s == null || s.isEmpty) ? null : s;
}
