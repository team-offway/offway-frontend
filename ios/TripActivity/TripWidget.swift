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
/// **디자인 시안 없이 앱 토큰으로 그렸다**(#297) — `WidgetPalette`. 시안이
/// 나오면 이 파일의 뷰만 갈아 끼운다.
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
            signedIn: true
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
                HomeMediumView(state: state)
            case (_, let state?):
                HomeSmallView(state: state)
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
    /// 홈 위젯 바탕 — 라이트 흰색 · 다크 Cool Neutral 20 `#292A2D`
    static let background = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0x29 / 255, green: 0x2A / 255, blue: 0x2D / 255, alpha: 1)
                : .white
        }
    )
}

/// 지역명 칩 — '정선군 여행'. 파랑 바탕에 파랑 글자
@available(iOS 16.1, *)
private struct RegionChip: View {
    let regionName: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "suitcase.rolling.fill")
                .font(.system(size: 10, weight: .bold))
            Text("\(regionName) 여행")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(WidgetPalette.primaryStrong)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(WidgetPalette.primaryFill, in: Capsule())
    }
}

/// 빈 상태 — 예정 없음 · 로그인 전. 소형·중형이 같이 쓴다
@available(iOS 16.1, *)
private struct HomeEmptyView: View {
    let snapshot: TripWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "suitcase.rolling.fill")
                .font(.title3)
                .foregroundStyle(WidgetPalette.primary)
            Spacer(minLength: 0)
            Text(snapshot.emptyTitle)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(WidgetPalette.labelStrong)
                .lineLimit(2)
            Text(snapshot.emptySubtitle ?? "Offway")
                .font(.system(size: 12))
                .foregroundStyle(WidgetPalette.labelAlternative)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// 홈 소형 — 숫자가 주인공이다. 칩 · 큰 D-n · 날짜
@available(iOS 16.1, *)
private struct HomeSmallView: View {
    let state: TripActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RegionChip(regionName: state.regionName)
            Spacer(minLength: 4)
            // 'D-5' · '2일차' — 좁은 자리는 숫자 그대로
            Text(state.compactLabel)
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(WidgetPalette.labelStrong)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(state.shortRangeLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WidgetPalette.labelAlternative)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(state.durationLabel)
                .font(.system(size: 11))
                .foregroundStyle(WidgetPalette.labelAlternative)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// 홈 중형 — 왼쪽은 소형과 같은 정보, 오른쪽은 **날짜 타일**(출발일 또는
/// 돌아오는 날). 넓어진 만큼 날짜를 달력처럼 크게 보여준다
@available(iOS 16.1, *)
private struct HomeMediumView: View {
    let state: TripActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                RegionChip(regionName: state.regionName)
                Spacer(minLength: 4)
                // 중형은 자리가 있어 문장으로 — '내일 정선군 여행' · '정선군 여행 2일차'
                Text(state.headline)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(WidgetPalette.labelStrong)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                Spacer(minLength: 4)
                Text("\(state.shortRangeLabel) · \(state.durationLabel)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WidgetPalette.labelAlternative)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            DateTile(state: state)
        }
    }
}

/// 달력 한 장 — 출발 전엔 **출발일**, 여행 중엔 **돌아오는 날**
@available(iOS 16.1, *)
private struct DateTile: View {
    let state: TripActivityAttributes.ContentState

    private var ongoing: Bool { state.dayNth != nil }
    private var ymd: YMD? { YMD(ongoing ? state.endDate : state.startDate) }

    var body: some View {
        VStack(spacing: 2) {
            Text(ongoing ? "돌아오는 날" : "출발")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WidgetPalette.primaryStrong)
            Text(ymd.map { "\($0.d)" } ?? "-")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(WidgetPalette.labelStrong)
                .lineLimit(1)
            Text(ymd.map { "\($0.m)월 \($0.weekday)요일" } ?? "")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetPalette.labelAlternative)
                .lineLimit(1)
        }
        .frame(width: 84)
        .frame(maxHeight: .infinity)
        .background(WidgetPalette.primaryFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                if let subtitle = snapshot.emptySubtitle {
                    Text(subtitle)
                        .font(.caption)
                        .lineLimit(1)
                }
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

extension View {
    /// iOS 17 은 위젯 배경을 `containerBackground` 로 줘야 한다 — 없으면
    /// StandBy·iPad 에서 배경이 깨진다. 잠금화면 자리는 배경이 없어 투명으로,
    /// 홈은 `WidgetPalette.background`(라이트 흰색·다크 Cool Neutral 20).
    /// 16 은 그 API 가 없어 홈에 여백과 배경만 준다
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
            padding().background(WidgetPalette.background)
        }
    }
}
