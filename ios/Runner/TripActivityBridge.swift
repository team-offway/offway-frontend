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
              let daysUntil = args["daysUntil"] as? Int,
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
            daysUntil: daysUntil,
            compactLabel: compactLabel
        )

        // 같은 코스가 이미 떠 있으면 새로 띄우지 않고 값만 갈아 끼운다 —
        // 두 번 띄우면 잠금화면에 같은 여행이 둘 쌓인다
        if let live = Activity<TripActivityAttributes>.activities.first(where: {
            $0.attributes.courseId == courseId
        }) {
            Task {
                await live.update(using: state)
                result(nil)
            }
            return
        }

        // 다른 코스가 떠 있으면 내리고 이것으로 바꾼다 — 한 번에 하나다
        endAll()

        do {
            _ = try Activity.request(
                attributes: TripActivityAttributes(
                    courseId: courseId,
                    regionName: regionName
                ),
                contentState: state,
                pushType: nil  // 1단계는 앱이 켜져 있을 때만 갱신한다
            )
            result(nil)
        } catch {
            result(
                FlutterError(
                    code: "START_FAILED",
                    message: error.localizedDescription,
                    details: nil
                )
            )
        }
    }

    private static func end(result: @escaping FlutterResult) {
        guard #available(iOS 16.1, *) else { return result(nil) }
        endAll()
        result(nil)
    }

    @available(iOS 16.1, *)
    private static func endAll() {
        for activity in Activity<TripActivityAttributes>.activities {
            Task { await activity.end(dismissalPolicy: .immediate) }
        }
    }
}
