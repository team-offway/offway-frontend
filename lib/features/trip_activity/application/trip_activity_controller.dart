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

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    syncInBackground();
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
    sync().catchError((Object e) {
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

    final cards = await _ref.read(savedCoursesProvider('UPCOMING').future);
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
