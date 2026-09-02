import 'dart:math' as math;
import 'dart:ui';

import '../data/sido_shapes.dart' show sidoKeyFor;
import 'region_geo.dart';

/// 랜덤 지역 선택 보드의 좌표계와 핀의 비행 경로.
///
/// 화면 폭이 기기마다 다르므로 **시안 단위(402×752)로 그려 놓고 통째로
/// 배율을 맞춘다** — 위젯은 `FittedBox` 하나로 끝나고, 여기 값들은 전부
/// 시안 픽셀이다. 지오코딩·물리 계산이 위젯과 섞이지 않게 순수 Dart로 둔다.
abstract final class RandomBoard {
  /// 상단바 아래 본문(시안 `Frame 2147228782`) 크기
  static const size = Size(402, 752);

  /// 한반도 SVG(`random_korea_base.svg`·`random_korea_overlay.svg`)가 놓이는 자리.
  ///
  /// 시안의 지도 프레임(`_경기도`)은 (6, 16)에 있고, 내보낸 SVG의 viewBox는
  /// 그 프레임 기준 (-0.84, -1.15)부터 시작한다 — 획 두께만큼 삐져나온 값이다
  static const mapRect = Rect.fromLTWH(6 - 0.84, 16 - 1.15, 385.42, 494.25);

  /// 제주도는 시안에서 본섬과 따로 그려져 있다 (실제보다 위로 당겨 놓았다)
  static const jejuRect = Rect.fromLTWH(112.6, 552.5, 62, 31);

  /// 핀이 쉬는 자리 — 가로 한가운데, 지도 아래
  static const pinRest = Offset(201, 658);

  /// 핀 지름 — 어느 단계든 같다. 시안 프레임의 92.9·78.2는 기울인 정사각형의
  /// 바깥 상자 크기지 핀이 커진 게 아니다
  static const pinDiameter = 67.7;

  /// 착지 후 줌인 배율. 시안 실측은 1.7(지도 383 → 653)인데 실기기에서
  /// 밋밋해 보여 조금 더 당긴다
  static const landingZoom = 2.7;

  /// 위경도 → 보드 좌표.
  ///
  /// 시안 지도는 살짝 기울어진 투영(TM 계열)이라 위도·경도를 따로 늘리면
  /// 동쪽이 위로 뜬다. 본토 SVG 윤곽의 꼭짓점 셋으로 회전까지 포함한
  /// 아핀을 풀었다 — 동단 호미곶(129.57°E, 36.08°N) = (350.9, 300.3),
  /// 북단 고성(128.36°E, 38.61°N) = (259.9, −0.1), 남단 해남 땅끝(126.53°E,
  /// 34.29°N) = (56.1, 470.9). 검증: 남동 끝이 부산 기장(129.18, 35.20),
  /// 서쪽 끝이 해남 화원(126.26, 34.66)으로 풀린다. 프레임 원점 (6, 16)을
  /// 더한다. 울릉·독도는 시안이 본토 쪽으로 당겨 그려 그 둘만 따로 잡는다
  static Offset project(double lat, double lng) {
    if (lng > 130) {
      // 울릉도(130.9°E)·독도(131.9°E) — 시안 지도의 섬 위치
      return lng > 131.5
          ? const Offset(388.5, 202.7)
          : const Offset(378.2, 186.9);
    }
    return Offset(
      6 + 92.198 * lng + 8.122 * lat - 11888.24,
      16 + 10.788 * lng - 113.607 * lat + 3001.42,
    );
  }
}

/// 지도 위 지역 칩 하나 — 이름과 자리.
class MapChip {
  MapChip({
    required this.regionId,
    required this.label,
    required this.center,
    this.sidoKey,
  });

  final String regionId;
  final String label;

  /// 착지하면 연두색으로 채울 시도(`강원`). 모르는 곳이면 null —
  /// 칩은 놓지만 면은 못 채운다
  final String? sidoKey;

  /// 칩 중심(보드 좌표). 겹침을 풀면서 조금 움직인다
  Offset center;

  /// 시안 칩: 좌우 11 + 글자, 높이 31. 15px 세미볼드 한글 한 자는 약 15px
  static const height = 31.0;
  double get width => 22 + label.length * 15.2;

