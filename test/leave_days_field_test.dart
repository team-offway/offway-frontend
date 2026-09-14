import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/api_envelope.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/home/data/home_repository.dart';
import 'package:offway/features/home/presentation/home_screen.dart';
import 'package:offway/features/leave/presentation/leave_register_screen.dart';
import 'package:offway/features/onboarding/data/leave_repository.dart';

/// 연차 사용 등록의 **차감 일수 칸**.
///
/// 총 연차 화면의 입력 칸과 골격이 같아 하나로 합칠 후보다(이슈 #227 ②).
/// 합치다 흘리면 사용자가 바로 겪는 자리라, 합치기 전에 지금 동작을 못 박는다.
///
/// 갈리는 축이 셋이다 — 이 화면에만 있는 것:
/// - 단위 `일`을 **빈 칸에도** 띄운다 (총 연차는 값이 있을 때만)
/// - 제목을 위젯이 품지 않는다 (총 연차는 품는다)
/// - `edited` 에 따라 안내 문구가 두 갈래로 갈린다
class _StubRepository implements LeaveRepository {
  @override
  Future<AvailableTime> availableTime({
    required String transport,
    DateTime? startDate,
    DateTime? endDate,
    String? periodStyle,
    DateTime? baseDate,
    String? weekendBridge,
    int? leaveDays,
  }) async => throw const ApiException(
    status: 0,
    code: 'TEST',
    detail: '테스트에는 서버가 없어요',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          leaveRepositoryProvider.overrideWithValue(_StubRepository()),
          homeSnapshotProvider.overrideWith(
            (ref) async => const HomeSnapshot(
              user: {'nickname': '예빈', 'remainingLeaveDays': 23.0},
              regions: [],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const LeaveRegisterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 날짜를 골라야 차감 일수 칸이 나타난다 — 이번 달 평일 하나를 집는다
  Future<void> pickOneWeekday(WidgetTester tester) async {
    await tester.tap(find.text('날짜를 선택해 주세요'));
    await tester.pumpAndSettle();

    var target = DateTime.now();
    while (target.weekday == DateTime.saturday ||
        target.weekday == DateTime.sunday) {
      target = target.add(const Duration(days: 1));
    }
    final day = find.text('${target.day}').first;
    await tester.scrollUntilVisible(
      day,
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(day);
    await tester.pump();
    await tester.tap(day);
    await tester.pumpAndSettle();
    await tester.tap(find.text('선택 완료'));
    await tester.pumpAndSettle();
  }

  testWidgets('차감 일수 칸은 빈 칸에도 단위를 띄운다', (tester) async {
    // 총 연차 칸과 갈리는 축이다 — 그쪽은 값이 있을 때만 '일'을 붙인다
    await pump(tester);
    await pickOneWeekday(tester);

    expect(find.text('일'), findsWidgets);
  });

  testWidgets('자동 계산값이면 그렇게 알린다', (tester) async {
    await pump(tester);
    await pickOneWeekday(tester);

    expect(find.text('자동 계산된 값이에요. 다르게 썼다면 직접 수정할 수 있어요.'), findsOneWidget);
  });

  testWidgets('손대면 문구가 갈린다', (tester) async {
    await pump(tester);
    await pickOneWeekday(tester);

    await tester.enterText(find.byType(TextField).last, '2');
    await tester.pumpAndSettle();

    expect(find.text('차감 일수가 직접 입력한 값으로 수정됐어요.'), findsOneWidget);
    expect(find.text('자동 계산된 값이에요. 다르게 썼다면 직접 수정할 수 있어요.'), findsNothing);
  });

  testWidgets('값을 지우면 아무 말도 하지 않는다', (tester) async {
    // 설명할 값 자체가 없다 — 오류도 안내도 띄우지 않는다
    await pump(tester);
    await pickOneWeekday(tester);

    await tester.enterText(find.byType(TextField).last, '');
    await tester.pumpAndSettle();

    expect(find.text('차감 일수가 직접 입력한 값으로 수정됐어요.'), findsNothing);
    expect(find.text('자동 계산된 값이에요. 다르게 썼다면 직접 수정할 수 있어요.'), findsNothing);
  });
}
