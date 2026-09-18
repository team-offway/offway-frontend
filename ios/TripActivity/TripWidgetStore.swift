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
///
/// **로그인 표시와 목록은 다른 사실이라 따로 쓴다.** 로그인 표시는 세션이
/// 시작·끝나는 자리(Dart `start()`·`stop()`)가, 목록은 코스를 맞출 때마다 쓴다.
/// 한 키에 묶으면 첫 조회가 실패한 사용자의 위젯이 "로그인하세요" 로 보인다
enum TripWidgetStore {
    /// Apple Developer 콘솔·두 타깃의 App Groups 와 같은 값이어야 한다
    static let appGroupId = "group.com.nth.offway"

    /// 위젯 종류 이름 — `TripWidget.kind`. 앱이 이 종류만 다시 그리게 한다
    static let widgetKind = "TripWidget"

    private static let tripsKey = "trip_widget.trips"
    private static let signedInKey = "trip_widget.signed_in"

    /// App Group 저장소.
    ///
    /// **엔타이틀먼트가 빠져도 nil 이 아니다** — 그때는 공유되지 않는 사적 컨테이너를
    /// 돌려주고 콘솔에 경고만 남긴다. 그러면 앱은 "썼다" 고 아는데 위젯은 빈 채로
    /// 남으니, 서명된 앱·익스텐션 둘 다에 그룹이 든 것을 빌드 때 확인한다
    static let defaults = UserDefaults(suiteName: appGroupId) ?? .standard

    /// 목록을 갈아 끼운다. **바뀌었을 때만** 참 — 같은 목록이면 위젯을 다시
    /// 그릴 이유가 없다(앱 재개마다 부르는 자리다)
    @discardableResult
    static func save(_ trips: [TripWidgetTrip]) throws -> Bool {
        // 값으로 비교한다 — 바이트는 인코더 사정에 따라 같은 목록도 다를 수 있다
        if load() == trips { return false }
        defaults.set(try JSONEncoder().encode(trips), forKey: tripsKey)
        return true
    }

    /// 세션이 시작됐다 — 목록이 아직 없어도 "로그인 전" 으로 보이지 않게
    static func markSignedIn() {
        defaults.set(true, forKey: signedInKey)
    }

    /// 로그아웃·탈퇴 — 앞사람의 여행이 위젯에 남지 않게 비운다
    static func clear() {
        defaults.removeObject(forKey: tripsKey)
        defaults.removeObject(forKey: signedInKey)
    }

    static func load() -> [TripWidgetTrip] {
        guard let data = defaults.data(forKey: tripsKey) else { return [] }
        return (try? JSONDecoder().decode([TripWidgetTrip].self, from: data)) ?? []
    }

    /// 로그인한 세션인가 — 위젯이 "여행 없음" 과 "로그인 전" 을 가른다
    static var isSignedIn: Bool { defaults.bool(forKey: signedInKey) }
}

/// 여행 하루치 — 그날의 날씨와 들를 곳.
///
/// **위젯에만 있다.** 라이브 액티비티 `ContentState` 는 서버 푸시와 칸이
/// 1:1 이라(core #577) 여기를 건드리면 서버도 바뀐다
struct TripWidgetDay: Codable, Equatable {
    /// 1 부터. 출발 당일이 1 이다
    let day: Int
    /// '맑음'·'비' — 서버가 주는 한글 값. 없으면 위젯이 로고를 그린다
    let sky: String?
    /// 그날 들를 곳 이름. **최대 넷**까지 온다(시안이 네 줄이다)
    let places: [String]

    /// Flutter 채널 인자에서 읽는다. `day` 가 없으면 쓸 수 없다
    init?(channelArgs args: [String: Any]) {
        guard let day = args["day"] as? Int else { return nil }
        self.day = day
        self.sky = args["sky"] as? String
        self.places = args["places"] as? [String] ?? []
    }
}

/// 위젯이 아는 여행 하나. 라이브 액티비티 `ContentState` 와 같은 칸에
/// **일자별 날씨·장소**([days])를 더한 것이다
struct TripWidgetTrip: Codable, Equatable {
    let courseId: String
    /// '정선군'
    let regionName: String
    /// `2026-09-23` — 출발일
    let startDate: String
    /// `2026-09-25` — 마지막날(포함)
    let endDate: String
    /// 일자별 날씨·장소. **비어 있을 수 있다** — 코스 상세를 못 읽었거나
    /// 위젯에 뜰 여행이 아니면 앱이 싣지 않는다
    let days: [TripWidgetDay]

