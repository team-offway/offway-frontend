import SwiftUI
import WidgetKit

/// 홈·잠금화면 **위젯** — 사용자가 직접 붙여 두는 상시 D-day.
///
/// 라이브 액티비티(`TripActivityWidget`)는 8시간이면 시스템이 끝내지만 위젯은
/// 제한이 없다. 자정에 D-3 이 D-2 가 되는 것도 서버 없이 된다 — 앱이 넘긴
/// 목록으로 여기서 14일치 시간표를 만들고 시스템이 날짜에 맞춰 칸을 바꾼다.
///
/// 문구는 라이브 액티비티와 같은 `ContentState` extension 이 조립한다.
///
/// 다섯 자리: 홈 소형·중형 · 잠금화면 직사각형(시계 아래 넓은 칸) · 원형(시계
/// 아래 동그라미) · 한 줄(시계 위 날짜 옆).
///
/// **홈 소형·중형은 시안대로다**(1669:42131 · 1669:42146). 잠금화면 세 자리는
/// 시안이 없고 시스템이 색을 정하는 자리라 앱 토큰(`WidgetPalette`)으로 둔다.
@available(iOS 16.1, *)
struct TripWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: TripWidgetStore.widgetKind, provider: TripWidgetProvider()) { entry in
            TripWidgetView(snapshot: entry)
        }
        .configurationDisplayName("여행 D-day")
        .description("다음 여행까지 남은 날을 보여줘요.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline,
        ])
        // **시스템 기본 여백을 끈다**(iOS 17+). 켜 두면 우리가 준 16 위에
        // 시스템이 한 겹 더 붙여 실측 34pt 가 되어 시안과 어긋난다
        .widgetContentMarginsDisabled()
    }
}

/// 시간표의 한 칸이 곧 엔트리다 — `date` 를 이미 갖고 있다
@available(iOS 16.1, *)
extension TripWidgetSnapshot: TimelineEntry {}

@available(iOS 16.1, *)
struct TripWidgetProvider: TimelineProvider {
    /// 위젯 갤러리 미리보기 — 실제 데이터 없이 모양만
    private var sample: TripWidgetSnapshot {
        TripWidgetSnapshot(
            date: Date(),
            state: TripActivityAttributes.ContentState(
                regionName: "정선군",
                daysLeft: 5,
                dayNth: nil,
                startDate: "2026-09-23",
                endDate: "2026-09-25"
            ),
            courseId: "0",
            signedIn: true,
            day: TripWidgetDay(
                channelArgs: [
                    "day": 1,
                    "sky": "맑음",
                    "places": ["삼탄아트마인", "정선5일장", "병방치스카이워크", "아라리촌"],
                ]
            )
        )
    }

    private var current: TripWidgetSnapshot {
        TripWidgetTimeline.snapshot(
            at: Date(),
            trips: TripWidgetStore.load(),
            signedIn: TripWidgetStore.isSignedIn
        )
    }

    func placeholder(in context: Context) -> TripWidgetSnapshot { sample }

    func getSnapshot(in context: Context, completion: @escaping (TripWidgetSnapshot) -> Void) {
        completion(context.isPreview ? sample : current)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TripWidgetSnapshot>) -> Void) {
        let entries = TripWidgetTimeline.entries(
            now: Date(),
            trips: TripWidgetStore.load(),
            signedIn: TripWidgetStore.isSignedIn
        )
        // 마지막 칸이 지나면 다시 부른다. 그 전에 앱이 목록을 갈아 끼우면 즉시 다시 만든다
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - 자리별 뷰

/// 자리(family)에 맞는 뷰를 고른다.
///
/// **잠금화면 세 자리는 iOS 가 색을 정한다** — 배경화면에 맞춰 흰색·반투명으로
/// 그리므로 우리 색이 안 먹고 글자와 SF Symbol 만 된다. 홈 소형·중형만 우리
/// 디자인이 그대로 나간다.
@available(iOS 16.1, *)
struct TripWidgetView: View {
    let snapshot: TripWidgetSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch (family, snapshot.state) {
            case (.accessoryInline, _):
                InlineView(snapshot: snapshot)
            case (.accessoryCircular, _):
                CircularView(snapshot: snapshot)
            case (.accessoryRectangular, _):
                RectangularView(snapshot: snapshot)
            case (.systemMedium, let state?):
                HomeMediumView(state: state, day: snapshot.day)
            case (_, let state?):
                HomeSmallView(state: state, day: snapshot.day)
            case (_, nil):
                HomeEmptyView(snapshot: snapshot)
            }
        }
        .widgetContainerBackground(accessory: family.isAccessory)
        // 누르면 앱이 열린다 — 여행이 있으면 그 코스, 없으면 코스 만들기
        .widgetURL(snapshot.deepLink)
    }
}

