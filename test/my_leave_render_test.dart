import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
            ],
          ),
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
