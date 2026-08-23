import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens/tokens.dart';

/// 하단 플로팅 탭이 가리키는 최상위 목적지
enum AppTab {
  home('홈', 'assets/icons/tab_home_v2.svg'),
  myCourse('내 코스', 'assets/icons/tab_course_v2.svg'),
  my('마이', 'assets/icons/tab_my_v2.svg');

  const AppTab(this.label, this.iconAsset);

  final String label;
  final String iconAsset;
}

/// 탭 한 칸의 폭·간격 — 알약이 미끄러질 거리를 이 값으로 잰다
const _tabWidth = 72.0;
const _tabGap = 6.0;
const _barPadding = 4.0;
const _tabStep = _tabWidth + _tabGap;

/// 알약이 옮겨가는 시간
const _slideDuration = Duration(milliseconds: 400);

/// 앞/뒤 모서리가 어긋나 출발하는 간격 — 이 차이가 알약을 늘어나 보이게 한다
const _staggerDuration = Duration(milliseconds: 55);

/// 목표를 7%쯤 지나쳤다 돌아오는 약한 스프링.
/// 팀 웹(18th-team3-client)의 `SLIDE_EASE`와 오버슈트를 맞춘 값이다 —
/// [Curves.easeOutBack]은 10%를 넘겨 탭바에는 과하다
/// stagger 때문에 두 모서리가 시차를 두고 각각 지나쳐 실제 오버슈트는
/// 이 값보다 커진다 — 7%로 두면 화면에서는 20pt를 넘겨 튕겨나간 것처럼 보인다
const _slideEase = Cubic(0.25, 1.0, 0.5, 1.08);

/// 손을 뗐을 때 튕겨 붙는 스프링.
///
/// 웹 `SPRING_EASE`는 오버슈트가 36%인데, 그건 손가락이 이미 목표 근처까지
/// 끌어다 놓은 **몇 픽셀짜리** 스냅에 쓰는 값이다. 한 칸(78)을 그 값으로
/// 옮기면 28pt를 지나쳤다 돌아와 튕겨나간 것처럼 보인다. 18%로 낮춘다
const _snapEase = Cubic(0.25, 1.0, 0.5, 1.15);

/// 이만큼 끌면 탭이 아니라 드래그로 본다 — 손떨림이 드래그로 빠지지 않을 만큼
const _dragThreshold = 12.0;

/// 끌리는 속도를 이 범위로 자른다. 밖으로 두면 홱 그을 때 알약이 찌그러진다
const _maxVelocity = 10.0;

/// 홈·지역 상세 등에서 공유하는 하단 플로팅 탭.
/// [current]가 null이면 어느 탭도 활성으로 보이지 않는다(하위 화면).
class AppTabPills extends StatefulWidget {
  const AppTabPills({super.key, this.current = AppTab.home, this.onTap});

  final AppTab? current;
  final ValueChanged<AppTab>? onTap;

  @override
  State<AppTabPills> createState() => _AppTabPillsState();
}

class _AppTabPillsState extends State<AppTabPills> {
  /// 끌고 있는 동안의 알약 왼쪽 위치. null이면 손을 대지 않은 상태다
  double? _dragLeft;

  /// 직전 프레임 대비 손가락 속도 — 늘어남·기울기의 세기가 된다
  double _velocity = 0;

  /// 문턱을 넘겨 드래그로 판정됐는지. 넘기 전에는 탭으로 본다
  bool _dragged = false;

  /// 잡고 있는 동안 알약이 부푼다. 손을 떼도 **착지를 마칠 때까지** 유지한다 —
  /// 떼자마자 줄이면 부푼 채 미끄러지는 맛이 사라진다
  bool _grabbing = false;
  Timer? _landingTimer;

  double _startX = 0;
  double _anchorLeft = 0;

  static double _leftFor(int index) => index * _tabStep;

  int _indexFor(double left) =>
      ((left + _tabWidth / 2) ~/ _tabStep).clamp(0, AppTab.values.length - 1);

