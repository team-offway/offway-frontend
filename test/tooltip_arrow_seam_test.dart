import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/widgets/app_tooltip_bubble.dart';

/// 화살표와 말풍선이 만나는 자리에 **가는 선이 보이지 않는다**.
///
/// 말풍선 색은 반투명(88%)이다. 화살표와 말풍선을 각각 반투명으로 칠하면
/// 맞닿는 한 줄이 부분 커버리지로 남아 뒤 배경이 더 비친다 — 실기기에서
/// 화살표 밑에 가는 선으로 보였다. 바탕을 불투명으로 그린 뒤 투명도를 한 번만
/// 주고, 화살표를 반 픽셀 밀어 넣어 맞닿는 줄이 서로를 덮게 했다.
///
/// **글자는 그 레이어 밖이다** — 같이 감싸면 글자까지 흐려진다.
void main() {
  /// 툴팁을 그려 픽셀을 돌려준다
  Future<({Uint8List bytes, int width, int height})> render(
    WidgetTester tester, {
    required bool arrowAtBottom,
  }) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: AppTooltipBubble(
                text: '눌러서 자세히 보기',
                arrowAtBottom: arrowAtBottom,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    late ({Uint8List bytes, int width, int height}) shot;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      shot = (
        bytes: data!.buffer.asUint8List(),
        width: image.width,
        height: image.height,
      );
    });
    return shot;
  }

  /// 화살표가 말풍선과 만나는 **접합부 둘레**의 알파를 읽는다.
  ///
  /// [dx]는 화살표 왼쪽 끝에서의 거리 — 어깨(끝)와 가운데를 따로 본다.
  ///
  /// **세로줄 전체를 읽지 않는다** — 말풍선 안쪽까지 내려가면 글자 획(알파
  /// 255)이 섞여, 바탕이 고른지와 상관없는 값으로 실패한다
  List<int> arrowColumn(
    ({Uint8List bytes, int width, int height}) shot, {
    required int dx,
    required bool arrowAtBottom,
  }) {
    // 화살표는 오른쪽에서 8 들어온 자리에 폭 20 (논리 → 물리 ×3)
    final x = shot.width - 8 * 3 - 20 * 3 + dx;
    // 화살표가 차지하는 자리는 높이 8(물리 24). 위를 가리키면 맨 위,
    // 아래를 가리키면 맨 아래다
    final seam = arrowAtBottom ? shot.height - 24 : 24;
    return [
      for (var y = seam - 14; y < seam + 6; y++)
        shot.bytes[(y * shot.width + x) * 4 + 3],
    ];
  }

  /// 칠해진 구간이 **한 덩이**이고 그 안의 알파가 고르다.
  ///
  /// 0을 그냥 걸러내면 `[226, 0, 226]` 처럼 가운데가 뚫린 줄도 통과한다 —
  /// 그것이야말로 눈에 보이는 선이다. 앞뒤 빈 자리만 허용하고 사이는 막는다
  void expectNoSeam(List<int> column, {required String at}) {
    final first = column.indexWhere((a) => a > 0);
    final last = column.lastIndexWhere((a) => a > 0);
    expect(first, isNot(-1), reason: '$at: 화살표가 안 그려졌다');

    final body = column.sublist(first, last + 1);
    expect(
      body.where((a) => a == 0),
      isEmpty,
      reason: '$at: 칠해진 구간 가운데가 뚫렸다 ($column)',
    );
    expect(
      body.toSet(),
      hasLength(1),
      reason: '$at: 알파가 고르지 않다 — 옅은 줄이 선으로 보인다 ($body)',
    );
  }

  for (final arrowAtBottom in [false, true]) {
    final where = arrowAtBottom ? '아래를 가리킬 때' : '위를 가리킬 때';

    testWidgets('$where 어깨에 옅은 줄이 없다', (tester) async {
      // 어깨는 도형이 좌우로 뻗어 말풍선 윗변과 만나는 자리다 — 여기가
      // 가장 잘 드러난다
      final shot = await render(tester, arrowAtBottom: arrowAtBottom);
      expectNoSeam(
        arrowColumn(shot, dx: 8, arrowAtBottom: arrowAtBottom),
        at: '$where 왼쪽 어깨',
      );
      expectNoSeam(
        arrowColumn(shot, dx: 51, arrowAtBottom: arrowAtBottom),
        at: '$where 오른쪽 어깨',
      );
    });

    testWidgets('$where 가운데도 마찬가지다', (tester) async {
      final shot = await render(tester, arrowAtBottom: arrowAtBottom);
      expectNoSeam(
        arrowColumn(shot, dx: 30, arrowAtBottom: arrowAtBottom),
        at: '$where 가운데',
      );
    });
  }

  testWidgets('글자는 흐려지지 않는다 — 바탕만 반투명이다', (tester) async {
    // 바탕과 함께 감싸면 글자까지 88.6%가 된다. 시안은 흰 글씨가 또렷하다
    final shot = await render(tester, arrowAtBottom: false);

    var brightest = 0;
    var alphaThere = 0;
    for (var y = shot.height ~/ 2 - 8; y < shot.height ~/ 2 + 8; y++) {
      for (var x = 40; x < shot.width - 40; x++) {
        final i = (y * shot.width + x) * 4;
        if (shot.bytes[i] > brightest) {
          brightest = shot.bytes[i];
          alphaThere = shot.bytes[i + 3];
        }
      }
    }

    expect(alphaThere, 255, reason: '글자가 바탕과 함께 흐려졌다');
  });
}
