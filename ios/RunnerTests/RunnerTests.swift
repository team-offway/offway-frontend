import XCTest

@testable import Runner

/// 잠금화면 문구 조립 — 서버가 자정에 보내는 재료(core #577)에서 무엇을 그리는가.
///
/// **이 규칙은 여기 한 곳뿐이다.** 앱이 띄울 때도 서버가 갱신할 때도 같은
/// 다섯 칸이 들어와 같은 코드가 조립한다. 여기가 어긋나면 잠금화면이 통째로
/// 엉뚱한 말을 한다.
@available(iOS 16.1, *)
final class TripPhraseTests: XCTestCase {
    private func state(
        region: String = "정선군",
        daysLeft: Int? = nil,
        dayNth: Int? = nil,
        start: String = "2026-09-23",
        end: String = "2026-09-25"
    ) -> TripActivityAttributes.ContentState {
        TripActivityAttributes.ContentState(
            regionName: region,
            daysLeft: daysLeft,
            dayNth: dayNth,
            startDate: start,
            endDate: end
        )
    }

    // MARK: 출발 전

    func test앞둔여행은Dn으로적는다() {
        let s = state(daysLeft: 3)
        XCTAssertEqual(s.headline, "정선군 여행 D-3")
        XCTAssertEqual(s.compactLabel, "D-3")
    }

    func test하루앞이면내일이라고말한다() {
        // D-1 보다 읽힌다 — 좁은 자리는 그대로 D-1
        let s = state(daysLeft: 1)
        XCTAssertEqual(s.headline, "내일 정선군 여행")
        XCTAssertEqual(s.compactLabel, "D-1")
    }

    func test남은날0은당일로친다() {
        // 서버·앱 모두 당일은 dayNth 로 보내지만, 0 이 오면 D-0 을 띄우지 않는다
        let s = state(daysLeft: 0)
        XCTAssertEqual(s.headline, "정선군 여행 1일차")
        XCTAssertEqual(s.compactLabel, "1일차")
    }

    // MARK: 여행 중

    func test여행중에는며칠째인지말한다() {
        let s = state(dayNth: 2)
        XCTAssertEqual(s.headline, "정선군 여행 2일차")
        XCTAssertEqual(s.compactLabel, "2일차")
    }

    func test첫날은1일차다() {
        let s = state(dayNth: 1)
        XCTAssertEqual(s.headline, "정선군 여행 1일차")
        XCTAssertEqual(s.compactLabel, "1일차")
    }

    func test여행중이면남은날이있어도며칠째가이긴다() {
        // 둘 다 오는 것은 계약 위반이지만, 그래도 빈칸을 내지 않는다
        let s = state(daysLeft: 2, dayNth: 1)
        XCTAssertEqual(s.headline, "정선군 여행 1일차")
    }

    func test둘다없으면지역만말한다() {
        let s = state()
        XCTAssertEqual(s.headline, "정선군 여행")
        XCTAssertEqual(s.compactLabel, "여행")
    }

    // MARK: 기간

    func test기간은두날짜에서만든다() {
        XCTAssertEqual(state(start: "2026-09-23", end: "2026-09-23").durationLabel, "당일치기")
        XCTAssertEqual(state(start: "2026-09-23", end: "2026-09-24").durationLabel, "1박 2일")
        XCTAssertEqual(state(start: "2026-09-23", end: "2026-09-25").durationLabel, "2박 3일")
    }

    func test달을넘겨도이어서센다() {
        XCTAssertEqual(state(start: "2026-09-30", end: "2026-10-02").durationLabel, "2박 3일")
    }

    // MARK: 날짜 범위

    func test여러날이면끝날을붙인다() {
        XCTAssertEqual(state(start: "2026-09-23", end: "2026-09-25").rangeLabel, "2026.9.23 - 9.25")
    }

    func test당일치기는하루만적는다() {
        XCTAssertEqual(state(start: "2026-09-23", end: "2026-09-23").rangeLabel, "2026.9.23")
    }

    func test해를넘기면끝날에도연도를붙인다() {
        // '12.31 - 1.2' 로는 어느 해에 끝나는지 알 수 없다
        XCTAssertEqual(state(start: "2026-12-31", end: "2027-01-02").rangeLabel, "2026.12.31 - 2027.1.2")
    }

    // MARK: 서버 계약 — core #577 ApnsPayload 가 보내는 JSON 그대로

    /// 서버 `ApnsPayload.contentState()` 가 만드는 모양이다. **칸 이름이 하나라도
    /// 어긋나면 iOS 가 조용히 못 읽는다** — 오류 없이 화면만 안 바뀐다. 그래서
    /// 실제 JSON 을 디코딩해 본다. 서버 쪽은 `ApnsPayloadTest` 가 같은 이름을
    /// 잠그고 있어, 둘이 함께 계약을 쥔다
    func test서버가보내는JSON을그대로읽는다() throws {
        let json = """
        {"regionName":"정선군","daysLeft":2,"dayNth":null,"startDate":"2026-09-23","endDate":"2026-09-25"}
        """.data(using: .utf8)!

        let s = try JSONDecoder().decode(TripActivityAttributes.ContentState.self, from: json)

        XCTAssertEqual(s.regionName, "정선군")
        XCTAssertEqual(s.daysLeft, 2)
        XCTAssertNil(s.dayNth)
        XCTAssertEqual(s.startDate, "2026-09-23")
        XCTAssertEqual(s.headline, "정선군 여행 D-2")
        XCTAssertEqual(s.compactLabel, "D-2")
    }

