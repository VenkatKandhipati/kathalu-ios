import Foundation
import UserNotifications

/// The daily reading reminder (local notifications — works offline, no server).
///
/// Instead of one repeating notification, the next `daysAhead` days are
/// scheduled individually so each can carry that day's story and the streak,
/// and today's can be dropped once the day's 3 minutes are read. `AppModel`
/// reschedules at launch, on foreground, when today's goal is met, and when
/// the setting changes — so the near-term messages stay accurate.
@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    /// One per day; if the app isn't opened for two weeks, the reminders stop.
    private static let daysAhead = 14
    private static let idPrefix = "daily-reminder-"

    private let center = UNUserNotificationCenter.current()

    /// Routes a tapped reminder's deep link; set by the app's root view. A tap
    /// that arrives before then (cold launch) waits in `pendingURL`.
    var onOpen: ((URL) -> Void)? {
        didSet {
            if let url = pendingURL, let onOpen {
                pendingURL = nil
                onOpen(url)
            }
        }
    }
    private var pendingURL: URL?

    override private init() {
        super.init()
        center.delegate = self
    }

    // MARK: Permission

    /// Asks once; afterwards returns the stored answer without a prompt.
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    var isAuthorized: Bool {
        get async {
            let status = await center.notificationSettings().authorizationStatus
            return status == .authorized || status == .provisional
        }
    }

    // MARK: Scheduling

    struct Plan {
        /// Minutes after midnight.
        var minuteOfDay: Int
        /// Streak through yesterday/today (UserData.streak).
        var streak: Int
        var readToday: Bool
        /// Story of the day for a given date.
        var storyForDate: (Date) -> Story?
    }

    private var scheduling: Task<Void, Never>?

    /// Replaces every pending reminder with the next `daysAhead` days. Runs
    /// after any reschedule still in flight, so two can't interleave.
    func reschedule(_ plan: Plan?) {
        let previous = scheduling
        scheduling = Task {
            await previous?.value
            await cancelAll()
            if let plan { await schedule(plan) }
        }
    }

    private func schedule(_ plan: Plan) async {
        guard await isAuthorized else { return }

        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        for offset in 0..<Self.daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(byAdding: .minute, value: plan.minuteOfDay, to: day),
                  fire > now
            else { continue }
            if offset == 0 && plan.readToday { continue }  // today's goal already met
            guard let story = plan.storyForDate(day) else { continue }

            // Only the next reminder knows the streak (later ones depend on
            // days not read yet): reading that day makes it streak + 1.
            let isNext = offset == 0 || (offset == 1 && plan.readToday)
            let reaching = plan.streak + 1
            let milestone = isNext && plan.streak > 0 && ReminderContent.milestones.contains(reaching)
                ? reaching : nil
            let content = notificationContent(
                ReminderContent.make(for: day, story: story, milestone: milestone), story: story)

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let request = UNNotificationRequest(
                identifier: Self.idPrefix + DayStamp(date: day).description,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            try? await center.add(request)
        }
    }

    private func notificationContent(_ reminder: ReminderContent, story: Story) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        content.userInfo = ["url": "kathalu://story/\(story.index)"]
        return content
    }

    #if DEBUG
    private var testRound = 0

    /// Fires one reminder after `seconds`, for testing on a device without
    /// waiting. Each tap shows the next style — word, story, then a
    /// milestone — using today's story. Background the app to see it.
    func sendTest(_ plan: Plan, after seconds: TimeInterval = 10) async {
        guard await isAuthorized, let story = plan.storyForDate(.now) else { return }
        let kinds: [ReminderContent.Kind] = [.word, .story, .word]
        let round = testRound % kinds.count
        testRound += 1
        let reminder = ReminderContent.make(
            for: .now, story: story, milestone: round == 2 ? 30 : nil, kind: kinds[round])
        try? await center.add(UNNotificationRequest(
            identifier: "reminder-test",
            content: notificationContent(reminder, story: story),
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)))
    }
    #endif

    private func cancelAll() async {
        let ids = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: UNUserNotificationCenterDelegate

    /// Already in the app — no banner needed.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        []
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let raw = response.notification.request.content.userInfo["url"] as? String,
              let url = URL(string: raw) else { return }
        await MainActor.run {
            if let onOpen { onOpen(url) } else { pendingURL = url }
        }
    }
}
