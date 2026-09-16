# 다이나믹 아일랜드 — 설정 현황

**2026-09-14: Xcode 연결까지 끝났다.** `flutter build ios` 가 통과하고
`Runner.app/PlugIns/TripActivityExtension.appex` 가 들어간다.

## 끝난 것

- [x] 최소 버전 — **확장만 16.1**, 앱(Runner·Podfile)은 **15.0 그대로**

  앱까지 올리면 iOS 15 기기(6s·7·SE1)가 **앱 자체를 업데이트받지 못한다.**
  그 기기들은 Live Activity 를 어차피 못 쓴다(16.1+ API 인 데다 다이나믹
  아일랜드는 14 Pro 부터의 하드웨어다) — 얻는 것 없이 코스 추천·연차
  계산까지 통째로 잃는다. 15.x 에서는 `isAvailable()` 이 false 라 조용히
  아무 일도 하지 않는다
- [x] Widget Extension 타겟 `TripActivityExtension` 생성
- [x] `TripActivityAttributes.swift` — `ios/TripActivity/` 로 옮겨 **양쪽 타겟**이 읽는다
- [x] `TripActivityWidget.swift` — 동기화 폴더라 자동으로 확장 소속
- [x] `TripActivityBridge.swift` — Runner 타겟에 등록
- [x] `Runner/Info.plist` 에 `NSSupportsLiveActivities`
- [x] 샘플 파일(`TripActivityControl.swift` 등) 삭제

## 앱에서 켜는 것도 끝났다

`app/app.dart` 의 `initState` 에서 부른다.

```dart
if (ref.read(postSplashRouteProvider) == AppRoutes.home) {
  ref.read(tripActivityControllerProvider).start();
}
```

**`main()` 이 아니라 여기다** — `main()` 은 `runApp` 전이라 `ref` 가 없고,
로그인 여부도 여기서만 가릴 수 있다. 로그인 전에 부르면 예정 코스를 읽는
요청이 401 을 맞는다.

`start()` 는 앱이 포그라운드로 돌아올 때마다 스스로 다시 맞춘다.

## 확인 방법

**시뮬레이터에서도 된다.** 다이나믹 아일랜드가 있는 기종(iPhone 14 Pro
이상)을 고르면 된다. 13 Pro 같은 노치 기종은 실기기든 시뮬레이터든
잠금화면 카드만 보인다 — 아일랜드 자체가 없는 하드웨어다.

1. 내 코스에 **5일 안쪽 날짜**로 코스를 담는다
2. **홈 화면으로 나간다**
3. 알약 양옆에 `D-3` 이, 잠금화면에 카드가 뜨는지 본다

**앱을 보고 있는 동안에는 알약이 안 뜬다.** 그 화면에 이미 정보가 있어
시스템이 접어 두는 iOS 동작이다(지도앱 길안내와 같다) — 고장이 아니다.

실기기에 붙일 때는 `--profile` 로 빌드한다. `--debug` 바이너리는 Dart
코드를 맥의 Flutter 툴에서 받아오므로, `flutter run` 이나 Xcode 없이
단독 실행하면 엔진이 못 떠서 `signal 11` 로 죽는다.

## 겪은 것 — 다시 만나면

**빌드 사이클(`Cycle inside Runner`)** — Xcode 가 `Embed Foundation Extensions`
페이즈를 **맨 뒤**에 넣는데, Flutter·CocoaPods 스크립트가 같은 앱 번들을
매만지므로 순환이 생긴다. 그 페이즈를 **`Resources` 바로 뒤**로 옮기면
풀린다(appex 가 먼저 들어가고 그 뒤에 스크립트가 손댄다).

**`pod install` 이 objectVersion 을 모른다고 실패** — Xcode 26 이 새 프로젝트에
쓰는 형식을 CocoaPods 1.16.2 가 못 읽는다. 지금은 `objectVersion = 54` 로
낮춰 둬서 재현되지 않는다 — 다시 올라가면 이 증상이 돌아온다.

