import SwiftUI
import WidgetKit

/// 확장의 **진입점**.
///
/// `TripActivityWidget` 은 `Widget` 일 뿐이라 그 자체로는 시스템에 등록되지
/// 않는다. `@main` 을 단 번들이 있어야 WidgetKit 이 무엇을 그릴지 안다 —
/// 이게 없으면 확장은 빌드도 되고 앱에도 실려 나가지만 **아무것도 뜨지
/// 않는다**(등록된 Swift 타입이 하나도 없다).
///
/// Xcode 템플릿이 만들어 주는 파일인데, 샘플이라 판단해 지웠다가 다시 넣었다.
@main
struct TripActivityBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.1, *) {
            TripActivityWidget()
        }
    }
}
