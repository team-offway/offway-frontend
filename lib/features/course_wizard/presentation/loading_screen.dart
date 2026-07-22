import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';

/// O-07 · 로딩 (와이어프레임)
/// 서버 연동 전이므로 일정 시간 후 후보지역으로 자동 이동한다.
class WizardLoadingScreen extends StatefulWidget {
  const WizardLoadingScreen({super.key});

  /// mock 추천 계산 시간
  static const searchDuration = Duration(seconds: 2);

  @override
  State<WizardLoadingScreen> createState() => _WizardLoadingScreenState();
}

class _WizardLoadingScreenState extends State<WizardLoadingScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // TODO(server): 추천 API 연동 시 실제 요청 완료 시점에 이동
    _timer = Timer(WizardLoadingScreen.searchDuration, () {
      if (mounted) {
        context.pushReplacement(AppRoutes.wizardCandidates);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: CircularProgressIndicator(
                strokeWidth: 9,
                color: Color(0xFF191B1F),
                backgroundColor: Color(0xFFF2F3F6),
              ),
            ),
            SizedBox(height: 40),
            Text(
              '조건에 맞는\n여행지를 찾고 있어요..',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF171719),
                letterSpacing: -0.6,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
