import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/course/application/pending_trip_provider.dart';
import 'package:offway/features/home/data/home_repository.dart';
import 'package:offway/features/home/presentation/home_screen.dart';
import 'package:offway/features/leave/data/leave_usages_provider.dart';
import 'package:offway/features/leave/domain/leave_usage.dart';
import 'package:offway/features/leave/presentation/leave_usages_screen.dart';
import 'package:offway/features/leave/presentation/my_leave_screen.dart';

void main() {
  testWidgets('내 연차 화면이 그려진다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myLeaveProvider.overrideWith(
            (ref) async => MyLeave(
              totalDays: 30,
              usedDays: 7,
              remainingDays: 23,
              usages: const [],
            ),
          ),
          leaveUsagesProvider.overrideWith(
            (ref) async => [
              LeaveUsage(
                id: 1,
                usedOn: DateTime(2026, 6, 12),
                days: 1,
                reason: '개인 사유 · 코로나에 걸렸음 콜록콜ㄱ록 아이고',
              ),
              // 서버가 memo를 따로 주는 새 내역(core #323) — 위 1번은 그 전에
              // '사유 · 메모'로 합쳐 저장된 옛 내역이다. 둘 다 두 줄이어야 한다
              LeaveUsage(
                id: 2,
                usedOn: DateTime(2026, 6, 12),
                days: 1,
                reason: '개인 사유',
                memo: '청춘! 이는 듣기만 하여도 가슴이 설레는 말이다.',
              ),
              LeaveUsage(
                id: 3,
                usedOn: DateTime(2026, 6, 12),
                days: 1,
                courseId: 7,
                courseName: '정선 여행',
              ),
            ],
          ),
          // 물어볼 지난 여행은 없다 — 안 덮으면 화면이 서버를 부르고,
          // 그 요청 타이머가 테스트가 끝날 때까지 남는다
          pendingTripProvider.overrideWith((ref) async => null),
          homeSnapshotProvider.overrideWith(
            (ref) async => const HomeSnapshot(
              user: {'nickname': '예빈', 'remainingLeaveDays': 23.0},
              regions: [],
            ),
          ),
        ],
        child: const MaterialApp(home: MyLeaveScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('내 연차'), findsOneWidget);
    expect(find.text('잔여 연차일수'), findsOneWidget);
    expect(find.text('23일'), findsOneWidget);
    expect(find.text('사용 연차 등록하기'), findsOneWidget);
    expect(find.text('연차 사용 내역'), findsOneWidget);
    expect(find.text('2026.06.12(금)'), findsNWidgets(3));
    expect(find.text('정선 여행'), findsOneWidget);
    expect(find.text('-1일'), findsNWidgets(3));
    // 옛 내역(합쳐 저장)도 새 내역(memo 분리)도 사유·메모 두 줄로 갈라진다
    expect(find.text('개인 사유'), findsNWidgets(2));
    expect(find.text('코로나에 걸렸음 콜록콜ㄱ록 아이고'), findsOneWidget);
    expect(find.text('청춘! 이는 듣기만 하여도 가슴이 설레는 말이다.'), findsOneWidget);
  });

  testWidgets('내역이 많아도 네 개까지만 카드로 보인다', (tester) async {
    // 서버가 목록을 잘라 주지 않는다(개수·페이지 파라미터가 없다) — 다 쌓으면
    // 아래 '총 연차일수 수정하기'가 한참 밑으로 밀려 보이지 않는다
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myLeaveProvider.overrideWith(
            (ref) async => MyLeave(
              totalDays: 30,
              usedDays: 7,
              remainingDays: 23,
              usages: const [],
            ),
          ),
          leaveUsagesProvider.overrideWith(
            (ref) async => [
              for (var i = 0; i < 7; i++)
                LeaveUsage(
                  id: i + 1,
                  usedOn: DateTime(2026, 6, i + 1),
                  days: 1,
                  reason: '사유 $i',
                ),
            ],
          ),
          pendingTripProvider.overrideWith((ref) async => null),
          homeSnapshotProvider.overrideWith(
            (ref) async => const HomeSnapshot(
              user: {'nickname': '예빈', 'remainingLeaveDays': 23.0},
              regions: [],
            ),
          ),
        ],
        child: const MaterialApp(home: MyLeaveScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(LeaveUsageCard), findsNWidgets(4));
    // 잘린 나머지는 '더보기'가 맡는다 — 그 길이 없으면 볼 방법이 사라진다
    expect(find.text('더보기'), findsOneWidget);
    expect(find.text('사유 4'), findsNothing);
  });

  testWidgets('사용 내역 아래에 총 연차일수를 고치러 가는 자리가 있다', (tester) async {
    // 마이 탭과 함께 진입점이 둘이다 — 여기는 내역을 훑다가 총량이
    // 틀렸음을 깨닫는 맥락에서 바로 이어지는 경로다
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myLeaveProvider.overrideWith(
            (ref) async => MyLeave(
              totalDays: 30,
              usedDays: 7,
              remainingDays: 23,
              usages: const [],
            ),
          ),
          leaveUsagesProvider.overrideWith((ref) async => const <LeaveUsage>[]),
          pendingTripProvider.overrideWith((ref) async => null),
          homeSnapshotProvider.overrideWith(
            (ref) async => const HomeSnapshot(
              user: {'nickname': '예빈', 'remainingLeaveDays': 23.0},
              regions: [],
            ),
          ),
        ],
        child: const MaterialApp(home: MyLeaveScreen()),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(find.text('총 연차일수 수정하기'), 200);
    expect(find.text('연차가 새로 갱신됐나요?\n총 연차일수를 수정할 수 있어요'), findsOneWidget);
  });

  testWidgets('갓 등록한 내역에만 New 칩이 붙는다', (tester) async {
    // 시안: 등록 시점 기준 24시간. 사용일이 아니라 등록 시각(core #384)이다
    final now = DateTime.now();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myLeaveProvider.overrideWith(
            (ref) async => MyLeave(
              totalDays: 30,
              usedDays: 3,
              remainingDays: 27,
              usages: const [],
            ),
          ),
          leaveUsagesProvider.overrideWith(
            (ref) async => [
              // 방금 등록 — 사용일은 지난달이어도 New
              LeaveUsage(
                id: 3,
                usedOn: DateTime(2026, 8, 1),
                days: 1,
                reason: '방금 것',
                createdAt: now.subtract(const Duration(minutes: 10)),
              ),
              // 이틀 전 등록 — 사용일이 미래여도 New가 아니다
              LeaveUsage(
                id: 2,
                usedOn: DateTime(2027, 1, 1),
                days: 1,
                reason: '이틀 전 것',
                createdAt: now.subtract(const Duration(days: 2)),
              ),
              // 등록 시각을 모르는 옛 내역
              LeaveUsage(
                id: 1,
                usedOn: DateTime(2026, 8, 10),
                days: 1,
                reason: '옛 것',
              ),
            ],
          ),
          pendingTripProvider.overrideWith((ref) async => null),
          homeSnapshotProvider.overrideWith(
            (ref) async => const HomeSnapshot(
              user: {'nickname': '예빈', 'remainingLeaveDays': 27.0},
              regions: [],
            ),
          ),
        ],
        child: const MaterialApp(home: MyLeaveScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('New'), findsOneWidget);
    // 그 칩이 '방금 것' 카드 안에 있는지 — 다른 카드에 붙으면 판정이 틀린 것
    expect(
      find.ancestor(
        of: find.text('New'),
        matching: find.byType(LeaveUsageCard),
      ),
      findsOneWidget,
    );
    final card = tester.widget<LeaveUsageCard>(
      find.ancestor(
        of: find.text('New'),
        matching: find.byType(LeaveUsageCard),
      ),
    );
    expect(card.usage.reason, '방금 것');
  });

  testWidgets('취소 내역(음수)은 부호가 겹치지 않고 +로 보인다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myLeaveProvider.overrideWith(
            (ref) async => MyLeave(
              totalDays: 30,
              usedDays: 0,
              remainingDays: 30,
              usages: const [],
            ),
          ),
          leaveUsagesProvider.overrideWith(
            (ref) async => [
              LeaveUsage(id: 1, usedOn: DateTime(2026, 8, 10), days: 3),
              // 예전 상쇄 방식으로 쌓인 음수 행 — '-' 를 글자로 붙이면 '--3일'이 된다
              LeaveUsage(id: 2, usedOn: DateTime(2026, 8, 10), days: -3),
            ],
          ),
          // 물어볼 지난 여행은 없다 — 안 덮으면 화면이 서버를 부르고,
          // 그 요청 타이머가 테스트가 끝날 때까지 남는다
          pendingTripProvider.overrideWith((ref) async => null),
          homeSnapshotProvider.overrideWith(
            (ref) async => const HomeSnapshot(
              user: {'nickname': '예빈', 'remainingLeaveDays': 30.0},
              regions: [],
            ),
          ),
        ],
        child: const MaterialApp(home: MyLeaveScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('--3일'), findsNothing);
    expect(find.text('-3일'), findsOneWidget);
    expect(find.text('+3일'), findsOneWidget);
  });

  testWidgets('삭제 모달은 상단바 56 + 항목 76으로 시안 높이를 지킨다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          leaveUsagesProvider.overrideWith(
            (ref) async => [
              LeaveUsage(id: 1, usedOn: DateTime(2026, 8, 10), days: 2),
            ],
          ),
        ],
        child: const MaterialApp(home: LeaveUsagesScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('더 보기'));
    await tester.pumpAndSettle();

    // 항목이 76 안에서 중앙에 놓여야 원 위 여백이 시안(22)과 맞는다
    final row = find.ancestor(
      of: find.text('사용 내역 삭제'),
      matching: find.byType(SizedBox),
    );
    final heights = row
        .evaluate()
        .map((e) => (e.widget as SizedBox).height)
        .whereType<double>()
        .toList();
    expect(heights, contains(76.0));

    // 닫기는 DS 에셋이어야 한다 — Material Icons.close가 남아 있으면 안 된다
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('삭제 확인은 공통 DS 모달로 뜬다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          leaveUsagesProvider.overrideWith(
            (ref) async => [
              LeaveUsage(id: 1, usedOn: DateTime(2026, 8, 10), days: 2),
            ],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const LeaveUsagesScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('더 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('사용 내역 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byType(Checkbox).evaluate().isEmpty
          ? find.text('2026.08.10(월)')
          : find.byType(Checkbox).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '삭제하기'));
    await tester.pumpAndSettle();

    // Material AlertDialog로 되돌아가면 폭·여백이 시안과 달라진다
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('사용 내역을 삭제할까요?'), findsOneWidget);
    final card = tester.getRect(
      find
          .descendant(
            of: find.byType(Dialog),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    expect(card.width, 320);
  });

  testWidgets('삭제 모드 체크박스는 18×18이고 끈 상태는 속이 비어 있다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          leaveUsagesProvider.overrideWith(
            (ref) async => [
              LeaveUsage(id: 1, usedOn: DateTime(2026, 8, 10), days: 2),
              LeaveUsage(id: 2, usedOn: DateTime(2026, 8, 19), days: 1),
            ],
          ),
        ],
        child: const MaterialApp(home: LeaveUsagesScreen()),
      ),
    );
    await tester.pump();

    // 더 보기 → 삭제 로 삭제 모드에 들어간다
    await tester.tap(find.byTooltip('더 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('사용 내역 삭제'));
    await tester.pumpAndSettle();

    final boxes = find.byWidgetPredicate(
      (w) => w is DecoratedBox && w.decoration is BoxDecoration,
    );
    final checkBoxes = <BoxDecoration>[];
    for (final e in boxes.evaluate()) {
      final size = e.size;
      if (size != null && size.width == 18 && size.height == 18) {
        checkBoxes.add((e.widget as DecoratedBox).decoration as BoxDecoration);
      }
    }
    expect(checkBoxes, hasLength(2), reason: '카드마다 18×18 체크박스가 하나씩');
    // 아무것도 안 고른 상태 — 칠하지 않아 하늘색 카드 배경이 그대로 비친다
    for (final d in checkBoxes) {
      expect(d.color, isNull);
      expect(d.border, isNotNull);
    }
  });
}