**동기화 폴더** — Xcode 26 은 `TripActivity` 를
`PBXFileSystemSynchronizedRootGroup` 으로 만든다. 그 폴더의 `.swift` 는
따로 등록하지 않아도 확장 타겟에 들어간다(그래서 Add Files 에서 회색으로
보인다). 반대로 **`ios/Runner/` 는 옛 방식**이라 손으로 등록해야 한다.

## 안 한 것

**시안 반영** — 지금은 SF Symbol·시스템 서체로만 배치해 뒀다. 디자인이
나오면 `TripActivityWidget.swift` 의 뷰만 갈아 끼우면 된다(값 전달 경로는
그대로다).

## 서버가 자정마다 갱신한다 — core #577 (B안)

앱이 꺼져 있어도 `D-3` 이 `D-2` 로 바뀐다. 서버가 APNs 를 직접 불러
(FCM 은 Live Activity 를 중계하지 않는다) 카드를 갱신한다.

**재료는 앱과 서버가, 문구는 네이티브가.** `ContentState` 는 `regionName` ·
`daysLeft` · `dayNth` · `startDate` · `endDate` 다섯 칸이고, 앱이 띄울 때도
서버가 갱신할 때도 같은 칸을 넣는다. 조립은 `TripActivityAttributes.swift` 의
`ContentState` extension 한 곳이다 — 카피를 바꿀 때 서버를 고칠 일이 없다. 규칙은 `RunnerTests` 의
`TripPhraseTests` 가 잠근다.

**칸 이름이 하나라도 어긋나면 오류 없이 화면만 안 바뀐다.** 서버
`ApnsPayload` 와 1:1 이라, 바꿀 일이 생기면 양쪽을 같은 PR 에서 고친다.

흐름: 카드를 띄우면(`pushType: .token`) iOS 가 토큰을 주고 → 네이티브가
`onPushToken` 으로 Dart 에 올리고 → `LiveActivityRepository` 가
`POST /api/v1/live-activities` 로 등록한다. 카드를 내리면 `DELETE` 로 지운다.
등록은 멱등이라 토큰이 다시 와도 같은 요청을 다시 보내면 된다.

**서버에 APNs 키가 들어가야 산다.** `APNS_KEY_ID` 등 환경변수가
비어 있으면 서버는 갱신만 끄고 부팅한다(`ApnsResult.DISABLED`). 키는
Sign in with Apple 과 같은 `.p8` 이고, core #582 가 `deploy.yml` 에 배선해
운영에 들어갔다(2026-09-16).

## 카드는 8시간짜리다 — Apple 제약

라이브 액티비티는 **앱이나 사람이 끝내지 않아도 8시간이 지나면 시스템이
끝낸다.** 끝나는 순간 다이나믹 아일랜드에서 사라지고, 잠금화면에는 최대
4시간 더(총 12시간) 남은 뒤 치워진다. 푸시 갱신은 이 8시간을 늘려 주지
않는다(Apple ActivityKit "Displaying live data with Live Activities").