// MARK: 홈 화면

/// 앱 색 토큰 — Flutter `AppColors` 와 같은 값. 시안 없이 그린 자리라
/// 토큰을 그대로 옮겨 앱과 한 벌로 보이게 한다.
///
/// **색의 주인은 여기 하나다.** 라이브 액티비티(`TripActivityWidget`)도 이 파랑을
/// 쓴다 — 에셋(`AccentColor`)에 같은 값을 두면 토큰이 바뀔 때 한쪽만 고쳐져
/// 잠금화면 카드와 위젯이 다른 파랑이 된다
@available(iOS 16.1, *)
enum WidgetPalette {
    /// Primary/Normal · Light Blue 60 `#3DC2FF`
    static let primary = Color(red: 0x3D / 255, green: 0xC2 / 255, blue: 0xFF / 255)
    /// Primary/Strong · Light Blue 50 `#00AEFF` — 글자로 쓰는 파랑
    static let primaryStrong = Color(red: 0x00 / 255, green: 0xAE / 255, blue: 0xFF / 255)
    /// 파랑 칩 바탕 — Primary 12%. 다크에서도 바탕 위에 옅게 뜬다
    static let primaryFill = primary.opacity(0.12)

    /// 다이나믹 아일랜드·잠금화면 카드의 파랑 `#18D2FE` — 시안(1603:38922 외)이
    /// 정한 값이고 로고 에셋도 같은 색이다. 홈 위젯이 쓰는 [primary](#3DC2FF)와
    /// 다르다 — 시안이 없던 때 앱 토큰으로 그린 자리라 그쪽은 그대로 둔다
    static let islandAccent = Color(red: 0x18 / 255, green: 0xD2 / 255, blue: 0xFE / 255)
    /// '코스 보기' 버튼 바탕 — 시안은 같은 파랑 20%다
    static let islandButtonFill = islandAccent.opacity(0.2)
    /// 펼친 카드의 부제 — 시스템 회색(systemGray2) `#A4A4A9`
    static let islandSubtitle = Color(red: 0xA4 / 255, green: 0xA4 / 255, blue: 0xA9 / 255)
    /// Label/Strong · Alternative — 다크에서는 시스템이 뒤집는다
    static let labelStrong = Color.primary
    static let labelAlternative = Color.secondary
    /// 홈 위젯 바탕 — 시안(1669:41752 · 1669:42384)은 라이트 흰색 · 다크 검정
    static let background = Color(
        uiColor: UIColor { $0.userInterfaceStyle == .dark ? .black : .white }
    )

    /// 중형의 장소 패널 바탕 — 라이트 `#F7F7F8` · 다크 `#313131` 60%
    /// (시안 1669:42474 · 1669:42509)
    static let placesPanel = Color(
        uiColor: UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0x31 / 255, green: 0x31 / 255, blue: 0x31 / 255, alpha: 0.6)
            : UIColor(red: 0xF7 / 255, green: 0xF7 / 255, blue: 0xF8 / 255, alpha: 1) }
    )

    /// 패널 안 장소 이름 — 라이트 `#565656` · 다크 **흰색**.
    /// 다크에서 부제(`#EAEAEA` 70%)보다 밝다 — 패널이 바탕보다 밝아 글자도 세진다
    static let placeName = Color(
        uiColor: UIColor { $0.userInterfaceStyle == .dark
            ? .white
            : UIColor(red: 0x56 / 255, green: 0x56 / 255, blue: 0x56 / 255, alpha: 1) }
    )
}

