import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/course_wizard/data/sido_polygons.dart';
import 'package:offway/features/course_wizard/domain/random_map.dart';
import 'package:offway/features/course_wizard/domain/region_geo.dart';

/// 착지하면 채울 시도 경계가 좌표 표·지도와 맞물리는지 고정한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SidoPolygons polygons;
  setUpAll(() async {
    polygons = SidoPolygons.parse(
      await rootBundle.loadString('assets/data/sido_polygons.json'),
    );
  });

  test('시도 17곳 경계가 있다', () {
    expect(polygons.length, 17);
    for (final sido in const ['강원', '충남', '전남', '경북', '경남', '부산', '인천']) {
      expect(polygons.ringsFor(sido), isNotEmpty, reason: sido);
    }
  });

  test('서버 이름으로 시도 키를 만든다 — 겹치는 이름은 시도로 가른다', () {
    expect(sidoKeyFor(name: '정선군'), '강원');
    expect(sidoKeyFor(name: '고성군', sido: '경상남도'), '경남');
    expect(sidoKeyFor(name: '동구', sido: '부산광역시'), '부산');
    // 표에 없어도 서버 시도로는 만든다 — 면은 채울 수 있다
    expect(sidoKeyFor(name: '서울', sido: '서울특별시'), '서울');
    expect(sidoKeyFor(name: '서울'), isNull);
  });

  test('좌표 표의 89곳이 전부 제 시도 경계 안에 있다', () {
    for (final g in kRegionGeos) {
      final rings = polygons.ringsFor(g.sido)!;
      expect(
        rings.any((ring) => _contains(ring, g.lat, g.lng)),
        isTrue,
        reason: '${g.sido}/${g.name} (${g.lat}, ${g.lng})',
      );
    }
  });

  test('투영하면 시도 면의 한가운데가 지도 안에 들어간다', () {
    for (final sido in const ['강원', '충남', '전남', '경북', '경남', '전북', '충북', '경기']) {
      var sumX = 0.0, sumY = 0.0, n = 0;
      for (final ring in polygons.ringsFor(sido)!) {
        for (final (lat, lng) in ring) {
          final p = RandomBoard.project(lat, lng);
          sumX += p.dx;
          sumY += p.dy;
          n++;
        }
      }
      expect(
        RandomBoard.mapRect.contains(Offset(sumX / n, sumY / n)),
        isTrue,
        reason: sido,
      );
    }
  });
}

/// 짝수-홀수 규칙 — 고리 하나 안에 점이 있는가
bool _contains(List<(double, double)> ring, double lat, double lng) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final (lat1, lng1) = ring[i];
    final (lat2, lng2) = ring[j];
    if ((lat1 > lat) != (lat2 > lat)) {
      final x = lng1 + (lat - lat1) * (lng2 - lng1) / (lat2 - lat1);
      if (x > lng) inside = !inside;
    }
  }
  return inside;
}
