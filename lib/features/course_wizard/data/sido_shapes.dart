import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/region_geo.dart';

/// 시안 지도에서 뽑은 시도 조각 (`assets/data/sido_shapes.json`).
///
/// 랜덤 지역 선택에서 핀이 내려앉으면 **그 지역이 속한 시도**를 연두색으로
/// 채운다(시안 착지 화면 — 보령에 앉으면 충남 전체). 다른 출처의 경계를
/// 투영해 그리면 지도 선과 어긋나 깨져 보이므로, **지도 SVG 자체의 시도
/// 조각**을 보드 좌표로 그대로 담았다 — 선과 정확히 맞는다.
///
/// 충남만 예외다. 시안 지도는 충남을 "이웃 시도를 다 그리고 남는 자리"로
/// 그려 조각이 없다. 그래서 충남은 본토 실루엣을 통째로 칠하고 그 위에
/// 나머지 시도 흰 조각([overlay] SVG)을 덮어 남는 자리만 보이게 한다 —
/// [isUnderOverlay]가 참인 시도는 지도 조각 아래에 그린다.
///
/// 키는 시도 약칭(`강원`·`경남`), 값은 고리들(섬은 따로), 점은 보드
/// 좌표 `[x, y]`다. 경기·경북은 서울·대구 고리를 구멍으로 품는다
/// (짝홀 규칙으로 뚫린다).
class SidoShapes {
  const SidoShapes(this._rings, this._underOverlay);

  final Map<String, List<List<Offset>>> _rings;
  final Set<String> _underOverlay;

  static SidoShapes parse(String json) {
    final raw = jsonDecode(json) as Map<String, dynamic>;
    final shapes = raw['shapes'] as Map<String, dynamic>;
    return SidoShapes(
      {
        for (final entry in shapes.entries)
          entry.key: [
            for (final ring in entry.value as List)
              [
                for (final p in ring as List)
                  Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
              ],
          ],
      },
      {for (final s in raw['underOverlay'] as List) s as String},
    );
  }

  int get length => _rings.length;

  /// 시도 약칭의 고리들(보드 좌표). 없으면 null
  List<List<Offset>>? ringsFor(String sido) => _rings[sido];

  /// 지도 조각 아래에 그려야 하는 시도인가 (충남)
  bool isUnderOverlay(String sido) => _underOverlay.contains(sido);
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

/// 앱 번들에서 한 번 읽는다 — 100KB 남짓이라 첫 진입 때 잠깐이면 된다.
/// 못 읽으면 예외 대신 빈 값으로 — 면을 못 채울 뿐 던지기는 되어야 한다
final sidoShapesProvider = FutureProvider<SidoShapes>((ref) async {
  try {
    // loadString은 50KB를 넘으면 isolate에서 푼다 — 위젯 테스트(가짜 시계)
    // 에서는 그 결과가 돌아오지 않아 면이 안 그려진다. 바이트로 읽어 직접 푼다
    final bytes = await rootBundle.load('assets/data/sido_shapes.json');
    return SidoShapes.parse(utf8.decode(bytes.buffer.asUint8List()));
  } on Object {
    return const SidoShapes({}, {});
  }
});
