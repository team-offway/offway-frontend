import ActivityKit
import Foundation

/// 잠금화면·다이나믹 아일랜드에 띄우는 여행 D-day.
///
/// **서버와 앱이 같은 재료를 넣는다.** 앱이 켜져 있을 때는 Flutter 가, 자정에는
/// 서버가(core #577) `ContentState` 를 채운다. 어느 쪽이 채우든 **문구는 여기서
/// 조립한다** — 조립이 한 곳이라 두 경로가 다른 말을 하지 않고, 카피를 바꿀 때
/// 서버를 고칠 일이 없다.
///
/// `ContentState` 의 칸 이름은 서버 `ApnsPayload` 와 **1:1** 이다. 하나라도
/// 어긋나면 iOS 가 디코딩에 실패하는데, 오류 없이 화면만 안 바뀐다.
@available(iOS 16.1, *)
struct TripActivityAttributes: ActivityAttributes {
    /// 살아 있는 동안 바뀌지 않는 값 — 같은 코스를 찾는 열쇠다
    let courseId: String

    struct ContentState: Codable, Hashable {
        /// '정선군'
        let regionName: String

        /// 남은 날. **출발 전에만 값이 있다.** 여행 중이면 nil
        let daysLeft: Int?

        /// 여행 며칠째(출발 당일이 1). **여행 중에만 값이 있다.** 출발 전이면 nil
        let dayNth: Int?

        /// `2026-09-23` — 출발일
        let startDate: String

        /// `2026-09-25` — 마지막날(포함)
        let endDate: String
    }
}

// MARK: - 문구 조립

/// 재료를 화면에 쓸 말로 바꾼다.
///
/// 규칙은 셋이다. 바꾸고 싶으면 **여기만** 고친다 — 서버는 숫자만 보내고
/// 이 규칙을 모른다.
///
/// 1. 출발 당일은 `D-DAY` 가 아니라 **`1일차`** 다. 이미 떠나온 사람에게 D-0 은
///    알려 주는 것이 없다
/// 2. **D-1 만** 잠금화면 문구가 `내일 …` 이다. 좁은 자리는 `D-1` 그대로다
/// 3. 기간·날짜 범위는 두 날짜에서 만든다 — 서버가 따로 보내지 않는다
@available(iOS 16.1, *)
extension TripActivityAttributes.ContentState {
    /// '정선군 여행 D-3' · '내일 정선군 여행' · '정선군 여행 2일차'
    var headline: String {
        if let nth = dayNth { return "\(regionName) 여행 \(nth)일차" }
        guard let left = daysLeft else { return "\(regionName) 여행" }
        // 둘 다 안 보내는 쪽이 정상이지만, 0 이 오면 당일로 친다
        if left <= 0 { return "\(regionName) 여행 1일차" }
        if left == 1 { return "내일 \(regionName) 여행" }
        return "\(regionName) 여행 D-\(left)"
    }

    /// 'D-3' · '2일차' — 알약 옆 좁은 자리. 지역명은 안 들어간다
    var compactLabel: String {
        if let nth = dayNth { return "\(nth)일차" }
        guard let left = daysLeft else { return "여행" }
        if left <= 0 { return "1일차" }
        return "D-\(left)"
    }

    /// '2026.9.23 - 9.25' — 해를 넘기면 끝날에도 연도를 붙인다
    var rangeLabel: String {
        guard let s = YMD(startDate), let e = YMD(endDate) else { return startDate }
        let head = "\(s.y).\(s.m).\(s.d)"
        if s == e { return head }
        let tail = s.y == e.y ? "\(e.m).\(e.d)" : "\(e.y).\(e.m).\(e.d)"
        return "\(head) - \(tail)"
    }

    /// '당일치기' · '1박 2일' · '2박 3일'
    var durationLabel: String {
        guard let s = YMD(startDate), let e = YMD(endDate) else { return "" }
        let nights = max(0, YMD.days(from: s, to: e))
        return nights == 0 ? "당일치기" : "\(nights)박 \(nights + 1)일"
    }
}

/// `yyyy-MM-dd` 한 토막. 시간대·서머타임과 무관하게 **달력 날짜로만** 센다 —
/// 잠금화면 D-day 가 하루 틀리면 기능이 있으나 마나다
private struct YMD: Equatable {
    let y: Int
    let m: Int
    let d: Int

    init?(_ text: String) {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        (y, m, d) = (parts[0], parts[1], parts[2])
    }

    /// 두 날짜 사이 일수 — UTC 그레고리력으로 고정해 어디서 돌려도 같다
    static func days(from a: YMD, to b: YMD) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        guard let da = cal.date(from: DateComponents(year: a.y, month: a.m, day: a.d)),
              let db = cal.date(from: DateComponents(year: b.y, month: b.m, day: b.d))
        else { return 0 }
        return cal.dateComponents([.day], from: da, to: db).day ?? 0
    }
}
