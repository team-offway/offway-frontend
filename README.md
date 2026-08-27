# OffWay

> 연차로 떠나는 로컬 여행 플래너

남은 연차로 다녀올 수 있는 **인구감소지역** 여행 코스를 추천하는 iOS 앱입니다. 백엔드는 별도 레포([team-offway/core](https://github.com/team-offway/core), Java Spring)에서 REST API로 제공합니다.

[![App Store에서 다운로드](https://toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-app-store/black/ko-kr)](https://apps.apple.com/app/id6793610290)

## 서비스 소개

연차는 남았는데 어디로 갈지 정하기 어렵고, 인구감소지역은 좋은 콘텐츠가 있어도 잘 알려지지 않습니다. OffWay는 **남은 연차·이동수단·일정 취향**을 입력받아 도달 가능한 지역과 날짜별 코스를 만들어 줍니다.

**핵심 플로우**

```text
로그인 → 잔여연차 입력 → 홈
  └ 코스 추천받기
      ├ 날짜가 정해졌다면 → 캘린더에서 기간 선택
      └ 아직이라면      → 기간 스타일 선택 (당일치기 / 주말 포함 / 연차만)
          → 이동수단 → 일정 밀도 → 추천 계산 → 후보 지역 → 코스 확정
```

**핵심 정책** — 모든 코스는 **최대 2박3일**입니다. 인구감소지역 89곳을 전수 조사한 결과 콘텐츠가 40건 수준인 지역도 있어, 그 이상 길어지면 코스가 빈약해지기 때문입니다.

## 기술 스택

| 영역 | 선택 |
|---|---|
| 프레임워크 | Flutter 3.38 / Dart 3.10 |
| 상태관리 | flutter_riverpod 3 |
| 라우팅 | go_router |
| HTTP 클라이언트 | dio (JWT Auth 인터셉터 포함) |
| 토큰 저장 | flutter_secure_storage (iOS Keychain) |
| 모델/직렬화 | `Map<String, dynamic>` + 수동 `fromJson` (코드 생성 없음) |
| 지도 | flutter_naver_map (Dynamic Map) |
| 소셜 로그인 | kakao_flutter_sdk_user, sign_in_with_apple, google_sign_in |
| 공유 | kakao_flutter_sdk_share (카카오톡 공유 카드) |
| 푸시 | firebase_core, firebase_messaging (기기 등록·포그라운드 배너까지 연동) |

## 폴더 구조

```text
lib/
├── main.dart                  # 엔트리포인트 (SDK 초기화 + ProviderScope)
├── app/app.dart               # 루트 위젯 (MaterialApp.router)
├── core/                      # 앱 전역 공통 모듈
│   ├── config/app_config.dart     # API base URL·공개 키 (--dart-define 주입)
│   ├── network/dio_client.dart    # Dio 프로바이더 + Auth 인터셉터
│   ├── router/app_router.dart     # GoRouter 라우트 정의
│   ├── storage/secure_storage.dart# JWT 토큰 Keychain 저장소
│   └── theme/                     # Material 3 테마 + 디자인 토큰(tokens/)
├── mock/                      # 테스트 픽스처 로더 (앱 코드에서는 쓰지 않음)
└── features/                  # 기능(도메인) 단위 모듈
    ├── auth/                      # 로그인 (카카오·Apple·구글)
    ├── onboarding/                # 잔여연차 입력
    ├── home/                      # 홈
    ├── region/                    # 지역 상세
    ├── course_wizard/             # 코스 추천 위저드
    ├── course/                    # 코스 확정·내 코스·공유
    ├── leave/                     # 내 연차·사용 내역
    ├── notification/              # 알림
    ├── policy/                    # 약관·방침
    └── my/                        # 마이
```

새 기능은 `features/<기능명>/` 아래에 `data`(API·repository) / `domain`(모델) / `presentation`(화면·상태) 구조로 추가합니다.

## 실행

```bash
flutter run                                          # iOS 시뮬레이터 실행

# 배포 서버 접속 (권장)
flutter run --dart-define-from-file=env.json

# 주소만 따로 지정할 때 (로컬 백엔드 등)
flutter run --dart-define=API_BASE_URL=http://localhost:8080

# 특정 화면부터 시작 (개발용)
flutter run --dart-define=INITIAL_ROUTE=/wizard/calendar
```

`env.json`은 `env.json.example`을 복사해 만듭니다. 배포 서버가 임시 Basic 게이트 뒤에 있어 계정 없이 부르면 전부 401이 납니다. **gitignore 대상이라 커밋하지 않습니다.**

## 현재 상태

**App Store 정식 출시** (2026-08-27, v1.0.0). 전 화면이 실 서버와 연동되어 있고, mock 데이터는 테스트에서만 씁니다.

| 영역 | 상태 |
|---|---|
| 코스 추천 → 확정 → 내 코스 | 서버 연동 완료 |
| 카카오·Apple·구글 로그인 | 연동 완료 |
| 연차 등록·삭제·코스 차감/취소 (반반차 0.25일 지원) | 연동 완료 |
| 코스 공유 (카카오톡·링크·이미지·웹 페이지) | 연동 완료 |
| 지역 상세 · 이번달 추천 여행지 | 연동 완료 |
| 알림 목록 · 푸시(FCM) | 연동 완료 (기기 등록, 포그라운드 배너) |
| 회원탈퇴 | 연동 완료 |

사전 배포와 검증은 TestFlight로 진행합니다.

## 웹 (offway.cloud)

공유 링크를 받은 사람이 **앱 없이 브라우저에서** 코스를 보는 페이지와, 심사에 필요한 법적 문서를 함께 배포합니다. Vercel 프로젝트의 Root Directory는 `web/share`입니다.

| 주소 | 내용 |
|---|---|
| `/` | 서비스 소개 랜딩 |
| `/r/{token}` | 추천코스 공유 — 담기 전 코스를 공유한 링크 |
| `/m/{token}` | 내 코스 공유 — 담아둔 코스 (여행 날짜·사용 연차·D-DAY) |
| `/privacy` · `/terms` | 개인정보처리방침 · 이용약관 (한국어·영문) |

백엔드(`https://api.offway.cloud`)가 브라우저 직접 호출에 CORS를 열어 주지 않으므로, `web/share/api/*.js`가 같은 출처에서 받아 대신 부릅니다.

## 테스트 / 린트

```bash
flutter test        # 위젯·단위 테스트
flutter analyze
dart format .
```

PR마다 GitHub Actions가 포맷·분석·테스트를 검사하며, 통과해야 머지할 수 있습니다. `main` 직접 푸시는 브랜치 보호로 차단되어 있습니다.

## 비고

- 번들 ID: `com.nth.offway` · App Store 등록명: **[Offway - 연차로 떠나는 로컬 여행](https://apps.apple.com/app/id6793610290)**
- Xcode 작업 시 `ios/Runner.xcworkspace`를 엽니다 (`.xcodeproj` 아님)
- 카카오 앱 키를 바꿀 때는 `ios/Flutter/AppKeys.xcconfig`(URL scheme)와 `AppConfig`(SDK 초기화) **두 곳을 함께** 수정해야 합니다. 한쪽만 바꾸면 카카오톡에서 앱으로 복귀하지 못합니다
- 레포가 **public**이므로 시크릿은 어떤 형태로도 커밋하지 않습니다 (카카오 REST API 키·Admin 키·클라이언트 시크릿, Apple `.p8`·APNs 키, 네이버 지도 Client Secret 등 — 서버가 쓰는 값은 백엔드 환경변수로만 관리)
- 예외적으로 **제공자가 공개 식별자로 명시했고 콘솔에서 번들 ID(`com.nth.offway`) 제한이 걸린 값**만 포함되어 있습니다: 네이버 지도 Client ID, 카카오 네이티브 앱 키, 구글 `REVERSED_CLIENT_ID`. 그 외 값은 `--dart-define`으로 주입합니다
