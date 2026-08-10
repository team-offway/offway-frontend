import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/app_circular_loading.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/app_back_button.dart';
import '../data/course_repository.dart';
import 'widgets/course_map.dart';

/// 장소 상세 (`GET /pois/{contentId}`)
final poiDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>(
      (ref, contentId) =>
          ref.watch(courseRepositoryProvider).poiDetail(contentId),
    );

/// 코스 속 장소 하나의 상세 — 대표 이미지·소개·기본정보·위치와 길 찾기.
///
/// [name]은 코스 리스트에서 넘어온 장소명 그대로 헤더에 쓴다.
class PoiDetailScreen extends ConsumerWidget {
  const PoiDetailScreen({
    super.key,
    required this.contentId,
    required this.name,
  });

  final String contentId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(poiDetailProvider(contentId));

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: detail.when(
                loading: () => const AppCircularLoadingView(),
                // 서버 detail이 사용자 문구면 그대로, 그 외에는 기본 안내로
                error: (e, _) => AppErrorView(
                  description: e is ApiException ? e.detail : '잠시 후 다시 시도해 주세요',
                  onRetry: () => ref.invalidate(poiDetailProvider(contentId)),
                ),
                data: (poi) => _Body(name: name, poi: poi),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        // 없으면 Stack이 자식 크기로 줄어 Positioned의 left가 화면이 아니라
        // 제목 기준이 된다 — 뒤로가기가 제목 옆에 붙어버린다
        fit: StackFit.expand,
        children: [
          Padding(
            // 긴 장소명이 뒤로 가기 버튼을 침범하지 않게 좌우를 비워둔다
            padding: const EdgeInsets.symmetric(horizontal: 52),
            child: Center(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.headline2Bold.copyWith(
                  color: AppColors.labelNormal,
                ),
              ),
            ),
          ),
          Positioned(
            // 다른 화면과 같은 위치 — 버튼이 아이콘보다 넓어 여백을 줄여 맞춘다
            left: 6,
            child: AppBackButton(
              // 딥링크로 바로 들어오면 스택이 비어 pop이 안 된다 — 홈으로 보낸다
              onTap: () =>
                  context.canPop() ? context.pop() : context.go(AppRoutes.home),
              color: AppColors.labelAlternative,
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.name, required this.poi});

  final String name;
  final Map<String, dynamic> poi;

  @override
  Widget build(BuildContext context) {
    final imageUrl = poi['imageUrl'] as String?;
    final catchphrase = poi['catchphrase'] as String?;
    final overview = poi['overview'] as String?;
    final lat = (poi['lat'] as num?)?.toDouble();
    final lng = (poi['lng'] as num?)?.toDouble();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 대표 이미지 — TourAPI 이미지가 없으면 옅은 자리로 대체
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 220,
                  width: double.infinity,
                  color: AppColors.backgroundNormalAlternative,
                  child: imageUrl == null
                      ? Icon(
                          Icons.image_outlined,
                          size: 48,
                          color: AppColors.labelAssistive,
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.expand(),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              // TODO(server): 디자인의 혜택 뱃지('입장료 50% 할인')는 장소 단위
              // 혜택 데이터가 아직 없다 — 응답에 실리면 여기서 보여준다
              // 한줄 설명 — 별도 카피가 생기기 전까지 캐치프레이즈를 쓴다
              Text(
                catchphrase ?? name,
                style: AppTypography.heading2Bold.copyWith(
                  color: AppColors.labelNormal,
                ),
              ),
              if (overview != null) ...[
                const SizedBox(height: 8),
                Text(
                  // 소개글은 자르지 않고 전부 보여준다 — 3줄에서 끊으면
                  // 문장이 중간에 잘려 무슨 곳인지 알 수 없다
                  overview,
                  style: AppTypography.label1ReadingMedium.copyWith(
                    color: AppColors.labelNeutral,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Text(
                '기본정보',
                style: AppTypography.headline1Bold.copyWith(
                  color: AppColors.labelNormal,
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoCard(),
              if (lat != null && lng != null) ...[
                const SizedBox(height: 16),
                // 이 스팟 위치만 표시하는 정적 지도 (코스 전체 동선 아님)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 198,
                    child: AbsorbPointer(
                      child: CourseMap(
                        places: [
                          {'name': name, 'mapx': lng, 'mapy': lat},
                        ],
                        dayKey: 0,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: lat == null || lng == null
                      ? null
                      : () => _openDirections(context, lat, lng),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryNormal,
                    disabledBackgroundColor: AppColors.interactionDisable,
                    foregroundColor: AppColors.staticWhite,
                    disabledForegroundColor: AppColors.labelAssistive,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('길 찾기', style: AppTypography.body1NormalBold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundNormalAlternative,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('주소', poi['address'] as String?),
          const SizedBox(height: 12),
          _buildInfoRow('운영시간', poi['useTime'] as String?),
          const SizedBox(height: 12),
          _buildInfoRow('휴무일', poi['restDate'] as String?),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 시안은 라벨 폭을 고정하지 않고 글자만큼만 차지한다
        Text(
          label,
          style: AppTypography.label1NormalBold.copyWith(
            color: AppColors.labelAlternative,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value ?? '정보없음',
            style: AppTypography.label1NormalMedium.copyWith(
              // 값이 없을 때는 실제 정보와 구분되게 한 단계 옅힌다
              color: value == null
                  ? AppColors.labelAssistive
                  : AppColors.labelNeutral,
            ),
          ),
        ),
      ],
    );
  }

  /// 외부 지도 앱으로 길 찾기 — 목적지 좌표만 넘기고 출발지는 지도 앱이
  /// 현재 위치로 잡는다. 네이버지도가 없으면 OS 기본 지도로 넘어간다
  /// (iOS 애플 지도 · Android 지도 인텐트).
  Future<void> _openDirections(
    BuildContext context,
    double lat,
    double lng,
  ) async {
    final naver = Uri.parse(
      'nmap://route/car?dlat=$lat&dlng=$lng'
      '&dname=${Uri.encodeComponent(name)}&appname=com.nth.offway',
    );
    final fallback = Theme.of(context).platform == TargetPlatform.android
        ? Uri.parse('geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(name)})')
        : Uri.parse('https://maps.apple.com/?daddr=$lat,$lng');
    try {
      // launchUrl은 실패해도 예외 대신 false를 줄 수 있어 반환값까지 본다
      if (await canLaunchUrl(naver) && await launchUrl(naver)) return;
      final opened = await launchUrl(
        fallback,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        showAppToast(context, '지도 앱을 열지 못했어요');
      }
    } catch (_) {
      if (context.mounted) showAppToast(context, '지도 앱을 열지 못했어요');
    }
  }
}
