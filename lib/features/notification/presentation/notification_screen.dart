import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_back_button.dart';

/// 알림 한 건.
///
/// [read]가 false면 아직 안 본 알림이라 옅은 하늘색 배경으로 구분한다.
typedef AppNotification = ({
  String title,
  String body,
  String timeLabel,
  bool read,
});

/// TODO(server): 알림 API가 아직 없다 — 조회·읽음 처리·권한 등록이 모두 필요하다.
/// 스펙이 나오면 이 mock을 리포지토리 호출로 바꾼다.
final notificationsProvider = Provider.autoDispose<List<AppNotification>>((
  ref,
) {
  return const [
    (
      title: '알림',
      body: "오늘은 '정선 여행'을 떠나는 날이에요.",
      timeLabel: '방금전',
      read: false,
    ),
    (
      title: '알림',
      body: "'정선 여행' 다녀오셨나요?\n연차 차감을 확인해주세요.",
      timeLabel: '방금전',
      read: true,
    ),
    (title: '알림', body: "'정선 여행'까지 3일 남았어요.", timeLabel: '방금전', read: true),
  ];
});

/// 안 읽은 알림이 하나라도 있는지 — 홈 종 아이콘의 배지가 이 값을 본다
final hasUnreadNotificationsProvider = Provider<bool>(
  (ref) => ref.watch(notificationsProvider).any((n) => !n.read),
);

/// 기기 알림 권한이 켜져 있는지.
///
/// TODO(push): 실제 권한 조회로 바꾼다 (permission_handler 등).
/// 지금은 늘 켜진 것으로 보고 목록을 그린다.
final notificationEnabledProvider = Provider.autoDispose<bool>((ref) => true);

/// 알림 목록 — 홈 상단 종 아이콘에서 들어온다.
class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(notificationEnabledProvider);
    final items = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: !enabled
                  ? const _PermissionOff()
                  : items.isEmpty
                  ? const _EmptyNotifications()
                  : _buildList(items),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<AppNotification> items) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverList.builder(
          itemCount: items.length,
          itemBuilder: (context, i) => _NotificationCell(item: items[i]),
        ),
        // 보관 기간 안내는 목록이 짧아도 화면 아래쪽에 놓인다
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 40),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Text(
                '오래된 알림은 30일 후 자동 삭제돼요',
                style: AppTypography.label1NormalMedium.copyWith(
                  color: AppColors.labelAssistive,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        // 없으면 Stack이 제목 크기로 줄어 Positioned가 화면 기준이 아니게 된다
        fit: StackFit.expand,
        children: [
          Center(
            child: Text(
              '알림',
              style: AppTypography.headline2Bold.copyWith(
                color: AppColors.labelStrong,
              ),
            ),
          ),
          Positioned(
            left: 6,
            child: AppBackButton(
              onTap: () =>
                  context.canPop() ? context.pop() : context.go(AppRoutes.home),
            ),
          ),
        ],
      ),
    );
  }
}

/// 알림 한 줄 — 안 읽은 건 옅은 하늘색으로 깔린다
class _NotificationCell extends StatelessWidget {
  const _NotificationCell({required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: item.read ? AppColors.backgroundNormal : AppPalette.lightBlue95,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // 아이콘이 첫 줄(라벨) 높이에 맞게 앉도록 살짝 내린다
            padding: const EdgeInsets.only(top: 2),
            child: SvgPicture.asset(
              'assets/icons/ic_bell_fill.svg',
              width: 16,
              height: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTypography.label1NormalMedium.copyWith(
                    color: AppColors.labelAlternative,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.body,
                  style: AppTypography.body1NormalMedium.copyWith(
                    color: AppColors.labelNeutral,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.timeLabel,
            style: AppTypography.label1NormalMedium.copyWith(
              color: AppColors.labelAssistive,
            ),
          ),
        ],
      ),
    );
  }
}

/// 받은 알림이 하나도 없을 때 — 말풍선 위에 벨을 얹는다
class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 말풍선이 벨 위에 3px 겹쳐 얹힌다
          SvgPicture.asset(
            'assets/icons/ic_empty_course_bubble.svg',
            width: 29,
            height: 29,
          ),
          Transform.translate(
            offset: const Offset(0, -3),
            child: SvgPicture.asset(
              'assets/icons/ic_empty_bell.svg',
              width: 48,
              height: 48,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '알림이 없어요',
            style: AppTypography.heading2Bold.copyWith(
              color: AppColors.labelStrong,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '새로운 소식이 오면 알려드릴게요',
            style: AppTypography.body1NormalMedium.copyWith(
              color: AppColors.labelAlternative,
            ),
          ),
        ],
      ),
    );
  }
}

/// 기기 알림 권한이 꺼져 있을 때 — 설정으로 보낸다
class _PermissionOff extends StatelessWidget {
  const _PermissionOff();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/ic_empty_bell.svg',
            width: 48,
            height: 48,
          ),
          const SizedBox(height: 14),
          Text(
            '알림이 꺼져있어요',
            style: AppTypography.heading2Bold.copyWith(
              color: AppColors.labelStrong,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '알림을 받기 위해 권한 허용이 필요해요',
            style: AppTypography.body1NormalMedium.copyWith(
              color: AppColors.labelAlternative,
            ),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            // TODO(push): 기기 설정 화면으로 보낸다 (app_settings 등)
            onTap: () {},
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppPalette.coolNeutral20,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '알림 켜기',
                style: AppTypography.body2NormalMedium.copyWith(
                  color: AppColors.inverseLabel,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
