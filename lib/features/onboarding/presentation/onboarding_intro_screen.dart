import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';

/// 온보딩 소개 (O-01). 앱이 무엇을 해주는지 두 장으로 알린다.
///
/// 마지막 장에서 '다음'을 누르면 로그인으로 넘긴다. 건너뛰기는 시안에 없다 —
/// 두 장뿐이라 넘기는 버튼이 더 번거롭다.
class OnboardingIntroScreen extends StatefulWidget {
  const OnboardingIntroScreen({super.key});

  @override
  State<OnboardingIntroScreen> createState() => _OnboardingIntroScreenState();
}

class _OnboardingIntroScreenState extends State<OnboardingIntroScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _page == _pages.length - 1;

  void _next() {
    if (_isLast) {
      context.go(AppRoutes.login);
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _previous() {
    _controller.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      body: SafeArea(
        // 하단은 액션 영역이 직접 여백을 잡는다
        bottom: false,
        child: Column(
          children: [
            // 시안: 상태바 아래 163 - 상태바 높이만큼은 SafeArea가 이미 먹었다
            const SizedBox(height: 104),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _IntroPage(page: _pages[i]),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      // 시안 Action Area: 좌우·상하 20, 버튼 사이 12
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Row(
        children: [
          // 첫 장에는 '이전'이 없다 — 시안대로 '다음'만 폭을 다 쓴다
          if (_page > 0) ...[
            Expanded(
              child: FilledButton(
                onPressed: _previous,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.fillNormal,
                  foregroundColor: AppColors.labelNeutral,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('이전', style: AppTypography.body1NormalMedium),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: FilledButton(
              onPressed: _next,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryNormal,
                foregroundColor: AppColors.staticWhite,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('다음', style: AppTypography.body1NormalBold),
            ),
          ),
        ],
      ),
    );
  }
}

/// 온보딩 한 장의 내용.
class _IntroPageData {
  const _IntroPageData({
    required this.eyebrow,
    required this.title,
    required this.asset,
  });

  /// 제목 위 하늘색 한 줄
  final String eyebrow;
  final String title;
  final String asset;
}

const _pages = <_IntroPageData>[
  _IntroPageData(
    eyebrow: '오프웨이에선',
    title: '짧은 연차도 특별한 여행이 돼요',
    asset: 'assets/images/onboarding_hero_luggage.svg',
  ),
  _IntroPageData(
    eyebrow: '내 연차에 맞는',
    title: '코스 추천과 정부 혜택까지!',
    asset: 'assets/images/onboarding_hero_signboard.svg',
  ),
];

class _IntroPage extends StatelessWidget {
  const _IntroPage({required this.page});

  final _IntroPageData page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 시안: 콘텐츠 폭 360 (402 - 좌우 21)
      padding: const EdgeInsets.symmetric(horizontal: 21),
      child: Column(
        children: [
          Text(
            page.eyebrow,
            textAlign: TextAlign.center,
            style: AppTypography.body1NormalMedium.copyWith(
              color: AppColors.primaryStrong,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: AppTypography.heading1Bold.copyWith(
              color: AppColors.labelNeutral,
            ),
          ),
          const SizedBox(height: 34),
          // 시안 치수 316.18 x 314.31. 좁은 기기에서는 폭에 맞춰 줄인다
          Flexible(
            child: SvgPicture.asset(
              page.asset,
              width: 316.18,
              height: 314.31,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
