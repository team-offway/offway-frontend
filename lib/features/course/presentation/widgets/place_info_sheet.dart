import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/tokens/tokens.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../data/course_repository.dart';
import 'place_content_badge.dart';

/// 장소 운영 정보 — 여행 당일 휴무일·운영시간 안내에만 조회한다
final poiScheduleProvider = FutureProvider.autoDispose
    .family<({String? useTime, String? restDate}), String>(
      (ref, contentId) =>
          ref.watch(courseRepositoryProvider).poiSchedule(contentId),
    );

/// 장소를 눌렀을 때 운영 정보 시트를 띄운다.
///
/// 코스 확정·내 코스 상세가 함께 쓴다. 두 화면이 장소 줄을 다르게 그리지만
/// 누른 뒤 보는 것은 같아야 한다 — 한쪽만 바로 상세로 넘어가면 같은 코스를
/// 담기 전후로 다르게 동작하는 꼴이 된다.
///
/// [isToday]는 **여행 당일에만** 참이다. 그때 값 대신 빨간 경고가 나온다.
/// 담기 전(코스 확정)은 여행 날짜가 없으니 거짓이다.
void showPlaceInfoSheet(
  BuildContext context, {
  required Map<String, dynamic> place,
  required bool isToday,
  required VoidCallback onOpenDetail,
}) {
  showAppBottomSheet<void>(
    context,
    // 운영시간이 긴 장소는 시트가 길어진다 — 화면의 3/4까지만 쓴다
    maxHeightRatio: 0.75,
    builder: (sheetContext) => PlaceInfoSheet(
      place: place,
      isToday: isToday,
      onOpenDetail: () {
        Navigator.of(sheetContext).pop();
        onOpenDetail();
      },
    ),
  );
}

/// 장소 운영 정보 시트 — 이름·추천 문구와 운영시간·휴무일.
///
/// 여행 당일에는 값 대신 경고 문구가 빨간색으로 나온다
/// ("오늘은 휴무일이에요" / "오늘 운영이 끝났어요").
class PlaceInfoSheet extends ConsumerWidget {
  const PlaceInfoSheet({
    super.key,
    required this.place,
    required this.isToday,
    required this.onOpenDetail,
  });

  final Map<String, dynamic> place;
  final bool isToday;
  final VoidCallback onOpenDetail;

  /// 장소 성격 뱃지를 서버 값에서 만든다.
  ///
  /// **아직 서버가 안 주는 필드다**(2026-09-13). 지금은 늘 빈 목록이고,
  /// 그래서 모달이 예전과 똑같이 보인다. 계약만 맞춰 두어 서버가 채우면
  /// 앱 배포 없이 뜬다.
  ///
  /// 값 모양은 시안 문구를 그대로 쓴다 — '반려동물 동반'·'주말에 붐빔'.
  /// 서버가 다른 말로 주면 그 말이 그대로 나온다
  static List<Widget> _contentBadges(Map<String, dynamic> place) {
    return [
      if (place['petFriendly'] == true)
        const PlaceContentBadge(
          icon: 'assets/icons/ic_pet.svg',
          text: '반려동물 동반',
        ),
      if (place['crowdNote'] case final String note when note.isNotEmpty)
        PlaceContentBadge(icon: 'assets/icons/ic_crowd.svg', text: note),
    ];
  }

  /// 운영시간 문자열 끝의 마감 시각(HH:MM)이 이미 지났는지.
  /// 18:00~02:00처럼 자정을 넘기는 표기는 확신할 수 없어 판정하지 않는다.
  static bool closingPassed(String useTime, DateTime now) {
    final matches = RegExp(r'(\d{1,2}):(\d{2})').allMatches(useTime).toList();
    if (matches.isEmpty) return false;
    int minutesOf(RegExpMatch m) =>
        int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
    final closing = minutesOf(matches.last);
    if (matches.length >= 2 && closing < minutesOf(matches.first)) {
      return false;
    }
    return now.hour * 60 + now.minute >= closing;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentId = place['poiContentId'] as String?;
    final schedule = contentId == null
        ? null
        : ref.watch(poiScheduleProvider(contentId));
    final loading = schedule?.isLoading ?? false;
    final useTime = schedule?.value?.useTime;
    final restDate = schedule?.value?.restDate;
    final now = DateTime.now();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];