  Rect get rect =>
      Rect.fromCenter(center: center, width: width, height: height);
}

/// 후보 목록(추천 응답을 앱 모양으로 바꾼 맵)으로 지도 칩을 만든다.
///
/// 자리는 **서버가 준 `lat`·`lng`가 먼저다** (core #405). 없으면 앱 내장 표
/// ([regionGeoFor])로 물러난다 — 옛 서버·목 데이터용 폴백이다. 둘 다 없으면
/// 그 지역은 놓을 수 없고 뽑히지도 않는다. 겹침은 풀어서 돌려준다.
List<MapChip> buildMapChips(List<Map<String, dynamic>> candidates) {
  final chips = <MapChip>[];
  for (final c in candidates) {
    final name = c['name'] as String? ?? '';
    final sido = c['sido'] as String?;
    final lat = (c['lat'] as num?)?.toDouble();
    final lng = (c['lng'] as num?)?.toDouble();
    final Offset? center;
    if (lat != null && lng != null) {
      center = RandomBoard.project(lat, lng);
    } else {
      final geo = regionGeoFor(name: name, sido: sido);
      center = geo == null ? null : RandomBoard.project(geo.lat, geo.lng);
    }
    if (center == null) continue;
    chips.add(
      MapChip(
        regionId: c['id'] as String,
        label: regionChipLabel(name),
        center: center,
        sidoKey: sidoKeyFor(name: name, sido: sido),
      ),
    );
  }
  relaxChips(chips);
  return chips;
}

/// 칩끼리 겹치지 않게 살짝 밀어낸다.
///
/// 전남 열여섯 군데처럼 촘촘한 곳은 좌표대로 놓으면 서로 덮는다. 겹치는
/// 쌍을 중심 사이 방향으로 반씩 밀기를 몇 번 되풀이하면 대개 풀린다 —
/// 정확한 해가 아니라도 읽히면 된다. 지도 밖으로는 나가지 않는다.
void relaxChips(List<MapChip> chips, {int iterations = 300, double gap = 4}) {
  final bounds = RandomBoard.mapRect.deflate(8);
  for (var i = 0; i < iterations; i++) {
    var moved = false;
    for (var a = 0; a < chips.length; a++) {
      for (var b = a + 1; b < chips.length; b++) {
        final ra = chips[a].rect.inflate(gap / 2);
        final rb = chips[b].rect.inflate(gap / 2);
        if (!ra.overlaps(rb)) continue;
        moved = true;
        final overlap = ra.intersect(rb);
        var delta = chips[b].center - chips[a].center;
        // 정확히 같은 자리면 방향이 없다 — 위아래로 가른다(칩은 납작하다)
        if (delta.distance < 0.01) delta = const Offset(0, 1);
        final sx = delta.dx == 0 ? 1.0 : delta.dx.sign;
        final sy = delta.dy == 0 ? 1.0 : delta.dy.sign;
        // 겹친 폭·높이 중 작은 쪽으로 빠져나가는 게 덜 움직인다.
        // 딱 겹친 만큼만 밀면 부동소수점 끝자리에서 다시 겹친다 — 조금 더 민다
        final push = overlap.width < overlap.height
            ? Offset((overlap.width + 0.5) * sx, 0)
            : Offset(0, (overlap.height + 0.5) * sy);
        chips[a].center -= push / 2;
        chips[b].center += push / 2;
      }
    }
    for (final chip in chips) {
      chip.center = Offset(
        chip.center.dx.clamp(
          bounds.left + chip.width / 2,
          bounds.right - chip.width / 2,
        ),
        chip.center.dy.clamp(
          bounds.top + MapChip.height / 2,
          bounds.bottom - MapChip.height / 2,
        ),
      );
    }
    if (!moved) break;
  }
}

/// 핀이 날아가는 길 — 발사 전에 끝까지 정해 둔다.
///
/// **도착지를 먼저 뽑고 비행은 연출이다.** 진짜 물리로 튕기면 어디에 멈출지
/// 보장할 수 없다. 조준 방향으로 벽에 튕기며 돌아다니다가, 남은 시간이
/// 목표까지 가는 데 필요한 만큼이 되면 속도를 이어받은 곡선으로 내려앉는다.
///
/// 튕길 때마다 '가고 싶은 방향'을 조금 흔들고 그쪽으로 몇 프레임에 걸쳐
/// 돌아 들어간다 — 완벽한 반사는 같은 길을 되풀이해 기계처럼 보이고,
/// 순간적으로 꺾으면 각이 튄다.
class PinFlight {
  PinFlight._(this._samples, this.total, this._dt);