/// 왼쪽 위 아이콘 — **날씨가 있으면 날씨, 없으면 로고**(시안 1669:42131).
///
/// 날씨는 서버가 코스에 실어 주는 한글 값(`맑음`·`비`)으로 고른다. 모르는
/// 값이거나 아예 없으면 로고다 — 여행이 멀어 예보가 없거나, 코스 상세를
/// 못 읽었을 때다
@available(iOS 16.1, *)
private struct WidgetLeadingIcon: View {
    let sky: String?
    let size: CGFloat

    /// 서버 sky 값 → 에셋. 앱 `_WeatherChip` 과 같은 표다
    private static let assets = [
        "맑음": "WeatherSunny",
        "구름많음": "WeatherCloudyPartly",
        "흐림": "WeatherOvercast",
        "비": "WeatherRain",
        "눈": "WeatherSnow",
        "비눈": "WeatherRainSnow",
    ]

    var body: some View {
        if let asset = sky.flatMap({ Self.assets[$0] }) {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            // **잠금화면 카드와 같은 에셋을 쓴다**(`TripLogo`). 시안에서 받은
            // 로고는 부모의 45° 회전이 빠진 채로 와서 각도가 달랐다 — 두 자리가
            // 같은 파일을 쓰면 앞으로도 어긋나지 않는다.
            //
            // 템플릿이라 색을 여기서 정한다
            Image("TripLogo")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(WidgetPalette.islandAccent)
        }
    }
}

/// 시안 서체.
///
/// 제목만 **Wanted Sans**(SIL OFL 1.1)를 싣는다 — 시안이 그렇다. 앱 본체는
/// Pretendard 를 쓰지만 위젯에는 안 실려 있고, 24pt 한 자리를 위해 본문용
/// 두께까지 넣을 이유가 없어 Bold 하나만 번들에 둔다(134KB).
///
/// 지역·날짜는 시안이 **SF Pro Text**, 곧 iOS 시스템 서체라 그대로 쓴다.
///
/// **`fixedSize` 로 잡는다** — 위젯은 자리가 정해져 있어 사용자의 큰 글자
/// 설정까지 따라가면 시안 배치가 무너진다
@available(iOS 16.1, *)
private enum WidgetFont {
    /// 'D-1' · '2일차' — 시안 24 Bold
    static let title = Font.custom("WantedSansStd-Bold", fixedSize: 24)
    /// '예정된 여행이 없어요' — 시안 16 Bold(1669:42224)
    static let emptyTitle = Font.custom("WantedSansStd-Bold", fixedSize: 16)
}

/// 시안 글자색 — 라이트·다크가 다르다(1669:41752 · 1669:42384)
@available(iOS 16.1, *)
private enum WidgetText {
    /// 제목 — 라이트 `#404040` · 다크 흰색
    static let title = Color(
        uiColor: UIColor { $0.userInterfaceStyle == .dark
            ? .white
            : UIColor(red: 0x40 / 255, green: 0x40 / 255, blue: 0x40 / 255, alpha: 1) }
    )
    /// 부제 — 라이트 `#565656` · 다크 `#EAEAEA` 70%
    static let subtitle = Color(
        uiColor: UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0xEA / 255, green: 0xEA / 255, blue: 0xEA / 255, alpha: 0.7)
            : UIColor(red: 0x56 / 255, green: 0x56 / 255, blue: 0x56 / 255, alpha: 1) }
    )
    /// 날짜 — 라이트·다크 같은 `#838388`
    static let date = Color(red: 0x83 / 255, green: 0x83 / 255, blue: 0x88 / 255)
}

