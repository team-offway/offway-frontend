import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:offway/core/router/app_router.dart';
import 'package:offway/features/auth/application/current_user_provider.dart';
import 'package:offway/features/auth/data/auth_repository.dart';
import 'package:offway/features/my/presentation/my_screen.dart';
import 'package:offway/features/notification/application/push_registration.dart';
import 'package:offway/features/trip_activity/application/trip_activity_controller.dart';
import 'package:offway/features/trip_activity/data/trip_activity_service.dart';

/// 로그아웃할 때 잠금화면을 반드시 내린다.
///
/// **Live Activity 는 앱을 꺼도 잠금화면에 남는다.** 내리지 않으면 다음
/// 사람이 앞사람의 여행지·날짜를 그대로 본다 — 기기를 함께 쓰면 남의
/// 정보가 새는 셈이다. 탈퇴·세션 만료도 같은 이유로 내린다(같은 한 줄이라
/// 여기서 로그아웃 경로만 못 박는다).
void main() {
  late _SpyTripActivityService spy;

  setUp(() {
    spy = _SpyTripActivityService();
    // 아이콘 뱃지는 플러그인을 부른다 — 테스트에서는 삼킨다
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          (call) async => null,
        );
  });

  Widget wrap() => ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) async => {'nickname': '영찬'}),
      tripActivityServiceProvider.overrideWithValue(spy),
      pushRegistrationProvider.overrideWithValue(_FakePushRegistration()),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/my',
        routes: [
          GoRoute(path: '/my', builder: (_, _) => const MyScreen()),
          GoRoute(
            path: AppRoutes.login,
            builder: (_, _) => const Scaffold(body: Text('로그인 화면')),
          ),
        ],
      ),
    ),
  );

  testWidgets('로그아웃하면 잠금화면에 뜬 여행을 내린다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();

    // 확인 모달의 기본 확인 버튼
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    // 화면 전환까지는 보지 않는다 — 뱃지 정리가 플러그인을 타서 테스트
    // 환경에서는 그 뒤가 갈린다. 여기서 못 박을 것은 '내렸는가' 하나다
    expect(spy.ended, isTrue, reason: '로그인 화면으로 가기 전에 내려야 한다');
  });
}

class _SpyTripActivityService implements TripActivityService {
  bool ended = false;

  @override
  Future<void> end() async => ended = true;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> start(Object trip, {DateTime? now}) async {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePushRegistration implements PushRegistration {
  @override
  noSuchMethod(Invocation invocation) async => null;
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> logout() async {}

  @override
  noSuchMethod(Invocation invocation) async => null;
}
