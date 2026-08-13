import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_circular_loading.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/constants/trip_constants.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/utils/leave_format.dart';
import '../../../core/utils/widget_capture.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/place_thumbnail.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../course_wizard/presentation/calendar_screen.dart'
    show tripConsumedLeaveProvider;
import '../../home/presentation/home_screen.dart' show homeSnapshotProvider;
import '../data/course_repository.dart';
import '../data/kakao_share.dart';
import '../domain/share_link.dart';
import 'my_courses_screen.dart';
import 'widgets/course_day_tabs.dart';
import 'widgets/course_map.dart';
import 'widgets/course_share_image.dart';
import 'widgets/course_share_sheet.dart';
import 'widgets/dotted_line.dart';

/// 저장한 코스 하나 (`GET /courses/{id}`) — 카드 정보와 일정을 함께 받는다
final savedCourseDetailProvider = FutureProvider.autoDispose
    .family<
      ({Map<String, dynamic> saved, Map<String, dynamic> course})?,
      String
    >(
      (ref, savedId) =>
          ref.watch(courseRepositoryProvider).savedCourseDetail(savedId),
    );

/// 장소 운영 정보 — 여행 당일 휴무일·운영시간 안내에만 조회한다
final poiScheduleProvider = FutureProvider.autoDispose
    .family<({String? useTime, String? restDate}), String>(
      (ref, contentId) =>
          ref.watch(courseRepositoryProvider).poiSchedule(contentId),
    );

/// 내 코스에서 선택해 들어온 코스 상세.
///
/// 여행일까지 남은 날에 따라 보여주는 정보가 달라진다 — 멀면 거리만,
/// 가까우면 날씨가 붙고, 당일에는 기온까지 보여준다. 지도는 탭하면 크게
/// 펼쳐지고 ▲로 되돌린다.
class SavedCourseScreen extends ConsumerStatefulWidget {
  const SavedCourseScreen({super.key, required this.savedId});

  final String savedId;

  @override
  ConsumerState<SavedCourseScreen> createState() => _SavedCourseScreenState();
}

class _SavedCourseScreenState extends ConsumerState<SavedCourseScreen> {
  int _selectedDay = 1;

