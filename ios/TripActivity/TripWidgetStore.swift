import Foundation

/// 홈·잠금화면 위젯이 읽는 **예정 여행 목록** — 앱이 써 두고 익스텐션이 읽는다.
///
/// 앱과 익스텐션은 저장소가 서로 달라, 같은 곳을 보려면 App Group 이 있어야
/// 한다(`group.com.nth.offway`, 두 타깃 모두 켜 둔다).
///
/// **고른 하나가 아니라 목록을 쓴다.** 하나만 써 두면 그 여행이 끝난 다음 날
/// 앱을 안 열었을 때 다음 여행으로 못 넘어간다. 날짜별로 무엇을 보여줄지는
/// 위젯이 시간표를 만들 때 `TripWidgetTrip.pick` 이 정한다 — 그 규칙은 Dart
/// `TripCountdown.pick` 과 같다(창 `within` 만 없다).
enum TripWidgetStore {
    /// Apple Developer 콘솔·두 타깃의 App Groups 와 같은 값이어야 한다
    static let appGroupId = "group.com.nth.offway"

    private static let tripsKey = "trip_widget.trips"
    private static let signedInKey = "trip_widget.signed_in"

    /// App Group 저장소. 그룹이 안 잡힌 빌드면 nil — 그때는 조용히 아무것도
    /// 안 쓴다(위젯이 빈 상태로 남을 뿐 앱은 그대로 간다)
    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupId) }

    /// 목록을 갈아 끼운다. 로그인한 사람의 것이므로 로그인 표시도 함께 세운다
    static func save(_ trips: [TripWidgetTrip]) throws {
        let data = try JSONEncoder().encode(trips)
        defaults?.set(data, forKey: tripsKey)
        defaults?.set(true, forKey: signedInKey)
    }

    /// 로그아웃·탈퇴 — 앞사람의 여행이 위젯에 남지 않게 비운다
    static func clear() {
        defaults?.removeObject(forKey: tripsKey)
        defaults?.removeObject(forKey: signedInKey)
    }

    static func load() -> [TripWidgetTrip] {
        guard let data = defaults?.data(forKey: tripsKey) else { return [] }
        return (try? JSONDecoder().decode([TripWidgetTrip].self, from: data)) ?? []
    }

    /// 로그인한 적이 있는가 — 위젯이 "여행 없음" 과 "로그인 전" 을 가른다
    static var isSignedIn: Bool { defaults?.bool(forKey: signedInKey) ?? false }
}

/// 위젯이 아는 여행 하나. 라이브 액티비티 `ContentState` 와 같은 칸이다 —
/// 새 계약이 아니라 그 재료를 목록으로 둔 것
struct TripWidgetTrip: Codable, Equatable {
    let courseId: String
    /// '정선군'
    let regionName: String
    /// `2026-09-23` — 출발일
    let startDate: String
    /// `2026-09-25` — 마지막날(포함)
    let endDate: String
}

extension TripWidgetTrip {
    /// 출발·종료를 읽는다. 못 읽거나 **종료가 출발보다 앞서면 nil** —
    /// 역전 데이터를 그대로 두면 지난 날짜에 'D--3' 이 찍힌다
    var range: (start: YMD, end: YMD)? {
        guard let s = YMD(startDate), let e = YMD(endDate),
              YMD.days(from: s, to: e) >= 0
        else { return nil }
        return (s, e)
    }

    /// 여행 중인가 — 첫날부터 마지막날까지
    func isOngoing(_ today: YMD) -> Bool {
        guard let r = range else { return false }
        return YMD.days(from: r.start, to: today) >= 0
            && YMD.days(from: today, to: r.end) >= 0
    }

    /// 이미 끝난 여행인가 — 마지막날이 지났으면
    func isPast(_ today: YMD) -> Bool {
        guard let r = range else { return true }
        return YMD.days(from: r.end, to: today) > 0
    }

