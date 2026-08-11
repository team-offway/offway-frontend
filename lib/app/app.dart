import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/router/app_router.dart';
import '../core/router/deep_link_listener.dart';
import '../core/theme/app_theme.dart';

class OffwayApp extends ConsumerWidget {
  const OffwayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'OffWay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      // 공유 링크로 열린 경우를 받으려면 라우터 안쪽이어야 한다 —
      // 바깥에 두면 GoRouter.of(context)가 라우터를 찾지 못한다
      builder: (context, child) =>
          DeepLinkListener(child: child ?? const SizedBox.shrink()),
    );
  }
}
