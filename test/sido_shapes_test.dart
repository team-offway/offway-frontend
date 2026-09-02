import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/course_wizard/data/sido_shapes.dart';
import 'package:offway/features/course_wizard/domain/random_map.dart';
import 'package:offway/features/course_wizard/domain/region_geo.dart';

/// 착지하면 채울 시도 조각이 좌표 표·지도와 맞물리는지 고정한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SidoShapes shapes;
  setUpAll(() async {
    shapes = SidoShapes.parse(
      await rootBundle.loadString('assets/data/sido_shapes.json'),
    );
  });

  test('인구감소지역이 있는 시도 11곳의 조각이 전부 있다', () {
    for (final sido in kRegionGeos.map((g) => g.sido).toSet()) {
      expect(shapes.ringsFor(sido), isNotEmpty, reason: sido);
    }
  });

  test('충남만 지도 조각 아래에 그린다 — 시안 지도에 충남 조각이 없다', () {
    expect(shapes.isUnderOverlay('충남'), isTrue);
    expect(shapes.isUnderOverlay('강원'), isFalse);
  });

  test('서버 이름으로 시도 키를 만든다 — 겹치는 이름은 시도로 가른다', () {
    expect(sidoKeyFor(name: '정선군'), '강원');
    expect(sidoKeyFor(name: '고성군', sido: '경상남도'), '경남');
    expect(sidoKeyFor(name: '동구', sido: '부산광역시'), '부산');
    // 표에 없어도 서버 시도로는 만든다 — 면은 채울 수 있다
    expect(sidoKeyFor(name: '서울', sido: '서울특별시'), '서울');
    expect(sidoKeyFor(name: '서울'), isNull);
  });

  test('좌표 표의 89곳이 제 시도 조각 근처에 놓인다', () {
    // 섬·해안 지역은 시안 지도가 뭉뚱그려 그려 점이 조각 밖일 수 있다 —
    // 시도 조각 전체의 상자에서 10px 안이면 같은 곳으로 본다
    for (final g in kRegionGeos) {
      // 울릉은 시안이 자리를 옮겨 그린 섬이고, 인천 조각은 본토뿐이라
      // 강화·옹진(섬)이 멀다 — 시안 지도가 그 섬들을 그리지 않았다
      if (g.name == '울릉군' || g.sido == '인천') continue;
      final p = RandomBoard.project(g.lat, g.lng);
      Rect? box;
      for (final ring in shapes.ringsFor(g.sido)!) {
        for (final o in ring) {
          final r = Rect.fromLTWH(o.dx, o.dy, 0, 0);
          box = box == null ? r : box.expandToInclude(r);
        }
      }
      expect(
        box!.inflate(10).contains(p),
        isTrue,
        reason: '${g.sido}/${g.name} → $p vs $box',
      );
    }
  });

  test('조각은 전부 지도 안에 있다', () {
    for (final sido in kRegionGeos.map((g) => g.sido).toSet()) {
      for (final ring in shapes.ringsFor(sido)!) {
        for (final o in ring) {
          expect(
            RandomBoard.mapRect.inflate(1).contains(o),
            isTrue,
            reason: sido,
          );
        }
      }
    }
  });
}
