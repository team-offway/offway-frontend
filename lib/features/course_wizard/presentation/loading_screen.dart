import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_loading_indicator.dart';

/// O-07 · 로딩
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
      backgroundColor: AppColors.backgroundNormal,
      body: AppLoadingView(title: '조건에 맞는\n여행지를 찾고 있어요..'),
    );
  }
}
