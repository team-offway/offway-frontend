import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/tokens/tokens.dart';

/// 연차 사용 내역이 하나도 없을 때 자리를 채우는 안내.
/// 내 연차의 내역 칸과 내역 전체 화면이 같은 모습을 쓴다.
class LeaveEmptyView extends StatelessWidget {
  const LeaveEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 말풍선이 영수증 위에 살짝 겹쳐 앉는다 (시안 폭 48 기준)
        SizedBox(
          width: 48,
          child: Column(
            children: [
              SvgPicture.asset(
                'assets/icons/ic_empty_message.svg',
                width: 29.04,
                height: 29.04,
              ),
              SvgPicture.asset(
                'assets/icons/ic_empty_receipt.svg',
                width: 48,
                height: 48,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '연차 사용 내역이 없어요',
          textAlign: TextAlign.center,
          style: AppTypography.heading2Bold.copyWith(
            color: AppColors.labelStrong,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '사용한 연차를 등록해보세요',
          textAlign: TextAlign.center,
          style: AppTypography.body1NormalMedium.copyWith(
            color: AppColors.labelAlternative,
          ),
        ),
      ],
    );
  }
}