    func test여행중갱신도읽는다() throws {
        // 서버는 null 인 칸도 빼지 않고 싣는다 — 빼면 앱이 직전 값을 그대로 쓴다
        let json = """
        {"regionName":"정선군","daysLeft":null,"dayNth":2,"startDate":"2026-09-23","endDate":"2026-09-25"}
        """.data(using: .utf8)!

        let s = try JSONDecoder().decode(TripActivityAttributes.ContentState.self, from: json)

        XCTAssertNil(s.daysLeft)
        XCTAssertEqual(s.dayNth, 2)
        XCTAssertEqual(s.headline, "정선군 여행 2일차")
    }

    func test칸이름이어긋나면읽지못한다() {
        // 계약이 깨지는 방향을 잠근다 — 서버가 이름을 바꾸면 여기가 먼저 안다
        let json = """
        {"region":"정선군","daysLeft":2,"dayNth":null,"startDate":"2026-09-23","endDate":"2026-09-25"}
        """.data(using: .utf8)!

        XCTAssertThrowsError(
            try JSONDecoder().decode(TripActivityAttributes.ContentState.self, from: json)
        )
    }

    // MARK: 깨진 입력

    func test날짜가깨지면원문을그대로내고기간은비운다() {
        let s = state(start: "언제", end: "2026-09-25")
        XCTAssertEqual(s.rangeLabel, "언제")
        XCTAssertEqual(s.durationLabel, "")
    }

    func test날짜가뒤집혀도음수박은없다() {
        XCTAssertEqual(state(start: "2026-09-25", end: "2026-09-23").durationLabel, "당일치기")
    }
}

// MARK: - 위젯

/// 위젯이 날짜마다 무엇을 보여줄지 — Dart `TripCountdown.pick` 과 같은 규칙에
/// 창(within)만 없다. 시간표는 앱이 넘긴 목록에서 여기서 만든다(서버 없음).
@available(iOS 16.1, *)
final class TripWidgetTests: XCTestCase {
    private func trip(
        _ id: String,
        region: String = "정선군",
        start: String,
        end: String? = nil
    ) -> TripWidgetTrip {
        TripWidgetTrip(courseId: id, regionName: region, startDate: start, endDate: end ?? start)
    }

    private let today = YMD(y: 2026, m: 9, d: 20)

    func test여행중인것이먼저다() {
        let picked = TripWidgetTrip.pick(
            [
                trip("1", start: "2026-09-22"),
                trip("2", region: "가평군", start: "2026-09-19", end: "2026-09-21"),
            ],
            today: today
        )
        XCTAssertEqual(picked?.courseId, "2")
        XCTAssertEqual(picked?.contentState(today: today)?.dayNth, 2)
        XCTAssertNil(picked?.contentState(today: today)?.daysLeft)
    }

    func test없으면가장가까운예정여행이다() {
        let picked = TripWidgetTrip.pick(
            [trip("1", start: "2026-10-05"), trip("2", start: "2026-09-25")],
            today: today
        )
        XCTAssertEqual(picked?.courseId, "2")
        XCTAssertEqual(picked?.contentState(today: today)?.daysLeft, 5)
    }

    func test창이없다_먼여행도보여준다() {
        // 라이브 액티비티는 D-5 부터지만 위젯은 사용자가 붙인 자리라 빈칸이면 뺀다
        let picked = TripWidgetTrip.pick([trip("1", start: "2026-10-02")], today: today)
        XCTAssertEqual(picked?.contentState(today: today)?.daysLeft, 12)
        XCTAssertEqual(picked?.contentState(today: today)?.headline, "정선군 여행 D-12")
    }

    func test지난여행과역전데이터는건너뛴다() {
        let picked = TripWidgetTrip.pick(
            [
                trip("1", start: "2026-09-10", end: "2026-09-12"),
                trip("2", start: "2026-09-30", end: "2026-09-28"),
                trip("3", start: "2026-09-29"),
            ],
            today: today
        )
        XCTAssertEqual(picked?.courseId, "3")
        XCTAssertNil(TripWidgetTrip.pick([trip("1", start: "2026-09-10")], today: today))
    }