    init(
        courseId: String,
        regionName: String,
        startDate: String,
        endDate: String,
        days: [TripWidgetDay] = []
    ) {
        self.courseId = courseId
        self.regionName = regionName
        self.startDate = startDate
        self.endDate = endDate
        self.days = days
    }

    /// **`days` 가 없는 옛 데이터도 읽는다.** 앱을 업데이트한 직후 디스크에는
    /// 이 칸이 없는 목록이 들어 있다 — 기본값을 안 두면 통째로 디코딩에
    /// 실패해 위젯이 "예정된 여행이 없어요" 로 보인다
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        courseId = try c.decode(String.self, forKey: .courseId)
        regionName = try c.decode(String.self, forKey: .regionName)
        startDate = try c.decode(String.self, forKey: .startDate)
        endDate = try c.decode(String.self, forKey: .endDate)
        days = try c.decodeIfPresent([TripWidgetDay].self, forKey: .days) ?? []
    }

    /// Flutter 채널 인자에서 읽는다 — 라이브 액티비티 `start` 와 위젯 목록이
    /// 같은 네 칸을 같은 이름으로 싣는다. 하나라도 빠지면 nil.
    /// `days` 는 위젯만 싣는 값이라 없어도 된다
    init?(channelArgs args: [String: Any]) {
        guard let courseId = args["courseId"] as? String,
              let regionName = args["regionName"] as? String,
              let startDate = args["startDate"] as? String,
              let endDate = args["endDate"] as? String
        else { return nil }
        self.init(
            courseId: courseId,
            regionName: regionName,
            startDate: startDate,
            endDate: endDate,
            days: (args["days"] as? [[String: Any]] ?? [])
                .compactMap(TripWidgetDay.init(channelArgs:))
        )
    }
}

extension TripWidgetTrip {
    /// 출발·종료를 읽는다. 못 읽거나 **종료가 출발보다 앞서면 nil** —
    /// 디스크의 옛 데이터·역전 데이터를 그대로 두면 지난 날짜에 'D--3' 이 찍힌다
    var range: (start: YMD, end: YMD)? {
        guard let s = YMD(startDate), let e = YMD(endDate), s <= e else { return nil }
        return (s, e)
    }

    /// 그날 보여줄 여행 하나 — Dart `TripCountdown.pick` 과 같은 규칙.
    ///
    /// 1. 여행 중인 것이 있으면 그중 출발일이 가장 이른 것
    /// 2. 없으면 앞으로 올 것 중 출발일이 가장 가까운 것
    ///
    /// **며칠 뒤까지라는 창은 없다.** 라이브 액티비티는 잠금화면을 "차지" 하는
    /// 카드라 D-5 부터만 띄우지만, 위젯은 사용자가 스스로 붙여 둔 자리다 —
    /// 붙여 뒀는데 빈칸이면 뺀다. D-12 도 보여준다.
    ///
    /// 지난 여행·역전 데이터는 돌려주지 않는다
    static func pick(_ trips: [TripWidgetTrip], today: YMD) -> TripWidgetTrip? {
        let parsed = trips.compactMap { trip in trip.range.map { (trip: trip, range: $0) } }
        let ongoing = parsed.filter { $0.range.start <= today && today <= $0.range.end }
        if let now = ongoing.min(by: { $0.range.start < $1.range.start }) { return now.trip }
        return parsed.filter { today < $0.range.start }
            .min(by: { $0.range.start < $1.range.start })?.trip
    }

