import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/widgets/app_loading_indicator.dart';

/// 로딩 마크의 회전 — 디자이너 `Loading.svg`의 모션을 고정한다.
///
/// ```css
/// @keyframes loading-spin {
///   0%   { animation-timing-function: ease-out; transform: rotate(-360deg); }
///   25%  { animation-timing-function: ease-out; transform: rotate(-270deg); }
///   50%  { animation-timing-function: ease-out; transform: rotate(-180deg); }
///   75%  { animation-timing-function: ease-out; transform: rotate(-90deg);  }
///   100% { transform: rotate(0deg); }
/// }
/// .spinner { animation: loading-spin 2s linear infinite; }
/// ```
void main() {
  /// 지금 그려진 회전 각도(도). 없으면 null
  double? angleOf(WidgetTester tester) {
    final finder = find.ancestor(
      of: find.byType(AppLoadingIndicator),
      matching: find.byType(Transform),
    );
    final transforms = <Transform>[
      ...tester.widgetList<Transform>(
        find.descendant(
          of: find.byType(AppLoadingIndicator),
          matching: find.byType(Transform),
        ),
      ),
      ...tester.widgetList<Transform>(finder),
    ];
    if (transforms.isEmpty) return null;

    // 회전 행렬에서 각도를 되뽑는다 (0~360)
    final m = transforms.first.transform;
    final radians = math.atan2(m.storage[1], m.storage[0]);
    final degrees = radians * 180 / math.pi;
    return degrees < 0 ? degrees + 360 : degrees;
  }

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(body: Center(child: AppLoadingIndicator())),
    ),
  );

  testWidgets('한 바퀴에 2초가 걸린다', (tester) async {
    await pump(tester);

    // 2초 뒤에는 제자리로 돌아온다
    await tester.pump(const Duration(seconds: 2));
    final full = angleOf(tester)!;
    expect(full, closeTo(0, 1), reason: '한 바퀴 뒤 제자리');

    await tester.pump(const Duration(milliseconds: 1000));
    expect(angleOf(tester)!, closeTo(180, 1), reason: '반 바퀴는 1초');
  });

  testWidgets('네 구간의 경계에서 정확히 90°씩 지난다', (tester) async {
    // 시안 keyframes: 0·25·50·75·100%가 90° 간격이다
    await pump(tester);

    // 같은 위젯이 계속 도는 중이므로 시간은 누적된다 —
    // 500ms씩 흘려보내며 경계마다 확인한다
    for (final expected in const [90.0, 180.0, 270.0]) {
      await tester.pump(const Duration(milliseconds: 500));
      expect(angleOf(tester)!, closeTo(expected, 1), reason: '$expected°');
    }
  });

  testWidgets('구간 안에서는 감속한다', (tester) async {
    // ease-out이면 구간 절반 시점에 이미 절반(45°)을 넘어서 있다.
    // 등속이라면 정확히 45°다
    await pump(tester);
    await tester.pump(const Duration(milliseconds: 250));

    final mid = angleOf(tester)!;
    expect(mid, greaterThan(45), reason: 'ease-out이면 앞이 빠르다');
    expect(mid, lessThan(90), reason: '구간을 넘지는 않는다');
  });

  testWidgets('멈추지 않고 계속 돈다', (tester) async {
    await pump(tester);

    // 여러 바퀴를 돌아도 살아 있다
    await tester.pump(const Duration(seconds: 6));
    expect(angleOf(tester), isNotNull);

    // 타이머를 남기지 않고 정리된다
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
  });
}
