import ActivityKit
import Foundation

/// 잠금화면·다이나믹 아일랜드에 띄우는 여행 D-day.
///
/// **문구는 Flutter 가 만들어 넘긴다.** 네이티브가 한국어를 조립하면 같은
/// 말을 두 곳에서 관리하게 된다 — 여기서는 받은 문자열을 그리기만 한다.
///
/// `ContentState` 의 모양은 서버가 푸시로 갱신할 때 그대로 맞춰야 하는
/// 계약이다(2단계). 지금은 앱이 켜져 있을 때만 갱신한다.
@available(iOS 16.1, *)
struct TripActivityAttributes: ActivityAttributes {
    /// 살아 있는 동안 바뀌지 않는 값
    let courseId: String
    let regionName: String

    struct ContentState: Codable, Hashable {
        /// '정선군 여행 D-3' · '정선군 여행 2일차' — 앱이 만든 한 줄
        let headline: String

        /// '2026.9.23 - 9.25'
        let rangeLabel: String

        /// '2박 3일'
        let durationLabel: String

        /// 'D-3' · '2일차' — 다이나믹 아일랜드 좁은 자리에 넣는 한 토막.
        ///
        /// **네이티브에서 조건으로 만들지 않는다.** 좁은 자리에 분기를 두면
        /// 여행 중일 때 자리가 빈 채로 남는다 — 앱이 만든 문자열을 그대로 쓴다
        let compactLabel: String
    }
}
