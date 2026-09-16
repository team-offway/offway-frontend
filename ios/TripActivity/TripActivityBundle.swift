import SwiftUI
import WidgetKit

/// 확장의 **진입점**.
///
/// `TripActivityWidget` 은 `Widget` 일 뿐이라 그 자체로는 시스템에 등록되지
/// 않는다. `@main` 을 단 번들이 있어야 WidgetKit 이 무엇을 그릴지 안다.
///
/// **`body` 안에서 `if #available` 을 쓰지 않는다.** `some Widget` 을
/// 돌려주는 자리라 조건 분기를 두면 위젯이 비어 버린다(확장은 뜨는데
/// 화면이 검게 나온다). 버전 제약은 구조체에 `@available` 로 단다.
@available(iOS 16.1, *)
@main
struct TripActivityBundle: WidgetBundle {
    var body: some Widget {
        // 라이브 액티비티(앱이 띄우는 8시간 카드)와 위젯(사용자가 붙이는 상시)
        TripActivityWidget()
        TripWidget()
    }
}