/// 시안의 글자 덩이 — 제목·지역·날짜 세 줄(1669:41759). 소형과 중형이 같이 쓴다.
///
/// **줄 높이를 22로 고정한다.** 시안이 세 줄 모두 line-height 22 로 잡았고
/// (글자 크기는 24·12·10 으로 다르다), 그래야 줄 간격이 시안과 맞는다.
/// SwiftUI 기본 줄 높이는 글꼴 크기를 따라가므로 24pt 줄이 시안보다 커진다
@available(iOS 16.1, *)
private struct WidgetTextBlock: View {
    /// 'D-1' · '1일차'
    let title: String
    /// '공주시 여행'
    let subtitle: String
    /// '9.14(월) - 9.15(화)'
    let date: String

    /// 시안 실측 — 세 줄 모두 22
    private static let lineHeight: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // **줄여 쓰지도, 자리를 늘리지도 않는다.** 칸(22)이 글자(24)보다
            // 작은 건 시안도 같다 — 글자는 위아래로 넘치되 자리는 22 만
            // 차지해야 아래 두 줄이 시안 위치에 온다.
            // `minimumScaleFactor` 를 주면 축소되고, `fixedSize` 를 주면
            // 자연 높이(29)를 고집해 아래가 밀린다
            Text(title)
                .font(WidgetFont.title)
                .foregroundStyle(WidgetText.title)
                .lineLimit(1)
                .frame(height: Self.lineHeight, alignment: .leading)
            // 시안 실측: 제목 y=0(h22) · 지역 y=26 → 사이가 4
            Spacer().frame(height: 4)
            Text(subtitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WidgetText.subtitle)
                .lineLimit(1)
                .frame(height: Self.lineHeight, alignment: .leading)
            // 지역 y=26(h22, 끝 48) · 날짜 y=47 — 시안이 1 겹쳐 둔다
            Text(date)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(WidgetText.date)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(height: Self.lineHeight, alignment: .leading)
                .padding(.top, -1)
        }
    }
}

/// 시안 실측 — 소형 프레임 164.67 기준(1669:41752).
///
/// 절대값을 그대로 쓴다. 실제 자리(iPhone 기준 155~170)와 몇 pt 차이라
/// 비율로 환산하면 오히려 어긋난다 — 남는 세로는 아이콘과 글자 사이가 먹는다
@available(iOS 16.1, *)
private enum SmallSpec {
    /// 좌우 여백 — 아이콘 14.56 · 글자 16. 글자에 맞춘다
    static let sidePadding: CGFloat = 16
    /// 위 여백 — 아이콘 y
    static let topPadding: CGFloat = 17.89
    /// 아래 여백 — 마지막 줄 끝(146.125)에서 프레임 끝까지
    static let bottomPadding: CGFloat = 18.5
    /// 아이콘 크기
    static let iconSize: CGFloat = 31.68
}

/// 빈 상태 — 예정 없음 · 로그인 전(시안 1669:42215 · 1669:42239).
///
/// 아이콘은 늘 로고이고, 글자는 **두 줄**이다. 세 줄짜리(77.125)보다 아래인
/// y=96.4 에서 시작하는데, 두 줄(44)이 세 줄(69)보다 25 짧아 **바닥이 같다**
/// — 아래 여백을 그대로 두면 저절로 그 자리에 온다.
///
/// 제목이 16 이라 칸(22)보다 작다 — 여행이 있을 때의 24 와 달리 넘치지 않는다
@available(iOS 16.1, *)
private struct HomeEmptyView: View {
    let snapshot: TripWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetLeadingIcon(sky: nil, size: SmallSpec.iconSize)
            Spacer(minLength: 0)
            Text(snapshot.emptyTitle)
                .font(WidgetFont.emptyTitle)
                .foregroundStyle(WidgetText.title)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(height: 22, alignment: .leading)
            Text(snapshot.emptySubtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(WidgetText.date)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(height: 22, alignment: .leading)
                // 시안이 두 줄을 1 겹쳐 둔다(mb -1) — 세 줄짜리와 같은 규칙
                .padding(.top, -1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, SmallSpec.sidePadding)
        .padding(.top, SmallSpec.topPadding)
        .padding(.bottom, SmallSpec.bottomPadding)
    }
}

