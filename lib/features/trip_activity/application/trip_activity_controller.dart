import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../course/presentation/my_courses_screen.dart'
    show savedCoursesProvider;
import '../data/trip_activity_service.dart';
import '../domain/trip_countdown.dart';

final tripActivityServiceProvider = Provider<TripActivityService>(
  (ref) => TripActivityService(),
);

/// 잠금화면에 띄울 여행을 고르고, 앱이 앞으로 나올 때마다 값을 맞춘다.
///
/// **하루에 한 번꼴로 바뀌는 값이다**(D-3 → D-2). 자주 부를 이유가 없어
/// 앱이 켜지거나 포그라운드로 돌아올 때만 맞춘다 — 타이머를 두지 않는다.
///
/// 1단계(로컬)라 **앱이 꺼져 있는 동안에는 갱신되지 않는다.** 자정을 넘겨도
/// 다음에 앱을 열 때 맞춰진다. 서버 푸시로 갱신하려면 APNs 직접 호출이
/// 필요한데(이슈 #261 2단계) 그건 별도 작업이다.
class TripActivityController with WidgetsBindingObserver {
  TripActivityController(this._ref);

  final Ref _ref;
  bool _started = false;

  /// 진행 중인 맞추기. **겹쳐 돌면 안 된다** — 앱 재개가 연달아 오면
  /// (알림 센터를 내렸다 올리거나 앱 스위처를 스치면 실제로 그렇다)
  /// 늦게 시작한 쪽이 먼저 끝나 end() 와 start() 의 순서가 뒤집힌다
  Future<void>? _syncing;

  /// 멈춘 뒤인가. 진행 중이던 sync() 가 깨어났을 때 물러나게 한다 —
  /// 세션이 끝났는데 앞사람의 코스를 다시 띄우면 안 된다
  bool _stopped = false;

  void start() {
    if (_started) return;
    _started = true;
    _stopped = false;
    WidgetsBinding.instance.addObserver(this);
    syncInBackground();
  }

  /// 세션이 끝났다 — 옵저버를 떼고 **잠금화면도 내린다**.
  ///
  /// 로그아웃·탈퇴·세션 만료가 부른다. 내리기만 하고 옵저버를 남겨 두면
  /// 앱을 다시 앞으로 낼 때 앞사람의 코스로 다시 띄운다.
  ///
  /// **진행 중인 맞추기 뒤에 세운다.** 코스 조회에 머물러 있던 sync() 가
  /// 나중에 깨어나 start() 를 부르면, 방금 내린 앞사람의 여행이 다시
  /// 올라간다. 멈춘 뒤에는 sync() 가 스스로 물러나지만(_stopped),
  /// 이미 조회를 마친 것이 있을 수 있어 큐의 끝에서 내린다.
  ///
  /// 내려갔으면 참. **거짓이면 앞사람의 여행이 잠금화면에 남아 있다.**
  Future<bool> stop() async {
    dispose();
    _stopped = true;

    // 앞의 맞추기가 끝나길 기다린다 — 실패했든 말든 순서만 지키면 된다
    await (_syncing ?? Future<void>.value()).catchError((_) {});
    return _ref.read(tripActivityServiceProvider).end();
  }

  void dispose() {
    if (!_started) return;
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) syncInBackground();
  }

  /// 기다리지 않고 맞춘다 — 실패해도 앱이 하던 일을 막지 않는다.
  /// 잠금화면이 안 뜨는 것뿐이다
  void syncInBackground() {
    // 앞의 맞추기가 끝난 뒤에 잇는다 — 겹쳐 돌면 순서가 뒤집힌다
    _syncing = (_syncing ?? Future<void>.value())
        .then((_) => sync())
        .catchError((Object e) {
          debugPrint('잠금화면을 맞추지 못했다: $e');
        });
  }

  /// 예정 코스를 읽어 띄울 하나를 고른다.
  ///
  /// 띄울 것이 없으면(예정이 없거나 다 지났으면) 떠 있던 것을 내린다 —
  /// 끝난 여행이 잠금화면에 남아 있을 이유가 없다
  Future<void> sync({DateTime? now}) async {
    final service = _ref.read(tripActivityServiceProvider);
    if (!await service.isAvailable()) return;
    if (_stopped) return;

    final List<Map<String, dynamic>> cards;
    try {
      cards = await _ref.read(savedCoursesProvider('UPCOMING').future);
    } on Object catch (e) {
      // **코스를 못 읽었다고 떠 있는 것을 그냥 두지 않는다.** 서버가 계속
      // 실패하면 지난 여행 D-day 가 잠금화면에 무기한 남는다 — 무엇을
      // 띄울지 모르는 상태라면 아무것도 띄우지 않는 편이 맞다
      debugPrint('예정 코스를 읽지 못해 잠금화면을 내린다: $e');
      if (!_stopped) await service.end();
      rethrow;
    }

    // **조회를 기다리는 동안 세션이 끝났을 수 있다.** 그 사이에 stop() 이
    // 내려 둔 것을 여기서 다시 띄우면 앞사람의 여행이 되살아난다
    if (_stopped) return;

    final trips = cards
        .map(TripCountdown.tryFrom)
        .whereType<TripCountdown>()
        .toList();
    final picked = TripCountdown.pick(trips, now ?? DateTime.now());

    if (picked == null) {
      await service.end();
      return;
    }
    await service.start(picked, now: now);
  }
}

final tripActivityControllerProvider = Provider<TripActivityController>((ref) {
  final controller = TripActivityController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});
