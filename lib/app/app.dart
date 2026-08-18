import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/router/app_router.dart';
import '../core/router/deep_link_listener.dart';
import '../core/router/session_expiry_listener.dart';
import '../core/theme/app_theme.dart';
import '../features/notification/application/push_registration.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'OffWay',
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
