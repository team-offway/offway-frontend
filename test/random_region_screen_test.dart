import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/course_wizard/presentation/candidates_screen.dart';
import 'package:offway/features/course_wizard/presentation/random_region_screen.dart';

/// 랜덤 지역 선택 화면 — 후보만 칩으로 놓고, 핀을 꾹 눌렀다 떼면 한 곳에 내려앉는다.
void main() {
  final candidates = <Map<String, dynamic>>[
    {'id': '1', 'name': '정선군', 'sido': '강원특별자치도', 'intro': '정선 아리랑의 고장'},
    {'id': '2', 'name': '완도군', 'sido': '전남광주통합특별시'},
    {'id': '3', 'name': '고성군', 'sido': '경상남도'},
  ];

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wizardCandidatesProvider.overrideWith((ref) async => candidates),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const RandomRegionScreen(),
        ),
      ),
    );
    // 핀이 계속 도는 화면이라 settle을 기다릴 수 없다 — 프레임을 몇 번만 민다
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('후보 지역이 접미 없는 칩으로 놓이고 툴팁이 뜬다', (tester) async {
    await pump(tester);

    expect(find.text('랜덤 지역 선택'), findsOneWidget);
    expect(find.text('정선'), findsOneWidget);
    expect(find.text('완도'), findsOneWidget);
    expect(find.text('고성'), findsOneWidget);
    expect(find.text('핀을 꾹 눌러 던져보세요'), findsOneWidget);
  });

  testWidgets('톡 치면 아무 일도 없다 — 툴팁이 그대로다', (tester) async {
    await pump(tester);

    await tester.tap(find.bySemanticsLabel('핀. 꾹 눌렀다 떼면 지역을 랜덤으로 고릅니다'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('핀을 꾹 눌러 던져보세요'), findsOneWidget);
    expect(find.textContaining('다녀오'), findsNothing);
  });

  testWidgets('꾹 눌렀다 떼면 날아가 한 곳에 내려앉고 결과 모달이 뜬다', (tester) async {
    await pump(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel('핀. 꾹 눌렀다 떼면 지역을 랜덤으로 고릅니다')),
    );
    await tester.pump(const Duration(milliseconds: 400));
    // 조준 중에는 툴팁이 사라진다
    expect(find.text('핀을 꾹 눌러 던져보세요'), findsNothing);
    await gesture.up();

    // 비행 약 5초(±0.5) + 줌인 2초. 프레임 밖에서 시작한 애니메이션은 첫
    // 프레임에서 시각을 잡으므로, 시작 프레임을 한 번 밀고 나서 시간을 보낸다
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 6200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pump();

    expect(find.text('이번 여행지는'), findsOneWidget);
    // '정선으로'·'완도로' — 조사가 갈리므로 공통 꼬리로 찾는다
    expect(find.textContaining('로 떠나기'), findsOneWidget);
    expect(find.text('다시 던지기'), findsOneWidget);
    expect(find.text('여행지 목록으로 돌아가기'), findsOneWidget);
  });

  testWidgets('i를 누르면 안내가 뜬다', (tester) async {
    await pump(tester);

    await tester.tap(find.bySemanticsLabel('어떤 지역이 나오는지 안내'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('어떤 지역이 나오나요?'), findsOneWidget);
  });
}
