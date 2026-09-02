import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/region_geo.dart';

/// 인구감소지역 89곳의 시군구 경계 (`assets/data/region_polygons.json`).
///
/// 랜덤 지역 선택에서 핀이 내려앉은 **그 시군구**를 연두색으로 채우고 지도
/// 선과 같은 색으로 테두리를 긋는다. 시안 지도 SVG에는 시군구 조각이 없어
/// (시도 경계까지만) 통계청 행정구역 경계(southkorea-maps, 2013 단순화본)에서
/// 89곳만 추려 위경도로 담았다. 지도와 같은 투영([RandomBoard.project])으로
/// 그리므로 지도의 시도 선과 몇 px 안에서 맞는다 — 다른 출처라 완전히 겹치지는
/// 않는다.
///
/// 키는 `시도약칭/시군구`(`강원/정선군`) — 동구·서구·고성군처럼 이름이
/// 겹치는 곳을 가른다. 값은 외곽 고리들(섬이 많은 군은 여럿), 점은 `[lat, lng]`.
class RegionPolygons {
  const RegionPolygons(this._rings);

  final Map<String, List<List<(double, double)>>> _rings;

  static RegionPolygons parse(String json) {
    final raw = jsonDecode(json) as Map<String, dynamic>;
    return RegionPolygons({
      for (final entry in raw.entries)
        entry.key: [
          for (final ring in entry.value as List)
            [
              for (final p in ring as List)
                ((p[0] as num).toDouble(), (p[1] as num).toDouble()),
            ],
        ],
    });
  }

  int get length => _rings.length;

  /// [polygonKeyFor]로 만든 키의 고리들. 없으면 null
  List<List<(double, double)>>? ringsFor(String key) => _rings[key];
}

/// 서버 이름으로 경계 키를 만든다 — 좌표 표와 같은 규칙으로 찾는다.
/// 표에 없는 곳은 null (칩은 놓여도 면은 못 채운다)
String? polygonKeyFor({required String name, String? sido}) {
  final geo = regionGeoFor(name: name, sido: sido);
  return geo == null ? null : '${geo.sido}/${geo.name}';
}

/// 앱 번들에서 한 번 읽는다 — 85KB라 첫 진입 때 잠깐이면 된다.
/// 못 읽으면 예외 대신 빈 값으로 — 면을 못 채울 뿐 던지기는 되어야 한다
final regionPolygonsProvider = FutureProvider<RegionPolygons>((ref) async {
  try {
    // loadString은 50KB를 넘으면 isolate에서 푼다 — 위젯 테스트(가짜 시계)
    // 에서는 그 결과가 돌아오지 않아 면이 안 그려진다. 바이트로 읽어 직접 푼다
    final bytes = await rootBundle.load('assets/data/region_polygons.json');
    return RegionPolygons.parse(utf8.decode(bytes.buffer.asUint8List()));
  } on Object {
    return const RegionPolygons({});
  }
});
