import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/auth/application/current_user_provider.dart';
import 'package:offway/features/course/application/pending_trip_provider.dart';
import 'package:offway/features/home/data/home_repository.dart';
import 'package:offway/features/home/presentation/home_screen.dart';

/// 홈 인사말 — 로그인했으면 서버가 준 '게스트' 대신 진짜 이름을 부른다.
///
/// `/home`의 `user.name`은 비회원까지 아우르는 값이라 로그인해도 '게스트'가
/// 온다(core `HomeResponse.GUEST_NAME`). 홈은 `/users/me`로 덮은 값을 읽는다.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required Map<String, dynamic> user,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) async => user),
          homeSnapshotProvider.overrideWith(
            (ref) async => HomeSnapshot(user: user, regions: const []),
          ),
          pendingTripProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('로그인한 이름으로 인사한다', (tester) async {
    await pump(tester, user: {'nickname': '영찬', 'remainingLeaveDays': 12.0});

    expect(find.text('영찬님, 어디로 떠나볼까요?'), findsOneWidget);
  });

  testWidgets('이름이 없으면 이름 없이 인사한다', (tester) async {
    // 아직 못 읽었거나 서버가 이름을 못 준 상태.
    //
    // 예전에는 '오프웨이님'으로 불렀는데, 로그인 직후 잠깐 그렇게 떴다가
    // 내 이름으로 바뀌어 남의 이름으로 불리는 것처럼 보였다(#102).
    await pump(tester, user: {'remainingLeaveDays': 12.0});

    expect(find.text('어디로 떠나볼까요?'), findsOneWidget);
    // 'null님'도, 남의 이름도 보이면 안 된다
    expect(find.textContaining('null'), findsNothing);
    expect(find.textContaining('오프웨이님'), findsNothing);
  });
}
