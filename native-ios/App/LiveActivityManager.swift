import ActivityKit
import Foundation

/// Wraps ActivityKit start/update/end. The widget extension reads `DesignAttributes`
/// and renders the matching design view inside the Dynamic Island.
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activeId: Activity<DesignAttributes>.ID?

    private init() {}

    /// Start a new Live Activity for the given design. Ends any existing one first.
    func start(designId: String, ctx: LiveContext) async {
        await endAll()

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[Islet] Live Activities are disabled in Settings → \(brandName).")
            return
        }

        let attrs = DesignAttributes(designId: designId)
        let initial = ActivityContent(state: ctx.asContentState(), staleDate: nil)

        do {
            let activity = try Activity.request(
                attributes: attrs,
                content: initial,
                pushType: nil
            )
            activeId = activity.id
            print("[Islet] Started Live Activity \(activity.id) for \(designId)")
        } catch {
            print("[Islet] Failed to start Live Activity: \(error)")
        }
    }

    /// Push a new ContentState into the active Live Activity.
    func update(with ctx: LiveContext) async {
        guard let activity = Activity<DesignAttributes>.activities.first else { return }
        let content = ActivityContent(state: ctx.asContentState(), staleDate: nil)
        await activity.update(content)
    }

    /// End every active activity for this app.
    func endAll() async {
        for activity in Activity<DesignAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        activeId = nil
    }
}
