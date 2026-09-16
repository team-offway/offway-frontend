import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../course/presentation/my_courses_screen.dart'
    show savedCoursesProvider;
import '../data/live_activity_repository.dart';
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
/// 앱이 꺼져 있는 동안은 **서버가 자정마다 갱신한다**(core #577). 그러려면
/// 카드의 푸시 토큰을 서버가 알아야 하는데, 네이티브가 토큰을 올려 보내면
/// 여기서 등록한다. 카드를 내릴 때는 등록도 지운다.
class TripActivityController with WidgetsBindingObserver {
  TripActivityController(this._ref) {
    // 토큰 수신자는 **한 번만** 건다. 카드가 떠야 토큰이 오므로 start()
    // 전에는 어차피 안 오고, 세션이 끝난 뒤 늦게 온 것은 _stopped 가 거른다
    _ref.read(tripActivityServiceProvider).listenPushToken(_onPushToken);
  }

  final Ref _ref;
  bool _started = false;

  /// 진행 중인 맞추기. **겹쳐 돌면 안 된다** — 앱 재개가 연달아 오면
  /// (알림 센터를 내렸다 올리거나 앱 스위처를 스치면 실제로 그렇다)
  /// 늦게 시작한 쪽이 먼저 끝나 end() 와 start() 의 순서가 뒤집힌다
  Future<void>? _syncing;

  /// 멈춘 뒤인가. 진행 중이던 sync() 가 깨어났을 때 물러나게 한다 —
  /// 세션이 끝났는데 앞사람의 코스를 다시 띄우면 안 된다
  bool _stopped = false;

  /// 지금 잠금화면에 떠 있는(또는 띄우는 중인) 코스.
  ///
  /// 둘에 쓴다 — 내릴 때 서버 등록을 같이 지우고, **올라온 토큰이 이 코스의
  /// 것인지 가른다.** 네이티브 watcher 는 취소 검사와 Dart 호출 사이에 틈이
  /// 있어, 코스를 갈아타는 도중 내린 코스의 토큰이 늦게 닿을 수 있다
  String? _liveCourseId;

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
    // 서버 등록을 먼저 지운다 — 아직 이 사람의 토큰이 살아 있을 때라야
    // 요청이 통한다(로그아웃 뒤에는 401 이다)
    await _unregisterLive();
    final service = _ref.read(tripActivityServiceProvider);
    final ended = await service.end();
    // 위젯도 앞사람의 것이다 — 카드처럼 비운다
    final cleared = await service.clearWidget();
    return ended && cleared;
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

