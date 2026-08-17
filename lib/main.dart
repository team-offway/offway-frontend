import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'app/app.dart';
import 'core/network/dio_client.dart';
import 'features/auth/data/auth_repository.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  KakaoSdk.init(nativeAppKey: AppConfig.kakaoNativeAppKey);

  // 설정 파일(GoogleService-Info.plist)은 레포가 public이라 커밋하지 않는다 —
  // 없는 환경에서도 앱은 떠야 하므로 실패를 삼킨다. 구글 로그인과 푸시만
  // 동작하지 않는다.
  try {
    await Firebase.initializeApp();
  } on Exception catch (e) {
    debugPrint('Firebase 초기화 실패 (로그인·푸시 비활성): $e');
  }

  await FlutterNaverMap().init(
    clientId: AppConfig.naverMapClientId,
    onAuthFailed: (e) => debugPrint('네이버 지도 인증 실패: $e'),
  );
  runApp(
    ProviderScope(
      // 401을 만난 요청이 토큰을 되살릴 수 있게 연결한다. core가 인증 기능을
      // 직접 참조하면 순환 import가 되므로 여기서 이어 붙인다
      overrides: [
        tokenRefresherProvider.overrideWith(
          (ref) => ref.watch(authTokenRefresherProvider),
        ),
      ],
      child: const OffwayApp(),
    ),
  );
}
