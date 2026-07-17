# offway-frontend

Offway iOS 앱 (Flutter). 백엔드는 별도 레포(Java Spring)에서 REST API로 제공한다.

## 기술 스택

| 영역 | 선택 |
|---|---|
| 프레임워크 | Flutter 3.38 / Dart 3.10 |
| 상태관리 | flutter_riverpod 3 |
| 라우팅 | go_router |
| HTTP 클라이언트 | dio (Auth 인터셉터 포함) |
| 토큰 저장 | flutter_secure_storage (iOS Keychain) |
| 모델/직렬화 | freezed + json_serializable |

## 폴더 구조

```
lib/
├── main.dart                  # 엔트리포인트 (ProviderScope)
├── app/
│   └── app.dart               # 루트 위젯 (MaterialApp.router)
├── core/                      # 앱 전역 공통 모듈
│   ├── config/app_config.dart     # API base URL 등 환경 설정
│   ├── network/dio_client.dart    # Dio 프로바이더 + Auth 인터셉터
│   ├── router/app_router.dart     # GoRouter 라우트 정의
│   ├── storage/secure_storage.dart# JWT 토큰 Keychain 저장소
│   └── theme/app_theme.dart       # Material 3 라이트/다크 테마
└── features/                  # 기능(도메인) 단위 모듈
    └── home/
        └── presentation/home_screen.dart
```

새 기능은 `features/<기능명>/` 아래에 `data`(API·repository) / `domain`(모델) / `presentation`(화면·상태) 구조로 추가한다.

## 실행

```bash
# iOS 시뮬레이터 실행
flutter run

# 백엔드 API 주소 지정 (기본값: http://localhost:8080)
flutter run --dart-define=API_BASE_URL=https://api.example.com
```

## 코드 생성 (freezed / json_serializable)

모델에 `@freezed`, `@JsonSerializable`을 사용한 뒤:

```bash
dart run build_runner build --delete-conflicting-outputs
# 개발 중 자동 감지
dart run build_runner watch --delete-conflicting-outputs
```

## 테스트 / 린트

```bash
flutter test
flutter analyze
dart format .
```

## 비고

- iOS `Info.plist`에 `NSAllowsLocalNetworking`이 켜져 있어 시뮬레이터에서 로컬 Spring 서버(`http://localhost:8080`)와 통신 가능하다.
- 번들 ID: `com.nth.offway` (iOS/Android 동일)
