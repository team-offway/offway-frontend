import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offway/features/leave/presentation/leave_register_screen.dart';
import 'package:offway/features/leave/presentation/leave_usages_screen.dart';

void main() {
  testWidgets('연차 등록 화면: 세 조건이 다 차야 등록이 열린다', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LeaveRegisterScreen())),
    );
    await tester.pump();

    expect(find.text('연차 사용 등록'), findsOneWidget);
    expect(find.text('날짜를 선택해 주세요'), findsOneWidget);
    expect(find.text('0/50'), findsOneWidget);

    final submit = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(submit.onPressed, isNull, reason: '아무것도 안 골랐으면 잠겨 있어야 한다');

    // 사유·차감 일수만 골라도 날짜가 없으면 여전히 잠긴다
    await tester.tap(find.text('여행'));
    await tester.tap(find.text('1일'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
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
}
