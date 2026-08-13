import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/trip_constants.dart';
import '../../../core/location/origin_locator.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_toast.dart';
import '../../course_wizard/application/available_time_provider.dart';
import '../../course_wizard/application/course_wizard_provider.dart';
import '../data/course_repository.dart';
import '../data/kakao_share.dart';
import '../domain/share_link.dart';
import 'widgets/course_day_tabs.dart';
import 'widgets/course_map.dart';
import 'widgets/course_place_list.dart';
import 'widgets/course_share_sheet.dart';

/// 위저드 조건(밀도·이동수단·기간)과 현재 위치로 코스를 생성한다.
///
/// 여행 날짜·일수는 가용시간 계산(서버, 공휴일 반영)이 확정한 값을 쓰고,
/// 계산에 실패했을 때만 로컬 추정으로 폴백한다.
final courseProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, ({String regionId, int desiredDays})>((
      ref,
      query,
    ) async {
      final draft = ref.read(courseWizardProvider);
      final availableTime = await ref.watch(availableTimeProvider.future);
      final origin = await ref.read(originLocatorProvider).resolve();
      return ref
          .read(courseRepositoryProvider)
          .generate(
            regionId: query.regionId,
            travelDays: (availableTime?.travelDays ?? query.desiredDays).clamp(
              1,
              kMaxTripSpanDays + 1,
            ),
            density: draft.scheduleDensity == ScheduleDensity.relaxed
                ? 'RELAXED'
                : 'PACKED',
            transport: draft.transportMode == TransportMode.publicTransit
                ? 'TRANSIT'
                : 'CAR',
            origin: origin,
            travelDate:
                availableTime?.startDate ??
                draft.travelStartDate(DateUtils.dateOnly(DateTime.now())),
            // 캘린더에서 직접 고른 날짜만 확정으로 저장한다 — 추정 날짜를 실으면
            // 일정이 확정된 것처럼 보인다
            confirmedDate: draft.startDate,
          );
    });

/// O-09 · 코스확정 (당일치기 / 1박 이상)
class CourseScreen extends ConsumerStatefulWidget {
  const CourseScreen({
    super.key,
    required this.regionId,
    required this.desiredDays,
  });

  final String regionId;
  final int desiredDays;

