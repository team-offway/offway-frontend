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
/// 모달이 돌려주는 것 — 답과, 남겼다면 그 한 줄.
///
/// [comment]는 **다녀왔을 때만** 값이 있다. 안 갔거나 비워 뒀으면 null 이다
typedef TripOutcomeResult = ({TripOutcomeAnswer answer, String? comment});

/// 어떻게 닫히든 [TripOutcomeResult]가 나온다. 딤 탭·뒤로가기는
/// [TripOutcomeAnswer.later]다 — 시안이 '나중에 할게요와 동일'로 못박았고,
/// 답을 못 받은 채 영영 안 묻는 상태가 되면 연차가 틀린 채 남는다.
Future<TripOutcomeResult> showTripOutcomeDialog(
  BuildContext context, {
  required PendingTrip trip,
}) async {
  final result = await showDialog<TripOutcomeResult>(
    context: context,
    barrierColor: AppColors.materialDimmer,
    builder: (dialogContext) => _TripOutcomeDialog(trip: trip),
  );
  return result ?? (answer: TripOutcomeAnswer.later, comment: null);
}

class _TripOutcomeDialog extends StatefulWidget {
  const _TripOutcomeDialog({required this.trip});

  final PendingTrip trip;

  @override
  State<_TripOutcomeDialog> createState() => _TripOutcomeDialogState();
}

class _TripOutcomeDialogState extends State<_TripOutcomeDialog> {
  /// 시안 실측 — 카운터가 `0/50`이다. 서버는 200자까지 받지만(core #593)
  /// 한 줄로 남기는 자리라 시안을 따른다
  static const _maxLength = 50;

  /// 입력란 테두리 — 시안 `line/normal/neutral`(`#70737C` 16%).
  /// 앱 토큰은 같은 이름인데 32%라 쓸 수 없다
  static const _borderColor = Color(0x2970737C);

  final _comment = TextEditingController();

  PendingTrip get trip => widget.trip;