    /// 그날 보여줄 여행 하나 — Dart `TripCountdown.pick` 과 같은 규칙.
    ///
    /// 1. 여행 중인 것이 있으면 그중 출발일이 가장 이른 것
    /// 2. 없으면 앞으로 올 것 중 출발일이 가장 가까운 것
    ///
    /// **며칠 뒤까지라는 창은 없다.** 라이브 액티비티는 잠금화면을 "차지" 하는
    /// 카드라 D-5 부터만 띄우지만, 위젯은 사용자가 스스로 붙여 둔 자리다 —
    /// 붙여 뒀는데 빈칸이면 뺀다. D-12 도 보여준다
    static func pick(_ trips: [TripWidgetTrip], today: YMD) -> TripWidgetTrip? {
        let valid = trips.filter { $0.range != nil }
        // ISO 날짜는 문자열 순서가 곧 날짜 순서다
        if let ongoing = valid.filter({ $0.isOngoing(today) })
            .min(by: { $0.startDate < $1.startDate })
        {
            return ongoing
        }
        return valid.filter { !$0.isPast(today) && !$0.isOngoing(today) }
            .min(by: { $0.startDate < $1.startDate })
    }

    /// 그날의 재료 — 문구 조립은 `ContentState` extension 이 한다.
    /// 지난 여행이면 nil
    @available(iOS 16.1, *)
    func contentState(today: YMD) -> TripActivityAttributes.ContentState? {
        guard let r = range, !isPast(today) else { return nil }
        if isOngoing(today) {
            return TripActivityAttributes.ContentState(
                regionName: regionName,
                daysLeft: nil,
                dayNth: YMD.days(from: r.start, to: today) + 1,
                startDate: startDate,
                endDate: endDate
            )
        }
        return TripActivityAttributes.ContentState(
            regionName: regionName,
            daysLeft: YMD.days(from: today, to: r.start),
            dayNth: nil,
            startDate: startDate,
            endDate: endDate
        )
    }
}

/// 위젯 시간표의 한 칸 — 그 시각부터 보여줄 것
@available(iOS 16.1, *)
struct TripWidgetSnapshot: Equatable {
    let date: Date
    /// 보여줄 여행. 없으면 빈 상태
    let state: TripActivityAttributes.ContentState?
    /// 로그인 전이면 "로그인하고 여행을 담아보세요"
    let signedIn: Bool
    /// 눌렀을 때 열 코스 — 보여줄 여행이 있을 때만
    var courseId: String? = nil

    /// 위젯을 눌렀을 때 앱이 받는 주소. 여행이 있으면 그 코스 상세,
    /// 없으면 코스 만들기. 앱의 `widgetDeepLinkRoute` 가 푼다
    var deepLink: URL? {
        if let id = courseId {
            return URL(string: "offway://course/\(id)")
        }
        return URL(string: signedIn ? "offway://wizard" : "offway://home")
    }
}

/// 자정마다 바뀌는 시간표 — **서버·푸시 없이** 시스템이 날짜에 맞춰 칸을 바꾼다.
///
/// 지금 순간 하나 + 앞으로 `days`일치 자정 하나씩. 앱이 다시 열려 목록을 갈아
/// 끼우면 시간표도 새로 만든다(`reloadAllTimelines`)
@available(iOS 16.1, *)
enum TripWidgetTimeline {
    static let defaultDays = 14

    static func entries(
        now: Date,
        trips: [TripWidgetTrip],
        signedIn: Bool,
        calendar: Calendar = .current,
        days: Int = defaultDays
    ) -> [TripWidgetSnapshot] {
        var result = [snapshot(at: now, trips: trips, signedIn: signedIn, calendar: calendar)]
        let startOfToday = calendar.startOfDay(for: now)
        for offset in 1..<max(days, 1) {
            guard let midnight = calendar.date(byAdding: .day, value: offset, to: startOfToday)
            else { continue }
            result.append(snapshot(at: midnight, trips: trips, signedIn: signedIn, calendar: calendar))
        }
        return result
    }

    static func snapshot(
        at date: Date,
        trips: [TripWidgetTrip],
        signedIn: Bool,
        calendar: Calendar = .current
    ) -> TripWidgetSnapshot {
        let today = YMD(date, calendar: calendar)
        let picked = TripWidgetTrip.pick(trips, today: today)
        let state = picked?.contentState(today: today)
        return TripWidgetSnapshot(
            date: date,
            state: state,
            signedIn: signedIn,
            courseId: state == nil ? nil : picked?.courseId
        )
    }
}
