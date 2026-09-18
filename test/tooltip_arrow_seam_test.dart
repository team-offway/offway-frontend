import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/widgets/app_tooltip_bubble.dart';

/// 화살표와 말풍선이 만나는 자리에 **가는 선이 보이지 않는다**.
///
/// 말풍선 색은 반투명(88%)이다. 화살표와 말풍선을 각각 반투명으로 칠하면
/// 맞닿는 한 줄이 부분 커버리지로 남아 뒤 배경이 더 비친다 — 실기기에서
/// 화살표 밑에 가는 선으로 보였다. 둘을 불투명으로 그린 뒤 투명도를 한 번만
/// 주고, 화살표를 반 픽셀 밀어 넣어 맞닿는 줄이 서로를 덮게 했다.
void main() {
  /// 화살표 세로줄의 알파를 위에서 아래로 읽는다.
  ///
  /// [dx]는 화살표 왼쪽 끝에서의 거리 — 어깨(끝)와 가운데를 따로 본다
  Future<List<int>> arrowColumn(WidgetTester tester, {required int dx}) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: const AppTooltipBubble(text: '눌러서 자세히 보기'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    late List<int> column;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final w = image.width;
      final bytes = data!.buffer.asUint8List();
      // 화살표는 오른쪽에서 8 들어온 자리에 폭 20 (논리 → 물리 ×3)
      final x = w - 8 * 3 - 20 * 3 + dx;
      // 화살표 자리(높이 8 = 물리 24) 아래가 말풍선이다. 그 접합을 걸쳐 읽는다
      column = [for (var y = 18; y <= 30; y++) bytes[(y * w + x) * 4 + 3]];
    });
    return column;
  }

  /// 0(빈 자리)에서 한 번에 꽉 찬 값으로 올라가고, 그 뒤로는 그대로여야 한다.
  /// 중간에 낮은 값이 끼면 그게 눈에 보이는 가는 선이다
  void expectNoSeam(List<int> column, {required String at}) {
    final filled = column.where((a) => a > 0).toList();
    expect(filled, isNotEmpty, reason: '$at: 화살표가 안 그려졌다');
    expect(
      filled.toSet(),
      hasLength(1),
      reason: '$at: 알파가 고르지 않다 — 옅은 줄이 선으로 보인다 ($column)',
    );
  }

  testWidgets('화살표 어깨와 말풍선 사이에 옅은 줄이 없다', (tester) async {
    // 어깨는 도형이 좌우로 뻗어 말풍선 윗변과 만나는 자리다 — 여기가
    // 가장 잘 드러난다
    expectNoSeam(await arrowColumn(tester, dx: 8), at: '왼쪽 어깨');
  });

  testWidgets('화살표 가운데도 마찬가지다', (tester) async {
    expectNoSeam(await arrowColumn(tester, dx: 30), at: '가운데');
  });
}
