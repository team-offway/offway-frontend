import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/place_thumbnail.dart';
import '../application/course_wizard_provider.dart';
import '../domain/random_map.dart';
import '../domain/region_geo.dart';
import 'candidates_screen.dart' show wizardCandidatesProvider;

/// 랜덤 지역 선택 — 핀을 던져 후보지역 중 한 곳을 고른다.
///
/// 후보지역 화면의 "어디로 갈지 고민된다면?" 카드에서 들어온다. 지도 위에
/// **앞서 찾은 후보만** 칩으로 놓고, 아래 핀을 꾹 눌렀다 떼면 핀이 날아다니다
/// 한 칩에 내려앉는다. 결과는 그 자리에서 코스로 이어진다.
///
/// 흐름(시안 메모): 진입(핀 회전·툴팁) → 누름(회전 멈춤) → 꾹(조준선) →
/// 뗌(발사) → 약 5초 비행(스치는 칩 반짝) → 착지(2초 줌인) → 결과 모달.
class RandomRegionScreen extends ConsumerStatefulWidget {
  const RandomRegionScreen({super.key});

  @override
  ConsumerState<RandomRegionScreen> createState() => _RandomRegionScreenState();
}

enum _Phase { idle, pressed, aiming, flying, landing, result }

class _RandomRegionScreenState extends ConsumerState<RandomRegionScreen>
    with TickerProviderStateMixin {
  // TODO(디자인시스템): 시안 바다색. 토큰에 없는 값이라 상수로 둔다
  static const _seaColor = Color(0xFFB2E4FD);

  /// 대기 중 핀이 한 바퀴 도는 시간
  static const _spinPeriod = Duration(seconds: 3);

  /// 이만큼 누르고 있어야 조준으로 넘어간다 — 짧게 톡 치면 아무 일 없다
  static const _holdThreshold = Duration(milliseconds: 220);

  /// 조준선이 다 뻗는 데 걸리는 시간과 최대 길이
  static const _aimDuration = Duration(milliseconds: 600);
  static const _aimLength = 150.0;

  /// 착지 줌인 시간(시안 2초)과 되돌아오는 시간
  static const _zoomDuration = Duration(seconds: 2);
  static const _unzoomDuration = Duration(milliseconds: 400);

  /// 핀이 칩을 스칠 때 반짝이는 시간
  static const _flashDuration = Duration(milliseconds: 280);

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: _spinPeriod,
  )..repeat();
  late final AnimationController _aim = AnimationController(
    vsync: this,
    duration: _aimDuration,
  );
  late final AnimationController _flight = AnimationController(vsync: this);
  late final AnimationController _zoom = AnimationController(
    vsync: this,
    duration: _zoomDuration,
    reverseDuration: _unzoomDuration,
  );

  final _random = math.Random();

  _Phase _phase = _Phase.idle;
  Offset _pinPos = RandomBoard.pinRest;

  /// 누른 순간 굳힌 방향(라디안, 0이 위·시계방향). 조준·발사가 이 값을 쓴다
  double _heading = 0;
  Timer? _holdTimer;
  PinFlight? _plan;

  /// 스친 칩이 언제까지 반짝이는지
  final _flashUntil = <String, DateTime>{};
  MapChip? _landed;

  /// 후보 목록이 바뀔 때만 칩을 다시 놓는다 — 겹침 풀기는 싸지 않다
  List<Map<String, dynamic>>? _chipSource;
  List<MapChip> _chips = const [];

  @override
  void dispose() {
    _holdTimer?.cancel();
    _spin.dispose();
    _aim.dispose();
    _flight.dispose();
    _zoom.dispose();
    super.dispose();
  }

  // ─── 칩 배치 ───────────────────────────────────────────────────────────

  List<MapChip> _chipsFor(List<Map<String, dynamic>> candidates) {
    if (identical(candidates, _chipSource)) return _chips;
    final chips = <MapChip>[];
    for (final c in candidates) {
      final name = c['name'] as String? ?? '';
      final lat = (c['lat'] as num?)?.toDouble();
      final lng = (c['lng'] as num?)?.toDouble();
      final Offset? center;
      if (lat != null && lng != null) {
        // 서버가 좌표를 주면 그게 진실이다 — 표는 서버가 없을 때의 임시값
        center = RandomBoard.project(lat, lng);
      } else {
        final geo = regionGeoFor(name: name, sido: c['sido'] as String?);
        center = geo == null ? null : RandomBoard.project(geo.lat, geo.lng);
      }
      // 자리를 모르는 곳은 놓을 수 없다 — 뽑히지도 않는다
      if (center == null) continue;
      chips.add(
        MapChip(
          regionId: c['id'] as String,
          label: regionChipLabel(name),
          center: center,
        ),
      );
    }
    relaxChips(chips);
    _chipSource = candidates;
    return _chips = chips;
  }

  // ─── 제스처 ────────────────────────────────────────────────────────────

  void _onPinDown(PointerDownEvent _) {
    if (_phase != _Phase.idle) return;
    setState(() {
      _phase = _Phase.pressed;
      // 누른 순간의 방향이 곧 조준 방향이다 — 룰렛을 멈추듯
      _heading = _spin.value * 2 * math.pi;
    });
    _spin.stop();
    _holdTimer = Timer(_holdThreshold, () {
      if (!mounted || _phase != _Phase.pressed) return;
      setState(() => _phase = _Phase.aiming);
      _aim.forward(from: 0);
    });
  }

  void _onPinUp(PointerEvent _) {
    _holdTimer?.cancel();
    switch (_phase) {
      case _Phase.pressed:
        // 톡 친 것 — 아무 일도 없던 것처럼 다시 돈다
        setState(() => _phase = _Phase.idle);
        _spin.repeat();
      case _Phase.aiming:
        _launch();
      default:
        break;
    }
  }

  Offset get _direction => Offset(math.sin(_heading), -math.cos(_heading));

  void _launch() {
    final chips = _chips;
    if (chips.isEmpty) {
      setState(() => _phase = _Phase.idle);
      _spin.repeat();
      return;
    }
    // 결과를 먼저 뽑는다 — 비행은 이 칩으로 가는 연출이다
    final winner = chips[_random.nextInt(chips.length)];
    final plan = PinFlight.plan(
      start: _pinPos,
      direction: _direction,
      target: winner.center,
      bounds: (Offset.zero & RandomBoard.size).deflate(
        RandomBoard.pinDiameter / 2,
      ),
      random: _random,
    );
    _plan = plan;
    _aim.value = 0;
    setState(() => _phase = _Phase.flying);
    _flight
      ..duration = plan.total
      ..value = 0;
    _flight.addListener(_onFlightTick);
    _flight.forward().whenComplete(() {
      _flight.removeListener(_onFlightTick);
      if (mounted && _phase == _Phase.flying) _land(winner);
    });
  }

  void _onFlightTick() {
    final plan = _plan;
    if (plan == null) return;
    final pos = plan.positionAt(_flight.duration! * _flight.value);
    // 비행기는 가는 쪽을 본다(시안 발사·비행 화면). 아주 조금 움직인 프레임은
    // 방향이 흔들리므로 건너뛴다
    final delta = pos - _pinPos;
    if (delta.distance > 0.5) _heading = math.atan2(delta.dx, -delta.dy);
    final now = DateTime.now();
    for (final chip in _chips) {
      // 핀 몸통이 칩에 닿는 순간 — 스치기만 해도 반짝인다(시안)
      if (chip.rect.inflate(RandomBoard.pinDiameter / 3).contains(pos)) {
        _flashUntil[chip.regionId] = now.add(_flashDuration);
      }
    }
    setState(() => _pinPos = pos);
  }

  Future<void> _land(MapChip winner) async {
    setState(() {
      _phase = _Phase.landing;
      _landed = winner;
      _pinPos = winner.center;
      _flashUntil.clear();
    });
    HapticFeedback.mediumImpact();
    await _zoom.forward(from: 0);
    if (!mounted) return;
    setState(() => _phase = _Phase.result);
    await _showResult(winner);
  }

  Future<void> _showResult(MapChip winner) async {
    final candidates = _chipSource ?? const <Map<String, dynamic>>[];
    final region = candidates.firstWhere(
      (c) => c['id'] == winner.regionId,
      orElse: () => const <String, dynamic>{},
    );
    final answer = await showDialog<_ResultAnswer>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.materialDimmer,
      builder: (_) => _ResultDialog(label: winner.label, region: region),
    );
    if (!mounted) return;
    switch (answer) {
      case _ResultAnswer.go:
        final desiredDays = ref.read(courseWizardProvider).desiredTripDays;
        await _reset();
        if (!mounted) return;
        context.push(
          AppRoutes.coursePath(winner.regionId, desiredDays: desiredDays),
        );
      case _ResultAnswer.backToList:
        context.pop();
      case _ResultAnswer.again:
      case null:
        await _reset();
    }
  }

  /// 처음 상태로 — 줌을 풀고 핀을 제자리에 놓고 다시 돌린다
  Future<void> _reset() async {
    await _zoom.reverse();
    if (!mounted) return;
    setState(() {
      _landed = null;
      _plan = null;
      _pinPos = RandomBoard.pinRest;
      _phase = _Phase.idle;
    });
    _spin.repeat();
  }

  Future<void> _showInfo() => showDialog<void>(
    context: context,
    barrierColor: AppColors.materialDimmer,
    builder: (_) => const _InfoDialog(),
  );

  // ─── 그리기 ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final candidates = ref.watch(wizardCandidatesProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      // 바다가 홈 인디케이터 아래까지 이어진다(시안) — 아래 안전영역은 열어 둔다
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(context),
            // 시안: 상단바(98) 아래 23.5를 희게 두고 바다가 시작한다
            const SizedBox(height: 23.5),
            Expanded(
              child: candidates.when(
                loading: () => const AppLoadingView(title: '지도를 준비하고 있어요'),
                error: (e, _) => Center(
                  child: Text(
                    e is ApiException ? e.detail : '후보지역을 불러오지 못했어요',
                    textAlign: TextAlign.center,
                    style: AppTypography.label1NormalMedium.copyWith(
                      color: AppColors.labelAlternative,
                    ),
                  ),
                ),
                data: (list) => _buildBoard(_chipsFor(list)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Text(
              '랜덤 지역 선택',
              style: AppTypography.headline2Bold.copyWith(
                color: AppColors.labelStrong,
              ),
            ),
          ),
          Positioned(left: 6, child: AppBackButton(onTap: () => context.pop())),
          Positioned(
            right: 6,
            child: AppIconButton(
              icon: Icons.info_outline,
              // 시안은 속이 빈 원형 i(Icon/Normal/Circle Info) — 기존
              // ic_circle_info는 속이 찬 변형이라 따로 둔다
              asset: 'assets/icons/ic_circle_info_outline.svg',
              semanticLabel: '어떤 지역이 나오는지 안내',
              onTap: _showInfo,
            ),
          ),
        ],
      ),
    );
  }

  /// 시안 단위(402×752)로 그려 폭에 맞춰 통째로 배율을 맞춘다.
  ///
  /// 폭을 꽉 채우는 게 기본이다. 아래가 시안보다 짧은 기기는 보드 바닥이
  /// 잘려도 되지만 핀까지 잘리면 던질 수 없으므로, 핀이 다 들어갈 만큼만
  /// 줄인다. 바다색은 보드 밖까지 칠한다 — 옆이든 아래든 희게 남지 않게.
  ///
  /// **가로를 명시적으로 채운다.** Column 안에서는 가로가 느슨해서, 그냥 두면
  /// FittedBox가 세로에 맞춰 줄고 양옆이 빈다 (실기기에서 그렇게 떴다).
  Widget _buildBoard(List<MapChip> chips) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardWidth = math.min(
          constraints.maxWidth,
          constraints.maxHeight / _minBoardHeight * RandomBoard.size.width,
        );
        return ColoredBox(
          color: _seaColor,
          child: SizedBox.expand(
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: boardWidth,
                height: constraints.maxHeight,
                child: _buildScaledBoard(chips),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 보드에서 핀 바닥까지의 높이 — 이 아래는 잘려도 된다
  static const _minBoardHeight = 700.0;

  Widget _buildScaledBoard(List<MapChip> chips) {
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.fitWidth,
        alignment: Alignment.topCenter,
        child: SizedBox.fromSize(
          size: RandomBoard.size,
          child: AnimatedBuilder(
            animation: Listenable.merge([_spin, _aim, _zoom]),
            builder: (context, _) => Transform(
              transform: _zoomMatrix(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fromRect(
                    rect: RandomBoard.mapRect,
                    child: SvgPicture.asset(
                      'assets/images/random_korea_map.svg',
                      fit: BoxFit.fill,
                    ),
                  ),
                  Positioned.fromRect(
                    rect: RandomBoard.jejuRect,
                    child: SvgPicture.asset(
                      'assets/images/random_jeju.svg',
                      fit: BoxFit.fill,
                    ),
                  ),
                  for (final chip in chips) _buildChip(chip),
                  if (_phase == _Phase.aiming)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _AimLinePainter(
                            from: _pinPos,
                            direction: _direction,
                            startGap: RandomBoard.pinDiameter / 2 + 6,
                            length:
                                _aimLength *
                                Curves.easeOut.transform(_aim.value),
                          ),
                        ),
                      ),
                    ),
                  if (_phase == _Phase.idle)
                    const Positioned(
                      top: 567.7,
                      left: 0,
                      right: 0,
                      child: Center(child: _PinTooltip()),
                    ),
                  _buildPin(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 착지한 칩이 화면 가운데로 오도록 키운다. 0이면 그대로다
  Matrix4 _zoomMatrix() {
    final t = Curves.easeInOut.transform(_zoom.value);
    final landed = _landed;
    if (t == 0 || landed == null) return Matrix4.identity();
    final scale = 1 + (RandomBoard.landingZoom - 1) * t;
    final boardCenter = RandomBoard.size.center(Offset.zero);
    final anchor = Offset.lerp(landed.center, boardCenter, t)!;
    return Matrix4.identity()
      ..translateByDouble(anchor.dx, anchor.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-landed.center.dx, -landed.center.dy, 0, 1);
  }

  Widget _buildChip(MapChip chip) {
    final flashing =
        _flashUntil[chip.regionId]?.isAfter(DateTime.now()) ?? false;
    final landed = identical(chip, _landed);
    final rect = chip.rect;
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // 스칠 때 offway 50으로 반짝, 내려앉으면 브랜드색으로 굳는다
          color: landed
              ? AppColors.primaryNormal
              : flashing
              ? AppPalette.offway50
              : AppPalette.coolNeutral70,
          borderRadius: BorderRadius.circular(94),
        ),
        child: Text(
          chip.label,
          maxLines: 1,
          style: AppTypography.body2NormalBold.copyWith(
            color: AppPalette.common100,
          ),
        ),
      ),
    );
  }

  Widget _buildPin() {
    // 핀 크기는 어느 단계든 67.7 그대로다(시안 프레임의 92.9·78.2는 기울인
    // 사각형의 바깥 상자일 뿐이다). 내려앉으면 칩이 파랗게 굳고 핀은
    // 사라진다 — 남아 있으면 지역을 가린다
    final landed = _phase == _Phase.landing || _phase == _Phase.result;
    final heading = _phase == _Phase.idle
        ? _spin.value * 2 * math.pi
        : _heading;
    const d = RandomBoard.pinDiameter;
    return Positioned(
      left: _pinPos.dx - d / 2,
      top: _pinPos.dy - d / 2,
      width: d,
      height: d,
      child: Listener(
        onPointerDown: _onPinDown,
        onPointerUp: _onPinUp,
        onPointerCancel: _onPinUp,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: landed ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Semantics(
            button: true,
            label: '핀. 꾹 눌렀다 떼면 지역을 랜덤으로 고릅니다',
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.backgroundNormal,
                shape: BoxShape.circle,
                border: Border.all(color: AppPalette.offway50, width: 5),
              ),
              child: Center(
                // 에셋은 오른쪽 위(45°)를 보는 종이비행기다 — 45°를 빼야 위를
                // 향하고, 거기에 조준 방향을 더한다
                child: Transform.rotate(
                  angle: heading - math.pi / 4,
                  child: SvgPicture.asset(
                    'assets/icons/ic_paper_plane.svg',
                    width: 37,
                    height: 37,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 핀 가장자리에서 조준 방향으로 자라는 점선.
///
/// 시안: 굵기 3의 둥근 점을 11.5 간격으로. 핀 쪽이 light blue 40(진함)이고
/// 멀어질수록 offway 50으로 밝아지며 점도 조금 작아진다.
class _AimLinePainter extends CustomPainter {
  const _AimLinePainter({
    required this.from,
    required this.direction,
    required this.startGap,
    required this.length,
  });

  final Offset from;
  final Offset direction;
  final double startGap;
  final double length;

  static const _dotRadius = 1.5;
  static const _spacing = 11.5;

  @override
  void paint(Canvas canvas, Size size) {
    if (length <= 0) return;
    final paint = Paint()..style = PaintingStyle.fill;
    for (var d = 0.0; d <= length; d += _spacing) {
      final t = d / _aimMax;
      paint.color = Color.lerp(AppPalette.lightBlue40, AppPalette.offway50, t)!;
      canvas.drawCircle(
        from + direction * (startGap + d),
        _dotRadius * (1 - 0.35 * t),
        paint,
      );
    }
  }

  static const _aimMax = 150.0;

  @override
  bool shouldRepaint(_AimLinePainter old) =>
      old.from != from ||
      old.direction != direction ||
      old.length != length ||
      old.startGap != startGap;
}

/// "핀을 꾹 눌러 던져보세요" — 핀 위 말풍선.
///
/// 시안 Tooltip: inverse/background 88% 위에 primary 5%를 덮은 색, 반경 8,
/// 안쪽 12·8, 아래 꼬리 20×8.
class _PinTooltip extends StatelessWidget {
  const _PinTooltip();

  static final _fill = Color.alphaBlend(
    AppColors.primaryNormal.withValues(alpha: 0.05),
    AppColors.inverseBackground.withValues(alpha: 0.88),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _fill,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '핀을 꾹 눌러 던져보세요',
            style: AppTypography.label1NormalMedium.copyWith(
              color: AppColors.inverseLabel,
            ),
          ),
        ),
        CustomPaint(
          size: const Size(20, 8),
          painter: _TooltipTailPainter(_fill),
        ),
      ],
    );
  }
}

class _TooltipTailPainter extends CustomPainter {
  const _TooltipTailPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TooltipTailPainter old) => old.color != color;
}

enum _ResultAnswer { again, go, backToList }

/// 착지 결과 — "이번 여행지는 정선" + 한줄소개 + 썸네일 + 액션 둘.
///
/// 카드 아래 "여행지 목록으로 돌아가기"는 딤 위에 바로 놓인다(시안).
class _ResultDialog extends StatelessWidget {
  const _ResultDialog({required this.label, required this.region});

  final String label;
  final Map<String, dynamic> region;

  @override
  Widget build(BuildContext context) {
    final intro = region['intro'] as String?;
    final imageUrl = region['imageUrl'] as String?;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      // 시안: 카드 위가 y 206(874 기준) — 정중앙보다 조금 위다
      alignment: const Alignment(0, -0.18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 320,
            decoration: BoxDecoration(
              color: AppColors.backgroundElevated,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(19.5, 20, 19.5, 0),
                  child: Column(
                    children: [
                      Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primaryNormal.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '이번 여행지는',
                          style: AppTypography.label1NormalBold.copyWith(
                            color: AppColors.primaryNormal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: AppTypography.heading1Bold.copyWith(
                          color: AppColors.labelNormal,
                        ),
                      ),
                      // 한줄소개는 서버가 재료가 있을 때만 준다(core #140)
                      if (intro != null && intro.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          intro,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body2NormalMedium.copyWith(
                            color: AppColors.labelAlternative,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 281,
                        height: 164,
                        child: PlaceThumbnail(
                          imageUrl: imageUrl,
                          width: 281,
                          height: 164,
                          radius: 12,
                          iconSize: 64,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  // 시안: 썸네일 아래 22, 버튼 줄 32, 아래 20. 우측 28은
                  // 버튼이 가진 좌우 여백 8을 뺀 값
                  padding: const EdgeInsets.fromLTRB(28, 22, 20, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _TextAction(
                        label: '다시 던지기',
                        color: AppColors.labelAlternative,
                        onTap: () =>
                            Navigator.of(context).pop(_ResultAnswer.again),
                      ),
                      const SizedBox(width: 8),
                      _TextAction(
                        label: '$label으로 떠나기',
                        color: AppColors.primaryNormal,
                        onTap: () =>
                            Navigator.of(context).pop(_ResultAnswer.go),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(_ResultAnswer.backToList),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              child: Text(
                '여행지 목록으로 돌아가기',
                style: AppTypography.label1NormalBold.copyWith(
                  color: AppColors.backgroundNormalAlternative,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.backgroundNormalAlternative,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 모달의 텍스트 버튼 — 확인 모달과 같은 규칙(글자 폭 + 좌우 8)
class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Text(
          label,
          maxLines: 1,
          style: AppTypography.body1NormalBold.copyWith(color: color),
        ),
      ),
    );
  }
}

/// i 아이콘 → "어떤 지역이 나오나요?" — 상단바 바로 아래 카드(시안 y 14)
class _InfoDialog extends StatelessWidget {
  const _InfoDialog();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          // 시안: 상단 안전영역 아래 82 (상단바 44 + 38)
          padding: const EdgeInsets.fromLTRB(20, 82, 20, 0),
          child: Material(
            color: AppColors.backgroundElevated,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 9, 22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '어떤 지역이 나오나요?',
                          style: AppTypography.headline2Bold.copyWith(
                            color: AppColors.labelNormal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '앞서 찾은 조건에 맞는 여행지 안에서만 핀을 던져\n한 곳을 랜덤으로 골라드려요.',
                          style: AppTypography.label1NormalMedium.copyWith(
                            color: AppColors.labelAlternative,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppIconButton.close(
                    size: 22,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
