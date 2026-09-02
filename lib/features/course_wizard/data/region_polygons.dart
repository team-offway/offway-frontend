import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/region_geo.dart';

/// 인구감소지역 89곳의 시군구 경계 (`assets/data/region_polygons.json`).
///
/// 랜덤 지역 선택에서 핀이 내려앉은 군을 연두색으로 채우는 데 쓴다. 시안
/// 지도 SVG에는 시도 경계까지만 있어 군 하나를 따로 채울 면이 없다 —
/// 통계청 행정구역 경계(southkorea-maps, 2013 단순화본)에서 89곳만 추려
/// 위경도로 담았다. 지도와 같은 투영([RandomBoard.project])으로 그리면
/// 시안 지도의 선과 몇 px 안에서 맞는다.
///
/// 키는 `시도약칭/시군구`(`강원/정선군`)다 — 동구·서구·고성군처럼 이름이
/// 겹치는 곳을 가른다. 값은 외곽 고리들(다도해 군은 섬마다 하나)이고,
/// 각 점은 `[lat, lng]`다.
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

/// 서버 이름으로 폴리곤 키를 만든다 — 좌표 표와 같은 규칙으로 찾는다.
/// 표에 없는 곳은 null
String? polygonKeyFor({required String name, String? sido}) {
  final geo = regionGeoFor(name: name, sido: sido);
  return geo == null ? null : '${geo.sido}/${geo.name}';
}

/// 앱 번들에서 한 번 읽는다 — 85KB라 첫 진입 때 잠깐이면 된다.
/// 못 읽으면 예외 대신 빈 값으로 — 면을 못 채울 뿐 던지기는 되어야 한다
final regionPolygonsProvider = FutureProvider<RegionPolygons>((ref) async {
  try {
    final json = await rootBundle.loadString(
      'assets/data/region_polygons.json',
    );
    return RegionPolygons.parse(json);
  } on Object {
    return const RegionPolygons({});
  }
});
