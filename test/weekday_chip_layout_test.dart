import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/course_wizard/presentation/period_style_screen.dart';
import 'package:offway/features/home/data/home_repository.dart';
import 'package:offway/features/home/presentation/home_screen.dart';

/// 요일 칩 한 줄 — 시안 간격(13.2)은 402pt 기준이라 좁은 기기에서 넘친다.
void main() {
  Future<void> openSheet(WidgetTester tester, double width) async {
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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

  /// 칩 중심 사이 거리 = 칩 크기(39.6) + 간격
  double centerGap(WidgetTester tester) =>
      tester.getRect(find.text('화')).center.dx -
      tester.getRect(find.text('월')).center.dx;

  // iPhone SE(375) · 12/13/14(390) · 14 Pro(393) · 시안(402) · Pro Max(430)
  for (final width in [375.0, 390.0, 393.0, 402.0, 430.0]) {
    testWidgets('폭 $width 에서 한 줄이 넘치지 않는다', (tester) async {
      await openSheet(tester, width);
      // RenderFlex 오버플로는 예외로 올라온다
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('402 이상에서는 시안 간격 13.2를 지킨다', (tester) async {
    await openSheet(tester, 402);
    expect(centerGap(tester), closeTo(39.6 + 13.2, 0.1));
  });

  testWidgets('좁은 기기에서는 칩 크기를 지키고 간격만 좁힌다', (tester) async {
    // 칩은 탭 대상이라 크기를 줄이면 누르기 어려워진다
    await openSheet(tester, 390);
    final chip = tester.getRect(
      find.ancestor(of: find.text('월'), matching: find.byType(Container)).first,
    );
    expect(chip.width, closeTo(39.6, 0.1));
    expect(centerGap(tester), lessThan(39.6 + 13.2));
  });
}
