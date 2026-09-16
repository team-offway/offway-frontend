import ActivityKit
import SwiftUI
import WidgetKit

/// 여행 D-day 를 잠금화면과 다이나믹 아일랜드에 그린다.
///
/// **여기서는 배치만 맡는다.** 문구는 `ContentState` 가 재료에서 조립한다 —
/// 앱이 띄웠든 서버가 자정에 갱신했든(core #577) 같은 다섯 칸이 들어오고
/// 같은 규칙으로 그려진다.
///
/// 시안: 알약(1606:39073) · 펼침(1606:39170) · 최소(1605:38976).
/// 알약 배경은 **항상 검정**이라 시안의 파랑(`islandAccent`)이 그대로 나간다.
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
                // 카드를 누르면 그 코스로 — 펼침의 '코스 보기' 와 같은 주소다.
                // 카드 전체를 Link 로 감싸지 않는다: 잠금화면 카드의 탭은
                // 시스템이 다루는 자리라 widgetURL 로 목적지만 알려 준다
                .widgetURL(context.attributes.courseURL)
        } dynamicIsland: { context in
            DynamicIsland {
                // 펼침은 **center 한 덩이**로 넣는다 — leading/trailing 으로
                // 쪼개면 가운데 카메라 구멍만큼 벌어져 시안의 왼쪽 정렬이 깨진다
                DynamicIslandExpandedRegion(.center) {
                    ExpandedView(context: context)
                }
            } compactLeading: {
                // 시안(1606:39073): 알약 왼쪽에 로고 22
                IslandLogo(size: 22)
                    .padding(.leading, 2)
            } compactTrailing: {
                // **분기를 두지 않는다.** 좁은 자리라 숫자만 띄우는데,
                // 조건을 걸면 여행 중일 때 자리가 빈 채로 남는다.
                // 조립은 ContentState 가 했다 — 모든 갈래가 값을 낸다
                Text(context.state.compactLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WidgetPalette.islandAccent)
                    .padding(.trailing, 2)
            } minimal: {
                // 시안(1605:38976): 로고만 22
                IslandLogo(size: 22)
            }
            .keylineTint(WidgetPalette.islandAccent)
        }
    }
}

@available(iOS 16.1, *)
extension TripActivityAttributes {
    /// 누르면 갈 곳 — 그 코스 상세.
    ///
    /// 위젯이 쓰는 주소와 같은 형태다(`offway://course/{id}`). 코스 id 는
    /// 카드가 살아 있는 동안 바뀌지 않으므로 `attributes` 가 들고 있다.
    /// 잠금화면 카드와 펼침의 '코스 보기' 가 이 하나를 같이 쓴다 —
    /// 두 자리가 다른 곳으로 가면 안 된다
    var courseURL: URL {
        URL(string: "offway://course/\(courseId)")
            ?? URL(string: "offway://home")!
    }
}

/// 우리 로고 — 잠금화면·다이나믹 아일랜드가 함께 쓴다.
///
/// 에셋(`TripLogo`)은 템플릿이라 색을 코드가 정한다. 벡터(PDF)라 22·28·36
/// 어느 크기로도 깨지지 않는다
@available(iOS 16.1, *)
private struct IslandLogo: View {
    let size: CGFloat

    var body: some View {
        Image("TripLogo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .foregroundStyle(WidgetPalette.islandAccent)
    }
}

/// 펼친 카드 — 시안 1606:39170.
///
/// 로고 36 · 제목 16 흰색 · 부제 14 회색 · '코스 보기' 버튼.
/// **며칠 묵는지는 시안에 없다**(디자인 요청 9/16).
@available(iOS 16.1, *)
private struct ExpandedView: View {
    let context: ActivityViewContext<TripActivityAttributes>

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                IslandLogo(size: 36)

                VStack(alignment: .leading, spacing: 0) {
                    // '고성군 여행 1일차'
                    Text(context.state.headline)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    // '2026.9.14 - 9.15'
                    Text(context.state.rangeLabel)
                        .font(.system(size: 14))
                        .foregroundStyle(WidgetPalette.islandSubtitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)

            // 누르면 그 코스로 — 위젯과 같은 주소다(`offway://course/{id}`)
            Link(destination: context.attributes.courseURL) {
                Text("코스 보기")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(WidgetPalette.islandAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(WidgetPalette.islandButtonFill, in: Capsule())
            }
        }
        .padding(.top, 8)
    }
}

@available(iOS 16.1, *)
private struct LockScreenView: View {
    let context: ActivityViewContext<TripActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            // SF Symbol 대신 우리 로고 — 디자인 요청(9/16)
            IslandLogo(size: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.headline)
                    .font(.headline)
                    .foregroundStyle(.primary)
                // **며칠 묵는지는 빼고 날짜만** — 디자인 요청(9/16)
                Text(context.state.rangeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
