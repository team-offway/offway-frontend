import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/api_envelope.dart';
import 'package:offway/core/network/provider_retry.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/widgets/app_circular_loading.dart';
import 'package:offway/core/widgets/async_retry.dart';
import 'package:offway/features/course/presentation/poi_detail_screen.dart';

/// 오류 화면의 '다시 시도'가 눌린 것처럼 보여야 한다 — 백엔드 피드백.
///
/// 502 화면에서 다시 시도를 눌러도 화면이 그대로라 눌린 건지, 또 실패한 건지
/// 알 수 없었다. 다시 읽는 동안은 로딩, 또 실패하면 토스트.
void main() {
  /// 실제 프로바이더로 상태를 만든다 — 오류, 오류에서 다시 읽는 중, 데이터에서
  /// 다시 읽는 중. Riverpod 내부 API 없이 화면이 보는 그대로다
  late ProviderContainer container;
  late bool fail;
  final p = FutureProvider<int>((ref) async {
    if (fail) throw '502';
    return 1;
  }, retry: (retryCount, error) => null);

  Future<AsyncValue<int>> settle() async {
    try {
      await container.read(p.future);
    } catch (_) {}
    return container.read(p);
  }

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  /// [fail]을 정한 뒤에 구독해야 첫 읽기가 그 값으로 돈다
  void subscribe() => container.listen(p, (_, _) {});

  group('whenRetryable', () {
    String render(AsyncValue<int> v) => v.whenRetryable(
      data: (_) => 'data',
      error: (_, _) => 'error',
      loading: () => 'loading',
    );

    test('오류에서 다시 읽는 동안은 로딩이다 — 눌린 게 보인다', () async {
      fail = true;
      subscribe();
      final failed = await settle();
      expect(render(failed), 'error');
      container.invalidate(p);
      final retrying = container.read(p);
      expect(retrying.isLoading && retrying.hasError, isTrue);
      expect(render(retrying), 'loading');
      expect(retrying.isRetrying, isTrue);
    });

    test('데이터가 있는 새로고침은 이전 화면을 지킨다 — 스켈레톤이 깜빡이지 않게', () async {
      fail = false;
      subscribe();
      await settle();
      container.invalidate(p);
      final refreshing = container.read(p);
      expect(refreshing.isLoading && refreshing.hasValue, isTrue);
      expect(render(refreshing), 'data');
      expect(refreshing.isRetrying, isFalse);
    });
  });

  group('isRetryFailure', () {
    test('오류 → 다시 읽는 중 → 오류 만 참이다', () async {
      fail = true;
      subscribe();
      final firstLoading = container.read(p);
      final failed = await settle();
      // 첫 실패(로딩 → 오류)는 오류 화면이 이미 말한다
      expect(isRetryFailure(firstLoading, failed), isFalse);
      container.invalidate(p);
      final retrying = container.read(p);
      final failedAgain = await settle();
      expect(isRetryFailure(retrying, failedAgain), isTrue);
      // 다시 읽어 성공했으면 알릴 것이 없다
      fail = false;
      container.invalidate(p);
      final retrying2 = container.read(p);
      expect(isRetryFailure(retrying2, await settle()), isFalse);
      expect(isRetryFailure(null, failed), isFalse);
    });
  });

  group('장소 상세에서', () {
    testWidgets('다시 시도를 누르면 로딩이 보이고, 또 실패하면 토스트가 뜬다', (tester) async {
      var calls = 0;
      final holds = <Completer<Map<String, dynamic>>>[];
      await tester.pumpWidget(
        ProviderScope(
          // 앱과 같은 규칙 — 서버가 답한 오류는 자동으로 되묻지 않는다(#232).
          // 없으면 Riverpod 기본 재시도가 502를 계속 되물어 오류 화면이 안 온다
          retry: providerRetry,
          overrides: [
            poiDetailProvider.overrideWith((ref, id) {
              calls++;
              final c = Completer<Map<String, dynamic>>();
              holds.add(c);
              return c.future;
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const PoiDetailScreen(
              contentId: '1',
              name: '관광식당',
              regionName: '안동시 · 경상북도',
            ),
          ),
        ),
      );
      await tester.pump();
      // 첫 실패 — 오류 화면, 토스트는 없다
      holds[0].completeError(
        ApiException(
          status: 502,
          code: 'TOUR-001',
          detail: '관광 정보를 불러오지 못했습니다.',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('오류가 발생했어요'), findsOneWidget);
      expect(find.text(retryFailedMessage), findsNothing);

      await tester.tap(find.text('다시 시도'));
      await tester.pump();
      // 다시 읽는 동안 — 오류 화면 대신 로딩
      expect(calls, 2);
      expect(find.byType(AppCircularLoading), findsOneWidget);
      expect(find.text('오류가 발생했어요'), findsNothing);

      holds[1].completeError(
        ApiException(
          status: 502,
          code: 'TOUR-001',
          detail: '관광 정보를 불러오지 못했습니다.',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // 또 실패 — 오류 화면으로 돌아오고 토스트가 알린다
      expect(find.text('오류가 발생했어요'), findsOneWidget);
      expect(find.text(retryFailedMessage), findsOneWidget);
    });
  });
}
