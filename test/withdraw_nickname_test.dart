import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/auth/application/current_user_provider.dart';
import 'package:offway/features/home/presentation/home_screen.dart'
    show homeUserProvider;
import 'package:offway/features/my/presentation/withdraw_screen.dart';

/// 탈퇴 화면이 부르는 이름.
///
/// **`/home` 의 이름은 '게스트'다.** 비회원까지 아우르는 값이라
/// (core `HomeResponse.GUEST_NAME`) 로그인해도 그렇게 온다. 로그인한
/// 사람의 이름은 `currentUserProvider` 가 `/users/me` 로 덮은 값이다 —
/// 탈퇴 화면이 앞단을 보면 "게스트님, 정말 떠나시겠어요?" 가 된다.
void main() {
  Widget wrap({required String home, required String me}) => ProviderScope(
    overrides: [
      homeUserProvider.overrideWith((ref) async => {'nickname': home}),
      currentUserProvider.overrideWith((ref) async => {'nickname': me}),
    ],
    child: const MaterialApp(home: WithdrawScreen()),
  );

  testWidgets('홈이 게스트라고 해도 로그인한 이름을 부른다', (tester) async {
    await tester.pumpWidget(wrap(home: '게스트', me: '영찬'));
    await tester.pumpAndSettle();

    expect(find.text('영찬님, 정말 떠나시겠어요?'), findsOneWidget);
    expect(find.textContaining('게스트'), findsNothing);
  });

  testWidgets('이름을 못 받으면 이름 없이 묻는다', (tester) async {
    // 'null님'이 보이면 안 된다
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeUserProvider.overrideWith((ref) async => {}),
          currentUserProvider.overrideWith((ref) async => {}),
        ],
        child: const MaterialApp(home: WithdrawScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('정말 떠나시겠어요?'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
  });
}
