import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offway/features/home/data/home_repository.dart';
import 'package:offway/features/home/presentation/home_screen.dart';
import 'package:offway/features/leave/presentation/my_leave_screen.dart';

void main() {
  testWidgets('내 연차 화면이 그려진다', (tester) async {
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
}
