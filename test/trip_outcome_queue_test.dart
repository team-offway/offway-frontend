import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/dio_client.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/course/presentation/trip_outcome_prompt.dart';

/// 밀린 여행이 여럿일 때 **연달아 묻는다**.
///
/// 예전에는 "한 번 물었다"를 참·거짓으로만 들고 있어, 첫 답 뒤 나머지가
/// 묻혔다. 다른 메뉴를 다녀와야 다음 모달이 나왔다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<_Server> pump(WidgetTester tester) async {
    final server = _Server();
    final dio = Dio(BaseOptions(baseUrl: 'https://x'))
      ..httpClientAdapter = server;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: MaterialApp(theme: AppTheme.light, home: const _Host()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    return server;
  }

  testWidgets('답하면 다음 여행을 이어서 묻는다', (tester) async {
    await pump(tester);
    expect(find.text('정선 여행, 다녀오셨나요?'), findsOneWidget);

    await tester.tap(find.text('네, 다녀왔어요'));
    await tester.pumpAndSettle();

    // 화면을 나갔다 오지 않아도 둘째가 나온다
    expect(find.text('공주 여행, 다녀오셨나요?'), findsOneWidget);
  });

  testWidgets("'나중에 할게요'도 다음 여행으로 넘어간다", (tester) async {
    // 미룬 것은 그 여행 하나다 — 다른 여행까지 묻히면 안 된다
    await pump(tester);
    expect(find.text('정선 여행, 다녀오셨나요?'), findsOneWidget);

    await tester.tap(find.text('나중에 할게요'));
    await tester.pumpAndSettle();

    expect(find.text('공주 여행, 다녀오셨나요?'), findsOneWidget);
  });

  testWidgets('같은 여행을 두 번 묻지 않는다', (tester) async {
    // 프로바이더가 다시 읽혀도(연차 갱신 등) 방금 물은 여행은 건너뛴다
    await pump(tester);
    await tester.tap(find.text('네, 다녀왔어요'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('네, 다녀왔어요'));
    await tester.pumpAndSettle();

    // 둘 다 답했으니 남은 모달이 없다
    expect(find.textContaining('다녀오셨나요'), findsNothing);
  });
}

/// 모달을 띄우는 최소 화면 — 홈이 하는 일 중 이 흐름만 흉내 낸다
class _Host extends ConsumerStatefulWidget {
  const _Host();

  @override
  ConsumerState<_Host> createState() => _HostState();
}

class _HostState extends ConsumerState<_Host> with TripOutcomePrompt {
  @override
  Widget build(BuildContext context) {
    watchTripOutcomePrompt();
    return const Scaffold(body: Center(child: Text('홈')));
  }
}

/// 밀린 여행 둘을 들고 있다가 답한 것부터 지운다
class _Server implements HttpClientAdapter {
  final answered = <int>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    String body;
    if (options.path.contains('pending-trips')) {
      body = jsonEncode({
        'status': 200,
        'code': 'OK',
        'data': {
          'remainingDays': 10,
          'trips': [
            for (final id in [1, 2])
              if (!answered.contains(id))
                {
                  'courseId': id,
                  'regionName': id == 1 ? '정선군' : '공주시',
                  'travelDate': '2026-09-01',
                  'travelEndDate': '2026-09-02',
                  'consumedLeaveDays': 2,
                },
          ],
        },
      });
    } else if (options.path.contains('trip-outcome')) {
      answered.add(
        int.parse(
          RegExp(r'/courses/(\d+)/').firstMatch(options.path)!.group(1)!,
        ),
      );
      body = jsonEncode({
        'status': 200,
        'code': 'OK',
        'data': {'remainingDays': 8},
      });
    } else {
      body = jsonEncode({'status': 200, 'code': 'OK', 'data': {}});
    }
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
