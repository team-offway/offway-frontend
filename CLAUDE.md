# offway-frontend

iOS 출시를 목표로 하는 Flutter 앱. 백엔드는 별도 레포의 Java Spring REST API (로컬 기본 주소 `http://localhost:8080`, JWT 인증 예정).

## 개발 명령어

```bash
flutter run                                          # 실행 (기기 선택: -d <device-id>)
flutter run --dart-define=API_BASE_URL=<url>         # 백엔드 주소 지정
flutter analyze                                      # 정적 분석
flutter test                                         # 테스트
dart format .                                        # 포맷
dart run build_runner build --delete-conflicting-outputs  # freezed/json 코드 생성
```

## 구조

```
lib/
├── main.dart                  # 엔트리포인트 (ProviderScope)
├── app/app.dart               # 루트 위젯 (MaterialApp.router)
├── core/                      # 전역 공통 모듈
│   ├── config/app_config.dart     # API base URL 등 (--dart-define 주입)
│   ├── network/dio_client.dart    # Dio 프로바이더 + JWT Auth 인터셉터
│   ├── router/app_router.dart     # GoRouter 라우트 정의
│   ├── storage/secure_storage.dart# 토큰 Keychain 저장소
│   └── theme/app_theme.dart       # Material 3 테마
└── features/<기능명>/          # 기능 단위 모듈
    ├── data/                      # API 호출, repository
    ├── domain/                    # 모델 (freezed)
    └── presentation/              # 화면, 상태(Riverpod)
```

- 상태관리: flutter_riverpod 3 / 라우팅: go_router / HTTP: dio
- 새 기능은 `features/<기능명>/` 아래 data·domain·presentation 구조로 추가

## 워크플로우 (필수 준수)

- **main 직접 푸시 금지** — 브랜치 보호로 차단되어 있음. 항상 브랜치에서 작업
- **커밋은 브랜치에 쌓고, PR 생성은 사용자가 명시적으로 요청할 때만** ("PR 올려줘")
- **머지는 사용자 확인 후에만**
- **커밋 메시지·PR 본문에 Claude 관련 문구(Co-Authored-By 등) 절대 금지**
- 커밋 메시지는 한국어, conventional commit 접두어 사용 (feat/fix/chore/ci 등)
- CI(GitHub Actions)가 PR마다 포맷·분석·테스트 검사, 통과해야 머지 가능

## 주의사항

- 로컬 Flutter 3.38.4(Dart 3.10.3) 제약으로 `json_annotation`은 ^4.9.0 핀, `riverpod_lint` 미설치 (freezed 3.x와 충돌). Flutter 업그레이드 시 함께 갱신할 것
- 번들 ID: `com.nth.offway`, 서명 팀: `AWV8LRP46J` (유료 Apple Developer)
- Xcode 작업 시 `ios/Runner.xcworkspace`를 열 것 (`.xcodeproj` 아님)
- 레포가 **public**이므로 API 키·인증서·키스토어 등 민감 파일 커밋 금지