  @override
  ConsumerState<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends ConsumerState<CourseScreen> {
  int _selectedDay = 1;

  void _exitToHome() {
    ref.read(courseWizardProvider.notifier).reset();
    context.go(AppRoutes.home);
  }

  /// 저장 요청 중 — 중복 탭과 이중 저장을 막는다
  bool _saving = false;

  /// '새로운 추천 받기'로 다시 뽑은 코스. provider 결과보다 우선한다
  Map<String, dynamic>? _regenerated;

  /// 직전 재생성의 씨앗 — 다음 재생성에 넘겨야 다른 조합이 나온다
  int? _lastSeed;

  bool _regenerating = false;

  /// 같은 지역에서 코스를 다시 뽑는다. 화면을 떠나지 않고 그 자리에서 바뀐다.
  Future<void> _regenerate() async {
    if (_regenerating) return;
    setState(() => _regenerating = true);
    try {
      final draft = ref.read(courseWizardProvider);
      final availableTime = await ref.read(availableTimeProvider.future);
      final origin = await ref.read(originLocatorProvider).resolve();
      final result = await ref
          .read(courseRepositoryProvider)
          .regenerate(
            regionId: widget.regionId,
            travelDays: (availableTime?.travelDays ?? widget.desiredDays).clamp(
              1,
              kMaxTripSpanDays + 1,
            ),
            density: draft.scheduleDensity == ScheduleDensity.relaxed
                ? 'RELAXED'
                : 'PACKED',
            transport: draft.transportMode == TransportMode.publicTransit
                ? 'TRANSIT'
                : 'CAR',
            origin: origin,
            travelDate:
                availableTime?.startDate ??
                draft.travelStartDate(DateUtils.dateOnly(DateTime.now())),
            confirmedDate: draft.startDate,
            previousSeed: _lastSeed,
          );
      if (!mounted) return;
      setState(() {
        _regenerated = result.course;
        _lastSeed = result.seed;
        _selectedDay = 1; // 새 코스는 첫날부터 보여준다
      });
      if (!result.differentFromPrevious) {
        showAppToast(context, '이 지역은 장소가 많지 않아 비슷한 코스가 나올 수 있어요');
      }
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.detail);
    } catch (_) {
      // 응답 형태가 어긋나는 등 예상 밖 실패 — 조용히 끝나면 고장으로 오해한다
      if (mounted) showAppToast(context, '코스를 다시 만들지 못했어요');
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  /// 코스를 서버에 저장하고 내 코스 탭으로 이동한다.
  /// 위저드는 여기서 끝나므로 조건을 초기화한다.
  ///
  /// 프리셋 경로(당일치기·주말포함·연차만)로 만든 코스는 날짜가 없어서 먼저
  /// 날짜 지정 화면을 거친다 — 날짜 없이 저장하면 날씨·휴무일 안내도 연차
  /// 차감도 못 한다. 캘린더에서 미리 날짜를 고른 코스는 바로 저장한다.
  Future<void> _saveToMyCourses(Map<String, dynamic> course) async {
    if (_saving) return;

    final savePayload = Map<String, dynamic>.from(
      course['_save'] as Map<String, dynamic>,
    );
    if (savePayload['travelDate'] == null) {
      final durationDays = course['durationDays'] as int? ?? 1;
      final picked = await context.push<DateTime>(
        AppRoutes.courseSaveDatePath(travelDays: durationDays),
      );
      if (picked == null) return; // 뒤로 가면 담기 취소 — 코스 화면에 그대로 머문다
      savePayload['travelDate'] = isoDate(picked);
    }

    setState(() => _saving = true);
    try {
      // 담기만으로는 연차를 깎지 않는다 — 여행이 끝난 뒤 홈에서 다녀왔는지
      // 물어 그때 차감한다(안 간 여행까지 깎이지 않게). 미리 확정하고 싶으면
      // 내 코스 상세의 차감 액션을 쓴다
      await ref.read(courseRepositoryProvider).save(savePayload);
      if (!mounted) return;
      showAppToast(context, '내 코스에 담았어요', kind: AppToastKind.success);
      ref.read(courseWizardProvider.notifier).reset();
      context.go(AppRoutes.myCourses);
    } on ApiException catch (e) {
      // 담기지 않았는데 이동하면 담긴 줄 안다 — 머물러 알린다
      if (mounted) showAppToast(context, e.detail);
    } catch (_) {
      // '_save' 누락 등 예상 밖 실패도 사용자에게는 알려야 한다
      if (mounted) showAppToast(context, '코스를 담지 못했어요');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 담기 전 코스를 공유한다.
  ///
  /// 서버가 내 코스에 넣지 않고 링크만 발급해 준다 — 친구에게 보여주려고
  /// 굳이 담고 날짜까지 정할 필요가 없다.
  Future<void> _shareBeforeSaving(
    Map<String, dynamic> course, {
    required bool kakao,
  }) async {
    final payload = course['_save'] as Map<String, dynamic>?;
    if (payload == null) {
      showAppToast(context, '링크를 만들지 못했어요');
      return;
    }
    try {
      final token = await ref
          .read(courseRepositoryProvider)
          .shareWithoutSaving(payload);
      if (!mounted) return;

      final regionName = course['regionName'] as String? ?? '여행';
      final duration = _durationLabel(course['durationDays'] as int? ?? 1);
      final link = ShareLink.of(token);

      if (!kakao) {
        await Clipboard.setData(ClipboardData(text: link));
        if (mounted) {
          showAppToast(context, '링크를 복사했어요.', kind: AppToastKind.success);
        }
        return;
      }

      final sent = await KakaoShare.sendCourse(
        title: '$regionName 여행, $duration',
        description: '연차로 떠나는 로컬 여행 — 코스를 확인해보세요',
        linkUrl: link,
        shareToken: token,
        imageUrl: _firstImageOf(course),
      );
      if (mounted && !sent) showAppToast(context, '카카오톡을 열지 못했어요');
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.detail);
    } catch (_) {
      if (mounted) showAppToast(context, '링크를 만들지 못했어요');
    }
  }

  /// 카카오 카드에 쓸 대표 사진 — 첫날 첫 장소
  String? _firstImageOf(Map<String, dynamic> course) {
    for (final day in (course['days'] as List? ?? const [])) {
      for (final p in ((day as Map)['places'] as List? ?? const [])) {
        final url = (p as Map)['imageUrl'] as String?;
        if (url != null && url.isNotEmpty) return url;
      }
    }
    return null;
  }

  String _durationLabel(int days) => switch (days) {
    1 => '당일치기',
    2 => '1박2일',
    _ => '2박3일',
  };

  @override
  Widget build(BuildContext context) {
    final providerKey = (
      regionId: widget.regionId,
      desiredDays: widget.desiredDays,
    );
    // 조건이 바뀌어 provider가 새 코스를 만들면 이전 재추첨 결과는 버린다 —
    // 계속 들고 있으면 갱신된 조건의 코스가 화면에 나타나지 않는다
    ref.listen(courseProvider(providerKey), (previous, next) {
      final fresh = next.value;
      if (fresh != null && !identical(previous?.value, fresh)) {
        setState(() {
          _regenerated = null;
          _lastSeed = null;
        });
      }
    });
    final course = ref.watch(courseProvider(providerKey));

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      body: SafeArea(
        child: course.when(
          // 실제 코스 생성이라 몇 초 걸릴 수 있다 — O-07 로딩 디자인을 쓴다
          loading: () => const AppLoadingView(title: '나만의 여행 코스를\n만들고 있어요..'),
          // 서버 detail이 사용자 문구라 그대로 보여준다. 그 외에는 원인을 감춘다
          error: (e, _) => Center(
            child: Text(
              e is ApiException ? e.detail : '코스를 불러오지 못했어요',
              textAlign: TextAlign.center,
              style: AppTypography.label1NormalMedium.copyWith(
                color: AppColors.labelAlternative,
              ),
            ),
          ),
          data: (data) {
            if (data == null) {
              return const Center(child: Text('해당 지역의 코스가 아직 없어요'));
            }
            // 재생성한 코스가 있으면 그걸 보여준다 (조건이 바뀌면 provider가 새로 만든다)
            return _buildBody(_regenerated ?? data);
          },
        ),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> course) {
    final days = (course['days'] as List).cast<Map<String, dynamic>>();
    final durationDays = course['durationDays'] as int;
    final day = days.firstWhere(
      (d) => d['day'] == _selectedDay,
      orElse: () => days.first,
    );
    final places = (day['places'] as List).cast<Map<String, dynamic>>();

    return Column(
      children: [
        Padding(
          // 버튼이 아이콘보다 넓으므로 좌우 여백을 줄여 아이콘 위치를 맞춘다
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              AppIconButton(
                icon: Icons.close,
                onTap: _exitToHome,
                semanticLabel: '닫기',
              ),
              const Spacer(),
              // 내 코스 상세와 같은 DS 에셋을 쓴다 — Material 기본 아이콘은
              // 모양·굵기가 달라 두 화면의 공유 버튼이 서로 다르게 보였다
              Semantics(
                button: true,
                label: '공유하기',
                child: GestureDetector(
                  onTap: () => CourseShareSheets.showEntry(
                    context,
                    dayCount: durationDays,
                    // 담지 않아도 공유된다 — 서버가 링크만 따로 발급해 준다
                    onCopyLink: () => _shareBeforeSaving(course, kakao: false),
                    onKakaoShare: () => _shareBeforeSaving(course, kakao: true),
                  ),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/icons/ic_share_ios.svg',
                        width: 24,
                        height: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            children: [
              Center(
                child: SvgPicture.asset(
                  'assets/icons/ic_pin_location.svg',
                  width: 48,
                  height: 48,
                ),
              ),
              const SizedBox(height: 20),
              _buildHeadline(course, durationDays),
              const SizedBox(height: 8),
              Text(
                '맞춤코스로 연차 여행을 떠나보세요.',
                textAlign: TextAlign.center,
                style: AppTypography.body1NormalMedium.copyWith(
                  color: AppColors.labelAlternative,
                ),
              ),
              const SizedBox(height: 32),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 198,
                  child: CourseMap(places: places, dayKey: _selectedDay),
                ),
              ),
              const SizedBox(height: 20),
              if (durationDays > 1) ...[
                CourseDayTabs(
                  durationDays: durationDays,
                  selectedDay: _selectedDay,
                  onSelect: (d) => setState(() => _selectedDay = d),
                ),
                const SizedBox(height: 12),
              ],
              CoursePlaceList(
                places: places,
                regionName: course['regionName'] as String? ?? widget.regionId,
              ),
              // 안내 문구·버튼은 화면에 고정하지 않고 목록 끝에 따라온다 —
              // 고정하면 늘 떠 있어 코스를 보는 화면을 좁힌다
              const SizedBox(height: 24),
              Text(
                '추천 코스를 내 코스에 담으면\n언제든 확인이 가능해요!',
                textAlign: TextAlign.center,
                style: AppTypography.label1ReadingMedium.copyWith(
                  color: AppColors.labelAlternative,
                ),
              ),
              const SizedBox(height: 16),
              _buildActionArea(course),
            ],
          ),
        ),
      ],
    );
  }

  /// "정선군, 2박3일 추천코스입니다." — 지역·기간만 브랜드색으로 짚는다
  Widget _buildHeadline(Map<String, dynamic> course, int durationDays) {
    // 라우트의 regionId는 숫자 문자열이라 표시용 이름은 응답에서 받는다
    final regionName = course['regionName'] as String? ?? widget.regionId;
    final base = AppTypography.title3Bold.copyWith(
      color: AppColors.labelNormal,
    );
    return Text.rich(
      textAlign: TextAlign.center,
      TextSpan(
        style: base,
        children: [
          TextSpan(text: '$regionName, '),
          TextSpan(
            text: _durationLabel(durationDays),
            style: base.copyWith(color: AppColors.primaryNormal),
          ),
          const TextSpan(text: '\n추천코스입니다.'),
        ],
      ),
    );
  }

  /// 목록 끝에 따라오는 액션 묶음 — 좌우 여백은 리스트가 이미 준다
  Widget _buildActionArea(Map<String, dynamic> course) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saving ? null : () => _saveToMyCourses(course),
            icon: const Icon(Icons.download, size: 20),
            label: Text('내 코스에 담기', style: AppTypography.body1NormalBold),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryNormal,
              foregroundColor: AppColors.staticWhite,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _regenerating ? null : _regenerate,
            icon: const Icon(Icons.refresh, size: 20),
            label: Text('새로운 추천 받기', style: AppTypography.body1NormalBold),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryNormal,
              side: const BorderSide(color: AppColors.primaryNormal),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _exitToHome,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '홈으로 가기',
              style: AppTypography.label1ReadingMedium.copyWith(
                color: AppColors.labelAlternative,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