  factory PinFlight.plan({
    required Offset start,
    required Offset direction,
    required Offset target,
    required Rect bounds,
    required math.Random random,
    Duration total = const Duration(seconds: 5),
    double speed = 480,
  }) {
    const dt = 1 / 120;
    // 한 프레임에 꺾을 수 있는 최대 각(2.25°, 초당 270°, 회전 반경 약 100px) —
    // 벽에서 튕긴 뒤나 목표를 향해 돌 때 팽이처럼 돌지 않고 크게 호를 그린다
    const maxTurn = math.pi / 80;
    // 마지막 감속 구간 길이. 이 시간에 지금 속도로 멈추려면 목표까지
    // 속도×시간/3 안에 있어야 곡선이 고리를 그리지 않는다(에르미트 접선 조건)
    const approachSec = 0.7;
    final approachRadius = speed * approachSec / 3;
    final totalSec = total.inMicroseconds / 1e6;

    var pos = start;
    var dir = direction.distance < 1e-6
        ? const Offset(0, -1)
        : direction / direction.distance;
    var want = dir;
    var curSpeed = speed;
    final samples = <Offset>[pos];
    var step = 0;
    var t = 0.0;
    // false: 자유 비행(벽 반사·느린 방향 전환) / true: 목표를 향해 직진
    var cruising = false;

    while (true) {
      t += dt;
      final remaining = totalSec - t;
      final toTarget = target - pos;
      final dist = toTarget.distance;
      final toDir = dist < 1e-6 ? dir : toTarget / dist;

      final angle = _angleBetween(dir, toDir).abs();
      if (!cruising) {
        // 목표로 방향을 트는 시점 — 돌아서는 시간 + 직진 시간 + 감속 시간이
        // 남은 시간과 같아질 때. 다만 그 전 1.6초 안에 목표가 대략 앞쪽이면
        // 그때 미리 튼다 — 등 뒤에 두고 크게 U턴하는 것보다 자연스럽다.
        // 일찍 출발한 만큼은 직진하며 천천히 늦춰 시간을 맞춘다
        final turn = angle / maxTurn * dt;
        final straight = math.max(0, dist - approachRadius) / speed;
        final need = turn + straight + approachSec;
        // 미리 출발해도 되는 여유 = 직진 구간을 최저 속도(45%)로 늦춰 벌 수
        // 있는 시간. 이미 코앞이면 여유가 없다 — 일찍 붙어 기어가지 않게
        final slack = math.min(1.6, straight * (1 / 0.45 - 1));
        if (remaining <= need ||
            (remaining <= need + slack && angle < math.pi / 4)) {
          cruising = true;
        }
      }
      if (cruising) {
        // 가까워졌거나 시간이 다 됐으면 감속 착지로. 회전 반경보다 가까운데
        // 목표가 옆·뒤에 있으면 돌아서 맞추려다 주위를 맴돈다 — 바로 착지로
        if (dist <= approachRadius ||
            remaining <= approachSec ||
            (dist < 170 && angle > math.pi / 3)) {
          break;
        }
        want = toDir;
        // 시간이 남으면 그만큼 늦춘다(최저 45%). 급브레이크가 아니라
        // 프레임마다 조금씩 — 착륙하는 비행기처럼 미끄러진다
        final needNow =
            math.max(0, dist - approachRadius) / speed + approachSec;
        final wantSpeed = speed * (needNow / remaining).clamp(0.45, 1.0);
        curSpeed += (wantSpeed - curSpeed).clamp(-speed * dt, speed * dt);
      }

      var next = pos + dir * (curSpeed * dt);
      var bounced = false;
      if (next.dx < bounds.left || next.dx > bounds.right) {
        dir = Offset(-dir.dx, dir.dy);
        bounced = true;
      }
      if (next.dy < bounds.top || next.dy > bounds.bottom) {
        dir = Offset(dir.dx, -dir.dy);
        bounced = true;
      }
      if (bounced) {
        // 반사는 즉시(벽은 딱딱하다). 자유 비행 중이면 흔들림은 '가고 싶은
        // 방향'에만 줘서 몇 프레임에 걸쳐 돌아 들어가게 한다
        dir = _steady(dir);
        if (!cruising) {
          want = _steady(
            _rotate(dir, (random.nextDouble() - 0.5) * math.pi / 3),
          );
        }
        next = Offset(
          next.dx.clamp(bounds.left, bounds.right),
          next.dy.clamp(bounds.top, bounds.bottom),
        );
      } else {
        if (!cruising && step > 60 && step % 40 == 0) {
          // 벽 사이에서도 천천히 방향을 바꾼다 — 직선으로만 오가면 기계 같다
          want = _steady(
            _rotate(want, (random.nextDouble() - 0.5) * math.pi / 6),
          );
        }
        dir = _turnToward(dir, want, maxTurn);
      }
      step++;
      pos = next;
      samples.add(pos);
    }

    // 감속 착지: 지금 속도를 이어받아 목표에서 멈추는 에르미트 곡선.
    // 접선은 남은 거리의 3배를 넘기지 않는다 — 넘기면 지나쳤다 돌아온다
    final tail = math.max(approachSec / 2, totalSec - t + dt);
    final steps = math.max(1, (tail / dt).round());
    final p0 = pos;
    final reach = math.min(curSpeed * tail, (target - pos).distance * 3);
    final m0 = dir * reach;
    for (var i = 1; i <= steps; i++) {
      final s = i / steps;
      final s2 = s * s, s3 = s2 * s;
      final h00 = 2 * s3 - 3 * s2 + 1;
      final h10 = s3 - 2 * s2 + s;
      final h01 = -2 * s3 + 3 * s2;
      final p = p0 * h00 + m0 * h10 + target * h01;
      // 벽 옆에서 바깥쪽 속도로 시작하면 곡선이 잠깐 밖으로 나간다 — 붙든다
      samples.add(
        Offset(
          p.dx.clamp(bounds.left, bounds.right),
          p.dy.clamp(bounds.top, bounds.bottom),
        ),
      );
    }
    return PinFlight._(samples, total, dt);
  }

