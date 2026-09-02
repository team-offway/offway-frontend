import 'dart:math' as math;
import 'dart:ui';

import '../data/region_polygons.dart' show polygonKeyFor;
import 'region_geo.dart';

/// 랜덤 지역 선택 보드의 좌표계와 핀의 비행 경로.
///
/// 화면 폭이 기기마다 다르므로 **시안 단위(402×752)로 그려 놓고 통째로
/// 배율을 맞춘다** — 위젯은 `FittedBox` 하나로 끝나고, 여기 값들은 전부
/// 시안 픽셀이다. 지오코딩·물리 계산이 위젯과 섞이지 않게 순수 Dart로 둔다.
abstract final class RandomBoard {
  /// 상단바 아래 본문(시안 `Frame 2147228782`) 크기
  static const size = Size(402, 752);

  /// 시안 지도 프레임(`_경기도`)의 원점. 시도 조각(`sido_shapes.json`)과
  /// [project]가 이 원점 기준이다 — 디자이너가 지도를 옮기면 여기만 바꾼다
  /// (2026-09-03 시안 18824:29662에서 (6, 16) → (11.5, 89.24)로 내렸다)
  static const mapOrigin = Offset(11.5, 89.24);

  /// 한반도 SVG(`random_korea_base.svg`·`random_korea_overlay.svg`)가 놓이는 자리.
  ///
  /// 내보낸 SVG의 viewBox는 프레임 기준 (-0.84, -1.15)부터 시작한다 — 획
  /// 두께만큼 삐져나온 값이다
  static const mapRect = Rect.fromLTWH(
    11.5 - 0.84,
    89.24 - 1.15,
    385.42,
    494.25,
  );

  /// 제주도는 시안에서 본섬과 따로 그려져 있다 (실제보다 위로 당겨 놓았다)
  static const jejuRect = Rect.fromLTWH(118.07, 630.73, 62, 31);

  /// 핀이 쉬는 자리 — 가로 한가운데, 지도 아래
  static const pinRest = Offset(201, 658);

  /// 핀 지름 — 어느 단계든 같다. 시안 프레임의 92.9·78.2는 기울인 정사각형의
  /// 바깥 상자 크기지 핀이 커진 게 아니다
  static const pinDiameter = 67.7;

  /// 착지 후 줌인 배율. 시안 실측은 1.7(지도 383 → 653)인데 실기기에서
  /// 밋밋해 보여 더 당긴다
  static const landingZoom = 3.2;

  /// 위경도 → 보드 좌표.
  ///
  /// 시안 지도는 살짝 기울어진 투영(TM 계열)이라 위도·경도를 따로 늘리면
  /// 맞지 않는다. 지도 SVG의 시도 조각과 공공 시도 경계(통계청)를 통째로
  /// 대응시켜(가까운 점끼리 여섯 번 반복) 2차 다항식으로 맞췄다 — 오차
  /// 상위 10%가 1.6px 안이다. 해안 꼭짓점 셋으로 맞춘 1차식은 내륙 북부에서
  /// 5px 넘게 어긋나 접경 면이 지도 선을 넘어갔다. 기준점은 (127.5°E,
  /// 36.0°N)이고 [mapOrigin]을 더한다. 울릉·독도는 시안이 본토 쪽으로 당겨
  /// 그려 그 둘만 따로 잡는다
  static Offset project(double lat, double lng) {
    if (lng > 130) {
      // 울릉도(130.9°E)·독도(131.9°E) — 시안 지도의 섬 위치
      return mapOrigin +
          (lng > 131.5
              ? const Offset(382.5, 186.7)
              : const Offset(372.2, 170.9));
    }
    final u = lng - 127.5;
    final v = lat - 36.0;
    return Offset(
      mapOrigin.dx +
          159.6499 +
          90.53997 * u +
          8.94167 * v +
          0.64020 * u * u +
          -0.02196 * v * v +
          -0.39296 * u * v,
      mapOrigin.dy +
          288.8311 +
          6.71627 * u +
          -111.54036 * v +
          0.36103 * u * u +
          -0.17931 * v * v +
          -0.85028 * u * v,
    );
  }
}

/// 지도 위 지역 칩 하나 — 이름과 자리.
class MapChip {
  MapChip({
    required this.regionId,
    required this.label,
    required this.center,
    this.polygonKey,
  });

  final String regionId;
  final String label;

  /// 착지하면 연두색으로 채울 시군구 경계의 키(`강원/정선군`). 모르는 곳이면
  /// null — 칩은 놓지만 면은 못 채운다
  final String? polygonKey;

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
        polygonKey: polygonKeyFor(name: name, sido: sido),
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
/// 벽 사이는 직선이다. 튕길 때 반사각만 조금 흔든다 — 완벽한 반사는 같은
/// 길을 되풀이해 기계처럼 보인다.
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
    // 목표를 향해 돌 때 한 프레임에 꺾을 수 있는 최대 각(4.5°, 초당 540°,
    // 회전 반경 약 50px) — 짧게 돌고 나머지는 직선으로 간다
    const maxTurn = math.pi / 40;
    // 마지막 감속 구간 길이. 이 시간에 지금 속도로 멈추려면 목표까지
    // 속도×시간/3 안에 있어야 곡선이 고리를 그리지 않는다(에르미트 접선 조건)
    const approachSec = 0.35;
    // 비행 시간은 [total]에 딱 맞추지 않는다 — 방향 전환을 벽에서만 하므로
    // 이만큼 이르거나 늦어도 그냥 제 속도로 간다(속도를 늦춰 시간을 맞추면
    // 마지막이 굼떠 보인다)
    const tolerance = 0.5;
    final approachRadius = speed * approachSec / 3;
    final totalSec = total.inMicroseconds / 1e6;