그래서 지금 구조에서 자정 갱신이 실제로 먹는 건 **그날 16시 이후에 앱을
열어 카드를 띄운 경우**뿐이다. 낮에 띄운 카드는 자정 전에 이미 끝나 있다.
며칠 내내 잠금화면에 붙어 있게 하려면 서버가 하루 몇 번씩 새로 띄우는
push-to-start(iOS 17.2+, 이슈 #287)가 필요하고, 그것도 한 번에 8시간이다.

**끝난 카드를 "떠 있다"고 착각하지 않는다.** 시스템이 끝낸 카드는 잠금화면에
남아 있는 동안 `Activity.activities` 에도 `.ended` 로 남는다. `startOrUpdate`
는 `activityState == .active` 인 것만 갱신 대상으로 보고, 아니면 남은 것을
치우고 새로 띄운다 — 안 그러면 앱을 다시 열어도 카드가 안 살아난다.

**끝까지 확인하려면 TestFlight 빌드여야 한다.** 개발 빌드(시뮬레이터·
Xcode 실기기)의 토큰은 sandbox 라 운영 APNs 로 안 닿는다. 카드를 띄워 두고
자정을 넘겨 봐야 갱신이 오는지 안다.

## 위젯 — 상시 D-day (이슈 #297)

라이브 액티비티가 8시간짜리라, **며칠 내내 잠금화면·홈에 붙어 있는 D-day** 는
위젯(WidgetKit)이 맡는다. 사용자가 직접 붙이고, 시간 제한이 없고, 자정에
숫자가 바뀌는 것도 서버 없이 된다.

```
Flutter sync()  ─(예정 코스 목록)─▶  App Group UserDefaults  ◀─읽기─  TripWidget
   TripActivityService                 group.com.nth.offway            14일치 자정 시간표
   .setWidgetTrips / .clearWidget      TripWidgetStore                  → 시스템이 날짜에 맞춰 교체
                        └─▶ WidgetCenter.reloadAllTimelines()
```

- **저장은 목록, 선택은 위젯이.** 앱은 지난 여행을 뺀 예정 코스 목록을 통째로
  쓴다. 어느 날 무엇을 보여줄지는 `TripWidgetTrip.pick` 이 날짜별로 정한다 —
  Dart `TripCountdown.pick` 과 같은 규칙에 **창(D-5)만 없다.** 위젯은 사용자가
  붙여 둔 자리라 D-12 도 보여준다
- **문구는 라이브 액티비티와 같은 곳**(`ContentState` extension)이 조립한다
- 라이브 액티비티를 설정에서 껐어도 위젯은 쓴다 — `sync()` 가 `isAvailable()`
  보다 먼저 저장소를 쓴다
- 코스를 못 읽으면 위젯은 그대로 둔다(날짜는 스스로 세니 알던 여행엔 맞다).
  로그아웃·탈퇴(`stop()`)에서는 비운다 — 앞사람의 여행이 남지 않게
- 파일: `TripWidgetStore.swift`(앱·익스텐션 둘 다), `TripWidget.swift`(익스텐션),
  번들 `TripActivityBundle` 에 `TripWidget()` 추가. 새 타깃 없음 — 익스텐션
  배포 타깃 16.1 이라 iOS 15 는 위젯도 못 받는다(라이브 액티비티와 같은 선)

**App Group 이 있어야 한다.** 두 타깃의 entitlements 에
`com.apple.security.application-groups` = `group.com.nth.offway`. 그룹은 Apple
Developer 콘솔에 등록돼 있어야 실기기 서명이 통과한다(시뮬레이터는 안 따진다).

자리는 넷 — 홈 소형(`systemSmall`), 잠금화면 직사각형·원형·한 줄
(`accessoryRectangular`·`accessoryCircular`·`accessoryInline`). 잠금화면 세
자리는 iOS 가 배경화면에 맞춰 흰색·반투명으로 그리므로 우리 색이 안 먹는다 —
글자와 SF Symbol 만 쓴다. 홈 중형은 시안이 나오면.

**누르면 앱이 열린다.** 위젯은 `offway://course/{id}`(보여주던 여행) ·
`offway://wizard`(예정 없음) · `offway://home`(로그인 전)을 만들고
(`TripWidgetSnapshot.deepLink`), 앱은 `widgetDeepLinkRoute` 가 화면으로
푼다(`DeepLinkListener`, 공유 링크보다 먼저 가른다). 스킴은 `Info.plist`
`CFBundleURLSchemes` 의 `offway`.

**사용자가 직접 붙여야 한다** — iOS 에 앱이 대신 넣는 API 가 없다. 마이 메뉴
"여행 D-day 위젯" 이 잠금화면·홈 두 자리의 순서를 안내한다(`showWidgetGuideSheet`,
시안 없이 텍스트).

시뮬레이터에서 확인: 앱을 한 번 실행해 로그인한 뒤, 홈 화면 길게 → `+` →
OffWay → "여행 D-day". 잠금화면은 잠금화면 길게 → 사용자화 → 시계 아래 칸.
