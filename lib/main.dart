import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterNaverMap().init(
    clientId: AppConfig.naverMapClientId,
    onAuthFailed: (e) => debugPrint('네이버 지도 인증 실패: $e'),
  );
  runApp(const ProviderScope(child: OffwayApp()));
}
