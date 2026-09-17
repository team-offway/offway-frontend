import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/tokens/tokens.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../data/course_repository.dart';
import 'place_content_badge.dart';

/// 장소 운영 정보 — 여행 당일 휴무일·운영시간 안내에만 조회한다.
///
/// **한 번 받으면 세션 동안 들고 있는다.** 이 값을 쓰는 자리가 여행 당일
/// 코스 상세인데, 하루 6~8곳을 화면이 열릴 때마다 각각 받아 왔다. 날짜 탭을
/// 오가거나 화면을 나갔다 들어와도 그만큼 다시 나갔다(#315).
///
/// 운영시간·휴무일은 하루 사이에 바뀌는 값이 아니라 다시 물을 이유가 없다.
/// 보관하는 것도 두 문자열뿐이다 — 응답 자체는 장소 상세 전문이지만
/// `poiScheduleOf` 가 필요한 두 칸만 뽑는다.
///
/// **실패는 보관하지 않는다.** `keepAlive` 를 성공한 뒤에 걸어, 통신이 한 번
/// 실패했다고 그 장소의 안내가 세션 내내 비어 있지 않게 한다.
///
/// **코스 응답에 값이 실려 온 장소는 여기까지 오지 않는다**(#326·#330) —
/// [servedScheduleOf] 가 먼저 답한다. 이 조회는 그것이 없는 장소의 폴백이다:
/// 옛 응답, 서버가 아직 운영시간을 못 받은 장소, 그리고 숙소다.
///
/// 숙소는 서버 `OpeningHours` 가 `useTime`·`restDate` 두 값만 담아 체크인·
/// 체크아웃을 싣지 못한다 — 그 합성은 `poiScheduleOf` 가 장소 상세에서 한다
final poiScheduleProvider = FutureProvider.autoDispose
    .family<({String? useTime, String? restDate}), String>((
      ref,
      contentId,
    ) async {
      final schedule = await ref
          .watch(courseRepositoryProvider)
          .poiSchedule(contentId);
      ref.keepAlive();
      return schedule;
    });

/// 코스 응답에 **이미 실려 온** 운영 정보. 없으면 null — 그때만 장소 상세로
/// 물러난다.
///
/// **행 배지와 시트가 이 하나를 같이 쓴다.** 두 곳에 같은 판단이 따로 살면
/// 어긋난다 — 실제로 #326 이 행만 고치고 시트를 놓쳐, 같은 장소에 배지와
/// 시트가 다른 문구를 보일 수 있었다(#330).
///
/// 파싱에서 빈 문자열·공백을 이미 걸렀으므로(`scheduleText`, #329) 여기서
/// 키가 있다는 것은 **쓸 수 있는 값이 있다**는 뜻이다
({String? useTime, String? restDate})? servedScheduleOf(
  Map<String, dynamic> place,
) {
  final useTime = place['useTime'] as String?;
  final restDate = place['restDate'] as String?;
  if (useTime == null && restDate == null) return null;
  return (useTime: useTime, restDate: restDate);
}

/// 서버가 판정한 **오늘** 영업 상태 (core `OpeningStatus`).
///
/// 원문을 뜯어 오늘 여는지 가르는 일은 **서버가 소유한다** — core 주석이
/// "클라이언트마다 파싱하면 클라이언트마다 다르게 틀린다" 고 적어 두었다.
/// 실제로 앱의 요일 매칭은 이런 값에서 틀렸다(#331):
///
/// - `매주 월요일 (단, 공휴일인 경우 … 휴관)` → 공휴일 월요일에 여는데 닫혔다고 함
/// - `매월 첫째, 셋째 수요일` → 아예 못 잡음
///
/// **여행일이 오늘일 때만 실린다.** 그래서 이 값이 없으면 예전처럼 원문을
/// 본다 — 지우면 그 외 상황에서 판정이 통째로 사라진다
enum TodayOpening {
  /// 지금 영업 중 — **알릴 말은 없지만 판정은 있다.**
  ///
  /// 버리면 "판정했고 문제없음" 과 "판정 자체가 없음" 이 구분되지 않아,
  /// 원문 폴백이 돌아 서버가 읽은 예외를 앱이 도로 무시한다
  open,

  /// 오늘은 쉬는 날
  closedToday,

  /// 오늘 운영이 이미 끝남
  closedNow,

  /// 아직 여는 시각 전
  beforeOpen;

  /// 시트에 그대로 쓰는 문구 — core `OpeningStatus` 가 가진 말과 같다.
  /// 영업 중이면 알릴 것이 없다
  String? get message => switch (this) {
    open => null,
    closedToday => '오늘은 휴무일이에요',
    closedNow => '오늘 운영이 끝났어요',
    beforeOpen => '아직 문을 열기 전이에요',
  };
}

