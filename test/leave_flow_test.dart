import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offway/core/theme/tokens/tokens.dart';
import 'package:offway/features/home/data/home_repository.dart';
import 'package:offway/features/home/presentation/home_screen.dart';
import 'package:offway/features/leave/presentation/leave_register_screen.dart';
import 'package:offway/features/leave/presentation/leave_date_picker_screen.dart';
import 'package:offway/features/leave/presentation/leave_usages_screen.dart';
import 'package:offway/features/leave/presentation/my_leave_screen.dart';

void main() {
  testWidgets('연차 등록 화면: 여행·0.5일이 기본으로 골라져 있다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeSnapshotProvider.overrideWith(
            (ref) async => const HomeSnapshot(
              user: {'nickname': '예빈', 'remainingLeaveDays': 23.0},
              regions: [],
            ),
          ),
        ],
        child: const MaterialApp(home: LeaveRegisterScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('연차 사용 등록'), findsOneWidget);
    expect(find.text('날짜를 선택해 주세요'), findsOneWidget);

    // 기본 선택 확인 — 브랜드색 글자가 골라진 칩이다
    final travel = tester.widget<Text>(find.text('여행'));
    expect(travel.style?.color, AppColors.primaryNormal);
    final half = tester.widget<Text>(find.text('0.5일'));
    expect(half.style?.color, AppColors.primaryNormal);

    // 날짜만 비어 있으므로 등록은 아직 잠겨 있다
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('직접 입력하기를 누르면 입력 칸이 열린다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeSnapshotProvider.overrideWith(
            (ref) async => const HomeSnapshot(
              user: {'nickname': '예빈', 'remainingLeaveDays': 23.0},
              regions: [],
            ),
          ),
        ],
        child: const MaterialApp(home: LeaveRegisterScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('차감 일수를 입력해주세요.'), findsNothing);

    await tester.tap(find.text('직접 입력하기'));
    await tester.pump();
    expect(find.text('차감 일수를 입력해주세요.'), findsOneWidget);

    // 0.5 단위가 아니면 오류를 알리고 등록을 막는다
    await tester.enterText(find.byType(TextField).last, '9.1');
    await tester.pump();
    expect(find.text('지원하지 않는 단위입니다.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    // 맞는 값이면 오류가 사라진다 ('일'이 붙어 보인다)
    await tester.enterText(find.byType(TextField).last, '4');
    await tester.pump();
    expect(find.text('지원하지 않는 단위입니다.'), findsNothing);
    expect(find.text('4일'), findsOneWidget);

    // 프리셋을 다시 고르면 입력 칸이 닫힌다.
    // 입력 칸이 열려 화면이 좁아졌으니 칩을 화면 안으로 올린 뒤 누른다
    await tester.ensureVisible(find.text('1일'));
    await tester.pump();
    await tester.tap(find.text('1일'), warnIfMissed: false);
    await tester.pump();
    expect(find.text('차감 일수를 입력해주세요.'), findsNothing);
  });

  testWidgets('사용 내역: 코스 건만 펼쳐진다', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LeaveUsagesScreen())),
    );
    await tester.pump();

    expect(find.text('연차 사용 내역'), findsOneWidget);
    expect(find.text('코스 자세히 보기'), findsNothing);

    await tester.tap(find.text('정선 여행'));
    await tester.pumpAndSettle();
    expect(find.text('코스 자세히 보기'), findsOneWidget);

    // 다시 누르면 접힌다
    await tester.tap(find.text('정선 여행'));
    await tester.pumpAndSettle();
    expect(find.text('코스 자세히 보기'), findsNothing);
  });

  testWidgets('연차 사용일 선택: 2박3일 상한 없이 고를 수 있다', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LeaveDatePickerScreen())),
    );
    await tester.pump();

    expect(find.text('연차 사용일 선택'), findsOneWidget);
    expect(find.text('사용한 연차 날짜를 선택해 주세요.'), findsOneWidget);
    // 여행 캘린더의 2박3일 안내 배너는 없어야 한다
    expect(find.textContaining('까지 선택할 수 있어요'), findsNothing);

    final done = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(done.onPressed, isNull, reason: '날짜를 안 골랐으면 잠겨 있어야 한다');
  });

  testWidgets('내역이 없으면 빈 상태 안내가 뜬다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          leaveUsagesProvider.overrideWith((ref) => const <LeaveUsage>[]),
        ],
        child: const MaterialApp(home: LeaveUsagesScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('연차 사용 내역이 없어요'), findsOneWidget);
    expect(find.text('사용한 연차를 등록해보세요'), findsOneWidget);
  });
}
