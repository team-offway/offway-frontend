import ActivityKit
import SwiftUI
import WidgetKit

/// 여행 D-day 를 잠금화면과 다이나믹 아일랜드에 그린다.
///
/// **여기서는 배치만 맡는다.** 문구는 `ContentState` 가 재료에서 조립한다 —
/// 앱이 띄웠든 서버가 자정에 갱신했든(core #577) 같은 다섯 칸이 들어오고
/// 같은 규칙으로 그려진다.
@available(iOS 16.1, *)
struct TripActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            // 잠금화면 — 펼쳐 보이는 자리.
            //
            // **배경 틴트를 걸지 않는다.** 틴트를 걸고 글씨를 흰색으로 박으면
            // 라이트 모드에서 시스템이 배경을 밝게 덮어 흰 글씨가 흰 바탕에
            // 묻힌다 — 로그에는 렌더 success 로 찍히는데 화면은 비어 보인다.
            // 색은 시스템에 맡기고 `.primary`·`.secondary` 만 쓴다
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.regionName)
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
                // **분기를 두지 않는다.** 좁은 자리라 숫자만 띄우는데,
                // 조건을 걸면 여행 중일 때 자리가 빈 채로 남는다.
                // 조립은 ContentState 가 했다 — 모든 갈래가 값을 낸다
                Text(context.state.compactLabel)
                    .font(.caption2)
            } minimal: {
                Image(systemName: "suitcase.rolling")
            }
            .keylineTint(WidgetPalette.primary)
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
                // 위젯과 같은 파랑 — 색의 주인은 WidgetPalette 하나다
                .foregroundStyle(WidgetPalette.primary)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.headline)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(context.state.rangeLabel) · \(context.state.durationLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
