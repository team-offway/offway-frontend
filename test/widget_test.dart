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
    await tester.pump();
    // rootBundle 로드가 FakeAsync에 갇힌 채 전역 캐시에 남지 않도록 실제 비동기로 완료시킨다
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    // 홈은 네트워크 이미지 로드가 있어 pumpAndSettle 대신 유한 pump 사용
    await tester.pump();
    expect(find.text('남은 연차 일수'), findsOneWidget); // 홈 도착
  });

  testWidgets('홈에 mock 사용자·추천 여행지가 표시된다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('건너뛰기'));
    await tester.pump();
    // rootBundle 로드(실제 I/O)가 FakeAsync에서 멈추지 않도록 runAsync로 대기
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    // 네트워크 이미지 로드가 있어 pumpAndSettle 대신 유한 pump 사용
    await tester.pump();

    expect(find.text('11일'), findsOneWidget); // mock 잔여연차
    expect(find.textContaining('어디로 떠날까요?'), findsOneWidget);
    expect(find.text('이번달 추천 여행지'), findsOneWidget);
    expect(find.text('정선 · 강원'), findsOneWidget);
    expect(find.text('숙박비 30% 지원'), findsOneWidget);
  });

  testWidgets('바로 추천받기 → 날짜 갈림길에서 선택해야 다음이 활성화된다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('건너뛰기'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump(const Duration(milliseconds: 400)); // 전환 애니메이션 완료
    await tester.pump();

    await tester.tap(find.text('바로 추천받기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // 페이지 전환

    expect(find.text('여행 날짜가 있나요?'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);

    // 선택 전에는 다음 버튼 비활성
    final nextButton = find.widgetWithText(FilledButton, '다음');
    expect(tester.widget<FilledButton>(nextButton).onPressed, isNull);

    await tester.tap(find.text('아직 안 정했어요'));
    await tester.pump();
    expect(tester.widget<FilledButton>(nextButton).onPressed, isNotNull);
  });

  testWidgets('캘린더에서 2박3일 범위를 선택하면 선택 완료가 활성화된다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OffwayApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('건너뛰기'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.tap(find.text('바로 추천받기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('가고싶은 날짜가 있어요'));
    await tester.pump();
    await tester.tap(find.text('다음'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('여행 날짜 선택'), findsOneWidget);
    expect(find.text('최대 2박3일까지 선택할 수 있어요'), findsOneWidget);

    final done = find.widgetWithText(FilledButton, '선택 완료');
    expect(tester.widget<FilledButton>(done).onPressed, isNull);

    // 다음달 1일~2일 선택 (과거 날짜 회피, 첫 번째 달력의 셀은 중복 텍스트 가능성 → first)
    final nextMonth = DateTime.now().month == 12
        ? '1월'
        : '${DateTime.now().month + 1}월';
    await tester.scrollUntilVisible(
      find.textContaining(nextMonth),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
    // 다음달 헤더 아래의 1, 2일 탭
    await tester.tap(find.text('1').last);
    await tester.pump();
    await tester.tap(find.text('2').last);
    await tester.pump();

    expect(find.text('가는날'), findsOneWidget);
    expect(find.text('오는날'), findsOneWidget);
    expect(tester.widget<FilledButton>(done).onPressed, isNotNull);
  });
}