  void _onDragStart(DragStartDetails d, int activeIndex) {
    _startX = d.localPosition.dx;
    _anchorLeft = _dragLeft ?? _leftFor(activeIndex);
    _dragged = false;
    _landingTimer?.cancel();
    setState(() => _grabbing = true);
  }

  /// 착지가 끝나면 무광 알약으로 되돌린다 (웹 LANDING_MS = 480)
  void _scheduleLanding() {
    _landingTimer?.cancel();
    _landingTimer = Timer(const Duration(milliseconds: 480), () {
      if (mounted) setState(() => _grabbing = false);
    });
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final dx = d.localPosition.dx - _startX;
    if (!_dragged) {
      if (dx.abs() < _dragThreshold) return;
      _dragged = true;
    }
    setState(() {
      _dragLeft = (_anchorLeft + dx).clamp(
        0.0,
        _leftFor(AppTab.values.length - 1),
      );
      _velocity = d.delta.dx.clamp(-_maxVelocity, _maxVelocity);
    });
  }

  void _onDragEnd() {
    _scheduleLanding();
    if (!_dragged) {
      setState(() {
        _dragLeft = null;
        _velocity = 0;
      });
      return;
    }
    // 가장 가까운 탭으로 튕겨 붙는다
    final target = _indexFor(_dragLeft ?? 0);
    setState(() {
      _dragLeft = null;
      _velocity = 0;
    });
    if (AppTab.values[target] != widget.current) {
      widget.onTap?.call(AppTab.values[target]);
    }
  }

  @override
  void didUpdateWidget(AppTabPills old) {
    super.didUpdateWidget(old);
    // 탭을 눌러 옮길 때도 부푼 채 미끄러진다 — 끌 때만 부풀면 두 조작의
    // 느낌이 갈린다. 착지를 마치면 480ms 뒤 무광으로 돌아온다
    if (widget.current != old.current && widget.current != null) {
      _grabbing = true;
      _scheduleLanding();
    }
  }