    /// 그날의 재료 — 문구 조립은 `ContentState` extension 이 한다.
    /// 지난 여행이면 nil
    @available(iOS 16.1, *)
    func contentState(today: YMD) -> TripActivityAttributes.ContentState? {
        guard let r = range, today <= r.end else { return nil }
        let untilStart = YMD.days(from: today, to: r.start)
        return TripActivityAttributes.ContentState(
            regionName: regionName,
            // 둘 중 하나만 값이 있다 — 출발 전이냐 여행 중이냐
            daysLeft: untilStart > 0 ? untilStart : nil,
            dayNth: untilStart > 0 ? nil : -untilStart + 1,
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
    /// 그 여행의 코스 — 눌렀을 때 열 곳. `state` 와 함께 있거나 함께 없다
    let courseId: String?
    /// 로그인 전이면 "로그인하고 여행을 담아보세요"
    let signedIn: Bool

    /// 그날 보여줄 하루치 — 날씨와 들를 곳.
    ///
    /// **출발 전에는 첫날 것을 보여준다.** D-1 에 "곧 갈 날" 의 날씨와 코스를
    /// 미리 보는 자리라, 아직 시작 안 한 여행에 2일차를 띄울 이유가 없다.
    /// 여행 중이면 그 일자 것이다
    let day: TripWidgetDay?

    /// 빈 상태 문구 — 다섯 자리가 같은 말을 한다
    /// (시안 1669:42215 · 1669:42239)
    var emptyTitle: String {
        signedIn ? "예정된 여행이 없어요" : "로그인이 필요해요"
    }

    /// 빈 상태 둘째 줄 — **로그인 전에도 있다**(시안 1669:42253)
    var emptySubtitle: String {
        signedIn ? "다음 여행을 계획해보세요" : "여행 D-day를 확인해보세요"
    }

    /// 위젯을 눌렀을 때 앱이 받는 주소. 여행이 있으면 그 코스 상세,
    /// 없으면 코스 만들기, 로그인 전이면 홈. 앱의 `widgetDeepLinkRoute` 가 푼다
    ///
    /// **보여 주던 일자를 함께 싣는다**(`?day=2`, #338). 위젯이 '2일차' 라고
    /// 적어 놓고 눌렀더니 1일차가 열리면 방금 본 날을 다시 찾아야 한다.
    /// 출발 전이면 `dayNth` 가 없어 안 붙고, 앱은 첫날을 연다
    var deepLink: URL? {
        if let id = courseId {
            let day = state?.dayNth.map { "?day=\($0)" } ?? ""
            return URL(string: "offway://course/\(id)\(day)")
        }
        return URL(string: signedIn ? "offway://wizard" : "offway://home")
    }
}

/// 자정마다 바뀌는 시간표 — **서버·푸시 없이** 시스템이 날짜에 맞춰 칸을 바꾼다.
///
/// 지금 순간 하나 + 그 뒤 자정마다 하나, 모두 `days`칸. 앱이 다시 열려 목록을
/// 갈아 끼우면 시간표도 새로 만든다(`reloadTimelines`)
@available(iOS 16.1, *)
enum TripWidgetTimeline {
    static let defaultDays = 14

    /// 자정 경계와 날짜 셈이 **한 달력**(그 시간대의 그레고리력)에서 나온다
    static func entries(
        now: Date,
        trips: [TripWidgetTrip],
        signedIn: Bool,
        timeZone: TimeZone = .current,
        days: Int = defaultDays
    ) -> [TripWidgetSnapshot] {
        let calendar = YMD.gregorian(in: timeZone)
        var result = [snapshot(at: now, trips: trips, signedIn: signedIn, timeZone: timeZone)]
        let startOfToday = calendar.startOfDay(for: now)
        for offset in 1..<max(days, 1) {
            guard let midnight = calendar.date(byAdding: .day, value: offset, to: startOfToday)
            else { continue }
            result.append(snapshot(at: midnight, trips: trips, signedIn: signedIn, timeZone: timeZone))
        }
        return result
    }

    static func snapshot(
        at date: Date,
        trips: [TripWidgetTrip],
        signedIn: Bool,
        timeZone: TimeZone = .current
    ) -> TripWidgetSnapshot {
        let today = YMD(date, timeZone: timeZone)
        let picked = TripWidgetTrip.pick(trips, today: today)
        let state = picked?.contentState(today: today)
        return TripWidgetSnapshot(
            date: date,
            state: state,
            courseId: picked?.courseId,
            signedIn: signedIn,
            // 출발 전(`dayNth` 가 nil)이면 첫날 것을 미리 보여준다
            day: picked?.days.first { $0.day == (state?.dayNth ?? 1) }
        )
    }
}