    func test시간표는지금하나와자정마다하나다() {
        let seoul = TimeZone(identifier: "Asia/Seoul")!
        let cal = YMD.gregorian(in: seoul)
        let now = cal.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 15, minute: 30))!
        let entries = TripWidgetTimeline.entries(
            now: now,
            trips: [trip("1", start: "2026-09-23", end: "2026-09-25")],
            signedIn: true,
            timeZone: seoul,
            days: 14
        )
        XCTAssertEqual(entries.count, 14)
        XCTAssertEqual(entries[0].date, now)
        XCTAssertEqual(entries[0].state?.daysLeft, 3)
        // 둘째 칸은 다음 날 00:00 — 그 순간 D-2 가 된다
        XCTAssertEqual(
            cal.dateComponents([.year, .month, .day, .hour, .minute], from: entries[1].date),
            DateComponents(year: 2026, month: 9, day: 21, hour: 0, minute: 0)
        )
        XCTAssertEqual(entries[1].state?.daysLeft, 2)
        // 출발 당일 칸은 1일차, 여행이 끝난 뒤 칸은 빈 상태
        XCTAssertEqual(entries[3].state?.dayNth, 1)
        XCTAssertNil(entries[6].state)
        XCTAssertTrue(entries[6].signedIn)
    }

    func test위젯날짜는요일을붙여짧게() {
        let s = TripActivityAttributes.ContentState(
            regionName: "정선군", daysLeft: 3, dayNth: nil,
            startDate: "2026-09-23", endDate: "2026-09-25"
        )
        XCTAssertEqual(s.shortRangeLabel, "9.23(수) - 9.25(금)")
        XCTAssertEqual(YMD(y: 2026, m: 9, d: 20).weekday, "일")
        let same = TripActivityAttributes.ContentState(
            regionName: "정선군", daysLeft: 3, dayNth: nil,
            startDate: "2026-09-23", endDate: "2026-09-23"
        )
        XCTAssertEqual(same.shortRangeLabel, "9.23(수)")
    }

    func test날짜는시간대의그레고리력으로센다() {
        // 기기 달력이 불교력이어도(연도 2569) 여행 날짜는 그레고리력으로 적혀 있다 —
        // 시간대만 빌리고 달력은 그레고리력이라 2026 으로 나온다
        let seoul = TimeZone(identifier: "Asia/Seoul")!
        // 서울 9/20 00:30 은 UTC 로는 9/19 다 — 시간대가 날짜를 가른다
        let date = YMD.gregorian(in: seoul).date(
            from: DateComponents(year: 2026, month: 9, day: 20, hour: 0, minute: 30)
        )!
        XCTAssertEqual(YMD(date, timeZone: seoul), YMD(y: 2026, m: 9, d: 20))
        XCTAssertEqual(YMD(date, timeZone: TimeZone(identifier: "UTC")!), YMD(y: 2026, m: 9, d: 19))
        XCTAssertTrue(YMD(y: 2026, m: 9, d: 19) < YMD(y: 2026, m: 10, d: 1))
    }

    func test로그인전은빈상태에표시가남는다() {
        let s = TripWidgetTimeline.snapshot(at: Date(), trips: [], signedIn: false)
        XCTAssertNil(s.state)
        XCTAssertFalse(s.signedIn)
        XCTAssertEqual(s.deepLink?.absoluteString, "offway://home")
    }

    func test누르면여행이있으면그코스_없으면코스만들기다() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let now = cal.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 9))!
        let with = TripWidgetTimeline.snapshot(
            at: now, trips: [trip("122", start: "2026-09-23")], signedIn: true, timeZone: cal.timeZone
        )
        XCTAssertEqual(with.courseId, "122")
        XCTAssertEqual(with.deepLink?.absoluteString, "offway://course/122")

        let without = TripWidgetTimeline.snapshot(
            at: now, trips: [trip("1", start: "2026-09-10")], signedIn: true, timeZone: cal.timeZone
        )
        XCTAssertNil(without.courseId, "지난 여행은 눌러도 열 것이 없다")
        XCTAssertEqual(without.deepLink?.absoluteString, "offway://wizard")
    }

    func test저장한목록을그대로읽고_같은목록은바뀐것으로치지않는다() throws {
        TripWidgetStore.clear()
        let trips = [trip("1", start: "2026-09-23", end: "2026-09-25")]
        XCTAssertTrue(try TripWidgetStore.save(trips))
        XCTAssertFalse(try TripWidgetStore.save(trips), "같은 목록이면 위젯을 다시 그릴 이유가 없다")
        XCTAssertEqual(TripWidgetStore.load(), trips)
        // 로그인 표시는 목록과 따로다 — 목록을 썼다고 로그인으로 치지 않는다
        XCTAssertFalse(TripWidgetStore.isSignedIn)
        TripWidgetStore.markSignedIn()
        XCTAssertTrue(TripWidgetStore.isSignedIn)
        TripWidgetStore.clear()
        XCTAssertEqual(TripWidgetStore.load(), [])
        XCTAssertFalse(TripWidgetStore.isSignedIn)
    }

    func test채널인자는네칸이다_하나라도빠지면nil() {
        let full: [String: Any] = [
            "courseId": "1", "regionName": "정선군", "startDate": "2026-09-23", "endDate": "2026-09-25",
        ]
        XCTAssertEqual(TripWidgetTrip(channelArgs: full), trip("1", start: "2026-09-23", end: "2026-09-25"))
        var missing = full
        missing.removeValue(forKey: "endDate")
        XCTAssertNil(TripWidgetTrip(channelArgs: missing))
    }
}
