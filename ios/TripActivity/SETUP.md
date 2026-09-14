# 다이나믹 아일랜드 — Xcode에서 손으로 해야 하는 것

여기 Swift 파일들은 **아직 어떤 타겟에도 속해 있지 않다.** Xcode에서
Widget Extension 타겟을 만들어 붙여야 빌드에 들어간다.

Flutter 쪽(Dart)은 끝났다 — 값 계산·채널·컨트롤러·테스트 모두 있다.
아래만 하면 실기기에서 뜬다.

## 1. 최소 버전을 16.1로 올린다

Live Activity는 iOS 16.1+ 에서만 된다. 지금은 15.0이다.

- `ios/Podfile` 1행 → `platform :ios, '16.1'`
- Xcode → Runner 타겟 → Build Settings → **iOS Deployment Target** → 16.1
- `pod install` 다시

**15.x 기기는 앱 설치가 막힌다.** 2026년 기준 점유율이 1% 안팎이라
실질 영향은 작지만, 기존 TestFlight 테스터 중 15.x가 있으면 업데이트를
못 받는다.

## 2. Widget Extension 타겟을 만든다

Xcode → File → New → Target → **Widget Extension**

- Product Name: `TripActivity`
- **Include Live Activity** 체크 (중요)
- Include Configuration Intent 해제
- 만들면서 생기는 샘플 파일(`TripActivity.swift` 등)은 지운다

## 3. 이 폴더의 파일을 타겟에 넣는다

| 파일 | 속할 타겟 |
|---|---|
| `TripActivityAttributes.swift` | **Runner + TripActivity 둘 다** |
| `TripActivityWidget.swift` | TripActivity |
| `../Runner/TripActivityBridge.swift` | Runner |

`TripActivityAttributes.swift`가 양쪽에 있어야 한다 — 앱이 값을 만들고
확장이 그 값을 읽기 때문이다. Xcode 오른쪽 File Inspector의
**Target Membership**에서 둘 다 체크한다.

## 4. 확장의 Info.plist

새로 생긴 `TripActivity/Info.plist`에 아래가 있는지 확인한다
(Include Live Activity를 체크했으면 자동으로 들어간다).

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

`Runner/Info.plist`에는 **이미 넣어 뒀다.**

## 5. 앱에서 켜기

`main.dart`나 홈 화면에서 한 번 부르면 된다.

```dart
ref.read(tripActivityControllerProvider).start();
```

`start()`는 앱이 포그라운드로 돌아올 때마다 스스로 다시 맞춘다.

## 확인

실기기에서 — 시뮬레이터는 다이나믹 아일랜드를 흉내만 낸다.

1. 내 코스에 **7일 안쪽 날짜**로 코스를 담는다
2. 앱을 백그라운드로 보낸다
3. 잠금화면과 다이나믹 아일랜드에 `정선군 여행 D-3`이 뜨는지 본다

## 지금 안 하는 것

- **서버 푸시 갱신**(이슈 #261 2단계) — 앱이 꺼져 있는 동안에는 값이
  안 바뀐다. 자정을 넘겨도 다음에 앱을 열 때 맞춰진다. 푸시로 갱신하려면
  서버가 APNs를 직접 불러야 하는데(FCM은 Live Activity를 중계하지 않는다)
  그건 core 작업이 필요하다
- **App Group** — 지금은 MethodChannel로 값을 넘기므로 필요 없다.
  확장이 스스로 데이터를 읽어야 할 때만 필요하다