  @override
  void dispose() {
    _landingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.current == null
        ? -1
        : AppTab.values.indexOf(widget.current!);
    const barWidth =
        _barPadding * 2 + _tabWidth * 3 + _tabGap * 2; // 탭 셋 기준 바 안쪽 폭

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 리퀴드 글래스 — 뒤가 비치는 것과 라벨이 읽히는 것 사이를 잡는다.
            //
            // 웹(18th-team3-client `liquid-glass`)은 틴트 80%에 블러 3인데,
            // 그쪽은 블러와 틴트를 ::before/::after 로 나눠 쌓아 블러가 틴트에
            // 가리지 않는다. Flutter 는 BackdropFilter 위에 틴트를 바로 얹어
            // 같은 값을 쓰면 뒤가 220까지 밝아져 불투명 판이 된다.
            //
            // 그래서 틴트를 55%로 낮추고 블러를 12로 올린다 — 어두운 사진 위에서
            // 168 쯤으로, 뒤가 비치면서 검은 라벨도 읽힌다.
            //
            // 유리로 보이게 하는 마지막 한 겹은 테두리 안쪽 광택이다.
            // 바깥 그림자는 클립 밖에 둔다 — 안에 두면 함께 잘려 사라진다
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x29000000), // 16%
                        offset: Offset(0, 6),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        height: 58,
                        width: barWidth,
                        padding: const EdgeInsets.all(_barPadding),
                        decoration: BoxDecoration(
                          color: AppColors.staticWhite.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            // 좌상단 하이라이트 · 우하단 반사 (web의 inset 2겹)
                            BoxShadow(
                              color: AppColors.staticWhite.withValues(
                                alpha: 0.6,
                              ),
                              offset: const Offset(2, 2),
                              blurRadius: 1,
                              blurStyle: BlurStyle.inner,
                            ),
                            BoxShadow(
                              color: AppColors.staticWhite.withValues(
                                alpha: 0.4,
                              ),
                              offset: const Offset(-1, -1),
                              blurRadius: 1,
                              spreadRadius: 1,
                              blurStyle: BlurStyle.inner,
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final tab in AppTab.values) ...[
                                  if (tab != AppTab.values.first)
                                    const SizedBox(width: _tabGap),
                                  _Pill(
                                    tab: tab,
                                    active: tab == widget.current,
                                    onTap: widget.onTap == null
                                        ? null
                                        : () => widget.onTap!(tab),
                                  ),
                                ],
                              ],
                            ),
                            // 탭 위를 덮어 끌기만 가로챈다 — 세로 스크롤과 탭은
                            // 그대로 아래로 흘려보내고, 문턱(12)을 넘겨야 끌린다
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onHorizontalDragStart: (d) =>
                                    _onDragStart(d, index),
                                onHorizontalDragUpdate: _onDragUpdate,
                                onHorizontalDragEnd: (_) => _onDragEnd(),
                                onHorizontalDragCancel: _onDragEnd,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // 알약은 클립 **밖**에 둔다. 안에 두면 부풀 때(1.25배)도,
                // 양 끝 탭에서도 둥근 모서리에 눌려 찌그러진다 — 넘쳐 보이는
                // 것이 맞다. 아이콘 위로 올라오는 것도 웹과 같다(z-10)
                if (index >= 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Padding(
                        padding: const EdgeInsets.all(_barPadding),
                        child: _Indicator(
                          index: index,
                          dragLeft: _dragLeft,
                          velocity: _velocity,
                          grabbing: _grabbing,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 활성 탭 뒤에 깔리는 알약 — 탭이 바뀌면 미끄러져 옮겨간다.
///
/// **앞 모서리와 뒤 모서리를 따로 움직인다.** 둘을 같이 옮기면 그냥 평행이동이라
/// 밋밋한데, 진행 방향 쪽을 먼저 떠나보내면 이동 중에 알약이 늘어났다가
/// 착지하며 오므라든다. 웹이 `left`/`right`에 서로 다른 delay를 주는 것과 같다.
class _Indicator extends StatefulWidget {
  const _Indicator({
    required this.index,
    this.dragLeft,
    this.velocity = 0,
    this.grabbing = false,
  });

  final int index;

  /// 끌고 있는 동안의 위치. null이면 활성 탭 자리로 애니메이션한다
  final double? dragLeft;

  /// 손가락 속도 — 늘어남과 기울기의 세기
  final double velocity;

  /// 잡고 있는 동안 부푼다 (웹 `scale-125`)
  final bool grabbing;

  @override
  State<_Indicator> createState() => _IndicatorState();
}

class _IndicatorState extends State<_Indicator> {
  /// 진행 방향 — 오른쪽으로 가면 왼쪽 모서리가 늦게 출발한다
  bool _forward = true;

  /// 방금 손을 뗐는지 — 뗀 직후 한 번은 강한 스프링으로 튕겨 붙는다
  bool _snapping = false;

  @override
  void didUpdateWidget(_Indicator old) {
    super.didUpdateWidget(old);
    if (widget.index != old.index) _forward = widget.index > old.index;
    // 스냅은 손을 뗀 **그 한 번**만이다. 켜둔 채 두면 그 뒤 모든 탭 이동에
    // 36% 오버슈트가 걸려 알약이 목표를 한참 지나쳤다 돌아온다
    if (old.dragLeft != null && widget.dragLeft == null) {
      _snapping = true;
    } else if (widget.index != old.index || widget.dragLeft != null) {
      _snapping = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dragging = widget.dragLeft != null;
    final left = widget.dragLeft ?? widget.index * _tabStep;
    final right = (AppTab.values.length - 1) * _tabStep - left;
    // 앞서는 모서리는 바로, 따라오는 모서리는 늦게 — 그 사이 알약이 늘어난다
    final leftDelay = _forward ? _staggerDuration : Duration.zero;
    final rightDelay = _forward ? Duration.zero : _staggerDuration;
    // 끄는 동안엔 손가락을 그대로 따라야 한다 — 커브를 태우면 끈적하게 밀린다
    final curve = dragging
        ? Curves.linear
        : (_snapping ? _snapEase : _slideEase);
    final duration = dragging ? Duration.zero : _slideDuration;

    // 빠를수록 진행 방향으로 늘어나고(가로 +), 두께는 얇아진다(세로 −)
    final speed = widget.velocity.abs();
    final scaleX = 1 + speed * 0.02;
    final scaleY = 1 - speed * 0.012;
    // 잡으면 탭바 밖으로 넘칠 만큼 부푼다 — 손끝에 잡힌 덩어리로 읽힌다
    final grab = widget.grabbing ? 1.25 : 1.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _AnimatedEdge(
          value: left,
          delay: dragging ? Duration.zero : leftDelay,
          curve: curve,
          duration: duration,
          builder: (l) => _AnimatedEdge(
            value: right,
            delay: dragging ? Duration.zero : rightDelay,
            curve: curve,
            duration: duration,
            builder: (r) => Positioned(
              left: l,
              right: r,
              top: 0,
              bottom: 0,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                scale: grab,
                child: Transform(
                  alignment: Alignment.center,
                  // 끌려가듯 기우는 스큐 + 속도만큼의 스쿼시
                  transform: Matrix4.identity()
                    ..scaleByDouble(scaleX, scaleY, 1, 1)
                    ..setEntry(0, 1, -widget.velocity * 0.006),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      // 팀 웹과 같은 검정 8%. 회색(Cool Neutral) 8%는 흰
                      // 틴트 위에서 명도차가 11뿐이라 안 보였다 — 검정은 20
                      color: AppColors.staticBlack.withValues(
                        alpha: AppOpacity.o8,
                      ),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 값 하나를 [delay]만큼 늦게 출발시켜 [_slideEase]로 옮긴다.
///
/// [AnimatedPositioned]는 네 변을 한 커브로 함께 움직여 모서리를 어긋나게
/// 할 수 없다. 알약이 늘어나 보이려면 앞뒤가 따로 출발해야 한다
class _AnimatedEdge extends StatefulWidget {
  const _AnimatedEdge({
    required this.value,
    required this.delay,
    required this.builder,
    this.curve = _slideEase,
    this.duration = _slideDuration,
  });

  final double value;
  final Duration delay;
  final Widget Function(double value) builder;
  final Curve curve;
  final Duration duration;

  @override
  State<_AnimatedEdge> createState() => _AnimatedEdgeState();
}

class _AnimatedEdgeState extends State<_AnimatedEdge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late double _from = widget.value;
  late double _to = widget.value;

  @override
  void didUpdateWidget(_AnimatedEdge old) {
    super.didUpdateWidget(old);
    if (widget.value == _to) return;
    // 이동 중에 또 눌려도 지금 위치에서 이어간다 — 처음으로 튀지 않게
    _from = _current;
    _to = widget.value;
    _controller.duration = widget.duration;
    // 끄는 동안(duration 0)에는 애니메이션 없이 손가락을 그대로 따른다
    if (widget.duration == Duration.zero) {
      _controller.value = 1;
      return;
    }
    _controller.forward(from: 0);
    if (widget.delay > Duration.zero) {
      _controller.stop();
      // 화면을 떠나면 타이머도 거둔다 — 남겨두면 사라진 위젯을 깨우려 든다
      _delayTimer?.cancel();
      _delayTimer = Timer(widget.delay, () {
        if (mounted) _controller.forward(from: 0);
      });
    }
  }

  double get _current =>
      _from + (_to - _from) * widget.curve.transform(_controller.value);

  Timer? _delayTimer;

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (_, _) => widget.builder(_current),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.tab, required this.active, this.onTap});

  final AppTab tab;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.labelStrong : AppColors.labelAlternative;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _tabWidth,
        height: double.infinity,
        // 알약은 뒤에서 따로 그린다 — 여기서 배경을 칠하면 옮겨갈 것이 없다
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 색이 튀지 않고 번지듯 넘어가야 알약 이동과 한 동작으로 읽힌다
            AnimatedSlide(
              duration: _slideDuration,
              curve: _slideEase,
              offset: active ? const Offset(0, -0.06) : Offset.zero,
              child: SvgPicture.asset(
                tab.iconAsset,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: _slideDuration,
              curve: Curves.easeOut,
              style: AppTypography.caption2Medium.copyWith(color: color),
              child: Text(tab.label),
            ),
          ],
        ),
      ),
    );
  }
}
