import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/course_wizard/presentation/period_style_screen.dart';
import 'package:offway/features/home/data/home_repository.dart';
import 'package:offway/features/home/application/home_providers.dart';

/// 주말 포함 여행 시트의 안내 문구 — 완료가 잠긴 **이유**를 말하고, 조건을
/// 채우면 **사라진다**.
///
/// QA: 금·토처럼 이어 골라 완료가 켜졌는데도 '연속된 요일만 선택 가능해요' 가
/// 남아 있었다. 다 됐는데 안내가 남으면 아직 뭘 더 해야 하는 줄 안다.
void main() {
  const consecutive = '연속된 요일만 선택 가능해요';
  const needWeekend = '토요일이나 일요일이 하루는 포함돼야 해요';

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeSnapshotProvider.overrideWith(
            (ref) async => const HomeSnapshot(
              user: {'nickname': '영찬', 'remainingLeaveDays': 11.0},
              regions: [],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const PeriodStyleScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('주말 포함 여행'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pick(WidgetTester tester, String weekday) async {
    await tester.tap(find.text(weekday));
    await tester.pump();
  }

  testWidgets('아무것도 안 골랐을 때는 연속 안내가 보인다', (tester) async {
    await openSheet(tester);

    expect(find.text(consecutive), findsOneWidget);
    expect(find.text(needWeekend), findsNothing);
  });

  testWidgets('이어 골랐는데 주말이 없으면 주말 안내로 바뀐다', (tester) async {
    // 목·금 — 연속은 맞는데 완료가 흐린 이유가 주말이다
    await openSheet(tester);
    await pick(tester, '목');
    await pick(tester, '금');

    expect(find.text(needWeekend), findsOneWidget);
    expect(find.text(consecutive), findsNothing);
  });

  testWidgets('조건을 채우면 안내가 사라지고 버튼은 제자리다', (tester) async {
    await openSheet(tester);
    final buttonBefore = tester.getTopLeft(find.text('완료'));

    // 금·토 — 이어 골랐고 주말이 들어 완료가 켜진다
    await pick(tester, '금');
    await pick(tester, '토');

    expect(find.text(consecutive), findsNothing, reason: '다 됐는데 남으면 안 된다');
    expect(find.text(needWeekend), findsNothing);
    // 안내 자리를 비워도 한 줄 높이는 유지된다 — 버튼이 위로 튀면 손가락이
    // 누르려던 자리에서 벗어난다
    expect(tester.getTopLeft(find.text('완료')), buttonBefore);
  });
}
