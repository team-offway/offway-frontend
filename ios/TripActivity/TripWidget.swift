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
/// 다섯 자리: 홈 소형 · 잠금화면 직사각형(시계 아래 넓은 칸) · 원형(시계
/// 아래 동그라미) · 한 줄(시계 위 날짜 옆). 홈 중형은 시안이 나오면(#297).
@available(iOS 16.1, *)
struct TripWidget: Widget {
    static let kind = "TripWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: TripWidgetProvider()) { entry in
            TripWidgetView(entry: entry)
        }
        .configurationDisplayName("여행 D-day")
        .description("다음 여행까지 남은 날을 보여줘요.")
        .supportedFamilies([
            .systemSmall,
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline,
        ])
    }
}

@available(iOS 16.1, *)
struct TripWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: TripWidgetSnapshot

    init(_ snapshot: TripWidgetSnapshot) {
        date = snapshot.date
        self.snapshot = snapshot
    }
}

@available(iOS 16.1, *)
struct TripWidgetProvider: TimelineProvider {
    /// 위젯 갤러리 미리보기 — 실제 데이터 없이 모양만
    private var sample: TripWidgetEntry {
        TripWidgetEntry(
            TripWidgetSnapshot(
                date: Date(),
                state: TripActivityAttributes.ContentState(
                    regionName: "정선군",
                    daysLeft: 5,
                    dayNth: nil,
                    startDate: "2026-09-23",
                    endDate: "2026-09-25"
                ),
                signedIn: true,
                courseId: "0"
            )
        )
    }

    private var current: TripWidgetEntry {
        TripWidgetEntry(
            TripWidgetTimeline.snapshot(
                at: Date(),
                trips: TripWidgetStore.load(),
                signedIn: TripWidgetStore.isSignedIn
            )
        )
    }

    func placeholder(in context: Context) -> TripWidgetEntry { sample }

    func getSnapshot(in context: Context, completion: @escaping (TripWidgetEntry) -> Void) {
        completion(context.isPreview ? sample : current)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TripWidgetEntry>) -> Void) {
        let entries = TripWidgetTimeline.entries(
            now: Date(),
            trips: TripWidgetStore.load(),
            signedIn: TripWidgetStore.isSignedIn
        ).map(TripWidgetEntry.init)
        // 14일이 지나면 다시 부른다. 그 전에 앱이 목록을 갈아 끼우면 즉시 다시 만든다
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - 자리별 뷰

/// 자리(family)에 맞는 뷰를 고른다.
///
/// **잠금화면 세 자리는 iOS 가 색을 정한다** — 배경화면에 맞춰 흰색·반투명으로
/// 그리므로 우리 색이 안 먹고 글자와 SF Symbol 만 된다. 홈 소형만 우리
/// 디자인이 그대로 나간다.
@available(iOS 16.1, *)
struct TripWidgetView: View {
    let entry: TripWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                InlineView(snapshot: entry.snapshot)
            case .accessoryCircular:
                CircularView(snapshot: entry.snapshot)
            case .accessoryRectangular:
                RectangularView(snapshot: entry.snapshot)
            default:
                HomeSmallView(snapshot: entry.snapshot)
            }
        }
        .widgetContainerBackground(accessory: family.isAccessory)
        // 누르면 앱이 열린다 — 여행이 있으면 그 코스, 없으면 코스 만들기
        .widgetURL(entry.snapshot.deepLink)
    }
}

/// 홈 화면 소형 — 숫자가 주인공이다
@available(iOS 16.1, *)
private struct HomeSmallView: View {
    let snapshot: TripWidgetSnapshot

    var body: some View {
        if let state = snapshot.state {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "suitcase.rolling")
                    .font(.title3)
                    .foregroundStyle(.tint)
                Spacer(minLength: 0)
                // 'D-5' · '2일차'
                Text(state.compactLabel)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("\(state.regionName) 여행")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(state.rangeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "suitcase.rolling")
                    .font(.title3)
                    .foregroundStyle(.tint)
                Spacer(minLength: 0)
                Text(snapshot.signedIn ? "예정된 여행이 없어요" : "로그인하고 여행을 담아보세요")
                    .font(.subheadline.weight(.semibold))
                Text(snapshot.signedIn ? "남은 연차로 떠날 곳을 찾아보세요" : "OffWay")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

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
                Text("\(state.rangeLabel) · \(state.durationLabel)")
                    .font(.caption)
                    .lineLimit(1)
            } else {
                Label(
                    snapshot.signedIn ? "예정된 여행이 없어요" : "로그인하고 여행을 담아보세요",
                    systemImage: "suitcase.rolling"
                )
                .font(.headline)
                .widgetAccentable()
                .lineLimit(2)
                if snapshot.signedIn {
                    Text("남은 연차로 떠날 곳을 찾아보세요")
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
        if let state = snapshot.state {
            Label(state.headline, systemImage: "suitcase.rolling")
        } else {
            Label(snapshot.signedIn ? "예정된 여행이 없어요" : "OffWay", systemImage: "suitcase.rolling")
        }
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
    /// 홈은 시스템 배경으로. 16 은 그 API 가 없어 홈에 여백만 준다
    @ViewBuilder
    func widgetContainerBackground(accessory: Bool) -> some View {
        if #available(iOS 17.0, *) {
            if accessory {
                containerBackground(.clear, for: .widget)
            } else {
                containerBackground(.background, for: .widget)
            }
        } else if accessory {
            self
        } else {
            padding()
        }
    }
}