  /// 지도를 크게 펼친 상태(지도뷰)인지
  bool _mapExpanded = false;

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(savedCourseDetailProvider(widget.savedId));

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      body: SafeArea(
        child: detail.when(
          loading: () => const AppCircularLoadingView(),
          error: (e, _) => AppErrorView(
            description: e is ApiException ? e.detail : '잠시 후 다시 시도해 주세요',
            onRetry: () =>
                ref.invalidate(savedCourseDetailProvider(widget.savedId)),
          ),
          data: (data) => data == null
              ? const Center(child: Text('저장한 코스를 찾을 수 없어요'))
              : _buildBody(data.saved, data.course),
        ),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> saved, Map<String, dynamic> course) {
    final days = (course['days'] as List).cast<Map<String, dynamic>>();
    final durationDays = course['durationDays'] as int;
    final day = days.firstWhere(
      (d) => d['day'] == _selectedDay,
      orElse: () => days.first,
    );
    final places = (day['places'] as List).cast<Map<String, dynamic>>();
    final regionName = saved['regionName'] as String? ?? '';
    final start = DateTime.tryParse(saved['startDate'] as String? ?? '');
    final end = DateTime.tryParse(saved['endDate'] as String? ?? '');
    // 오늘 기준 남은 날 — 표시 밀도(날씨·기온 노출)를 이 값이 정한다
    final dDay = start == null
        ? null
        : calendarDaysBetween(DateUtils.dateOnly(DateTime.now()), start);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopBar(saved, course),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 12, bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitle(regionName, saved['durationLabel'] as String?),
                    const SizedBox(height: 8),
                    if (start == null || end == null)
                      // 날짜가 없으면 정하러 가는 링크가 날짜 자리를 대신한다
                      GestureDetector(
                        onTap: () async {
                          await context.push(
                            AppRoutes.courseSchedulePath(widget.savedId),
                          );
                          // 일정 화면에서 날짜가 바뀌었을 수 있으니 다시 불러온다
                          ref.invalidate(
                            savedCourseDetailProvider(widget.savedId),
                          );
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          '여행 일정 정하기',
                          style: AppTypography.body1NormalMedium.copyWith(
                            color: AppColors.labelAlternative,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.labelAlternative,
                          ),
                        ),
                      )
                    else
                      Text(
                        '${start.year}.${start.month}.${start.day} - ${end.month}.${end.day}',
                        style: AppTypography.body1NormalMedium.copyWith(
                          color: AppColors.labelAlternative,
                        ),
                      ),
                    if (start != null && end != null && dDay != null) ...[
                      const SizedBox(height: 16),
                      _buildBadges(start, end, dDay),
                    ],
                    const SizedBox(height: 28),
                    _buildMap(places),
                  ],
                ),
              ),
              // 시안: 썸네일과 Day 칩 사이 12
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: CourseDayTabs(
                  durationDays: durationDays,
                  selectedDay: _selectedDay,
                  onSelect: (d) => setState(() => _selectedDay = d),
                ),
              ),
              const SizedBox(height: 16),
              if (_mapExpanded)
                Center(
                  child: AppIconButton(
                    icon: Icons.keyboard_arrow_up,
                    // 가이드 아이콘 32
                    size: 32,
                    onTap: () => setState(() => _mapExpanded = false),
                    semanticLabel: '지도 접기',
                    color: AppColors.labelAlternative,
                  ),
                )
              else
                Center(
                  child: Container(
                    width: 374,
                    height: 1,
                    color: AppColors.lineNormalAlternative,
                  ),
                ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildDayHeader(day, dDay),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SavedPlaceList(
                  places: places,
                  // 당일에만 장소 운영 정보를 조회해 휴무일·운영시간을 알린다
                  showOpeningWarnings: dDay == 0,
                  onTapPlace: (place) =>
                      _showPlaceSheet(place, isToday: dDay == 0),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(Map<String, dynamic> saved, Map<String, dynamic> course) {
    return Padding(
      // 버튼이 아이콘보다 넓으므로 좌우 여백을 줄여 아이콘 위치를 맞춘다
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          AppBackButton(
            onTap: () => context.pop(),
            // 편집·공유 아이콘과 같은 위계 — 기본 검정은 혼자 진하다
            color: AppColors.labelAlternative,
          ),
          const Spacer(),
          _SvgIconButton(
            asset: 'assets/icons/ic_write.svg',
            semanticLabel: '코스 편집',
            onTap: _showEditSheet,
          ),
          _SvgIconButton(
            asset: 'assets/icons/ic_share_ios.svg',
            semanticLabel: '공유하기',
            onTap: () => CourseShareSheets.showEntry(
              context,
              dayCount: course['durationDays'] as int,
              onKakaoShare: () => _shareToKakao(saved),
              onCopyLink: () => _copyLink(saved),
              onSaveImage: (day) => _saveImage(saved, course, day),
            ),
          ),
        ],
      ),
    );
  }

  /// 카카오톡으로 코스 링크 보내기 — 링크 복사와 같은 토큰을 쓴다
  Future<void> _shareToKakao(Map<String, dynamic> saved) async {
    final shareToken = saved['shareToken'] as String?;
    if (shareToken == null || shareToken.isEmpty) {
      showAppToast(context, '링크를 만들지 못했어요. 잠시 후 다시 시도해 주세요');
      return;
    }

    final regionName = saved['regionName'] as String? ?? '여행';
    final duration = saved['durationLabel'] as String? ?? '';
    final sent = await KakaoShare.sendCourse(
      title: '$regionName 여행${duration.isEmpty ? '' : ', $duration'}',
      description: '연차로 떠나는 로컬 여행 — 코스를 확인해보세요',
      linkUrl: ShareLink.of(shareToken),
      shareToken: shareToken,
      imageUrl: saved['thumbnailUrl'] as String?,
    );
    if (!mounted || sent) return;
    showAppToast(context, '카카오톡을 열지 못했어요');
  }

  /// 공유 링크 복사.
  ///
  /// 서버가 준 토큰으로 만든 주소를 넣는다 — 받은 사람은 계정이 없어도
  /// 이 링크로 코스를 볼 수 있다. 보기 전용 웹페이지는 offway.cloud에 있다.
  Future<void> _copyLink(Map<String, dynamic> saved) async {
    final shareToken = saved['shareToken'] as String?;
    if (shareToken == null || shareToken.isEmpty) {
      showAppToast(context, '링크를 만들지 못했어요. 잠시 후 다시 시도해 주세요');
      return;
    }
    await Clipboard.setData(ClipboardData(text: ShareLink.of(shareToken)));
    if (mounted) {
      showAppToast(context, '링크를 복사했어요.', kind: AppToastKind.success);
    }
  }

  /// 이미지에 들어갈 사진들 — 캡처 전에 받아 둬야 빈 자리로 찍히지 않는다
  List<ImageProvider> _shareImages(Map<String, dynamic> course, int? day) {
    final allDays = (course['days'] as List).cast<Map<String, dynamic>>();
    final days = day == null ? allDays : allDays.where((d) => d['day'] == day);
    return [
      const AssetImage('assets/images/share_hero.png'),
      for (final d in days)
        for (final p in (d['places'] as List).cast<Map<String, dynamic>>())
          if (p['imageUrl'] case final String url when url.isNotEmpty)
            NetworkImage(url),
    ];
  }

  /// 이미지에 넣을 사용 연차 — 날짜가 없으면 계산할 수 없다
  double? _consumedLeave(Map<String, dynamic> saved) {
    final start = DateTime.tryParse(saved['startDate'] as String? ?? '');
    final end = DateTime.tryParse(saved['endDate'] as String? ?? '');
    if (start == null || end == null) return null;
    return ref.read(tripConsumedLeaveProvider((start: start, end: end))).value;
  }

  /// 일정 이미지를 만들어 사진첩에 저장한다. [day]가 null이면 전체 일정
  Future<void> _saveImage(
    Map<String, dynamic> saved,
    Map<String, dynamic> course,
    int? day,
  ) async {
    try {
      // 시안이 1080 기준이라 위젯도 그 폭으로 그린다 — 배율은 1로 두어야
      // 실제 결과가 1080이 된다
      final png = await captureWidgetPng(
        context,
        widget: CourseShareImage(
          saved: saved,
          course: course,
          day: day,
          consumedLeaveDays: _consumedLeave(saved),
        ),
        width: 1080,
        pixelRatio: 1,
        precacheImages: _shareImages(course, day),
      );
      await Gal.putImageBytes(
        png,
        name: 'offway_course_${widget.savedId}${day == null ? '' : '_day$day'}',
      );
      if (mounted) {
        showAppToast(context, '이미지를 저장했어요.', kind: AppToastKind.success);
      }
    } on GalException catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        e.type == GalExceptionType.accessDenied
            ? '설정에서 사진 접근 권한을 허용해 주세요'
            : '이미지를 저장하지 못했어요',
      );
    } catch (_) {
      if (mounted) showAppToast(context, '이미지를 저장하지 못했어요');
    }
  }

  /// `정선 여행, 2박3일` — 기간만 파란색으로 강조한다
  Widget _buildTitle(String regionName, String? durationLabel) {
    final base = AppTypography.title3Bold.copyWith(
      color: AppColors.labelNormal,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: '$regionName 여행, '),
          TextSpan(
            // 카드는 '2박 3일'로 띄지만 이 화면 디자인은 붙여 쓴다
            text: (durationLabel ?? '').replaceAll(' ', ''),
            style: base.copyWith(color: AppColors.primaryNormal),
          ),
        ],
      ),
    );
  }

  Widget _buildBadges(DateTime start, DateTime end, int dDay) {
    // 서버가 평일−공휴일로 계산 (실패 시 provider가 로컬 근사로 폴백)
    final consumed = ref
        .watch(tripConsumedLeaveProvider((start: start, end: end)))
        .value;
    return Row(
      children: [
        if (consumed != null) ...[
          _Badge(
            iconAsset: 'assets/icons/ic_clock.svg',
            label: '사용 연차 일수 ${formatLeaveDays(consumed)}일',
          ),
          const SizedBox(width: 8),
        ],
        _Badge(
          label: switch (dDay) {
            0 => 'D-DAY',
            > 0 => 'D-$dDay',
            _ => '여행완료',
          },
        ),
      ],
    );
  }

  Widget _buildMap(List<Map<String, dynamic>> places) {
    final map = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        // 가이드: 접힘 198 · 펼침 452
        height: _mapExpanded ? 452 : 198,
        child: CourseMap(places: places, dayKey: _selectedDay),
      ),
    );
    if (_mapExpanded) return map;
    // 접힌 상태는 미리보기 — 탭 한 번이 통째로 '펼치기'가 되도록 지도 조작을 막는다
    return GestureDetector(
      onTap: () => setState(() => _mapExpanded = true),
      child: AbsorbPointer(child: map),
    );
  }

  /// `여행 1일차 7.26 월` + 날씨 — 가까운 여행만 날씨가 붙고 당일엔 기온까지
  Widget _buildDayHeader(Map<String, dynamic> day, int? dDay) {
    final date = DateTime.tryParse(day['date'] as String? ?? '');
    final weather = day['weather'] as Map<String, dynamic>?;
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];

    return Row(
      children: [
        Text(
          '여행 ${day['day']}일차',
          style: AppTypography.headline2Bold.copyWith(
            color: AppColors.labelNeutral,
          ),
        ),
        if (date != null) ...[
          const SizedBox(width: 8),
          Text(
            '${date.month}.${date.day} ${weekdays[date.weekday - 1]}',
            style: AppTypography.headline2Bold.copyWith(
              color: AppColors.labelAlternative,
            ),
          ),
        ],
        // 다녀온 여행(dDay 음수)에는 날씨를 붙이지 않는다
        if (weather != null && dDay != null && dDay >= 0 && dDay <= 15) ...[
          const SizedBox(width: 8),
          _WeatherChip(
            weather: weather,
            // 당일에만 기온까지 — 멀수록 정보를 줄인다
            showTemp: dDay == 0,
          ),
        ],
      ],
    );
  }

  /// 장소를 누르면 운영 정보 시트를 띄운다
  void _showPlaceSheet(Map<String, dynamic> place, {required bool isToday}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundElevated,
      barrierColor: AppColors.materialDimmer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      // 운영시간이 긴 장소는 시트가 길어진다 — 화면의 3/4까지만 쓴다.
      // isScrollControlled가 없으면 이 상한 대신 화면의 9/16이 적용된다
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      builder: (sheetContext) => _PlaceSheet(
        place: place,
        isToday: isToday,
        onOpenDetail: () {
          Navigator.of(sheetContext).pop();
          final contentId = place['poiContentId'] as String?;
          if (contentId != null) {
            context.push(
              AppRoutes.poiDetailPath(contentId, name: place['name'] as String),
            );
          }
        },
      ),
    );
  }

  /// 편집 시트 — 여행날짜 수정 · 코스 삭제
  Future<void> _showEditSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.backgroundElevated,
      barrierColor: AppColors.materialDimmer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // 제목 바가 시트 전체 폭을 차지해야 닫기 버튼이 오른쪽 끝에 붙는다
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '편집',
                    style: AppTypography.headline2Bold.copyWith(
                      color: AppColors.labelAlternative,
                    ),
                  ),
                  Positioned(
                    right: 6,
                    child: AppIconButton(
                      icon: Icons.close,
                      onTap: () => Navigator.of(sheetContext).pop(),
                      semanticLabel: '닫기',
                      // 가이드는 제목과 같은 옅은 색 — 기본 검정은 너무 진하다
                      color: AppColors.labelAlternative,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _EditSheetRow(
              iconAsset: 'assets/icons/ic_calendar.svg',
              label: '여행날짜 수정',
              onTap: () => Navigator.of(sheetContext).pop('reschedule'),
            ),
            const SizedBox(height: 28),
            _EditSheetRow(
              iconAsset: 'assets/icons/ic_trash.svg',
              label: '코스 삭제',
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'reschedule':
        // TODO(server): 저장 코스 날짜 수정 API가 생기면 결과를 반영한다
        await context.push(AppRoutes.courseSchedulePath(widget.savedId));
        // 일정 화면에서 날짜가 바뀌었을 수 있으니 상세를 다시 불러온다
        ref.invalidate(savedCourseDetailProvider(widget.savedId));
      case 'delete':
        await _confirmDelete();
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '코스를 삭제할까요?',
          style: AppTypography.headline1Bold.copyWith(
            color: AppColors.labelNormal,
          ),
        ),
        content: Text(
          '삭제한 코스는 다시 볼 수 없어요.',
          style: AppTypography.body2NormalMedium.copyWith(
            color: AppColors.labelAlternative,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              '취소',
              style: AppTypography.body1NormalBold.copyWith(
                color: AppColors.labelNeutral,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '삭제하기',
              style: AppTypography.body1NormalBold.copyWith(
                color: AppColors.primaryNormal,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(courseRepositoryProvider).delete(widget.savedId);
      // 목록이 지워진 코스를 계속 보여주지 않도록 다시 불러오게 한다
      ref.invalidate(savedCoursesProvider);
      // 삭제하면 서버가 차감한 연차를 되돌린다 — 홈의 잔여 연차도 갱신
      ref.invalidate(homeSnapshotProvider);
      if (!mounted) return;
      showAppToast(context, '코스가 삭제됐어요.', kind: AppToastKind.success);
      context.pop();
    } on ApiException catch (e) {
      // 지워지지 않았는데 화면을 닫으면 지워진 줄 안다 — 머물러 알린다
      if (mounted) showAppToast(context, e.detail);
    }
  }
}

/// 편집 시트의 액션 한 줄 — 옅은 원 배경 아이콘 + 라벨
class _EditSheetRow extends StatelessWidget {
  const _EditSheetRow({
    required this.iconAsset,
    required this.label,
    required this.onTap,
  });

  final String iconAsset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.staticBlack.withValues(alpha: AppOpacity.o5),
                shape: BoxShape.circle,
              ),
              child: Center(
                // 시안: 배경 32 안에 아이콘 20, 61% 투명도로 옅게.
                // 에셋에 이미 투명도가 박혀 있어 불투명하게 덮은 뒤
                // 여기서 한 번만 옅게 만든다 — 안 그러면 61%가 두 번 곱해진다
                child: Opacity(
                  opacity: AppOpacity.o61,
                  child: SvgPicture.asset(
                    iconAsset,
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                      AppColors.staticBlack,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Text(
              label,
              style: AppTypography.body1NormalMedium.copyWith(
                color: AppColors.labelNeutral,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 상단 바의 SVG 아이콘 버튼 — 터치 영역 44×44
class _SvgIconButton extends StatelessWidget {
  const _SvgIconButton({
    required this.asset,
    required this.semanticLabel,
    required this.onTap,
  });

  final String asset;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(child: SvgPicture.asset(asset, width: 24, height: 24)),
        ),
      ),
    );
  }
}

/// 옅은 Primary 면 위의 정보 뱃지 (사용 연차·D-day)
class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.iconAsset});

  final String label;
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryNormal.withValues(alpha: AppOpacity.o8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconAsset case final asset?) ...[
            SvgPicture.asset(
              asset,
              width: 16,
              height: 16,
              colorFilter: const ColorFilter.mode(
                AppColors.primaryNormal,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.label2Bold.copyWith(
              color: AppColors.primaryNormal,
            ),
          ),
        ],
      ),
    );
  }
}

