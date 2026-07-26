# OffWay

> 연차로 떠나는 로컬 여행 플래너

남은 연차로 다녀올 수 있는 **인구감소지역** 여행 코스를 추천하는 iOS 앱입니다. 백엔드는 별도 레포([team-offway/core](https://github.com/team-offway/core), Java Spring)에서 REST API로 제공합니다.

## 서비스 소개

연차는 남았는데 어디로 갈지 정하기 어렵고, 인구감소지역은 좋은 콘텐츠가 있어도 잘 알려지지 않습니다. OffWay는 **남은 연차·이동수단·일정 취향**을 입력받아 도달 가능한 지역과 날짜별 코스를 만들어 줍니다.

**핵심 플로우**

```
로그인 → 잔여연차 입력 → 홈
  └ 코스 추천받기
      ├ 날짜가 정해졌다면 → 캘린더에서 기간 선택
      └ 아직이라면      → 기간 스타일 선택 (당일치기 / 주말 포함 / 연차만)
          → 이동수단 → 일정 밀도 → 추천 계산 → 후보 지역 → 코스 확정
```

**핵심 정책** — 모든 코스는 **최대 2박3일**입니다. 인구감소지역 89곳을 전수 조사한 결과 콘텐츠가 40건 수준인 지역도 있어, 그 이상 길어지면 코스가 빈약해지기 때문입니다. ([조사 문서](docs/tourapi-분류체계-조사.md))

## 기술 스택

| 영역 | 선택 |
|---|---|
| 프레임워크 | Flutter 3.38 / Dart 3.10 |
| 상태관리 | flutter_riverpod 3 |
| 라우팅 | go_router |
| HTTP 클라이언트 | dio (JWT Auth 인터셉터 포함) |
| 토큰 저장 | flutter_secure_storage (iOS Keychain) |
| 모델/직렬화 | freezed + json_serializable |
| 지도 | flutter_naver_map (Dynamic Map) |
| 소셜 로그인 | kakao_flutter_sdk_user, sign_in_with_apple |

## 폴더 구조

```
lib/
├── main.dart                  # 엔트리포인트 (SDK 초기화 + ProviderScope)
├── app/app.dart               # 루트 위젯 (MaterialApp.router)
├── core/                      # 앱 전역 공통 모듈
│   ├── config/app_config.dart     # API base URL·공개 키 (--dart-define 주입)
│   ├── network/dio_client.dart    # Dio 프로바이더 + Auth 인터셉터
│   ├── router/app_router.dart     # GoRouter 라우트 정의
│   ├── storage/secure_storage.dart# JWT 토큰 Keychain 저장소
│   └── theme/app_theme.dart       # Material 3 라이트/다크 테마
├── mock/                      # 서버 구축 전 mock 데이터 로더
└── features/                  # 기능(도메인) 단위 모듈
    ├── auth/                      # 로그인 (카카오·Apple)
    ├── onboarding/                # 잔여연차 입력
    ├── home/                      # 홈
    ├── course_wizard/             # 코스 추천 위저드
    └── course/                    # 코스 확정 (지도·Day 탭)
```

새 기능은 `features/<기능명>/` 아래에 `data`(API·repository) / `domain`(모델) / `presentation`(화면·상태) 구조로 추가합니다.

## 실행

```bash
flutter run                                   # iOS 시뮬레이터 실행

# 백엔드 주소 지정 (기본값: http://localhost:8080)
flutter run --dart-define=API_BASE_URL=https://api.example.com

# 특정 화면부터 시작 (개발용)
flutter run --dart-define=INITIAL_ROUTE=/wizard/calendar
```

## 현재 상태

서버 구축 전이라 **mock 데이터**로 전 화면이 동작합니다.

- `assets/mock/*.json` — 사용자·지역·코스 데이터. 지어낸 값이 아니라 **TourAPI 실데이터**(정선·영월의 실제 콘텐츠와 연관관광지 동선, 실좌표·실사진)로 구성
- 서버 연동 시 `lib/mock/mock_data_source.dart`를 실 API 구현으로 교체하면 됩니다

| 영역 | 상태 |
|---|---|
| 와이어프레임 19개 화면 | 구현 완료 (mock으로 전 구간 동작) |
| 카카오·Apple 로그인 | 앱 연동 완료 (서버 토큰 교환은 배포 후 검증) |
| 구글 로그인 | 미구현 |
| 디자인 시스템 | 시안 대기 — 교체 지점은 `TODO(디자인시스템)` 주석 표시 |
| 내 코스 / 마이 탭 | 미구현 |

## 자료

| 문서 | 내용 |
|---|---|
| [tourapi-분류체계-조사.md](docs/tourapi-분류체계-조사.md) | TourAPI 분류체계·테마 매칭·연관관광지 API 검증 (인구감소지역 89곳 전수) |
| [tourapi-조사데이터.json](docs/tourapi-조사데이터.json) | 지역별 수치 + 양대 API 지역 코드 매핑 (백엔드용) |
| [디자인용-샘플데이터.json](docs/디자인용-샘플데이터.json) | 실데이터 샘플 팩 (디자이너용) |

## 코드 생성 (freezed / json_serializable)

```bash
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs   # 개발 중 자동 감지
```

## 테스트 / 린트

```bash
flutter test
flutter analyze
dart format .
```

PR마다 GitHub Actions가 포맷·분석·테스트를 검사하며, 통과해야 머지할 수 있습니다.

## 비고

- 번들 ID: `com.nth.offway` · App Store 등록명: **OffWay - 연차로 떠나는 로컬 여행 플래너**
- iOS `Info.plist`에 `NSAllowsLocalNetworking`이 켜져 있어 시뮬레이터에서 로컬 Spring 서버와 통신 가능합니다
- Xcode 작업 시 `ios/Runner.xcworkspace`를 엽니다 (`.xcodeproj` 아님)
- 레포가 **public**이므로 서버용 키(카카오 REST API 키·시크릿, Apple `.p8`, APNs 키)는 커밋하지 않습니다. 앱에 내장되는 공개 식별자(네이버 지도 Client ID, 카카오 네이티브 앱 키)만 포함되어 있습니다
