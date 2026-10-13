import ActivityKit
import Foundation

/// Drives the "reading" Live Activity: the open story on the Lock Screen and in
/// the Dynamic Island, so a backgrounded read is one tap from resuming. Every
/// call no-ops where Live Activities are unavailable (iPad, or turned off).
@MainActor
final class ReadingActivityController {
    private var activity: Activity<ReadingActivityAttributes>?

    func start(story: Story) {
        guard activity == nil, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = ReadingActivityAttributes(
            storyIndex: story.index, title: story.title, titleEn: story.titleEn)
        let state = ReadingActivityAttributes.ContentState(
            progress: 0, wordsLookedUp: 0, secondsRead: 0, finished: false)
        activity = try? Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
    }

    func update(progress: Double, wordsLookedUp: Int, secondsRead: Int, finished: Bool) {
        guard let activity else { return }
        let state = ReadingActivityAttributes.ContentState(
            progress: progress, wordsLookedUp: wordsLookedUp, secondsRead: secondsRead, finished: finished)
        // Stale after 4h: the system greys it out if the app never comes back.
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(4 * 3600))
        Task { await activity.update(content) }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    /// Clears activities orphaned by a crash or force-quit mid-read.
    func endOrphans() {
        Task {
            for orphan in Activity<ReadingActivityAttributes>.activities {
                await orphan.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
