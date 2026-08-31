import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/leave/data/leave_usages_provider.dart';
import 'package:offway/features/leave/domain/leave_usage.dart';
import 'package:offway/features/leave/presentation/total_leave_screen.dart';

/// 마이 > 내 연차 관리 — 총 연차일수를 고치는 화면.
///
/// 이 화면이 고치는 것은 **기준값**이라 잘못 저장되면 잔여 연차가 통째로
/// 어긋난다. 무엇을 막고 무엇을 통과시키는지 고정한다.
void main() {
  Future<void> pump(WidgetTester tester, {double total = 25}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myLeaveProvider.overrideWith(
            (ref) async => MyLeave(
              totalDays: total,
              usedDays: 2,
              remainingDays: total - 2,
              usages: const [],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const TotalLeaveScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> startEditing(WidgetTester tester) async {
    await tester.tap(find.text('총 연차일수 수정하기'));
    await tester.pumpAndSettle();
  }

  group('잔여 연차 카드', () {
    testWidgets('잔여 일수를 보여준다', (tester) async {
      await pump(tester);
      expect(find.text('23일'), findsOneWidget);
      expect(find.text('잔여 연차'), findsOneWidget);
    });

    testWidgets('소수점은 다듬어 보여준다', (tester) async {
      // 서버가 double로 준다(반차 0.5) — 23.0일로 보이면 안 된다
      await pump(tester, total: 25.5);
      expect(find.text('23.5일'), findsOneWidget);
    });

    testWidgets('수정하기를 누르면 입력으로 바뀐다', (tester) async {
      await pump(tester);
      await startEditing(tester);

      expect(find.text('새로운 총 연차일수를 입력해주세요'), findsOneWidget);
      expect(find.text('잔여 연차'), findsNothing);
    });

    testWidgets('입력 칸은 비어서 시작한다', (tester) async {
      // 시안에 placeholder가 없다 — 예시 숫자를 남겨 두면 그게 지금 값인지
      // 그냥 예시인지 헷갈린다
      await pump(tester);
      await startEditing(tester);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, isEmpty);
      expect(field.decoration?.hintText, isNull);
    });
  });

  group('입력 검증', () {
    /// 화면에 뜬 오류 문구 — 없으면 null.
    ///
    /// 오류는 입력 칸 아래 별도 줄로 그린다(연차 사용 등록과 같은 방식)
    Future<String?> errorFor(WidgetTester tester, String input) async {
      await pump(tester);
      await startEditing(tester);
      await tester.enterText(find.byType(TextField), input);
      await tester.pumpAndSettle();
      final found = find.textContaining('지원하지 않는');
      if (found.evaluate().isNotEmpty) {
        return tester.widget<Text>(found).data;
      }
      // 다른 오류 문구도 잡는다 — 입력 칸 라벨·단위는 빼고 본다
      final texts = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .whereType<String>()
          .where(
            (t) =>
                t != '새로운 총 연차일수를 입력해주세요' &&
                t != '일' &&
                t != '내 연차 관리' &&
                t != '확인해주세요' &&
                t != '등록하기' &&
                !t.contains('재설정하면'),
          );
      return texts.isEmpty ? null : texts.first;
    }

    testWidgets('0.25 단위가 아니면 막는다', (tester) async {
      // 서버가 반반차까지 받는다 — 그보다 잘면 화면에 안 떨어지는 잔여가 생긴다
      expect(await errorFor(tester, '9.1'), '지원하지 않는 단위입니다.');
    });

    testWidgets('0 이하를 막는다', (tester) async {
      expect(await errorFor(tester, '0'), isNotNull);
    });

    testWidgets('반차는 받는다', (tester) async {
      expect(await errorFor(tester, '15.5'), isNull);
    });

    testWidgets('반반차도 받는다', (tester) async {
      expect(await errorFor(tester, '15.25'), isNull);
    });

    testWidgets('0.75는 쓰지 않는 단위라 막는다', (tester) async {
      expect(await errorFor(tester, '15.75'), '지원하지 않는 단위입니다.');
    });

    testWidgets('빈 값에는 오류를 띄우지 않는다', (tester) async {
      // 아직 아무것도 안 썼는데 빨간 글씨를 보이면 혼내는 것처럼 보인다
      expect(await errorFor(tester, ''), isNull);
    });
  });

  group('등록 버튼', () {
    Future<bool> enabled(WidgetTester tester, String input) async {
      await pump(tester);
      await startEditing(tester);
      if (input.isNotEmpty) {
        await tester.enterText(find.byType(TextField), input);
        await tester.pumpAndSettle();
      }
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('등록하기'),
          matching: find.byType(FilledButton),
        ),
      );
      return button.onPressed != null;
    }

    testWidgets('빈 값이면 잠겨 있다', (tester) async {
      expect(await enabled(tester, ''), isFalse);
    });

    testWidgets('잘못된 값이면 잠겨 있다', (tester) async {
      expect(await enabled(tester, '9.1'), isFalse);
    });

    testWidgets('성한 값이면 열린다', (tester) async {
      expect(await enabled(tester, '15'), isTrue);
    });
  });

  group('안내 문구', () {
    testWidgets('카드 화면에서는 총 연차일수를 설명한다', (tester) async {
      await pump(tester);
      expect(find.text('총 연차일수란?'), findsOneWidget);
    });

    testWidgets('수정 화면에서는 다시 계산된다고 알린다', (tester) async {
      // 사용 내역이 사라지는 줄 알고 망설이는 것을 막는다
      await pump(tester);
      await startEditing(tester);

      expect(find.text('확인해주세요'), findsOneWidget);
      expect(find.textContaining('사용 내역은 유지되지만'), findsOneWidget);
    });
  });
}
