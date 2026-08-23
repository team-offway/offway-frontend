import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/tokens/tokens.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/leave_format.dart';
import '../../domain/pending_trip.dart';

/// 모달에서 나온 답.
enum TripOutcomeAnswer {
  /// 다녀왔다 — 서버가 연차를 깎는다
  visited,

  /// 안 갔다 — 차감 없이 영구히 묻지 않는다
  notVisited,

  /// 나중에 할게요 — 오늘만 접고 내일 다시 묻는다.
  /// 딤 레이어 탭·뒤로가기도 같은 답이다(시안 노트)
  later,
}

/// "정선 여행, 다녀오셨나요?" — 여행 종료 D+1에 홈에서 묻는 모달.
///
/// [showAppConfirmDialog]를 쓰지 않는다. 이 모달은 답이 셋이고
/// **'나중에 할게요'가 모달 카드 바깥, 딤 레이어 위에 흰 밑줄 글씨로**
/// 놓인다 — 공통 모달의 2버튼 구조로는 담기지 않는 형태다.
///
/// 어떻게 닫히든 [TripOutcomeAnswer]가 나온다. 딤 탭·뒤로가기는
/// [TripOutcomeAnswer.later]다 — 시안이 '나중에 할게요와 동일'로 못박았고,
/// 답을 못 받은 채 영영 안 묻는 상태가 되면 연차가 틀린 채 남는다.
Future<TripOutcomeAnswer> showTripOutcomeDialog(
  BuildContext context, {
  required PendingTrip trip,
}) async {
  final answer = await showDialog<TripOutcomeAnswer>(
    context: context,
    barrierColor: AppColors.materialDimmer,
    builder: (dialogContext) => _TripOutcomeDialog(trip: trip),
  );
  return answer ?? TripOutcomeAnswer.later;
}

class _TripOutcomeDialog extends StatelessWidget {
  const _TripOutcomeDialog({required this.trip});

  final PendingTrip trip;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        // 시안 폭 320 고정 — 열어두면 넓은 기기에서 글줄이 늘어난다
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCard(context),
            // 시안: 카드 아래 6
            const SizedBox(height: 6),
            _buildLaterButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // 시안: 가로 28 · 위 42. 아래는 42가 아니라 17이다 —
            // Actions(y=205)가 Information(높이 230) 안으로 25 파고든다.
            // 42로 두면 모달이 시안(257)보다 25 높아진다
            padding: const EdgeInsets.fromLTRB(28, 42, 28, 17),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SvgPicture.asset(
                  'assets/icons/ic_briefcase.svg',
                  width: 48,
                  height: 48,
                ),
                // 시안: 아이콘~제목 8
                const SizedBox(height: 8),
                Text(
                  trip.title,
                  style: AppTypography.heading2Bold.copyWith(
                    color: AppColors.labelNormal,
                  ),
                ),
                // 시안: 제목~날짜 4
                const SizedBox(height: 4),
                Text(
                  tripPeriodLabel(trip.startDate, trip.endDate),
                  style: AppTypography.label1NormalMedium.copyWith(
                    color: AppColors.primaryNormal,
                  ),
                ),
                // 시안: 날짜~본문 16
                const SizedBox(height: 16),
                Text(
                  '다녀오셨다면 연차 '
                  '${formatLeaveDays(trip.consumedLeaveDays)}일을 차감할게요.',
                  style: AppTypography.body2NormalMedium.copyWith(
                    color: AppColors.labelAlternative,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            // 위 여백 없음 — 본문 블록의 아래 17이 곧 버튼과의 간격이다.
            // 우측 20 = 시안 28 − 버튼이 자체로 가진 좌우 여백 8
            padding: const EdgeInsets.fromLTRB(28, 0, 20, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _DialogAction(
                  label: '안갔어요',
                  color: AppColors.labelAlternative,
                  onTap: () =>
                      Navigator.of(context).pop(TripOutcomeAnswer.notVisited),
                ),
                // 시안 간격 24 − 양쪽 버튼 여백 8+8
                const SizedBox(width: 8),
                _DialogAction(
                  label: '네, 다녀왔어요',
                  color: AppColors.primaryNormal,
                  onTap: () =>
                      Navigator.of(context).pop(TripOutcomeAnswer.visited),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 카드 밖, 딤 레이어 위에 놓이는 흰 밑줄 글씨.
  ///
  /// 시안은 `background/normal/alternative`(#F7F7F8)를 쓴다 — 흰색이 아니라
  /// 아주 옅은 회색이고, 어두운 딤 위에서만 쓰이는 값이다.
  Widget _buildLaterButton(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(TripOutcomeAnswer.later),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // 시안 버튼 높이 28 = 글자 20 + 위아래 4. 좌우로도 6을 둬
          // 손가락이 빗나가지 않게 한다
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          child: Text(
            '나중에 할게요',
            style: AppTypography.label1NormalBold.copyWith(
              color: AppColors.backgroundNormalAlternative,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.backgroundNormalAlternative,
            ),
          ),
        ),
      ),
    );
  }
}

/// 시안의 텍스트 버튼 — 글자 폭에 맞춰 줄어든다.
///
/// 시안의 `w-[60px]`은 보이는 크기가 아니라 탭 영역이다. 폭을 60으로 박으면
/// 짧은 '안갔어요'가 부풀어 두 버튼 사이가 시안보다 벌어진다.
class _DialogAction extends StatelessWidget {
  const _DialogAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // 시안 버튼 높이 32 = 글자 24 + 위아래 4
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Text(
          label,
          maxLines: 1,
          style: AppTypography.body1NormalBold.copyWith(color: color),
        ),
      ),
    );
  }
}