/// 홈 소형 — 아이콘 하나에 글자 세 줄(시안 1669:41752)
@available(iOS 16.1, *)
private struct HomeSmallView: View {
    let state: TripActivityAttributes.ContentState
    let day: TripWidgetDay?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetLeadingIcon(sky: day?.sky, size: SmallSpec.iconSize)
            // 시안은 아이콘 끝(49.57)과 글자 시작(77.125) 사이가 27.55 다.
            // 남는 세로를 여기가 먹으면 기기 크기가 달라도 위아래가 맞는다
            Spacer(minLength: 0)
            WidgetTextBlock(
                title: state.compactLabel,
                subtitle: "\(state.regionName) 여행",
                date: state.shortRangeLabel
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, SmallSpec.sidePadding)
        .padding(.top, SmallSpec.topPadding)
        .padding(.bottom, SmallSpec.bottomPadding)
    }
}

/// 홈 중형 — 왼쪽은 소형과 같고, 오른쪽에 **그날 들를 곳**(시안 1669:42467).
///
/// 시안 실측(349.67 × 164.67): 글자는 왼쪽 130 안에, 패널은 x=130 부터 212.
/// 실제 자리는 이보다 좁아(329 내외) **비율로 나눈다** — 절대값으로 두면
/// 패널이 넘친다.
///
/// 장소가 없으면(코스 상세를 못 읽었거나 서버가 안 줬으면) 패널을 통째로
/// 빼고 소형처럼 그린다 — 빈 판이 붙어 있으면 고장 난 것처럼 보인다
@available(iOS 16.1, *)
private struct HomeMediumView: View {
    let state: TripActivityAttributes.ContentState
    let day: TripWidgetDay?

    private var places: [String] { day?.places ?? [] }

