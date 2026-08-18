import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens/tokens.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/app_circular_loading.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_toast.dart';
import '../application/notification_provider.dart';
import '../application/push_registration.dart';
import '../data/notification_repository.dart';
import '../domain/app_notification.dart';

/// 기기 알림 권한이 켜져 있는지.
///
/// 화면에 들어올 때마다 다시 읽는다 — 설정에서 켜고 돌아온 사람에게
/// 안내가 남아 있으면 안 된다.
final notificationEnabledProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(pushRegistrationProvider).isAuthorized(),
);

/// 알림 목록 — 홈 상단 종 아이콘에서 들어온다.
class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 설정에서 권한을 켜고 돌아왔을 수 있다 — 안내가 남아 있으면
    // 켰는데도 못 받는 줄 안다
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(notificationEnabledProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 아직 못 읽었으면 목록을 그린다 — 권한이 있는데 안내가 깜빡이면
    // 사용자를 설정으로 헛걸음시킨다
    final enabled = ref.watch(notificationEnabledProvider).value ?? true;
    final feed = ref.watch(notificationFeedProvider);

    // 목록을 읽을 때마다 배지를 맞춘다 — 읽고 나왔는데 배지가 남아 있으면
    // 눌러도 새 알림이 없어 사용자를 속인다
    ref.listen(notificationFeedProvider, (_, next) {
      final count = next.value?.unreadCount;
      if (count != null) {
        ref.read(hasUnreadNotificationsProvider.notifier).setUnreadCount(count);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundNormal,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: !enabled
                  ? const _PermissionOff()
                  : switch (feed) {
                      AsyncData(:final value)
                          when value.notifications.isEmpty =>
                        const _EmptyNotifications(),
                      AsyncData(:final value) => _buildList(
                        value.notifications,
                      ),
                      AsyncError() => AppErrorView(
                        onRetry: () => ref.invalidate(notificationFeedProvider),
                      ),
                      _ => const Center(child: AppCircularLoading()),
                    },
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

/// 알림 한 줄 — 안 읽은 건 옅은 하늘색으로 깔린다.
///
/// 누르면 읽음으로 바꾸고 종류에 맞는 화면으로 보낸다.
class _NotificationCell extends ConsumerWidget {
  const _NotificationCell({required this.item});

  final AppNotification item;

  /// 알림을 눌렀을 때 — 읽음 처리하고 갈 곳으로 보낸다.
  ///
  /// **읽음 처리를 기다리지 않고 이동한다.** 서버가 느리다고 화면이 멈춰
  /// 있으면 누른 보람이 없고, 실패해도 다음 조회에서 다시 안 읽음으로
  /// 보일 뿐이라 잃는 게 없다.
  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    final destination = _destination;
    if (destination != null) context.push(destination);

    if (item.read) return;
    try {
      final unread = await ref
          .read(notificationRepositoryProvider)
          .markRead(item.id);
      ref.read(hasUnreadNotificationsProvider.notifier).setUnreadCount(unread);
      ref.invalidate(notificationFeedProvider);
    } on ApiException {
      // 읽음 표시가 안 남는 것뿐이다 — 알릴 만한 실패가 아니다.
      // 비로그인은 여기서 403(COMMON-403)이 온다 — 서버가 쓰기에 JWT를
      // 요구한다. 이동은 이미 했으므로 화면 흐름은 끊기지 않는다
    }
  }

  /// 종류별로 갈 곳. 없으면 누르기만 하고 이동하지 않는다.
  String? get _destination => switch (item.type) {
    // 시안 흐름: 알림 → 내 연차. 그 화면이 "다녀오셨나요?" 모달을 띄운다
    NotificationType.tripAfter => AppRoutes.myLeave,
    // 내일 떠날 여행을 보러 간다. 코스가 지워졌으면 갈 곳이 없다
    NotificationType.tripTomorrow =>
      item.courseId == null
          ? null
          : AppRoutes.savedCoursePath(item.courseId.toString()),
    NotificationType.unknown => null,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _onTap(context, ref),
      behavior: HitTestBehavior.opaque,
      child: Container(
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
              item.timeLabel(),
              style: AppTypography.label1NormalMedium.copyWith(
                color: AppColors.labelAssistive,
              ),
            ),
          ],
        ),
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

  /// 이 앱의 설정 화면을 연다.
  ///
  /// **앱 안에서 다시 물을 수 없다.** iOS는 한 번 거부한 사용자에게 권한
  /// 팝업을 두 번 띄우지 않는다 — 켜려면 설정으로 가는 수밖에 없다.
  ///
  /// `app-settings:`는 iOS가 앱별 설정 화면에 붙여 둔 주소다.
  Future<void> _openSettings(BuildContext context) async {
    // false를 돌려주기도, PlatformException을 던지기도 한다 —
    // 둘 다 '못 열었다'이고 사용자에게는 같은 안내가 필요하다
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse('app-settings:'));
    } on Object catch (e) {
      debugPrint('설정 화면을 열지 못했다: $e');
    }
    if (opened || !context.mounted) return;
    // 열지 못하면 손으로 찾아가야 한다 — 어디로 갈지 알려준다
    showAppToast(context, '설정 > OffWay > 알림에서 켤 수 있어요');
  }

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
            onTap: () => _openSettings(context),
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
