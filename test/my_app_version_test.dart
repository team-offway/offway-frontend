import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/features/auth/application/current_user_provider.dart';
import 'package:offway/features/my/application/app_version_provider.dart';
import 'package:offway/features/my/presentation/my_screen.dart';

/// 마이 화면 맨 아래의 앱 버전 — 테스터가 "어느 빌드에서 그랬다"를 말할 때
/// TestFlight를 열어 보지 않아도 되게 하는 자리다.
void main() {
  Widget wrap({required Future<String> Function() version}) => ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) async => {'nickname': '영찬'}),
      // 플러그인은 테스트에서 못 읽는다 — 값을 바로 준다
      appVersionProvider.overrideWith((ref) => version()),
    ],
    child: const MaterialApp(home: MyScreen()),
  );

  group('표기', () {
    test('버전과 빌드번호를 괄호로 잇는다', () {
      expect(formatAppVersion('1.0.4', '32'), '1.0.4 (32)');
    });

    test('빌드번호가 없으면 버전만', () {
      expect(formatAppVersion('1.0.4', ''), '1.0.4');
    });

    test('버전이 없으면 빈 값 — 화면이 줄을 지운다', () {
      expect(formatAppVersion('', '32'), '');
    });
  });

  group('마이 화면', () {
    testWidgets('메뉴 아래에 앱 버전을 적는다', (tester) async {
      await tester.pumpWidget(wrap(version: () async => '1.0.4 (32)'));
      await tester.pumpAndSettle();

      expect(find.text('v1.0.4 (32)'), findsOneWidget);
      // 메뉴 행보다 아래에 온다
      final menu = tester.getBottomLeft(find.text('회원탈퇴'));
      final version = tester.getTopLeft(find.text('v1.0.4 (32)'));
      expect(version.dy, greaterThan(menu.dy));
    });

    testWidgets('못 읽으면 줄을 지운다 — 빈 "v"를 남기지 않는다', (tester) async {
      await tester.pumpWidget(wrap(version: () async => ''));
      await tester.pumpAndSettle();

      expect(find.textContaining('v'), findsNothing);
    });
  });
}