  /// 예정 코스를 읽어 **위젯 목록을 갈아 끼우고**, 잠금화면에 띄울 하나를 고른다.
  ///
  /// 띄울 것이 없으면(예정이 없거나 다 지났으면) 떠 있던 것을 내린다 —
  /// 끝난 여행이 잠금화면에 남아 있을 이유가 없다
  Future<void> sync({DateTime? now}) async {
    final service = _ref.read(tripActivityServiceProvider);
    if (_stopped) return;

    final List<Map<String, dynamic>> cards;
    try {
      cards = await _ref.read(savedCoursesProvider('UPCOMING').future);
    } on Object catch (e) {
      // **코스를 못 읽었다고 떠 있는 것을 그냥 두지 않는다.** 서버가 계속
      // 실패하면 지난 여행 D-day 가 잠금화면에 무기한 남는다 — 무엇을
      // 띄울지 모르는 상태라면 아무것도 띄우지 않는 편이 맞다.
      //
      // 위젯은 그대로 둔다 — 위젯은 날짜를 스스로 세므로 알던 여행에 대해선
      // 여전히 맞는 말을 한다. 비우면 잠깐의 통신 실패가 "예정된 여행이
      // 없어요" 로 보인다
      debugPrint('예정 코스를 읽지 못해 잠금화면을 내린다: $e');
      if (!_stopped) {
        await _unregisterLive();
        await service.end();
      }
      rethrow;
    }

    // **조회를 기다리는 동안 세션이 끝났을 수 있다.** 그 사이에 stop() 이
    // 내려 둔 것을 여기서 다시 띄우면 앞사람의 여행이 되살아난다
    if (_stopped) return;

    final at = now ?? DateTime.now();
    final trips = cards
        .map(TripCountdown.tryFrom)
        .whereType<TripCountdown>()
        .toList();

    // 위젯은 라이브 액티비티가 안 되는 기기(설정에서 껐거나)에서도 그린다 —
    // 가능 여부를 묻기 전에 먼저 쓴다. 지난 여행은 넘기지 않는다
    await service.setWidgetTrips(trips.where((t) => !t.isPast(at)).toList());

    if (!await service.isAvailable()) return;
    if (_stopped) return;

    final picked = TripCountdown.pick(trips, at);

    if (picked == null) {
      await _unregisterLive();
      await service.end();
      return;
    }
    // 다른 코스로 바뀐다 — 앞 코스의 등록은 지운다. 안 지우면 서버가
    // 내린 카드에 매일 갱신을 보내다 410 을 받고서야 치운다
    if (_liveCourseId != null && _liveCourseId != picked.courseId) {
      await _unregisterLive();
    }
    // **띄우기 전에 세운다.** 토큰은 start() 가 답한 뒤에 오지만, 그 전에
    // 세워 둬야 '시작 중인 코스' 의 토큰을 남의 것으로 버리지 않는다.
    // 띄우기가 실패해도 그대로 둔다 — 다음 맞추기가 다시 띄우고, 지울 일이
    // 생기면 등록된 적 없는 코스의 DELETE 는 서버가 성공으로 받는다
    _liveCourseId = picked.courseId;
    await service.start(picked, now: now);
  }

  /// 네이티브가 카드의 토큰을 올려 보냈다 — 서버에 등록한다.
  ///
  /// **기다리지 않는다.** 등록이 늦어도 카드는 이미 떠 있다. 실패하면 다음
  /// 자정 갱신이 안 오는 것뿐이고, iOS 가 토큰을 다시 주거나 앱이 다시
  /// 띄울 때 또 온다
  void _onPushToken(String courseId, String token) {
    if (_stopped) return; // 세션이 끝난 뒤 늦게 온 토큰 — 남의 것이 된다
    // **지금 떠 있는 코스의 토큰만 올린다.** 코스를 갈아타는 도중 내린 코스의
    // 토큰이 늦게 닿으면, 방금 지운 등록이 죽은 토큰으로 되살아난다 — 서버가
    // 자정마다 거기 보내다 410 을 받고서야 치운다
    if (courseId != _liveCourseId) {
      debugPrint('내린 코스($courseId)의 토큰은 올리지 않는다');
      return;
    }
    _ref
        .read(liveActivityRepositoryProvider)
        .register(courseId: courseId, token: token)
        .catchError((Object e) {
          debugPrint('잠금화면 갱신 토큰을 올리지 못했다: $e');
        });
  }

  /// 떠 있던 코스의 서버 등록을 지운다.
  ///
  /// 실패해도 삼킨다 — 안 불러도 결국 정리된다(여행이 끝나면 배치가, 토큰이
  /// 죽으면 410 이 지운다). 이 호출은 그보다 빨리 치우는 것뿐이라, 잠금화면
  /// 정리나 로그아웃을 막을 이유가 없다
  Future<void> _unregisterLive() async {
    final id = _liveCourseId;
    if (id == null) return;
    _liveCourseId = null;
    try {
      await _ref.read(liveActivityRepositoryProvider).unregister(id);
    } on Object catch (e) {
      debugPrint('잠금화면 갱신 등록을 지우지 못했다: $e');
    }
  }
}

final tripActivityControllerProvider = Provider<TripActivityController>((ref) {
  final controller = TripActivityController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});