    /// 시안의 가로 비율 — 글자 영역 130 : 패널 212
    private static let panelRatio: CGFloat = 212.0 / 349.67
    /// 패널 세로 비율 — 151 / 164.67
    private static let panelHeightRatio: CGFloat = 151.0 / 164.67
    /// 패널 오른쪽에 남는 여백 — (349.67 − 130 − 212) / 349.67
    private static let panelTrailingRatio: CGFloat = 7.67 / 349.67

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    // 중형 아이콘은 24 다(시안 1669:42492) — 소형(31.68)보다 작다
                    WidgetLeadingIcon(sky: day?.sky, size: 24)
                    Spacer(minLength: 0)
                    WidgetTextBlock(
                        title: state.compactLabel,
                        subtitle: "\(state.regionName) 여행",
                        date: state.shortRangeLabel
                    )
                }
                // **높이를 꽉 채운다.** 안 그러면 Spacer 가 늘어날 자리가 없어
                // 아이콘·글자가 전부 위로 붙는다
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.leading, SmallSpec.sidePadding)
                // 중형은 아이콘이 19.83 에서 시작한다
                .padding(.top, 19.83)
                .padding(.bottom, SmallSpec.bottomPadding)

                if !places.isEmpty {
                    PlacesPanel(places: places)
                        .frame(
                            width: geo.size.width * Self.panelRatio,
                            height: geo.size.height * Self.panelHeightRatio
                        )
                        // 시안은 패널 오른쪽에 7.67 이 남는다(130+212=342 / 349.67)
                        .padding(.trailing, geo.size.width * Self.panelTrailingRatio)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// 그날 들를 곳 — 번호 붙은 목록(시안 1669:42474). 최대 넷이다.
///
/// 시안 실측: 패널 안쪽 왼쪽 21, 줄 사이 8, 번호 원 16, 원과 이름 사이 10.
/// 목록은 패널 **세로 가운데**에 놓인다 — 넷이 안 될 때도 가운데다
@available(iOS 16.1, *)
private struct PlacesPanel: View {
    let places: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(places.enumerated()), id: \.offset) { index, name in
                HStack(spacing: 10) {
                    Text("\(index + 1)")
                        .font(.system(size: 9.33, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(WidgetPalette.primary, in: Circle())
                    Text(name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(WidgetPalette.placeName)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                // **줄 높이는 22 다.** 두지 않으면 번호 원(16)이 높이를 정해
                // 줄 간격이 30 이 아니라 24 가 된다 — 시안은 글자 칸이 22 다
                .frame(height: 22)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.leading, 21)
        .padding(.trailing, 12)
        .background(
            WidgetPalette.placesPanel,
            in: RoundedRectangle(cornerRadius: 25, style: .continuous)
        )
    }
}

// MARK: 잠금화면

/// 잠금화면 직사각형 — 시계 아래 넓은 칸, 글자 두 줄. **이번 목표의 핵심 자리**
@available(iOS 16.1, *)
private struct RectangularView: View {
    let snapshot: TripWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let state = snapshot.state {
                // '정선군 여행 D-5' · '내일 정선군 여행' · '정선군 여행 2일차'
                Label(state.headline, systemImage: "suitcase.rolling")
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                Text("\(state.shortRangeLabel) · \(state.durationLabel)")
                    .font(.caption)
                    .lineLimit(1)
            } else {
                Label(snapshot.emptyTitle, systemImage: "suitcase.rolling")
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(2)
                Text(snapshot.emptySubtitle)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// 잠금화면 원형 — 시계 아래 동그라미. 숫자만 들어간다
@available(iOS 16.1, *)
private struct CircularView: View {
    let snapshot: TripWidgetSnapshot

    var body: some View {
        ZStack {
            // 시스템이 배경화면에 맞춰 반투명 원을 그린다
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "suitcase.rolling")
                    .font(.caption2)
                if let state = snapshot.state {
                    // 'D-5' · '2일차'
                    Text(state.compactLabel)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .widgetAccentable()
                } else {
                    Text("—")
                        .font(.headline)
                }
            }
        }
    }
}

/// 잠금화면 한 줄 — 시계 위 날짜 옆. 아이콘 하나 + 짧은 글자
@available(iOS 16.1, *)
private struct InlineView: View {
    let snapshot: TripWidgetSnapshot

    var body: some View {
        Label(snapshot.state?.headline ?? snapshot.emptyTitle, systemImage: "suitcase.rolling")
    }
}

@available(iOS 16.1, *)
extension WidgetFamily {
    /// 잠금화면(시계 주변) 자리인가 — 색·배경을 시스템이 정하는 곳
    var isAccessory: Bool {
        switch self {
        case .accessoryInline, .accessoryCircular, .accessoryRectangular: return true
        default: return false
        }
    }
}

@available(iOS 16.1, *)
extension WidgetConfiguration {
    /// 시스템이 위젯 안쪽에 붙이는 기본 여백을 끈다(iOS 17+).
    ///
    /// 켜 두면 우리가 준 여백 위에 한 겹이 더 얹혀, 시안의 16 이 실측 34pt 가
    /// 된다. 16 에서는 그 여백 자체가 없어 아무것도 안 해도 된다
    func widgetContentMarginsDisabled() -> some WidgetConfiguration {
        if #available(iOS 17.0, *) {
            return contentMarginsDisabled()
        } else {
            return self
        }
    }
}

extension View {
    /// iOS 17 은 위젯 배경을 `containerBackground` 로 줘야 한다 — 없으면
    /// StandBy·iPad 에서 배경이 깨진다. 잠금화면 자리는 배경이 없어 투명으로,
    /// 홈은 `WidgetPalette.background`(라이트 흰색·다크 검정).
    ///
    /// **여백을 여기서 주지 않는다.** 시안 좌표가 자리마다 달라(소형 위 17.89 ·
    /// 중형 19.83) 각 뷰가 제 여백을 갖는다 — 여기서도 주면 두 겹이 된다
    @available(iOS 16.1, *)
    @ViewBuilder
    func widgetContainerBackground(accessory: Bool) -> some View {
        if #available(iOS 17.0, *) {
            if accessory {
                containerBackground(.clear, for: .widget)
            } else {
                containerBackground(WidgetPalette.background, for: .widget)
            }
        } else if accessory {
            self
        } else {
            background(WidgetPalette.background)
        }
    }
}
