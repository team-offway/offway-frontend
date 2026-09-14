import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:offway/core/network/dio_client.dart';
import 'package:offway/core/storage/secure_storage.dart';
import 'package:offway/core/router/app_router.dart';
import 'package:offway/core/router/session_expiry_listener.dart';
import 'package:offway/features/auth/application/current_user_provider.dart';
import 'package:offway/features/auth/data/auth_repository.dart';
import 'package:offway/features/my/presentation/my_screen.dart';
import 'package:offway/features/my/presentation/withdraw_screen.dart';
import 'package:offway/features/notification/application/push_registration.dart';
import 'package:offway/features/trip_activity/application/trip_activity_controller.dart';
import 'package:offway/features/trip_activity/data/trip_activity_service.dart';
import 'package:offway/features/trip_activity/domain/trip_countdown.dart';

/// 세션이 끝나면 잠금화면의 여행도 내린다 — **세 경로 모두**.
///
/// **Live Activity 는 앱을 꺼도 잠금화면에 남는다.** 내리지 않으면 다음
/// 사람이 앞사람의 여행지·날짜를 그대로 본다. 기기를 함께 쓰면 남의
/// 정보가 새는 셈이라, 로그아웃·탈퇴·세션 만료를 각각 못 박는다.
void main() {
  late _SpyService spy;

  setUp(() {
    spy = _SpyService();
    // 아이콘 뱃지·토큰 저장소가 플러그인을 부른다 — 테스트에서는 삼킨다
    for (final name in const [
      'dexterous.com/flutter/local_notifications',
      'plugins.it_nomads.com/flutter_secure_storage',
      // 세션 만료가 아이콘 뱃지를 지운다 — 덮지 않으면 그 await 에서
      // 멈춰 정작 검사하려는 stop() 까지 가지 못한다
      'app_badge_plus',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (call) async => null);
    }
  });

  overrides() => [
    currentUserProvider.overrideWith((ref) async => {'nickname': '영찬'}),
    // 세션 만료는 토큰부터 지운다 — 덮지 않으면 그 자리에서 예외가 나고
    // try 가 삼켜, 정작 검사하려는 stop() 까지 가지 못한다
    secureStorageProvider.overrideWithValue(
      TokenStorage(const FlutterSecureStorage()),
    ),
    tripActivityServiceProvider.overrideWithValue(spy),
    pushRegistrationProvider.overrideWithValue(_FakePushRegistration()),
    authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
  ];

  Widget wrap(Widget screen) => ProviderScope(
    overrides: overrides(),
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/here',
        routes: [
          GoRoute(path: '/here', builder: (_, _) => screen),
          GoRoute(
            path: AppRoutes.login,
            builder: (_, _) => const Scaffold(body: Text('로그인 화면')),
          ),
        ],
      ),
    ),
  );

  testWidgets('로그아웃하면 잠금화면에 뜬 여행을 내린다', (tester) async {
    await tester.pumpWidget(wrap(const MyScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(spy.ended, isTrue, reason: '로그인 화면으로 가기 전에 내려야 한다');
  });

  testWidgets('탈퇴하면 잠금화면에 뜬 여행을 내린다', (tester) async {
    // 계정이 아예 지워지는데 카드만 남으면 더 나쁘다
    await tester.pumpWidget(wrap(const WithdrawScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('떠날래요'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('탈퇴할게요'));
    await tester.pumpAndSettle();

    expect(spy.ended, isTrue, reason: '계정이 지워지기 전에 내려야 한다');
  });

  testWidgets('세션이 만료돼도 잠금화면을 내린다', (tester) async {
    late WidgetRef readyRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          home: SessionExpiryListener(
            child: Consumer(
              builder: (context, ref, _) {
                readyRef = ref;
                return const Scaffold(body: Text('홈'));
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    readyRef.read(sessionExpiredProvider.notifier).markExpired();
    await tester.pumpAndSettle();

    expect(spy.ended, isTrue, reason: '로그인 화면으로 되돌리기 전에 내려야 한다');
  });
}

/// **`noSuchMethod` 를 두지 않는다.** 두면 서비스에 메서드가 늘어도
/// 조용히 삼켜, 실기기에서만 터지는 구멍이 생긴다
class _SpyService implements TripActivityService {
  bool ended = false;

  @override
  Future<void> end() async => ended = true;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> start(TripCountdown trip, {DateTime? now}) async {}
}

class _FakePushRegistration implements PushRegistration {
  @override
  noSuchMethod(Invocation invocation) async => null;
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> logout() async {}

  @override
  Future<void> withdraw() async {}

  @override
  noSuchMethod(Invocation invocation) async => null;
}