/// 날씨 표시 — 아이콘만, 당일엔 기온까지
class _WeatherChip extends StatelessWidget {
  const _WeatherChip({required this.weather, required this.showTemp});

  final Map<String, dynamic> weather;
  final bool showTemp;

  /// 서버 sky 값(한글) → 아이콘. 모르는 값은 맑음으로 둔다
  static const _skyIcons = {
    '맑음': 'ic_weather_sunny',
    '구름많음': 'ic_weather_cloudy_partly',
    '흐림': 'ic_weather_overcast',
    '비': 'ic_weather_rain',
    '눈': 'ic_weather_snow',
    '비눈': 'ic_weather_rain_snow',
  };

  @override
  Widget build(BuildContext context) {
    final maxTemp = weather['maxTemp'] as int?;
    final icon = _skyIcons[weather['sky'] as String?] ?? 'ic_weather_sunny';
    final withTemp = showTemp && maxTemp != null;
    return Container(
      // 시안 버튼: 좌우 14 · 상하 7 (아이콘 16 기준 높이 38).
      // 기온 없이 아이콘만 있을 때도 같은 높이를 지킨다
      padding: withTemp
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 7)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.lineNormalNeutral),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/$icon.svg',
            // 시안 Leading Icon 16 — 기온이 붙어도 같은 크기다
            width: 16,
            height: 16,
          ),
          if (withTemp) ...[
            const SizedBox(width: 4),
            Text(
              '$maxTemp°',
              style: AppTypography.label2Medium.copyWith(
                color: AppColors.labelAlternative,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 저장 코스 전용 장소 목록 — 색 번호·이동거리 칩이 붙는 타임라인.
///
/// 코스확정 화면의 목록과 달리 장소 사이 이동거리를 보여주고, 숙소는 번호
/// 색으로 구분한다.
class _SavedPlaceList extends StatelessWidget {
  const _SavedPlaceList({
    required this.places,
    required this.showOpeningWarnings,
    required this.onTapPlace,
  });

  final List<Map<String, dynamic>> places;

  /// 여행 당일에만 참 — 장소별 휴무일·운영시간 확인 문구가 붙는다
  final bool showOpeningWarnings;

  final ValueChanged<Map<String, dynamic>> onTapPlace;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 번호들을 관통하는 세로 점선 — 거리 칩이 흰 배경으로 선을 가리며 얹힌다
        const Positioned(
          left: 11.4,
          top: 12,
          bottom: 12,
          child: DottedVerticalLine(),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < places.length; i++) ...[
              if (i > 0) _buildDistanceChip(places[i]),
              _PlaceRow(
                index: i + 1,
                place: places[i],
                showOpeningWarning: showOpeningWarnings,
                onTap: () => onTapPlace(places[i]),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// 앞 장소에서의 이동거리. 서버가 안 주면(첫 장소 등) 자리 없이 넘어간다
  Widget _buildDistanceChip(Map<String, dynamic> place) {
    final meters = place['distanceFromPrevMeters'] as int?;
    if (meters == null) return const SizedBox(height: 16);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        // 가이드보다 넓어 칩이 커 보였다 — 글자에 맞춰 좁힌다
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.backgroundNormal,
          border: Border.all(color: AppColors.lineNormalNeutral),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${(meters / 1000).toStringAsFixed(1)}km',
          style: AppTypography.caption1Regular.copyWith(
            color: AppColors.labelAlternative,
          ),
        ),
      ),
    );
  }
}

class _PlaceRow extends ConsumerWidget {
  const _PlaceRow({
    required this.index,
    required this.place,
    required this.showOpeningWarning,
    required this.onTap,
  });

  final int index;
  final Map<String, dynamic> place;
  final bool showOpeningWarning;
  final VoidCallback onTap;

  /// 운영 정보(자유 텍스트)에서 당일 안내 문구를 고른다.
  ///
  /// 휴무일 텍스트에 오늘 요일이 명시돼 있으면 '휴무일', 아니면서 상시 개방이
  /// 아닌 운영시간이 있으면 '운영시간 확인'. 확신할 수 없는 표현은 조용히 넘긴다.
  static String? openingWarning({String? useTime, String? restDate}) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final today = weekdays[DateTime.now().weekday - 1];
    if (restDate != null && restDate.contains('$today요일')) return '휴무일';
    if (useTime != null && useTime.isNotEmpty && !useTime.contains('상시')) {
      return '운영시간 확인';
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = place['imageUrl'] as String?;
    final catchphrase = place['catchphrase'] as String?;
    final isStay = place['kind'] == 'STAY';
    final contentId = place['poiContentId'] as String?;
    // 당일에만 장소 운영 정보를 불러 안내 문구를 만든다 (실패하면 조용히 생략)
    final schedule = showOpeningWarning && contentId != null
        ? ref.watch(poiScheduleProvider(contentId)).value
        : null;
    final warning = schedule == null
        ? null
        : openingWarning(
            useTime: schedule.useTime,
            restDate: schedule.restDate,
          );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: _buildRow(imageUrl, catchphrase, isStay, warning),
    );
  }

  Widget _buildRow(
    String? imageUrl,
    String? catchphrase,
    bool isStay,
    String? warning,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // 숙소만 색을 달리해 하루의 마침표가 한눈에 보이게 한다
              color: isStay
                  ? AppAccentColors.backgroundPink
                  : AppColors.primaryNormal,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: AppTypography.label1NormalBold.copyWith(
                color: AppColors.staticWhite,
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place['name'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body1NormalBold.copyWith(
                    color: AppColors.labelNormal,
                  ),
                ),
                if (catchphrase != null) ...[
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      style: AppTypography.label1ReadingMedium.copyWith(
                        color: AppColors.labelNeutral,
                      ),
                      children: [
                        TextSpan(
                          text: '추천 ',
                          style: AppTypography.label1ReadingMedium.copyWith(
                            color: AppColors.primaryStrong,
                          ),
                        ),
                        TextSpan(text: catchphrase),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        (place['category'] as String?) ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label2Regular.copyWith(
                          color: AppColors.labelAlternative,
                        ),
                      ),
                    ),
                    if (warning != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        warning,
                        style: AppTypography.label2Regular.copyWith(
                          color: AppColors.statusNegative,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 17),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: PlaceThumbnail(imageUrl: imageUrl),
        ),
      ],
    );
  }
}

/// 장소 운영 정보 시트 — 이름·추천 문구와 운영시간·휴무일.
///
/// 여행 당일에는 값 대신 경고 문구가 빨간색으로 나온다
/// ("오늘은 휴무일이에요" / "오늘 운영이 끝났어요").
class _PlaceSheet extends ConsumerWidget {
  const _PlaceSheet({
    required this.place,
    required this.isToday,
    required this.onOpenDetail,
  });

  final Map<String, dynamic> place;
  final bool isToday;
  final VoidCallback onOpenDetail;

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
        padding: const EdgeInsets.fromLTRB(20, 15, 20, 40),
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
                          const SizedBox(height: 4),
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
                    'assets/icons/ic_chevron_right.svg',
                    width: 12,
                    height: 24,
                    colorFilter: const ColorFilter.mode(
                      AppColors.labelAlternative,
                      BlendMode.srcIn,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
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
