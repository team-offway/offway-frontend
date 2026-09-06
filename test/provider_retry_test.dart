import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/network/api_envelope.dart';
import 'package:offway/core/network/provider_retry.dart';

/// 실패한 프로바이더를 앱이 언제 다시 부르는가 (core #475).
///
/// 공공데이터 장애 날 장소 상세가 502를 받고 2초에 14번 서버를 두드렸다 —
/// Riverpod 3의 기본 재시도(0.2초부터 10번)를 그대로 둔 탓이다.
void main() {
  ApiException server(int status) =>
      ApiException(status: status, code: 'TOUR-001', detail: '잠시 후 다시');
  final network = ApiException(
    status: 0,
    code: 'CLIENT-NETWORK',
    detail: '서버에 연결할 수 없어요',
  );

  group('providerRetry', () {
    test('서버가 답한 오류는 다시 묻지 않는다 — 곧바로 물어도 답이 같다', () {
      expect(providerRetry(0, server(502)), isNull);
      expect(providerRetry(0, server(404)), isNull);
      expect(providerRetry(0, server(400)), isNull);
    });

    test('연결이 안 된 경우는 1초부터 두 배씩 세 번까지', () {
      expect(providerRetry(0, network), const Duration(seconds: 1));
      expect(providerRetry(1, network), const Duration(seconds: 2));
      expect(providerRetry(2, network), const Duration(seconds: 4));
      expect(providerRetry(3, network), isNull);
    });

    test('프로그램 오류(Error)는 다시 물어도 같아 안 되묻는다', () {
      expect(providerRetry(0, StateError('버그')), isNull);
    });
  });

  group('ProviderScope에 걸었을 때', () {
    /// 실패하는 프로바이더를 지켜보며 몇 번 불렸는지 센다
    Future<int Function()> pump(WidgetTester tester, Object error) async {
      var calls = 0;
      final provider = FutureProvider.autoDispose<void>((ref) async {
        calls++;
        throw error;
      });
      await tester.pumpWidget(
        ProviderScope(
          retry: providerRetry,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                ref.watch(provider);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      return () => calls;
    }

    testWidgets('502는 한 번만 부른다', (tester) async {
      final calls = await pump(tester, server(502));
      await tester.pump(const Duration(seconds: 30));
      expect(calls(), 1);
    });

    testWidgets('연결 실패는 1·2·4초 뒤 세 번 더 부르고 멈춘다', (tester) async {
      final calls = await pump(tester, network);
      expect(calls(), 1);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(calls(), 2);
      await tester.pump(const Duration(milliseconds: 2100));
      expect(calls(), 3);
      await tester.pump(const Duration(milliseconds: 4100));
      expect(calls(), 4);
      await tester.pump(const Duration(seconds: 30));
      expect(calls(), 4);
    });
  });
}
