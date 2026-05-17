import AppKit
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private var lastStatuses: [String: String] = [:]
    private var lastBusyStartTime: [String: Date] = [:]
    private var lastFireTime: [String: Date] = [:]
    private var hasRequestedPermission = false

    private let minimumBusyDurationToNotify: TimeInterval = 8.0
    private let cooldownBetweenNotifications: TimeInterval = 30.0

    func ensurePermission() {
        guard !hasRequestedPermission else { return }
        hasRequestedPermission = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Observes session status transitions and fires notifications only for the *main*
    /// conversation finishing — not for every sub-agent or short tool turn.
    /// Heuristics:
    ///   1. The session must have been busy for >= 8s before transitioning to idle
    ///      (filters out fast tool-result/sub-agent turns)
    ///   2. Per-session cooldown of 30s between notifications (filters bursts)
    func observe(sessions: [SessionInfo]) {
        let settings = AppSettings.shared
        if !settings.notificationsEnabled {
            lastStatuses = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0.status) })
            return
        }

        let now = Date()
        for session in sessions {
            let prev = lastStatuses[session.id]
            let curr = session.status

            if prev != "busy" && curr == "busy" {
                lastBusyStartTime[session.id] = now
            }

            if prev == "busy" && curr == "idle" && session.isAlive {
                let busyStart = lastBusyStartTime[session.id] ?? now
                let busyDuration = now.timeIntervalSince(busyStart)
                let lastFire = lastFireTime[session.id] ?? .distantPast
                let sinceLastFire = now.timeIntervalSince(lastFire)

                if busyDuration >= minimumBusyDurationToNotify
                    && sinceLastFire >= cooldownBetweenNotifications {
                    fireCompletion(session: session)
                    lastFireTime[session.id] = now
                }
                lastBusyStartTime.removeValue(forKey: session.id)
            }
            lastStatuses[session.id] = curr
        }

        let alive = Set(sessions.map(\.id))
        lastStatuses = lastStatuses.filter { alive.contains($0.key) }
        lastBusyStartTime = lastBusyStartTime.filter { alive.contains($0.key) }
        lastFireTime = lastFireTime.filter { alive.contains($0.key) }
    }

    private func fireCompletion(session: SessionInfo) {
        let settings = AppSettings.shared
        let content = UNMutableNotificationContent()
        content.title = "Claude finished"
        content.body = session.name
        if settings.soundEnabled { content.sound = .default }
        let request = UNNotificationRequest(identifier: "claude.\(session.id).\(Date().timeIntervalSince1970)",
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in }

        if settings.soundEnabled {
            playCuteSound()
        }
    }

    private func playCuteSound() {
        if let s = NSSound(named: NSSound.Name("Glass")) {
            s.volume = 0.4
            s.play()
        }
    }
}
