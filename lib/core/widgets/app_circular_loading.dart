import 'package:flutter/material.dart';

import '../theme/tokens/tokens.dart';

/// 짧은 로딩에 쓰는 원형 스피너 (DS Circular 컴포넌트).
///
/// DS 문서: "로드 시간이 적은 일반적인 상황에서 사용합니다."
/// 오래 걸리는 작업(코스 생성 등)은 브랜드 마크가 도는 [AppLoadingView]를 쓴다.
class AppCircularLoading extends StatelessWidget {
  const AppCircularLoading({super.key, this.size = 28});

  /// 시안 기본 28×28
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        // 시안 실측 — 28 기준 선 굵기 2.1
        strokeWidth: size * 2.1 / 28,
        strokeCap: StrokeCap.round,
        color: AppColors.lineSolidNormal,
      ),
    );
  }
}

/// 화면 가운데에 짧은 로딩만 띄우는 자리
class AppCircularLoadingView extends StatelessWidget {
  const AppCircularLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: AppCircularLoading());
  }
}
