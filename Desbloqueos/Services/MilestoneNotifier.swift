import Foundation
import UnlockCore
import UserNotifications

/// Programa avisos del tipo "llevas 2 horas sin desbloquear tu iPhone".
///
/// Son notificaciones locales programadas hacia el futuro desde el último
/// desbloqueo. Como se quedan en la pantalla de bloqueo, la cifra está ahí
/// esperándote justo cuando vuelves a coger el teléfono, que es el momento en
/// el que sirve de algo.
///
/// Se reprograman cada vez que el teléfono se bloquea y se cancelan en cuanto
/// detectamos un desbloqueo.
final class MilestoneNotifier {

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private let identifierPrefix = "milestone."

    init(center: UNUserNotificationCenter = .current(), defaults: UserDefaults = SharedDefaults.shared) {
        self.center = center
        self.defaults = defaults
    }

    // MARK: - Permiso

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - Programación

    /// Programa un aviso por cada hito elegido, contando desde `anchor`.
    func schedule(from anchor: Date, now: Date = Date()) {
        cancelPending()

        guard defaults.bool(forKey: PreferenceKeys.notificationsEnabled) else { return }

        let stored = defaults.string(forKey: PreferenceKeys.milestones) ?? PreferenceDefaults.milestonesString
        let milestones = Set<TimeInterval>.milestones(from: stored).sorted()
        let elapsed = max(0, now.timeIntervalSince(anchor))

        for milestone in milestones {
            let delay = milestone - elapsed
            // Ese hito ya pasó mientras usabas el teléfono: no tiene sentido.
            guard delay > 1 else { continue }

            let content = UNMutableNotificationContent()
            content.title = title(for: milestone)
            content.body = body(for: milestone)
            content.sound = nil
            content.interruptionLevel = .passive
            content.threadIdentifier = "desbloqueos.milestones"

            let request = UNNotificationRequest(
                identifier: identifierPrefix + String(Int(milestone)),
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            )
            center.add(request, withCompletionHandler: nil)
        }
    }

    /// Quita los avisos que aún no han saltado.
    func cancelPending() {
        center.getPendingNotificationRequests { [identifierPrefix, center] requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(identifierPrefix) }
            guard !ids.isEmpty else { return }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Textos

    private func title(for milestone: TimeInterval) -> String {
        "\(DurationText.long(milestone)) sin desbloquear"
    }

    private func body(for milestone: TimeInterval) -> String {
        switch milestone {
        case ..<(60 * 60):
            return "Tu iPhone lleva \(DurationText.long(milestone)) esperando. Vas bien."
        case ..<(4 * 3600):
            return "Llevas \(DurationText.long(milestone)) sin cogerlo. Nada urgente ha pasado."
        default:
            return "\(DurationText.long(milestone)) sin desbloquearlo. Eso es una pausa de verdad."
        }
    }
}
