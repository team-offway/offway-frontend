import ActivityKit
import Flutter
import Foundation

/// Flutter 가 부르는 잠금화면 제어 — `TripActivityService` 와 짝이다.
///
/// **문구는 Flutter 가 만들어 넘긴다.** 여기서는 받은 값을 그대로 실어
/// 띄우기만 한다 — 같은 한국어를 두 곳에서 관리하지 않는다.
enum TripActivityBridge {
    /// Dart 쪽 `TripActivityService.channelName` 과 같아야 한다
    static let channelName = "com.nth.offway/trip_activity"

    static func register(with controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: controller.binaryMessenger
        )
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "isAvailable":
                result(isAvailable())
            case "start":
                start(call.arguments, result: result)
            case "end":
                end(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private static func isAvailable() -> Bool {
        guard #available(iOS 16.1, *) else { return false }
        // 사용자가 설정에서 껐을 수도 있다 — 그때도 거짓이다
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }

    private static func start(_ arguments: Any?, result: @escaping FlutterResult) {
        guard #available(iOS 16.1, *) else { return result(nil) }
        guard let args = arguments as? [String: Any],
              let courseId = args["courseId"] as? String,
              let regionName = args["regionName"] as? String,
              let headline = args["headline"] as? String,
              let rangeLabel = args["rangeLabel"] as? String,
              let durationLabel = args["durationLabel"] as? String,
              let compactLabel = args["compactLabel"] as? String
        else {
            return result(
                FlutterError(code: "BAD_ARGS", message: "필요한 값이 없다", details: nil)
            )
        }

        let state = TripActivityAttributes.ContentState(
            headline: headline,
            rangeLabel: rangeLabel,
            durationLabel: durationLabel,
            compactLabel: compactLabel
        )

        // **줄을 세워 보낸다.** 앱 재개가 연달아 오거나 sync 중에 로그아웃이
        // 겹치면 start 와 end 의 Task 가 동시에 돌아, 두 endAll 이 같은
        // activity 를 각각 내리는 사이 request 가 끼어든다 — 잠금화면에
        // 둘이 쌓이거나 방금 띄운 것이 곧바로 내려간다
        Task {
            do {
                try await ActivityQueue.shared.startOrUpdate(
                    courseId: courseId,
                    regionName: regionName,
                    state: state
                )
                await MainActor.run { result(nil) }
            } catch {
                await MainActor.run {
                    result(
                        FlutterError(
                            code: "START_FAILED",
                            message: error.localizedDescription,
                            details: nil
                        )
                    )
                }
            }
        }
    }

    private static func end(result: @escaping FlutterResult) {
        guard #available(iOS 16.1, *) else { return result(nil) }
        // 실제로 내려간 뒤에 답한다 — 먼저 답하면 Flutter 는 내려갔다고 아는데
        // 잠금화면에는 아직 남아 있다
        Task {
            await ActivityQueue.shared.endAll()
            await MainActor.run { result(nil) }
        }
    }
}

/// Activity 조작을 **한 줄로 세운다**.
///
/// `Activity.activities` 조회와 `request`·`end` 사이에 다른 호출이 끼어들면
/// "한 번에 하나" 가 깨진다. actor 안에서만 만지게 해 그 틈을 없앤다.
@available(iOS 16.1, *)
actor ActivityQueue {
    static let shared = ActivityQueue()

    func startOrUpdate(
        courseId: String,
        regionName: String,
        state: TripActivityAttributes.ContentState
    ) throws {
        // 같은 코스가 이미 떠 있으면 새로 띄우지 않고 값만 갈아 끼운다 —
        // 두 번 띄우면 잠금화면에 같은 여행이 둘 쌓인다
        if let live = Activity<TripActivityAttributes>.activities.first(where: {
            $0.attributes.courseId == courseId
        }) {
            Task { await live.update(using: state) }
            return
        }

        // 다른 코스가 떠 있으면 내리고 이것으로 바꾼다
        endAllNow()

        _ = try Activity.request(
            attributes: TripActivityAttributes(
                courseId: courseId,
                regionName: regionName
            ),
            contentState: state,
            pushType: nil  // 1단계는 앱이 켜져 있을 때만 갱신한다
        )
    }

    func endAll() {
        endAllNow()
    }

    private func endAllNow() {
        for activity in Activity<TripActivityAttributes>.activities {
            Task { await activity.end(dismissalPolicy: .immediate) }
        }
    }
}
