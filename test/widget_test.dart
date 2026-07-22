import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/app/app.dart';

void main() {
  testWidgets('앱 실행 시 로그인 화면이 보인다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
    await tester.pumpAndSettle();

    expect(find.text('offway'), findsOneWidget);
    expect(find.text('연차로 떠나는 로컬 여행'), findsOneWidget);
    expect(find.text('카카오로 시작하기'), findsOneWidget);
    expect(find.text('Apple로 시작하기'), findsOneWidget);
    expect(find.text('구글 계정으로 시작하기'), findsOneWidget);
  });

  testWidgets('소셜 로그인 버튼을 누르면 잔여연차 온보딩으로 이동한다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('남은 연차를 입력해 주세요'), findsOneWidget);
  });

  testWidgets('온보딩에서 연차를 조절하고 시작하면 홈으로 이동한다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('15일'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('16일'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(find.text('15일'), findsOneWidget);

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();
    expect(find.text('Offway'), findsOneWidget); // 홈 앱바
  });
}
