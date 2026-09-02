import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/course_wizard/data/region_polygons.dart';
import 'package:offway/features/course_wizard/domain/random_map.dart';
import 'package:offway/features/course_wizard/domain/region_geo.dart';

/// 착지한 시군구를 채울 경계 데이터가 좌표 표·지도와 맞물리는지 고정한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RegionPolygons polygons;
  setUpAll(() async {
    polygons = RegionPolygons.parse(
      await rootBundle.loadString('assets/data/region_polygons.json'),
    );
  });

  test('89곳 전부 경계가 있다', () {
    expect(polygons.length, 89);
    for (final g in kRegionGeos) {
      expect(
        polygons.ringsFor('${g.sido}/${g.name}'),
        isNotEmpty,
        reason: '${g.sido}/${g.name}',
      );
    }
  });

  test('서버 이름으로 키를 만든다 — 겹치는 이름은 시도로 가른다', () {
    expect(polygonKeyFor(name: '정선군'), '강원/정선군');
    expect(polygonKeyFor(name: '고성군', sido: '경상남도'), '경남/고성군');
    expect(polygonKeyFor(name: '동구', sido: '부산광역시'), '부산/동구');
    expect(polygonKeyFor(name: '서울'), isNull);
  });

  test('좌표 표의 점이 제 경계 안에 있다 — 표와 경계가 같은 곳을 가리킨다', () {
    for (final g in kRegionGeos) {
      final rings = polygons.ringsFor('${g.sido}/${g.name}')!;
      // 경계는 지도 프레임 좌표라 투영에서 원점을 뺀다. 지도 선에 붙이며
      // 경계가 몇 px 움직였으므로 안이거나 3px 안이면 같은 곳으로 본다
      // (부산 동구처럼 작은 구는 표의 점이 해안선 바깥에 놓인다)
      final p = RandomBoard.project(g.lat, g.lng) - RandomBoard.mapOrigin;
      expect(
        rings.any((ring) => _contains(ring, p) || _edgeDistance(ring, p) < 3),
        isTrue,
        reason: '${g.name} (${g.lat}, ${g.lng})',
      );
    }
  });

  test('경계의 한가운데가 지도 안에 들어간다', () {
    // 점 하나하나는 지도 밖일 수 있다 — 백령도(옹진)·가거도(신안)는 시안
    // 지도가 그리지 않는다. 면의 중심이 지도 안이면 채워도 어색하지 않다
    for (final g in kRegionGeos) {
      if (g.name == '울릉군') continue; // 시안이 자리를 옮겨 그린 섬
      var sum = Offset.zero;
      var n = 0;
      for (final ring in polygons.ringsFor('${g.sido}/${g.name}')!) {
        for (final o in ring) {
          sum += o;
          n++;
        }
      }
      expect(
        RandomBoard.mapRect.contains(
          RandomBoard.mapOrigin + sum / n.toDouble(),
        ),
        isTrue,
        reason: g.name,
      );
    }
  });
}

/// 짝수-홀수 규칙 — 고리 하나 안에 점이 있는가
bool _contains(List<Offset> ring, Offset p) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final a = ring[i];
    final b = ring[j];
    if ((a.dy > p.dy) != (b.dy > p.dy)) {
      final x = a.dx + (p.dy - a.dy) * (b.dx - a.dx) / (b.dy - a.dy);
      if (x > p.dx) inside = !inside;
    }
  }
  return inside;
}

/// 점에서 고리의 변까지 가장 가까운 거리
double _edgeDistance(List<Offset> ring, Offset p) {
  var best = double.infinity;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final a = ring[j];
    final b = ring[i];
    final ab = b - a;
    final t = ab.distanceSquared == 0
        ? 0.0
        : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / ab.distanceSquared)
              .clamp(0.0, 1.0);
    best = math.min(best, (p - (a + ab * t)).distance);
  }
  return best;
}
