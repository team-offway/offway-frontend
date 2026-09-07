import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/tokens.dart';
import '../../../policy/presentation/benefit_badge.dart';

/// '최근 인기 상승' 칩 — 서버가 `trend.rising`을 참으로 준 지역에만 붙는다.
///
/// 후보 지역 카드(시안 18860:76590)와 지역 상세(18860:76194)가 같은 칩을
/// 쓴다. 혜택 칩과 나란히 놓이는 자리라 크기 단계를 혜택 칩과 공유한다 —
/// 같은 줄에서 높이가 어긋나면 안 된다.
///
/// **눌러도 아무 일이 없다**(시안 Note). 혜택 칩은 정책 상세로 가지만 이쪽은
/// 열어 보일 상세가 없다 — 근거는 지역 상세의 마무리 안내가 답한다.
class RisingChip extends StatelessWidget {
  const RisingChip({super.key, this.size = BenefitBadgeSize.candidate});

  /// 옆에 놓이는 혜택 칩과 같은 단계
  final BenefitBadgeSize size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: size.padding,
      decoration: BoxDecoration(
        // 시안(18860:76590 Badge 2): 분홍 — Pink/95 바탕에 Pink/60 글자.
        // 혜택 칩(브랜드 파랑)과 색으로 갈린다. 예전엔 같은 파랑 계열이라
        // 둘이 붙으면 구분이 안 됐다
        // TODO(디자인시스템): 분홍의 Semantic 토큰이 생기면 교체한다
        color: AppPalette.pink95,
        borderRadius: BorderRadius.circular(size.radius),
      ),
      child: Text(
        '최근 인기 상승',
        style: size.textStyle.copyWith(color: AppPalette.pink60),
      ),
    );
  }
}