/// 코스 응답에 실려 온 영업 상태. 서버가 판정하지 못했으면 null.
///
/// `UNKNOWN` 은 서버가 아예 안 내려보낸다(`isDisplayable`) — 키가 없는 것과
/// 같고, 그때만 앱이 원문을 뜯어 짐작한다
TodayOpening? todayOpeningOf(Map<String, dynamic> place) =>
    switch (place['openingStatus']) {
      'OPEN' => TodayOpening.open,
      'CLOSED_TODAY' => TodayOpening.closedToday,
      'CLOSED_NOW' => TodayOpening.closedNow,
      'BEFORE_OPEN' => TodayOpening.beforeOpen,
      _ => null,
    };

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
  /// **둘 다 없으면 키가 아예 안 온다**(core #567·#568). 서버가 "모른다"와
  /// "아니다"를 갈라 두었다 — 반려동반이 아닌 곳과 판정할 수 없는 곳이
  /// 함께 여기 해당하므로, 없다고 '불가'로 적지 않는다.
  ///
  /// 혼잡 문구는 **서버가 준 `label`을 그대로** 쓴다. 앱이 말을 지어내지
  /// 않는다 — 기준(붐빔 80·한산 20)이 바뀌면 서버가 문구를 바꾼다
  static List<Widget> _contentBadges(Map<String, dynamic> place) {
    return [
      if (place.containsKey('petAccompany'))
        // 시안 문구 그대로 하나다. 값에는 전 구역·일부 구역 구분
        // (`wholeArea`)과 견종·유의사항이 함께 오는데, 서버는 그것을
        // **칩을 눌렀을 때 여는 내용**으로 설계했다(core #567) — 그 시안이
        // 나오면 여기서 꺼내 쓴다. 칩 문구를 앱이 지어내지 않는다
        const PlaceContentBadge(
          icon: 'assets/icons/ic_pet.svg',
          text: '반려동물 동반',
        ),
      if (place['crowd'] case final Map<String, dynamic> crowd)
        if (crowd['label'] case final String label when label.isNotEmpty)
          PlaceContentBadge(icon: 'assets/icons/ic_crowd.svg', text: label),
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
    // **코스 응답에 실려 온 값이 먼저다**(#330). 행 배지와 같은 규칙을 쓴다 —
    // 두 곳이 다른 값을 보이면 같은 장소인데 말이 갈린다
    final served = servedScheduleOf(place);
    final contentId = place['poiContentId'] as String?;
    final schedule = served != null || contentId == null
        ? null
        : ref.watch(poiScheduleProvider(contentId));
    final loading = schedule?.isLoading ?? false;
    final useTime = served?.useTime ?? schedule?.value?.useTime;
    final restDate = served?.restDate ?? schedule?.value?.restDate;
    final now = DateTime.now();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];

    // **서버가 판정했으면 그것이 먼저다**(#331). 공휴일 예외처럼 앱이 못 읽는
    // 조건까지 서버가 본다. 여행일이 오늘일 때만 실리므로, 없으면 예전처럼
    // 원문을 뜯어 짐작한다
    final status = todayOpeningOf(place);

    // 당일 기준 위험 상태면 값 대신 빨간 경고 문구를 보여준다
    var useValue = loading ? '—' : (useTime ?? '정보없음');
    var useEmpty = !loading && useTime == null;
    var useDanger = false;
    // 운영시간 칸이 받는 것 — 아직 안 열었거나 이미 닫혔거나
    final hoursMessage = switch (status) {
      TodayOpening.closedNow || TodayOpening.beforeOpen => status!.message,
      _ => null,
    };
    if (hoursMessage != null) {
      useValue = hoursMessage;
      useEmpty = false;
      useDanger = true;
    } else if (status == null &&
        isToday &&
        useTime != null &&
        closingPassed(useTime, now)) {
      useValue = '오늘 운영이 끝났어요';
      useEmpty = false;
      useDanger = true;
    }

    var restValue = loading ? '—' : (restDate ?? '정보없음');
    final restEmpty = !loading && restDate == null;
    var restDanger = false;
    if (status == TodayOpening.closedToday) {
      restValue = TodayOpening.closedToday.message!;
      restDanger = true;
    } else if (status == null &&
        isToday &&
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
                  // 시안(1545:45775)은 DS Chevron Right(Tight) 12×24다 —
                  // _16은 정사각 글리프라 같은 자리에서 더 뭉툭해 보인다.
                  //
                  // **색을 덮지 않는다.** 이 에셋에는 fill-opacity 0.61이
                  // 박혀 있어 그대로 두면 #37383C@61% 가 나오고, 시안 실측
                  // (133,133,136)과 맞는다. 여기에 labelAlternative(알파
                  // 0.61)를 srcIn으로 또 씌우면 0.37로 곱해져 흐려진다
                  SvgPicture.asset(
                    'assets/icons/ic_chevron_right.svg',
                    width: 12,
                    height: 24,
                  ),
                ],
              ),
            ),
            // 장소 성격 뱃지 — 반려동반·혼잡도(시안 18991:86950,
            // core #567·#568).
            //
            // 둘 다 없으면 줄째 사라진다 — 반려동반이 아닌 곳과 판정할 수
            // 없는 곳이 함께 여기 해당하므로, 없다고 '불가'로 적지 않는다
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
