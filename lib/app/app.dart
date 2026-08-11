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
      // 여기는 라우터 바깥이라 GoRouter.of(context)를 쓸 수 없다 —
      // 리스너는 appRouterProvider로 라우터를 직접 잡는다
      builder: (context, child) =>
          DeepLinkListener(child: child ?? const SizedBox.shrink()),
    );
  }
}
