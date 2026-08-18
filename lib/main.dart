import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'app/app.dart';
import 'core/network/dio_client.dart';
import 'core/router/app_router.dart';
import 'core/storage/secure_storage.dart';
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
  // 로그인해 둔 사람은 홈으로 바로 들어간다. 라우터가 만들어질 때 초기 경로가
  // 정해지므로 그 전에 Keychain을 읽는다 — 스플래시를 두지 않으려는 선택이다.
  // 토큰이 만료됐어도 홈으로 보낸다: 첫 요청이 401을 맞으면 인터셉터가
  // 재발급하고, 그것도 실패하면 세션 만료로 로그인 화면으로 돌아간다
  final storage = TokenStorage(const FlutterSecureStorage());
  // Keychain 읽기가 실패해도 앱은 떠야 한다 — 여기서 던지면 첫 화면이
  // 그려지기 전이라 흰 화면으로 죽는다. 못 읽으면 로그인부터 시작한다
  bool signedIn;
  try {
    signedIn = await storage.accessToken != null;
  } on Exception catch (e) {
    debugPrint('저장된 토큰을 읽지 못해 로그인부터 시작합니다: $e');
    signedIn = false;
  }

  runApp(
    ProviderScope(
      overrides: [
        // 401을 만난 요청이 토큰을 되살릴 수 있게 연결한다. core가 인증 기능을
        // 직접 참조하면 순환 import가 되므로 여기서 이어 붙인다
        tokenRefresherProvider.overrideWith(
          (ref) => ref.watch(authTokenRefresherProvider),
        ),
        secureStorageProvider.overrideWithValue(storage),
        if (signedIn)
          initialRouteProvider.overrideWith(
            // 개발용 INITIAL_ROUTE가 지정돼 있으면 그쪽을 존중한다
            (ref) => const String.fromEnvironment(
              'INITIAL_ROUTE',
              defaultValue: AppRoutes.home,
            ),
          ),
      ],
      child: const OffwayApp(),
    ),
  );
}