    var pos = start;
    var dir = direction.distance < 1e-6
        ? const Offset(0, -1)
        : direction / direction.distance;
    var want = dir;
    final samples = <Offset>[pos];
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
      if (!cruising &&
          remaining + tolerance <=
              _straightTime(dist, speed, approachRadius) + approachSec) {
        // 벽에서 틀 기회를 놓쳤다(드물다 — 다음 벽을 내다보고 튼다). 이대로
        // 가면 너무 늦으니 지금 목표로 튼다
        cruising = true;
        dir = toDir;
        want = dir;
      }
      if (cruising) {
        // 가까워졌거나 시간이 다 됐으면 감속 착지로. 회전 반경보다 가까운데
        // 목표가 옆·뒤에 있으면 돌아서 맞추려다 주위를 맴돈다 — 바로 착지로
        if (dist <= approachRadius ||
            remaining <= approachSec - tolerance ||
            (dist < 170 && angle > math.pi / 3)) {
          break;
        }
        // 벽에서 정확히 겨눴으므로 여기서는 미세 보정만 한다
        want = toDir;
      }

      var next = pos + dir * (speed * dt);
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
        next = Offset(
          next.dx.clamp(bounds.left, bounds.right),
          next.dy.clamp(bounds.top, bounds.bottom),
        );
        // 반사는 즉시(벽은 딱딱하다). 자유 비행 중이면 반사각을 조금(±15°)
        // 흔든다 — 완벽한 반사는 같은 길을 되풀이한다. 벽 사이는 직선이다
        dir = _steady(dir);
        if (!cruising) {
          dir = _steady(
            _rotate(dir, (random.nextDouble() - 0.5) * math.pi / 6),
          );
          // 방향 전환은 벽에서만 한다('뱅크샷'). 허공에서 꺾으면 어색하다.
          // 이 벽에서 목표로 곧장 가면 시간이 (허용 오차 안에서) 맞거나,
          // 다음 벽까지 갔다가는 늦을 때 여기서 목표 쪽으로 나간다
          final fromWall = target - next;
          final bankNeed =
              _straightTime(fromWall.distance, speed, approachRadius) +
              approachSec;
          final nextWall = next + dir * _distToWall(next, dir, bounds);
          final nextNeed =
              _straightTime(
                (target - nextWall).distance,
                speed,
                approachRadius,
              ) +
              approachSec;
          final remainingAtNext =
              remaining - _distToWall(next, dir, bounds) / speed;
          if (fromWall.distance > approachRadius &&
              (remaining <= bankNeed + tolerance ||
                  remainingAtNext < nextNeed - tolerance)) {
            cruising = true;
            dir = fromWall / fromWall.distance;
          }
        }
        want = dir;
      } else {
        dir = _turnToward(dir, want, maxTurn);
      }
      pos = next;
      samples.add(pos);
    }

    // 감속 착지: 지금 속도를 이어받아 목표에서 멈추는 에르미트 곡선.
    // 접선은 남은 거리의 3배를 넘기지 않는다 — 넘기면 지나쳤다 돌아온다
    const tail = approachSec;
    final steps = math.max(1, (tail / dt).round());
    final p0 = pos;
    final reach = math.min(speed * tail, (target - pos).distance * 3);
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
    // 실제 걸린 시간 — [total] 언저리(±[tolerance])다
    return PinFlight._(
      samples,
      Duration(microseconds: ((samples.length - 1) * dt * 1e6).round()),
      dt,
    );
  }

  /// [from]에서 [dir]로 직진하면 벽에 닿기까지의 거리(px)
  static double _distToWall(Offset from, Offset dir, Rect bounds) {
    var t = double.infinity;
    if (dir.dx > 1e-9) t = math.min(t, (bounds.right - from.dx) / dir.dx);
    if (dir.dx < -1e-9) t = math.min(t, (bounds.left - from.dx) / dir.dx);
    if (dir.dy > 1e-9) t = math.min(t, (bounds.bottom - from.dy) / dir.dy);
    if (dir.dy < -1e-9) t = math.min(t, (bounds.top - from.dy) / dir.dy);
    return t.isFinite ? t : 0;
  }

  /// 목표까지 [dist] 남았을 때 감속 반경 밖을 직진하는 데 걸리는 시간(초)
  static double _straightTime(double dist, double speed, double radius) =>
      math.max(0, dist - radius) / speed;

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
