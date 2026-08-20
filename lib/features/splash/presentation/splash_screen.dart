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
      body: Center(
        // 시안 치수: 126 x 49
        child: SvgPicture.asset(
          'assets/icons/logo_wordmark_blue.svg',
          width: 126,
          height: 49,
          semanticsLabel: 'Offway',
        ),
      ),
    );
  }
}
