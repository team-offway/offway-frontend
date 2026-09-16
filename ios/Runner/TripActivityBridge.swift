import ActivityKit
import Flutter
import Foundation
import WidgetKit

/// Flutter 가 부르는 잠금화면 제어 — `TripActivityService` 와 짝이다.
///
/// **재료만 받는다.** 문구는 `ContentState` 가 조립한다(core #577 B안). 서버가
/// 자정에 보내는 것과 같은 다섯 칸이라, 앱이 띄운 카드와 서버가 갱신한 카드가
/// 다른 말을 하지 않는다.
///
/// 띄운 카드의 **푸시 토큰은 Dart 로 되돌려 준다**(`onPushToken`). 서버 등록은
/// JWT 를 쥔 Dart 가 한다.
enum TripActivityBridge {
    /// Dart 쪽 `TripActivityService.channelName` 과 같아야 한다
    static let channelName = "com.nth.offway/trip_activity"

    /// Dart 를 되부를 때 쓴다 — 푸시 토큰이 나오면 이 채널로 올린다
    private static var channel: FlutterMethodChannel?

    static func register(with controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: controller.binaryMessenger
        )
        self.channel = channel
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "isAvailable":
                result(isAvailable())
            case "start":
                start(call.arguments, result: result)
            case "end":
                end(result: result)
            case "isWidgetAvailable":
                result(isWidgetAvailable())
            case "setWidgetTrips":
                setWidgetTrips(call.arguments, result: result)
            case "markWidgetSignedIn":
                markWidgetSignedIn(result: result)
            case "clearWidget":
                clearWidget(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    /// 카드 하나의 푸시 토큰이 나왔다 — Dart 가 서버에 올린다.
    ///
    /// **메인 스레드에서 부른다.** 채널 호출은 플랫폼 스레드가 계약이다
    @MainActor
    static func deliverPushToken(courseId: String, token: String) {
        channel?.invokeMethod(
            "onPushToken",
            arguments: ["courseId": courseId, "token": token]
        )
    }

    private static func isAvailable() -> Bool {
        guard #available(iOS 16.1, *) else { return false }
        // 사용자가 설정에서 껐을 수도 있다 — 그때도 거짓이다
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }

    private static func start(_ arguments: Any?, result: @escaping FlutterResult) {
        guard #available(iOS 16.1, *) else { return result(nil) }
        // 네 칸은 위젯 목록과 같은 이름·같은 파서다
        guard let args = arguments as? [String: Any],
              let trip = TripWidgetTrip(channelArgs: args)
        else {
            return result(
                FlutterError(code: "BAD_ARGS", message: "필요한 값이 없다", details: nil)
            )
        }
        let courseId = trip.courseId

        // Dart 의 null 은 NSNull 로 온다 — `as? Int` 가 nil 을 돌려주므로 그대로 옵셔널.
        // 둘 중 하나만 값이 있는 것이 정상이다(출발 전이냐 여행 중이냐)
        let state = TripActivityAttributes.ContentState(
            regionName: trip.regionName,
            daysLeft: args["daysLeft"] as? Int,
            dayNth: args["dayNth"] as? Int,
            startDate: trip.startDate,
            endDate: trip.endDate
        )

        // **줄을 세워 보낸다.** 앱 재개가 연달아 오거나 sync 중에 로그아웃이
        // 겹치면 start 와 end 의 Task 가 동시에 돌아, 두 endAll 이 같은
        // activity 를 각각 내리는 사이 request 가 끼어든다 — 잠금화면에
        // 둘이 쌓이거나 방금 띄운 것이 곧바로 내려간다
        Task {
            do {
                try await ActivityQueue.shared.startOrUpdate(
                    courseId: courseId,
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

    // MARK: 위젯

    /// 위젯을 그릴 수 있는 기기인가 — 익스텐션 배포 타깃(16.1)과 같은 선.
    /// 라이브 액티비티와 달리 사용자가 설정에서 끌 수 있는 것이 아니다
    private static func isWidgetAvailable() -> Bool {
        if #available(iOS 16.1, *) { return true }
        return false
    }

    /// 위젯이 읽을 예정 여행 목록을 App Group 저장소에 쓴다. **목록이 바뀌었을
    /// 때만** 위젯 시간표를 다시 만들게 한다 — 앱 재개마다 부르는 자리라
    /// 같은 목록으로 익스텐션을 깨우면 낭비다.
    ///
    /// 칸이 빠진 항목은 `start` 와 같이 **거절한다** — 조용히 버리면 위젯이
    /// "예정된 여행이 없어요" 를 보이는데 Dart 는 성공으로 안다
    private static func setWidgetTrips(_ arguments: Any?, result: FlutterResult) {
        guard let args = arguments as? [String: Any],
              let raw = args["trips"] as? [[String: Any]]
        else {
            return result(
                FlutterError(code: "BAD_ARGS", message: "trips 가 없다", details: nil)
            )
        }
        var trips: [TripWidgetTrip] = []
        for item in raw {
            guard let trip = TripWidgetTrip(channelArgs: item) else {
                return result(
                    FlutterError(code: "BAD_ARGS", message: "칸이 빠진 여행이 있다", details: nil)
                )
            }
            trips.append(trip)
        }
        do {
            if try TripWidgetStore.save(trips) {
                WidgetCenter.shared.reloadTimelines(ofKind: TripWidgetStore.widgetKind)
            }
        } catch {
            return result(
                FlutterError(
                    code: "WIDGET_SAVE_FAILED",
                    message: error.localizedDescription,
                    details: nil
                )
            )
        }
        result(nil)
    }

    /// 세션이 시작됐다 — 목록이 오기 전에도 "로그인 전" 으로 보이지 않게
    private static func markWidgetSignedIn(result: FlutterResult) {
        let wasSignedIn = TripWidgetStore.isSignedIn
        TripWidgetStore.markSignedIn()
        if !wasSignedIn {
            WidgetCenter.shared.reloadTimelines(ofKind: TripWidgetStore.widgetKind)
        }
        result(nil)
    }

    /// 로그아웃·탈퇴 — 위젯을 로그인 전 상태로 되돌린다
    private static func clearWidget(result: FlutterResult) {
        TripWidgetStore.clear()
        WidgetCenter.shared.reloadTimelines(ofKind: TripWidgetStore.widgetKind)
        result(nil)
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
/// "한 번에 하나" 가 깨진다. actor 안에서만 만지고, **await 가 있는 작업은
/// 체인으로 하나씩** 돌린다 — actor 는 await 지점에서 다른 호출을 받아들이므로
/// (재진입) 그것만으로는 틈이 남는다.
@available(iOS 16.1, *)
actor ActivityQueue {
    static let shared = ActivityQueue()

    /// 카드마다 토큰을 지켜보는 작업. **카드가 바뀌면 앞의 것을 끊는다** —
    /// 안 끊으면 내린 카드의 토큰이 계속 올라간다
    private var tokenWatchers: [String: Task<Void, Never>] = [:]

    /// 마지막으로 줄 세운 작업 — 다음 작업은 이것이 끝난 뒤 시작한다
    private var tail: Task<Void, Never>?

    /// 앞 작업이 끝난 뒤에 잇는다.
    ///
    /// `end` 를 기다리는 사이 다음 `startOrUpdate` 가 들어와 "떠 있는 카드
    /// 없음" 을 보고 새로 띄우면, 앞 작업이 깨어나 하나 더 띄운다 — 잠금화면에
    /// 둘이 쌓인다. 줄을 세우면 앞 작업이 request 까지 마친 뒤에야 다음이 본다
    private func enqueue<T: Sendable>(
        _ operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        let previous = tail
        let task = Task<T, Error> {
            await previous?.value
            return try await operation()
        }
        tail = Task { _ = try? await task.value }
        return try await task.value
    }

    func startOrUpdate(
        courseId: String,
        state: TripActivityAttributes.ContentState
    ) async throws {
        try await enqueue {
            try await self.performStartOrUpdate(courseId: courseId, state: state)
        }
    }

    /// 떠 있는 카드를 전부 내린다. **실제로 내려간 뒤에 돌아온다** — 로그아웃이
    /// 이걸 기다렸다가 답하므로, 먼저 돌아오면 Flutter 는 내려갔다고 아는데
    /// 잠금화면에는 아직 남아 있다
    func endAll() async {
        _ = try? await enqueue { await self.endAllNow() }
    }

    private func performStartOrUpdate(
        courseId: String,
        state: TripActivityAttributes.ContentState
    ) async throws {
        // 같은 코스가 이미 떠 있으면 새로 띄우지 않고 값만 갈아 끼운다 —
        // 두 번 띄우면 잠금화면에 같은 여행이 둘 쌓인다.
        //
        // **활성인 것만 "떠 있다"고 본다.** 라이브 액티비티는 8시간이 지나면
        // 시스템이 끝내는데(`.ended`), 끝난 카드도 잠금화면에 최대 4시간 더
        // 남아 있고 그동안 `activities` 에도 남는다. 그것을 찾아 `update` 를
        // 보내면 아무 일도 안 일어난다 — 앱을 다시 열어도 카드가 안 살아난다.
        // 끝난 것은 아래 `endAllNow()` 가 치우고 새로 띄운다
        if let live = Activity<TripActivityAttributes>.activities.first(where: {
            $0.attributes.courseId == courseId && $0.activityState == .active
        }) {
            await live.update(using: state)
            // 앱을 다시 켠 뒤라면 지켜보는 작업이 없다 — 토큰을 다시 올려
            // 서버가 최신 주소를 갖게 한다(등록은 멱등이다)
            watchPushToken(of: live)
            return
        }

        // 다른 코스가 떠 있으면 **다 내려간 뒤에** 이것으로 바꾼다. 기다리지
        // 않으면 앞 카드가 아직 살아 있을 때 request 가 돌아, 동시 개수 제한에
        // 걸려 실패하거나 잠깐 둘이 겹친다(#296 리뷰)
        await endAllNow()

        let activity = try Activity.request(
            attributes: TripActivityAttributes(courseId: courseId),
            contentState: state,
            // **토큰을 받는다.** 서버가 자정마다 이 카드를 갱신한다(core #577)
            pushType: .token
        )
        watchPushToken(of: activity)
    }

    private func endAllNow() async {
        for watcher in tokenWatchers.values { watcher.cancel() }
        tokenWatchers.removeAll()
        for activity in Activity<TripActivityAttributes>.activities {
            await activity.end(dismissalPolicy: .immediate)
        }
    }

    /// 토큰이 나올 때마다 Dart 로 올린다. iOS 는 첫 토큰을 곧 주고, 도중에
    /// 갈아 끼우면 또 준다 — 그때마다 같은 등록을 다시 보내면 된다
    private func watchPushToken(of activity: Activity<TripActivityAttributes>) {
        let courseId = activity.attributes.courseId
        tokenWatchers[courseId]?.cancel()
        tokenWatchers[courseId] = Task {
            for await data in activity.pushTokenUpdates {
                if Task.isCancelled { return }
                let hex = data.map { String(format: "%02x", $0) }.joined()
                await TripActivityBridge.deliverPushToken(courseId: courseId, token: hex)
            }
        }
    }
}
