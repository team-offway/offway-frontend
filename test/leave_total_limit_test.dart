import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/dio_client.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/leave/data/leave_usages_provider.dart';
import 'package:offway/features/leave/domain/leave_usage.dart';
import 'package:offway/features/leave/presentation/total_leave_screen.dart';

/// 이 화면은 **총 연차**를 고친다 — 잔여가 아니다.
///
/// 예전에는 잔여를 받아 사용분을 얹어 보냈다. 그러면 입력값이 아니라 그 합이
/// 서버 상한(99)에 걸려, 35일을 쓴 사람은 65를 넣을 수 없었다. 온보딩은
/// 총 연차를 받는데 이 화면만 잔여를 받아 같은 숫자가 다른 뜻이었다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<num>> pump(
    WidgetTester tester, {
    required double total,
    required double used,
    required String input,
  }) async {
    tester.view.physicalSize = const Size(402 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final sent = <num>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://x'))
      ..httpClientAdapter = _Stub(sent);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          myLeaveProvider.overrideWith(
            (ref) async => MyLeave(
              totalDays: total,
              usedDays: used,
              remainingDays: total - used,
              usages: const [],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const TotalLeaveScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('총 연차일수 수정하기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, input);
    await tester.pumpAndSettle();
    return sent;
  }

  bool saveEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed !=
      null;

  testWidgets('쓴 일수와 무관하게 입력값이 그대로 간다', (tester) async {
    // 사용 35일 + 입력 65 = 100 이 되어 거절되던 자리
    final sent = await pump(tester, total: 50, used: 35, input: '65');
    expect(saveEnabled(tester), isTrue);

    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(sent, [65.0], reason: '사용분을 얹지 않는다');
  });

  testWidgets('많이 쓴 사람도 99일까지 넣는다', (tester) async {
    final sent = await pump(tester, total: 50, used: 40, input: '99');
    expect(saveEnabled(tester), isTrue);

    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(sent, [99.0]);
  });

  testWidgets('100은 막는다 — 서버 상한과 같은 말을 한다', (tester) async {
    await pump(tester, total: 50, used: 0, input: '100');

    expect(find.text('99일까지 넣을 수 있어요.'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('입력칸 힌트는 지금 총 연차다', (tester) async {
    // 무엇을 고치는 중인지 알려 준다 — 잔여를 깔면 다른 값을 넣게 된다
    await pump(tester, total: 50, used: 35, input: '');

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.decoration?.hintText, '50일');
  });
}

class _Stub implements HttpClientAdapter {
  _Stub(this.sent);

  final List<num> sent;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'PATCH' && options.data is Map) {
      sent.add((options.data as Map)['totalDays'] as num);
    }
    return ResponseBody.fromString(
      jsonEncode({
        'status': 200,
        'code': 'OK',
        'data': {'remainingDays': 30},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