  /// [a]에서 [b]까지의 부호 있는 각(라디안)
  static double _angleBetween(Offset a, Offset b) =>
      math.atan2(a.dx * b.dy - a.dy * b.dx, a.dx * b.dx + a.dy * b.dy);

  /// [dir]을 [want] 쪽으로 최대 [maxTurn]만큼 돌린다
  static Offset _turnToward(Offset dir, Offset want, double maxTurn) {
    final angle = _angleBetween(dir, want);
    if (angle.abs() <= maxTurn) return want;
    return _rotate(dir, angle.sign * maxTurn);
  }

  final List<Offset> _samples;
  final Duration total;
  final double _dt;

  /// [t]초일 때 핀 중심. 끝을 넘기면 도착지에 머문다
  Offset positionAt(Duration t) {
    final sec = t.inMicroseconds / 1e6;
    final i = sec / _dt;
    final lo = i.floor();
    if (lo >= _samples.length - 1) return _samples.last;
    if (lo < 0) return _samples.first;
    final f = i - lo;
    return Offset.lerp(_samples[lo], _samples[lo + 1], f)!;
  }

  /// 너무 눕거나 너무 선 방향을 편다.
  ///
  /// 오른쪽 벽을 정면으로 맞고 튕기면 좌우로만 왔다 갔다 한다 — 가로·세로
  /// 성분이 각각 최소 0.4는 되게 해서 지도를 가로지르며 돈다
  static Offset _steady(Offset dir) {
    var dx = dir.dx, dy = dir.dy;
    if (dx.abs() < 0.4) dx = 0.4 * (dx < 0 ? -1 : 1);
    if (dy.abs() < 0.4) dy = 0.4 * (dy < 0 ? -1 : 1);
    final v = Offset(dx, dy);
    return v / v.distance;
  }

  static Offset _rotate(Offset v, double rad) => Offset(
    v.dx * math.cos(rad) - v.dy * math.sin(rad),
    v.dx * math.sin(rad) + v.dy * math.cos(rad),
  );
}
