import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/features/policy/data/policy_repository.dart';
import 'package:offway/features/policy/presentation/policy_detail_sheet.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'support/fake_url_launcher.dart';

/// 혜택 정책의 '신청하러 가기' — 앱 안에서 여는 것을 고정한다.
///
/// 지자체 신청 페이지를 사파리로 띄우면, 혜택을 확인하다 앱 밖으로 튕겨
/// 나가 보던 정책이 무엇이었는지부터 다시 찾아야 한다. 시트 위에서 열고
/// 닫으면 그대로 돌아오게 둔다.
void main() {
  Future<FakeUrlLauncher> openSheet(
    WidgetTester tester, {
    String? applyUrl,
  }) async {
    final launcher = FakeUrlLauncher.install();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          policyDetailProvider(7).overrideWith(
            (ref) async => {
              'policyId': 7,
              'title': '숙박 할인',
              'description': '도내 등록 숙소 1박당 2만원 할인',
              'applyUrl': ?applyUrl,
              'regions': const <Map<String, dynamic>>[],
            },
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showPolicyDetailSheet(context, 7),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    return launcher;
  }

  testWidgets('신청 페이지는 앱 안 브라우저로 연다', (tester) async {
    final launcher = await openSheet(
      tester,
      applyUrl: 'https://example.gov.kr/apply',
    );

    await tester.tap(find.text('신청하러 가기'));
    await tester.pumpAndSettle();

    expect(launcher.lastUrl, 'https://example.gov.kr/apply');
    // 사파리 앱으로 이탈(externalApplication)하면 보던 정책으로 돌아올 수 없다
    expect(launcher.lastMode, PreferredLaunchMode.inAppBrowserView);
    expect(launcher.launchCount, 1);
  });

  testWidgets('신청 주소가 없으면 버튼을 두지 않는다', (tester) async {
    // 눌러도 갈 곳이 없는 버튼은 고장으로 읽힌다
    await openSheet(tester);
    expect(find.text('신청하러 가기'), findsNothing);
  });

  testWidgets('못 열면 왜 안 됐는지 알린다', (tester) async {
    final launcher = await openSheet(
      tester,
      applyUrl: 'https://example.gov.kr/apply',
    );
    launcher.succeeds = false;

    await tester.tap(find.text('신청하러 가기'));
    await tester.pumpAndSettle();

    expect(find.text('신청 페이지를 열지 못했어요'), findsOneWidget);
  });
}
