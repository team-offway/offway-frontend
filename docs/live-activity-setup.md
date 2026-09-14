# 다이나믹 아일랜드 — 설정 현황

**2026-09-14: Xcode 연결까지 끝났다.** `flutter build ios` 가 통과하고
`Runner.app/PlugIns/TripActivityExtension.appex` 가 들어간다.

## 끝난 것

- [x] 최소 버전 **16.1** (Runner·Extension·Podfile 전부)
- [x] Widget Extension 타겟 `TripActivityExtension` 생성
- [x] `TripActivityAttributes.swift` — `ios/TripActivity/` 로 옮겨 **양쪽 타겟**이 읽는다
- [x] `TripActivityWidget.swift` — 동기화 폴더라 자동으로 확장 소속
- [x] `TripActivityBridge.swift` — Runner 타겟에 등록
- [x] `Runner/Info.plist` 에 `NSSupportsLiveActivities`
- [x] 샘플 파일(`TripActivityControl.swift` 등) 삭제

## 앱에서 켜는 것만 남았다

아직 아무도 `start()` 를 부르지 않아 **실제로는 안 뜬다.** 한 줄이면 된다.

```dart
ref.read(tripActivityControllerProvider).start();
```

넣을 자리 후보 — 홈 화면 `initState`, 또는 `main.dart` 의 앱 시작 직후.
`start()` 는 앱이 포그라운드로 돌아올 때마다 스스로 다시 맞춘다.

## 확인 방법

실기기에서만 된다 — 시뮬레이터는 다이나믹 아일랜드를 흉내만 낸다.

1. 내 코스에 **7일 안쪽 날짜**로 코스를 담는다
2. 앱을 백그라운드로 보낸다
3. 잠금화면·다이나믹 아일랜드에 `정선군 여행 D-3` 이 뜨는지 본다

## 겪은 것 — 다시 만나면

**빌드 사이클(`Cycle inside Runner`)** — Xcode 가 `Embed Foundation Extensions`
페이즈를 **맨 뒤**에 넣는데, Flutter·CocoaPods 스크립트가 같은 앱 번들을
매만지므로 순환이 생긴다. 그 페이즈를 **`Resources` 바로 뒤**로 옮기면
풀린다(appex 가 먼저 들어가고 그 뒤에 스크립트가 손댄다).

**`pod install` 이 objectVersion 70 을 모른다고 실패** — Xcode 26 이 쓰는
형식을 CocoaPods 1.16.2 가 아직 못 읽는다. 다만 `flutter build` 안에서
도는 pod install 은 통과하므로 실사용에 문제는 없었다.

**동기화 폴더** — Xcode 26 은 `TripActivity` 를
`PBXFileSystemSynchronizedRootGroup` 으로 만든다. 그 폴더의 `.swift` 는
따로 등록하지 않아도 확장 타겟에 들어간다(그래서 Add Files 에서 회색으로
보인다). 반대로 **`ios/Runner/` 는 옛 방식**이라 손으로 등록해야 한다.

## 안 한 것

**서버 푸시 갱신**(이슈 #261 2단계) — 앱이 꺼져 있는 동안에는 값이 안 바뀐다.
자정을 넘겨도 다음에 앱을 열 때 맞춰진다. 푸시로 갱신하려면 서버가 APNs 를
직접 불러야 하는데(FCM 은 Live Activity 를 중계하지 않는다) core 작업이 필요하다.
