import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens/tokens.dart';

/// 앱을 켜면 처음 보이는 화면 (O-00).
///
/// 하는 일은 잠깐 워드마크를 보여주는 것뿐이다 — 토큰 확인은 [main]이 라우터를
/// 만들기 전에 이미 끝내 놓는다. 다음 목적지도 그때 정해진 초기 경로를 그대로
/// 따른다(로그인했으면 홈, 아니면 온보딩).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.next});

  /// 이 시간이 지나면 갈 곳. [main]이 정한 초기 경로다.
  final String next;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// 워드마크가 눈에 남을 만큼만 머문다. 더 끌면 앱이 느려 보인다.
  static const _hold = Duration(milliseconds: 1200);

  /// 워드마크 중심의 세로 위치(화면 높이 대비).
  ///
  /// 시안 402x874에서 텍스트 박스가 `top: calc(50% - 84.72px)`, 높이 49다.
  /// 중심은 437 - 84.72 + 24.5 = 376.78 → 화면 높이의 43.11% 지점.
  ///
  /// 네이티브 런치스크린도 같은 값을 쓴다 — `LaunchScreen.storyboard`의 centerY
  /// 제약 multiplier. 한쪽만 바꾸면 두 화면이 어긋나 로고가 튄다.
  static const _wordmarkY = 0.4311;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_hold, _goNext);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _goNext() {
    if (!mounted) return;
    // go: 스플래시는 뒤로 돌아올 곳이 아니므로 스택에 남기지 않는다
    context.go(widget.next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      // 네이티브 런치스크린(LaunchScreen.storyboard)과 같은 자리에 그린다. iOS가
      // 먼저 띄우는 그 화면은 없앨 수 없으므로, 위치가 어긋나면 엔진이 뜨는 순간
      // 로고가 튀어 스플래시가 두 번 뜬 것처럼 보인다.
      body: Align(
        // 시안(402x874)에서 워드마크 중심이 세로 28.9% 지점.
        // Alignment.y는 -1(위)~1(아래)이므로 0.289*2-1 로 환산한다
        alignment: const Alignment(0, _wordmarkY * 2 - 1),
        // 폭만 준다. 시안의 텍스트 박스는 126x49지만 49는 행간을 포함한 높이라
        // 로고 잉크(125x38)와 비율이 다르다. 높이까지 주면 49에 맞춰 늘어나
        // 폭이 161pt가 된다 — 시안보다 1.29배 크다.
        child: SvgPicture.asset(
          'assets/icons/logo_wordmark_blue.svg',
          width: 126,
          semanticsLabel: 'Offway',
        ),
      ),
    );
  }
}
