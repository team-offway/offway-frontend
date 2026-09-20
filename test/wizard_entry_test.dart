import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:offway/core/router/app_router.dart';
import 'package:offway/features/course_wizard/application/course_wizard_provider.dart';
import 'package:offway/features/course_wizard/domain/origin_hub.dart';
import 'package:offway/features/course_wizard/presentation/wizard_entry.dart';

/// '코스 추천받기'로 들어갈 때마다 처음부터다.
///
/// 위저드 상태는 앱이 살아 있는 동안 남는다. 날짜·유형까지 고르다 뒤로 나와
/// 홈에서 다시 누르면 지난 선택이 그대로 있었다.
void main() {
  testWidgets('진입하면 고르다 만 값이 비고 출발지부터 시작한다', (tester) async {
    late WidgetRef capturedRef;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return TextButton(
                onPressed: () => startCourseWizard(context, ref),
                child: const Text('코스 추천받기'),
              );
            },
          ),
        ),
        GoRoute(
          path: AppRoutes.wizardOrigin,
          builder: (_, _) => const Text('출발지'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump();

    // 지난번에 날짜 경로·이동수단·밀도까지 고르다 나온 상태
    final notifier = capturedRef.read(courseWizardProvider.notifier);
    notifier
      ..selectOrigin(
        const OriginHub(
          code: 'TRAIN:NAT610226',
          name: '정선역',
          area: '강원',
          kind: 'TRAIN_STATION',
        ),
      )
      ..selectDatePath(DatePathChoice.haveDates)
      ..selectDate(DateTime(2026, 9, 12))
      ..selectTransport(TransportMode.values.first)
      ..selectDensity(ScheduleDensity.values.first);
    expect(capturedRef.read(courseWizardProvider).datePath, isNotNull);

    await tester.tap(find.text('코스 추천받기'));
    await tester.pumpAndSettle();

    final draft = capturedRef.read(courseWizardProvider);
    expect(draft.origin, isNull);
    expect(draft.datePath, isNull);
    expect(draft.startDate, isNull);
    expect(draft.transportMode, isNull);
    expect(draft.scheduleDensity, isNull);
    expect(find.text('출발지'), findsOneWidget);
  });
}
