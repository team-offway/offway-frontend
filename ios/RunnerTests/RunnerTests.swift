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
