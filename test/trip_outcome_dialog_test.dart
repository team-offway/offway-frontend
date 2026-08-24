import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/course/domain/pending_trip.dart';
import 'package:offway/features/course/presentation/widgets/trip_outcome_dialog.dart';

/// "다녀오셨나요?" 모달이 시안 정책대로 답을 내는지 고정한다.
void main() {
  final trip = PendingTrip.tryParse(const {
    'courseId': 12,
    'regionName': '정선군',
    'travelDate': '2026-07-20',
    'travelEndDate': '2026-07-22',
    'consumedLeaveDays': 3.0,
  })!;

  /// 모달을 띄우고, 나온 답을 담을 상자를 돌려준다
  Future<List<TripOutcomeAnswer>> pump(WidgetTester tester) async {
    final answers = <TripOutcomeAnswer>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async =>
                answers.add(await showTripOutcomeDialog(context, trip: trip)),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    return answers;
  }

  testWidgets('시안 문구를 그대로 보여준다', (tester) async {
    await pump(tester);

    expect(find.text('정선 여행, 다녀오셨나요?'), findsOneWidget);
    expect(find.text('7.20(월) – 7.22(수) · 2박 3일'), findsOneWidget);
    expect(find.text('다녀오셨다면 연차 3일을 차감할게요.'), findsOneWidget);
  });

  testWidgets('버튼 셋이 모두 있다', (tester) async {
    await pump(tester);

    expect(find.text('안갔어요'), findsOneWidget);
    expect(find.text('네, 다녀왔어요'), findsOneWidget);
    // '나중에 할게요'는 모달 카드 밖, 딤 위에 있다
    expect(find.text('나중에 할게요'), findsOneWidget);
  });

  testWidgets('다녀왔어요를 누르면 visited', (tester) async {
    final answers = await pump(tester);

    await tester.tap(find.text('네, 다녀왔어요'));
    await tester.pumpAndSettle();

    expect(answers, [TripOutcomeAnswer.visited]);
  });

  testWidgets('안갔어요를 누르면 notVisited', (tester) async {
    final answers = await pump(tester);

    await tester.tap(find.text('안갔어요'));
    await tester.pumpAndSettle();

    expect(answers, [TripOutcomeAnswer.notVisited]);
  });

  testWidgets('나중에 할게요를 누르면 later', (tester) async {
    final answers = await pump(tester);

    await tester.tap(find.text('나중에 할게요'));
    await tester.pumpAndSettle();

    expect(answers, [TripOutcomeAnswer.later]);
  });

  testWidgets('딤 레이어를 누르면 나중에 할게요와 같다', (tester) async {
    // 시안 노트: '딤 레이어 클릭시 (나중에 할게요 버튼과 동일하게 적용)'
    final answers = await pump(tester);

    // 모달 카드 바깥 — 화면 맨 위를 누른다
    await tester.tapAt(const Offset(200, 20));
    await tester.pumpAndSettle();

    expect(answers, [TripOutcomeAnswer.later]);
  });

  testWidgets('뒤로가기도 나중에 할게요다', (tester) async {
    // 답을 못 받은 채 닫히면 연차가 틀린 채 남는다 —
    // null이 아니라 later로 떨어져야 내일 다시 묻는다
    final answers = await pump(tester);

    final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
    await widgetsAppState.didPopRoute();
    await tester.pumpAndSettle();

    expect(answers, [TripOutcomeAnswer.later]);
  });

  testWidgets('반차가 섞인 차감도 소수로 보여준다', (tester) async {
    final halfDay = PendingTrip.tryParse(const {
      'courseId': 13,
      'regionName': '영월군',
      'travelDate': '2026-07-20',
      'travelEndDate': '2026-07-21',
      'consumedLeaveDays': 1.5,
    })!;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showTripOutcomeDialog(context, trip: halfDay),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    // '1.5일'이지 '2일'이 아니다
    expect(find.text('다녀오셨다면 연차 1.5일을 차감할게요.'), findsOneWidget);
  });

  testWidgets('차감할 연차가 없으면 차감 안내를 접는다 — 시안 1207-40034', (tester) async {
    // 주말만 다녀온 여행 — "연차 0일을 차감할게요"는 안내가 아니라 헛말이다
    final weekendTrip = PendingTrip.tryParse(const {
      'courseId': 14,
      'regionName': '정선군',
      'travelDate': '2026-07-25',
      'travelEndDate': '2026-07-26',
      'consumedLeaveDays': 0.0,
    })!;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showTripOutcomeDialog(context, trip: weekendTrip),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    // 제목·날짜·버튼은 그대로, 차감 문장만 없다
    expect(find.text('정선 여행, 다녀오셨나요?'), findsOneWidget);
    expect(find.text('7.25(토) – 7.26(일) · 1박 2일'), findsOneWidget);
    expect(find.textContaining('차감할게요'), findsNothing);
    expect(find.text('네, 다녀왔어요'), findsOneWidget);
  });
}
