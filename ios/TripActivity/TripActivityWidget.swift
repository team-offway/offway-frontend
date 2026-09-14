import ActivityKit
import SwiftUI
import WidgetKit

/// 여행 D-day 를 잠금화면과 다이나믹 아일랜드에 그린다.
///
/// **값은 Flutter 가 넘긴다** — 여기서는 배치만 맡는다. 문구를 네이티브가
/// 만들면 같은 말을 두 곳에서 고치게 된다.
@available(iOS 16.1, *)
struct TripActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            // 잠금화면 — 펼쳐 보이는 자리
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.regionName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.durationLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.headline)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.rangeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "suitcase.rolling")
            } compactTrailing: {
                // 좁은 자리라 숫자만 — 지난 여행은 셈이 뒤집히므로 숨긴다
                if context.state.daysUntil > 0 {
                    Text("D-\(context.state.daysUntil)")
                        .font(.caption2)
                } else if context.state.daysUntil == 0 {
                    Text("D-DAY").font(.caption2)
                }
            } minimal: {
                Image(systemName: "suitcase.rolling")
            }
            .keylineTint(Color.accentColor)
        }
    }
}

@available(iOS 16.1, *)
private struct LockScreenView: View {
    let context: ActivityViewContext<TripActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "suitcase.rolling")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.9))

            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.headline)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(context.state.rangeLabel) · \(context.state.durationLabel)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
