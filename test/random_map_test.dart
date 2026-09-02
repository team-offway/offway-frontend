import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/course_wizard/domain/random_map.dart';
import 'package:offway/features/course_wizard/domain/region_geo.dart';

/// 랜덤 지역 선택의 순수 로직 — 좌표 찾기, 지도 투영, 칩 겹침 풀기, 핀 비행.
void main() {
  group('좌표 찾기', () {
    test('접미가 붙든 안 붙든 같은 곳이다', () {
      expect(regionGeoFor(name: '정선군')!.lat, 37.381);
      expect(regionGeoFor(name: '정선')!.lat, 37.381);
    });

    test('이름이 겹치면 시도로 가른다 — 고성군은 강원과 경남에 있다', () {
      expect(regionGeoFor(name: '고성군', sido: '강원특별자치도')!.sido, '강원');
      expect(regionGeoFor(name: '고성군', sido: '경상남도')!.sido, '경남');
      expect(regionGeoFor(name: '동구', sido: '부산광역시')!.sido, '부산');
      expect(regionGeoFor(name: '서구', sido: '대구광역시')!.sido, '대구');
    });

    test('시도 이름은 앞 글자로 맞춘다 — 통합 시도 이름도 포함', () {
      expect(sidoKey('전남광주통합특별시'), '전남');
      expect(sidoKey('전북특별자치도'), '전북');
      expect(sidoKey('경상북도'), '경북');
      expect(sidoKey('충청남도'), '충남');
      expect(sidoKey('인천광역시'), '인천');
    });

    test('모르는 곳은 null — 후보에 있어도 지도에 못 놓는다', () {
      expect(regionGeoFor(name: '서울'), isNull);
    });

    test('89곳이 전부 있다', () {
      expect(kRegionGeos.length, 89);
    });

    test('칩 이름은 접미를 뗀다 — 한 글자만 남으면 그대로', () {
      expect(regionChipLabel('완도군'), '완도');
      expect(regionChipLabel('동구'), '동구');
    });
  });

  group('지도 투영', () {
    test('북쪽이 위, 동쪽이 오른쪽이다', () {
      final busan = RandomBoard.project(35.180, 129.075);
      final gangwha = RandomBoard.project(37.747, 126.488);
      expect(busan.dx, greaterThan(gangwha.dx));
      expect(busan.dy, greaterThan(gangwha.dy));
    });

    test('89곳 전부 지도 안에 놓인다', () {
      for (final g in kRegionGeos) {
        final p = RandomBoard.project(g.lat, g.lng);
        expect(
          RandomBoard.mapRect.contains(p),
          isTrue,
          reason: '${g.name} → $p',
        );
      }
    });
  });

  group('칩 만들기', () {
    test('서버 좌표가 오면 표보다 먼저 쓴다 (core #405)', () {
      // 이름은 정선인데 좌표는 부산 — 서버가 진실이다
      final chips = buildMapChips([
        {
          'id': '1',
          'name': '정선군',
          'sido': '강원특별자치도',
          'lat': 35.180,
          'lng': 129.075,
        },
      ]);
      expect(chips.single.center, RandomBoard.project(35.180, 129.075));
      expect(chips.single.label, '정선');
      expect(chips.single.polygonKey, '강원/정선군');
    });

    test('좌표가 없으면 표로 물러나고, 표에도 없으면 놓지 않는다', () {
      final chips = buildMapChips([
        {'id': '1', 'name': '정선군', 'sido': '강원특별자치도'},
        {'id': '2', 'name': '서울', 'sido': '서울특별시'},
      ]);
      expect(chips.map((c) => c.regionId), ['1']);
      expect(chips.single.center, RandomBoard.project(37.381, 128.661));
    });
  });

  group('칩 겹침 풀기', () {
    test('전남 열여섯 곳을 놓아도 서로 겹치지 않는다', () {
      final chips = [
        for (final g in kRegionGeos.where((g) => g.sido == '전남'))
          MapChip(
            regionId: g.name,
            label: regionChipLabel(g.name),
            center: RandomBoard.project(g.lat, g.lng),
          ),
      ];
      relaxChips(chips);
      for (var a = 0; a < chips.length; a++) {
        for (var b = a + 1; b < chips.length; b++) {
          expect(
            chips[a].rect.overlaps(chips[b].rect),
            isFalse,
            reason: '${chips[a].label} × ${chips[b].label}',
          );
        }
        expect(RandomBoard.mapRect.contains(chips[a].center), isTrue);
      }
    });

    test('겹치지 않으면 움직이지 않는다', () {
      final chip = MapChip(
        regionId: '1',
        label: '정선',
        center: const Offset(200, 200),
      );
      relaxChips([chip]);
      expect(chip.center, const Offset(200, 200));
    });
  });

  group('핀 비행', () {
    const bounds = Rect.fromLTWH(30, 30, 342, 692);
    const target = Offset(120, 300);

    PinFlight plan({int seed = 1, Offset direction = const Offset(0, -1)}) =>
        PinFlight.plan(
          start: RandomBoard.pinRest,
          direction: direction,
          target: target,
          bounds: bounds,
          random: math.Random(seed),
        );

    test('출발은 핀 자리, 도착은 뽑힌 칩이다', () {
      final flight = plan();
      expect(flight.positionAt(Duration.zero), RandomBoard.pinRest);
      final end = flight.positionAt(flight.total);
      expect((end - target).distance, lessThan(0.5));
    });

    test('끝을 지나 물어도 도착지에 머문다', () {
      final flight = plan();
      final after = flight.positionAt(
        flight.total + const Duration(seconds: 3),
      );
      expect((after - target).distance, lessThan(0.5));
    });

    test('날아다니는 동안 보드 밖으로 나가지 않는다', () {
      for (final seed in [1, 2, 3, 7, 42]) {
        final flight = plan(seed: seed, direction: const Offset(0.7, -0.7));
        for (var ms = 0; ms <= flight.total.inMilliseconds; ms += 16) {
          final p = flight.positionAt(Duration(milliseconds: ms));
          expect(
            bounds.inflate(1).contains(p),
            isTrue,
            reason: 'seed $seed t=$ms → $p',
          );
        }
      }
    });

    test('처음엔 조준 방향으로 간다', () {
      final flight = plan(direction: const Offset(1, 0));
      final early = flight.positionAt(const Duration(milliseconds: 100));
      expect(early.dx, greaterThan(RandomBoard.pinRest.dx + 20));
      expect((early.dy - RandomBoard.pinRest.dy).abs(), lessThan(1));
    });

    test('오른쪽 벽을 정면으로 맞아도 좌우로만 오가지 않는다', () {
      // 벽에서 튕길 때 세로 성분을 살려 두므로 위아래로도 넓게 돈다
      for (final seed in [1, 2, 3]) {
        final flight = plan(seed: seed, direction: const Offset(1, 0));
        var minY = double.infinity, maxY = -double.infinity;
        for (var ms = 0; ms <= 3900; ms += 16) {
          final p = flight.positionAt(Duration(milliseconds: ms));
          minY = math.min(minY, p.dy);
          maxY = math.max(maxY, p.dy);
        }
        expect(maxY - minY, greaterThan(250), reason: 'seed $seed');
      }
    });

    test('비행은 약 5초 — 벽에서만 방향을 틀므로 ±0.5초 흔들린다', () {
      for (final seed in [1, 2, 3, 4, 5]) {
        final flight = plan(seed: seed, direction: const Offset(0.7, -0.7));
        expect(flight.total.inMilliseconds, inInclusiveRange(4400, 5600));
      }
    });

    test('멀리서 끌려가지 않는다 — 끝나기 0.5초 전엔 목표 근처에 와 있다', () {
      // 마지막 벽에서 목표로 곧장 나가 제 속도로 가다가 짧게(0.35초)
      // 내려앉는다. 어느 방향으로 쏘든, 목표가 어디든 그렇다
      for (final target in const [
        Offset(80, 100),
        Offset(330, 60),
        Offset(200, 380),
        Offset(60, 480),
      ]) {
        for (final seed in [1, 2, 3]) {
          for (final dir in const [Offset(1, 0), Offset(0, -1)]) {
            final flight = PinFlight.plan(
              start: RandomBoard.pinRest,
              direction: dir,
              target: target,
              bounds: bounds,
              random: math.Random(seed),
            );
            final beforeEnd = flight.positionAt(
              flight.total - const Duration(milliseconds: 500),
            );
            expect(
              (beforeEnd - target).distance,
              lessThan(200),
              reason: 'target $target seed $seed dir $dir',
            );
          }
        }
      }
    });

    test('아래로 조준해도 튕겨서 계속 움직인다', () {
      final flight = plan(direction: const Offset(0, 1));
      final mid = flight.positionAt(const Duration(seconds: 2));
      expect((mid - RandomBoard.pinRest).distance, greaterThan(50));
    });
  });
}
