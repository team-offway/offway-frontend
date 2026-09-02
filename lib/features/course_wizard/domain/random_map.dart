import 'dart:math' as math;
import 'dart:ui';

/// 랜덤 지역 선택 보드의 좌표계와 핀의 비행 경로.
///
/// 화면 폭이 기기마다 다르므로 **시안 단위(402×752)로 그려 놓고 통째로
/// 배율을 맞춘다** — 위젯은 `FittedBox` 하나로 끝나고, 여기 값들은 전부
/// 시안 픽셀이다. 지오코딩·물리 계산이 위젯과 섞이지 않게 순수 Dart로 둔다.
abstract final class RandomBoard {
  /// 상단바 아래 본문(시안 `Frame 2147228782`) 크기
  static const size = Size(402, 752);

  /// 한반도 SVG(`random_korea_map.svg`)가 놓이는 자리.
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

  /// 착지 후 줌인 배율 — 시안 실측(지도 383 → 653)
  static const landingZoom = 1.7;

  /// 위경도 → 보드 좌표. 본토 SVG 윤곽으로 보정한 등장방형 근사다.
  ///
  /// 본토 폴리곤의 서단(태안 126.10°E)이 x 34.2, 동단(호미곶 129.58°E)이
  /// x 350.9, 북단(고성 38.61°N)이 y −0.1, 남단(해남 34.29°N)이 y 470.9 —
  /// 여기에 지도 프레임 원점 (6, 16)을 더한다. 울릉·독도는 시안 지도가
  /// 실제보다 본토 쪽으로 당겨 그렸으므로 그 둘만 따로 자리를 잡는다
  static Offset project(double lat, double lng) {
    if (lng > 130) {
      // 울릉도(130.9°E)·독도(131.9°E) — 시안 지도의 섬 위치
      return lng > 131.5
          ? const Offset(388.5, 202.7)
          : const Offset(378.2, 186.9);
    }
    return Offset(
      6 + 34.2 + (lng - 126.10) * 91.0,
      16 - 0.1 + (38.61 - lat) * 109.0,
    );
  }
}

/// 지도 위 지역 칩 하나 — 이름과 자리.
class MapChip {
  MapChip({required this.regionId, required this.label, required this.center});

  final String regionId;
  final String label;

  /// 칩 중심(보드 좌표). 겹침을 풀면서 조금 움직인다
  Offset center;

  /// 시안 칩: 좌우 11 + 글자, 높이 31. 15px 세미볼드 한글 한 자는 약 15px
  static const height = 31.0;
  double get width => 22 + label.length * 15.2;

  Rect get rect =>
      Rect.fromCenter(center: center, width: width, height: height);
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
/// 보장할 수 없다. 조준 방향으로 벽에 튕기며 돌아다니다가([freeDuration]),
/// 마지막 [approachDuration] 동안 목표 칩으로 부드럽게 빨려 들어간다.
///
/// 튕길 때마다 각도를 조금 흔든다 — 완벽한 반사는 같은 길을 되풀이해
/// 기계처럼 보인다.
class PinFlight {
  PinFlight._(this._samples, this.total, this._dt);

  factory PinFlight.plan({
    required Offset start,
    required Offset direction,
    required Offset target,
    required Rect bounds,
    required math.Random random,
    Duration total = const Duration(seconds: 5),
    Duration approach = const Duration(milliseconds: 1100),
    double speed = 480,
  }) {
    const dt = 1 / 120;
    final free = (total - approach).inMicroseconds / 1e6;
    var pos = start;
    var dir = direction.distance < 1e-6
        ? const Offset(0, -1)
        : direction / direction.distance;
    final samples = <Offset>[pos];

    for (var t = dt; t <= free; t += dt) {
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
        final jitter = (random.nextDouble() - 0.5) * math.pi / 5; // ±18°
        dir = _rotate(dir, jitter);
        next = Offset(
          next.dx.clamp(bounds.left, bounds.right),
          next.dy.clamp(bounds.top, bounds.bottom),
        );
      }
      pos = next;
      samples.add(pos);
    }

    // 마지막 구간: 지금 속도 방향을 이어받아 목표에서 멈추는 에르미트 곡선.
    // 갑자기 방향을 꺾지 않아 '끌려간다'는 느낌이 안 든다
    final approachSec = approach.inMicroseconds / 1e6;
    final steps = (approachSec / dt).round();
    final p0 = pos;
    final m0 = dir * (speed * approachSec * 0.6);
    for (var i = 1; i <= steps; i++) {
      final s = i / steps;
      final s2 = s * s, s3 = s2 * s;
      final h00 = 2 * s3 - 3 * s2 + 1;
      final h10 = s3 - 2 * s2 + s;
      final h01 = -2 * s3 + 3 * s2;
      samples.add(p0 * h00 + m0 * h10 + target * h01);
    }
    return PinFlight._(samples, total, dt);
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

  static Offset _rotate(Offset v, double rad) => Offset(
    v.dx * math.cos(rad) - v.dy * math.sin(rad),
    v.dx * math.sin(rad) + v.dy * math.cos(rad),
  );
}
