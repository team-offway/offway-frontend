import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offway/core/router/app_router.dart';
import 'package:offway/core/theme/app_theme.dart';
import 'package:offway/core/theme/tokens/tokens.dart';
import 'package:offway/core/widgets/app_loading_indicator.dart';

/// 코스를 만드는 동안의 로딩 (시안 O-07) — 지역 이름이 든 제목, 시안 크기.
void main() {
  test('코스 경로에 지역 이름을 실어 로딩 문구가 쓰게 한다', () {
    expect(
      AppRoutes.coursePath('7', desiredDays: 2, regionName: '정선군'),
      '/course/7?days=2&region=%EC%A0%95%EC%84%A0%EA%B5%B0',
    );
    // 이름이 없으면 예전 경로 그대로다
    expect(AppRoutes.coursePath('7', desiredDays: 2), '/course/7?days=2');
  });

  testWidgets('로딩 뷰는 제목 24 Bold, 부제 16 Medium 옅은 색이다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: AppLoadingView(title: '정선군 여행 코스를\n만들고 있어요..'),
        ),
      ),
    );
    await tester.pump();

    final title = tester.widget<Text>(find.text('정선군 여행 코스를\n만들고 있어요..'));
    expect(title.style?.fontSize, 24);
    expect(title.style?.fontWeight, FontWeight.w700);
    final sub = tester.widget<Text>(find.text('잠시만 기다려주세요.'));
    expect(sub.style?.fontSize, 16);
    expect(sub.style?.color, AppColors.labelAlternative);
  });
}
