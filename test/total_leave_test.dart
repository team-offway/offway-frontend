import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/theme/tokens/tokens.dart';
import 'package:offway/features/leave/data/leave_usages_provider.dart';
import 'package:offway/features/leave/domain/leave_usage.dart';
import 'package:offway/features/leave/presentation/total_leave_screen.dart';
import 'package:offway/features/onboarding/data/leave_repository.dart';

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

      expect(find.text('총 연차일수를 입력해주세요'), findsOneWidget);
      expect(find.text('잔여 연차'), findsNothing);
    });

    testWidgets('입력 칸은 비어 있고 지금 값을 옅게 깔아 둔다', (tester) async {
      // 무엇을 고치는 중인지 알려 주되, 값은 넣지 않는다 — 그대로 등록을
      // 누르면 아무것도 안 바뀌는데 바뀐 것처럼 보인다
      await pump(tester);
      await startEditing(tester);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, isEmpty);
      expect(field.decoration?.hintText, '23일');
    });
  });

  group('입력 검증', () {
    /// 화면에 뜬 오류 문구 — 없으면 null.
    ///
    /// 오류는 입력 칸 아래 별도 줄로 그린다(연차 사용 등록과 같은 방식).
    /// **색으로 찾는다** — 문구 목록을 나열해 걸러내면 라벨 한 글자만 바뀌어도
    /// 테스트가 깨진다. 오류만 statusNegative를 쓰므로 그것이 정확한 표식이다
    Future<String?> errorFor(WidgetTester tester, String input) async {
      await pump(tester);
      await startEditing(tester);
      await tester.enterText(find.byType(TextField), input);
      await tester.pumpAndSettle();

      final red = find
          .byType(Text)
          .evaluate()
          .map((e) => e.widget as Text)
          .where((t) => t.style?.color == AppColors.statusNegative)
          .map((t) => t.data)
          .whereType<String>();
      return red.isEmpty ? null : red.first;
    }

    testWidgets('0.25 단위가 아니면 막는다', (tester) async {
      // 서버가 반반차까지 받는다 — 그보다 잘면 화면에 안 떨어지는 잔여가 생긴다
      expect(await errorFor(tester, '9.1'), '지원하지 않는 단위입니다.');
    });

    testWidgets('0일도 받는다', (tester) async {
      // "쓸 수 있는 게 없다"도 넣을 수 있어야 한다 — 서버도 0~99를 받는다
      expect(await errorFor(tester, '0'), isNull);
    });

    testWidgets('99일을 넘으면 막는다', (tester) async {
      // 서버가 받는 상한이다 — 400으로 되돌아오기 전에 이유를 알려 준다
      expect(await errorFor(tester, '100'), isNotNull);
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

  group('저장', () {
    testWidgets('입력한 값이 잔여 연차로 그대로 남는다', (tester) async {
      // 서버가 받는 것은 총 연차이고 잔여는 거기서 사용분을 뺀 파생값이다.
      // 입력값을 그대로 보내면 이미 쓴 만큼 줄어들어, 방금 넣은 숫자와 다른
      // 값이 카드에 뜬다 — 쓴 일수를 얹어 보내야 한다
      final repo = _RecordingLeaveRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            leaveRepositoryProvider.overrideWithValue(repo),
            myLeaveProvider.overrideWith(
              (ref) async => const MyLeave(
                totalDays: 25,
                usedDays: 2,
                remainingDays: 23,
                usages: [],
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
      await tester.tap(find.text('총 연차일수 수정하기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '15');
      await tester.pumpAndSettle();
      await tester.tap(find.text('등록하기'));
      await tester.pumpAndSettle();

      // 잔여 15를 원하면 총은 15 + 이미 쓴 2 = 17이어야 한다
      expect(repo.sentTotalDays, 17);
    });
  });
}

/// 서버로 보낸 총 연차를 기록하는 대역
class _RecordingLeaveRepository implements LeaveRepository {
  double? sentTotalDays;

  @override
  Future<double> updateTotalDays(double totalDays) async {
    sentTotalDays = totalDays;
    return totalDays;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
