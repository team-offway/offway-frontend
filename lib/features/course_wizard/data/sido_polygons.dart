import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/region_geo.dart';

/// 시도 17곳의 경계 (`assets/data/sido_polygons.json`).
///
/// 랜덤 지역 선택에서 핀이 내려앉으면 **그 지역이 속한 시도**를 연두색으로
/// 채운다(시안 착지 화면 — 보령에 앉으면 충남 전체). 시안 지도 SVG에는
/// 채울 면이 따로 없어, 통계청 행정구역 경계(southkorea-maps, 2013
/// 단순화본)에서 시도 외곽만 위경도로 담았다. 지도와 같은 투영
/// ([RandomBoard.project])으로 그리면 시안 지도의 선과 몇 px 안에서 맞는다.
///
/// 키는 시도 약칭(`강원`·`경남`·`부산`)이다 — 좌표 표([kRegionGeos])와 같다.
/// 값은 외곽 고리들(섬이 많은 시도는 여럿)이고, 각 점은 `[lat, lng]`다.
class SidoPolygons {
  const SidoPolygons(this._rings);

  final Map<String, List<List<(double, double)>>> _rings;

  static SidoPolygons parse(String json) {
    final raw = jsonDecode(json) as Map<String, dynamic>;
    return SidoPolygons({
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

  /// 시도 약칭의 고리들. 없으면 null
  List<List<(double, double)>>? ringsFor(String sido) => _rings[sido];
}

/// 서버 이름으로 시도 키를 만든다.
///
/// 좌표 표에서 찾아 그 시도를 쓴다 — 표가 이름 중복(동구·고성군)을 이미
/// 가려 놓았다. 표에 없는 곳은 서버가 준 시도 이름으로라도 만든다
String? sidoKeyFor({required String name, String? sido}) {
  final geo = regionGeoFor(name: name, sido: sido);
  if (geo != null) return geo.sido;
  return sido == null ? null : sidoKey(sido);
}

/// 앱 번들에서 한 번 읽는다 — 68KB라 첫 진입 때 잠깐이면 된다.
/// 못 읽으면 예외 대신 빈 값으로 — 면을 못 채울 뿐 던지기는 되어야 한다
final sidoPolygonsProvider = FutureProvider<SidoPolygons>((ref) async {
  try {
    final json = await rootBundle.loadString('assets/data/sido_polygons.json');
    return SidoPolygons.parse(json);
  } on Object {
    return const SidoPolygons({});
  }
});