    // 당일 기준 위험 상태면 값 대신 빨간 경고 문구를 보여준다
    var useValue = loading ? '—' : (useTime ?? '정보없음');
    var useEmpty = !loading && useTime == null;
    var useDanger = false;
    if (isToday && useTime != null && closingPassed(useTime, now)) {
      useValue = '오늘 운영이 끝났어요';
      useEmpty = false;
      useDanger = true;
    }
    var restValue = loading ? '—' : (restDate ?? '정보없음');
    final restEmpty = !loading && restDate == null;
    var restDanger = false;
    if (isToday &&
        restDate != null &&
        restDate.contains('${weekdays[now.weekday - 1]}요일')) {
      restValue = '오늘은 휴무일이에요';
      restDanger = true;
    }

    return SafeArea(
      // 운영시간이 여러 줄인 장소(도서관 등)는 시트를 넘긴다 — 넘칠 때만
      // 스크롤되고, 짧으면 내용만큼만 차지한다
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 35, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onOpenDetail,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place['name'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.headline1Bold.copyWith(
                            color: AppColors.labelNormal,
                          ),
                        ),
                        if (place['catchphrase'] case final String phrase) ...[
                          const SizedBox(height: 2),
                          Text(
                            phrase,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.label2Medium.copyWith(
                              color: AppColors.labelAlternative,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SvgPicture.asset(
                    'assets/icons/ic_chevron_right_16.svg',
                    width: 16,
                    height: 16,
                    colorFilter: const ColorFilter.mode(
                      AppColors.labelAlternative,
                      BlendMode.srcIn,
                    ),
                  ),
                ],
              ),
            ),
            // 장소 성격 뱃지 — 반려동물 동반·혼잡도(시안 18991:86950).
            //
            // **서버가 아직 안 준다.** 필드가 비어 있으면 줄째 사라지므로,
            // 값이 실리기 시작하면 앱을 고치지 않아도 그대로 뜬다
            if (_contentBadges(place) case final badges
                when badges.isNotEmpty) ...[
              // 시안 실측: 캐치프레이즈 아래 12
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: badges),
              // 시안 실측: 뱃지 아래 24
              const SizedBox(height: 24),
            ] else
              const SizedBox(height: 30),
            _buildInfoRow(
              // 시안은 꽉 찬 시계가 아니라 테두리형이다 —
              // 배지·기간스타일이 쓰는 ic_clock과는 다른 아이콘
              iconAsset: 'assets/icons/ic_clock_outline.svg',
              label: '운영시간',
              value: useValue,
              danger: useDanger,
              empty: useEmpty,
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              iconAsset: 'assets/icons/ic_calendar.svg',
              label: '휴무일',
              value: restValue,
              danger: restDanger,
              empty: restEmpty,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String iconAsset,
    required String label,
    required String value,
    required bool danger,
    bool empty = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 시안 에셋이 Label/Alternative(61%)를 이미 품고 있다 —
        // 여기서 또 칠하면 투명도가 겹쳐 흐려진다
        SvgPicture.asset(iconAsset, width: 24, height: 24),
        const SizedBox(width: 10),
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: AppTypography.body2NormalMedium.copyWith(
              color: AppColors.labelAlternative,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: AppTypography.body2NormalMedium.copyWith(
              // 값이 없을 때는 실제 정보와 구분되게 한 단계 옅힌다
              color: danger
                  ? AppColors.statusNegative
                  : empty
                  ? AppColors.labelAssistive
                  : AppColors.labelNeutral,
            ),
          ),
        ),
      ],
    );
  }
}
