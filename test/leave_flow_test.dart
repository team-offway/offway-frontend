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
import 'package:offway/features/leave/data/leave_usages_provider.dart';
import 'package:offway/features/leave/domain/leave_usage.dart';
import 'package:offway/features/onboarding/data/leave_repository.dart';

/// 화면 검증용 내역 — 직접 등록 2건 + 코스 차감 1건
final _sampleUsages = [
  LeaveUsage(
    id: 1,
    usedOn: DateTime(2026, 6, 12),
    days: 1,
    reason: '개인 사유 · 코로나에 걸렸음 콜록콜ㄱ록 아이고',
  ),
  LeaveUsage(
    id: 2,
    usedOn: DateTime(2026, 6, 12),
    days: 1,
    reason: '개인 사유 · 청춘! 이는 듣기만 하여도 가슴이 설레는 말이다.',
  ),
  LeaveUsage(
    id: 3,
    usedOn: DateTime(2026, 6, 12),
    days: 1,
    courseId: 7,
    courseName: '정선 여행',
  ),
];

/// 되돌리기 요청만 기록하는 대역 — 서버를 부르지 않는다
class _RecordingLeaveRepository implements LeaveRepository {
  _RecordingLeaveRepository(this.reverted);

  final List<({DateTime usedOn, double days})> reverted;

  @override
  Future<void> revertUsage(LeaveUsage usage) async =>
      reverted.add((usedOn: usage.usedOn, days: -usage.days));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('연차 등록 화면: 여행·0.25일이 기본으로 골라져 있다', (tester) async {
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
    final quarter = tester.widget<Text>(find.text('0.25일'));
    expect(quarter.style?.color, AppColors.primaryNormal);
    // 고르지 않은 칩까지 파래지면 어느 것이 골라졌는지 알 수 없다
    final half = tester.widget<Text>(find.text('0.5일'));
    expect(half.style?.color, isNot(AppColors.primaryNormal));

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
      ProviderScope(
        overrides: [
          leaveUsagesProvider.overrideWith((ref) async => _sampleUsages),
        ],
        child: const MaterialApp(home: LeaveUsagesScreen()),
      ),
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

  testWidgets('내 연차: 더보기로 들어가지 않아도 코스 건이 펼쳐진다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myLeaveProvider.overrideWith(
            (ref) async => MyLeave(
              totalDays: 15,
              usedDays: 3,
              remainingDays: 12,
              usages: _sampleUsages,
            ),
          ),
          leaveUsagesProvider.overrideWith((ref) async => _sampleUsages),
        ],
        child: const MaterialApp(home: MyLeaveScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('코스 자세히 보기'), findsNothing);

    // 카드가 접힌 화면 아래쪽에 있어 스크롤해 올려야 탭이 닿는다
    await tester.ensureVisible(find.text('정선 여행'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('정선 여행'));
    await tester.pumpAndSettle();
    expect(find.text('코스 자세히 보기'), findsOneWidget);
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
          leaveUsagesProvider.overrideWith((ref) async => const <LeaveUsage>[]),
        ],
        child: const MaterialApp(home: LeaveUsagesScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('연차 사용 내역이 없어요'), findsOneWidget);
    expect(find.text('사용한 연차를 등록해보세요'), findsOneWidget);
  });

  testWidgets('삭제 모드: 고른 것이 있어야 삭제할 수 있다', (tester) async {
    final reverted = <({DateTime usedOn, double days})>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          leaveUsagesProvider.overrideWith((ref) async => _sampleUsages),
          leaveRepositoryProvider.overrideWithValue(
            _RecordingLeaveRepository(reverted),
          ),
        ],
        child: const MaterialApp(home: LeaveUsagesScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('더 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('사용 내역 삭제'));
    await tester.pumpAndSettle();

    // 아무것도 안 골랐으면 삭제가 잠겨 있다
    final delete = find.widgetWithText(FilledButton, '삭제하기');
    expect(tester.widget<FilledButton>(delete).onPressed, isNull);

    await tester.tap(find.text('개인 사유').first);
    await tester.pump();
    expect(tester.widget<FilledButton>(delete).onPressed, isNotNull);

    // 확인 모달을 거쳐야 지워진다
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(find.text('사용 내역을 삭제할까요?'), findsOneWidget);
    expect(find.text('삭제하면 차감된 연차가 복구돼요.'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '삭제하기'));
    await tester.pump();
    await tester.pump();

    // 되돌리기 요청이 실제로 나간다 (같은 날짜에 음수를 남겨 상쇄)
    expect(reverted, hasLength(1));
    expect(reverted.first.days, -1);
    // 삭제 모드는 빠져나온다
    expect(find.widgetWithText(FilledButton, '삭제하기'), findsNothing);
  });
}