  @override
  void initState() {
    super.initState();
    // 글자 수 카운터가 따라 움직인다
    _comment.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _comment
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  /// 안 갔으면 한 줄을 싣지 않는다 — 서버가 거절한다(`ITINERARY-012`).
  ///
  /// **비워 뒀으면 null 이다.** 입력창을 눌렀다 지우면 빈 문자열이 남는데,
  /// 그대로 올리면 "남겼다" 와 "비웠다" 가 같은 모양이 된다
  void _close(TripOutcomeAnswer answer) {
    final text = _comment.text.trim();
    Navigator.of(context).pop((
      answer: answer,
      comment: answer == TripOutcomeAnswer.visited && text.isNotEmpty
          ? text
          : null,
    ));
  }

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
    // 주말·공휴일만 다녀와 깎을 연차가 없는 여행은 차감 안내를 접는다 —
    // "연차 0일을 차감할게요"는 안내가 아니라 헛말이다 (시안 1207-40034 변형)
    final deductsLeave = trip.consumedLeaveDays > 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            // 시안 실측(1683:43616) — 좌우 20 · 위 24(아이콘 y).
            //
            // 아래는 **보이는 것을 기준으로 잡았다.** Figma 좌표로는 44지만
            // (입력란 끝 240 → Actions 284) 실제 시안 렌더는 41이고,
            // 여기에 버튼이 자체로 가진 세로 여백 4와 글자 줄 높이 여백이
            // 더해지므로 28을 준다 — 그래야 실측이 시안과 맞는다
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              // **가운데 정렬이다.** 시안이 아이콘·글자·날짜를 모두 가운데
              // 두고(`items-center`·`text-center`), 그 아래 입력란만 폭을 채운다
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 시안 36 — 예전 판(48)보다 작다
                SvgPicture.asset(
                  'assets/icons/ic_briefcase.svg',
                  width: 36,
                  height: 36,
                ),
                // 시안: 아이콘 끝 60 → 글자 블록 68
                const SizedBox(height: 8),
                Text(
                  trip.title,
                  textAlign: TextAlign.center,
                  style: AppTypography.heading2Bold.copyWith(
                    color: AppColors.labelNeutral,
                  ),
                ),
                if (deductsLeave) ...[
                  // 시안: 제목 끝 28 → 차감 안내 32
                  const SizedBox(height: 4),
                  Text(
                    '다녀오셨다면 연차 '
                    '${formatLeaveDays(trip.consumedLeaveDays)}일을 차감할게요.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body2NormalMedium.copyWith(
                      color: AppColors.labelAlternative,
                    ),
                  ),
                ],
                // **날짜가 맨 아래다**(시안 y=58). 차감 안내와 자리가 바뀌었다
                const SizedBox(height: 4),
                Text(
                  tripPeriodLabel(trip.startDate, trip.endDate),
                  textAlign: TextAlign.center,
                  style: AppTypography.label2Medium.copyWith(
                    color: AppColors.primaryNormal,
                  ),
                ),
                // 시안: 날짜 끝 76 → 입력란 92
                const SizedBox(height: 16),
                _buildCommentField(),
              ],
            ),
          ),
          Padding(
            // 위 여백 없음 — 본문 블록의 아래 44가 곧 버튼과의 간격이다.
            // 우측 20 = 시안 28 − 버튼이 자체로 가진 좌우 여백 8
            padding: const EdgeInsets.fromLTRB(28, 0, 20, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _DialogAction(
                  label: '안갔어요',
                  color: AppColors.labelAlternative,
                  onTap: () => _close(TripOutcomeAnswer.notVisited),
                ),
                // 시안 간격 24 − 양쪽 버튼 여백 8+8
                const SizedBox(width: 8),
                _DialogAction(
                  label: '네, 다녀왔어요',
                  color: AppColors.primaryNormal,
                  onTap: () => _close(TripOutcomeAnswer.visited),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 그 지역이 어땠는지 남기는 한 줄 (시안 1683:43632).
  ///
  /// **선택이다.** 비워 두고 답해도 되고, 서버도 없으면 없는 대로 받는다 —
  /// 모달의 본업은 연차 차감이라 평가가 그것을 막으면 안 된다(core #593).
  ///
  /// 안 갔다고 답하면 실어 보내지 않으므로, 쓰다가 '안갔어요'를 눌러도
  /// 버려질 뿐 오류가 되지 않는다
  Widget _buildCommentField() {
    final region = trip.shortRegionName;
    return Container(
      // 시안 실측(1683:43632) — 안쪽 12, 입력 영역과 카운터 사이 12,
      // 카운터 칸 24. 입력 영역은 안내 두 줄이 들어가게 잡는다
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        // **토큰을 쓰지 않는다.** 시안의 `line/normal/neutral` 은 16% 인데
        // 앱 토큰(`lineNormalNeutral`)은 32% 라 두 배 진하다. 토큰을 고치면
        // 그것을 쓰는 다른 화면들이 함께 옅어져, 이 자리만 시안 값으로 둔다
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            // 안내가 두 줄이라 그만큼 — 한 줄로 잡으면 둘째 줄이 잘린다
            height: 40,
            child: TextField(
              controller: _comment,
              maxLength: _maxLength,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: AppTypography.label1NormalMedium.copyWith(
                color: AppColors.labelNormal,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                // 기본 카운터를 끈다 — 시안은 입력란 **안쪽 아래**에 둔다
                counterText: '',
                hintText: region == null
                    ? '이번 여행은 어떠셨나요?\n좋았던 점이나 아쉬웠던 점을 남겨주세요.'
                    : '$region 여행은 어떠셨나요?\n좋았던 점이나 아쉬웠던 점을 남겨주세요.',
                hintStyle: AppTypography.label1NormalMedium.copyWith(
                  color: AppColors.labelAssistive,
                ),
              ),
            ),
          ),
          // 시안: 입력 영역(끝 32)과 카운터(44) 사이 12
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${_comment.text.characters.length}/$_maxLength',
              style: AppTypography.label2Medium.copyWith(
                color: AppColors.labelAlternative,
              ),
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
        onTap: () => _close(TripOutcomeAnswer.later),
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
