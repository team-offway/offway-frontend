import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/router/app_router.dart';
import '../core/router/deep_link_listener.dart';
import '../core/router/session_expiry_listener.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/application/current_user_provider.dart';
import '../features/notification/application/push_presenter.dart';
import '../features/notification/application/push_registration.dart';
import '../features/trip_activity/application/trip_activity_controller.dart';
import '../features/home/application/home_providers.dart';

class OffwayApp extends ConsumerStatefulWidget {
  const OffwayApp({super.key});

  @override
  ConsumerState<OffwayApp> createState() => _OffwayAppState();
}

class _OffwayAppState extends ConsumerState<OffwayApp> {
  @override
  void initState() {
    super.initState();
    // 푸시는 덤이라 기다리지 않는다 — 권한 팝업이 뜨는 동안 앱이 멈추면
    // 안 되고, 실패해도 화면은 그대로 가야 한다
    unawaited(ref.read(pushRegistrationProvider).start());
    // 서버는 data-only 메시지를 보낸다(core #270) — 배너는 앱이 그린다.
    // 이게 없으면 알림 목록에는 쌓이는데 배너가 안 뜬다
    unawaited(ref.read(pushPresenterProvider).start());

    // 아래는 **로그인돼 있을 때만** 한다 — 셋 다 서버를 부르므로
    // 로그인 전에 부르면 401을 맞는다
    if (ref.read(postSplashRouteProvider) == AppRoutes.home) {
      // 스플래시가 머무는 동안 홈·내 정보를 미리 읽는다. 홈이 그려진
      // 뒤에야 요청을 보내면 그 시간이 통째로 낭비되고, 사용자는 스플래시
      // 다음에 스켈레톤을 한 번 더 본다. 두 프로바이더는 autoDispose가
      // 아니라 여기서 읽어 둔 값을 홈이 그대로 받는다
      ref
        ..read(homeSnapshotProvider)
        ..read(currentUserProvider);
      // 홈 데이터가 오는 대로 **첫 화면 사진**부터 받아 둔다. 홈이 그려진
      // 뒤 카드가 요청하면 이미 받았거나 받는 중인 것을 이어받는다(같은
      // 캐시·같은 주소는 한 번만 받는다). 실패해도 카드가 다시 받는다
      prefetchHomeFirstImages(ref);

      // 잠금화면·다이나믹 아일랜드의 여행 D-day.
      //
      // **한 번 띄우면 앱과 무관하게 살아 있다** — 앱을 꺼도 잠금화면에
      // 남는다. 다만 시작·갱신은 앱이 켜져 있을 때만 하므로(1단계는 푸시
      // 갱신이 없다) 앱이 열릴 때마다 맞춘다
      ref.read(tripActivityControllerProvider).start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Offway',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      // 여기는 라우터 바깥이라 GoRouter.of(context)를 쓸 수 없다 —
      // 리스너들은 appRouterProvider로 라우터를 직접 잡는다
      builder: (context, child) => SessionExpiryListener(
        child: DeepLinkListener(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
