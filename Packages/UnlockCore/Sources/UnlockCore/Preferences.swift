import Foundation

/// Un aviso programado: "llevas X sin desbloquear el teléfono".
public struct Milestone: Identifiable, Hashable, Sendable {
    public let seconds: TimeInterval
    public var id: TimeInterval { seconds }

    public init(seconds: TimeInterval) {
        self.seconds = seconds
    }

    public var label: String { DurationText.long(seconds) }

    /// Opciones que se ofrecen en Ajustes.
    public static let all: [Milestone] = [
        Milestone(seconds: 15 * 60),
        Milestone(seconds: 30 * 60),
        Milestone(seconds: 60 * 60),
        Milestone(seconds: 2 * 3600),
        Milestone(seconds: 4 * 3600),
        Milestone(seconds: 8 * 3600),
        Milestone(seconds: 12 * 3600),
        Milestone(seconds: 24 * 3600)
    ]

    public static let defaultSelection: Set<TimeInterval> = [
        30 * 60, 60 * 60, 2 * 3600, 4 * 3600, 8 * 3600
    ]
}

/// Claves de las preferencias, compartidas con el widget.
public enum PreferenceKeys {
    public static let notificationsEnabled = "pref.notificationsEnabled"
    public static let milestones = "pref.milestones"
    public static let minimumInterval = "pref.minimumInterval"
    public static let appSwitchGrace = "pref.appSwitchGrace"
    public static let goalSeconds = "pref.goalSeconds"
    public static let hasOnboarded = "pref.hasOnboarded"
}

public enum PreferenceDefaults {
    /// Dos avisos de desbloqueo separados por menos de esto son el mismo evento.
    /// Hace falta porque iOS nos avisa del mismo desbloqueo por varias vías.
    public static let minimumInterval: TimeInterval = 8
    /// Volver a la app desde otra app solo cuenta como desbloqueo si estuviste
    /// fuera al menos este tiempo. Por debajo de eso fue un cambio de app, no
    /// un desbloqueo, y contarlo inflaría las cifras.
    public static let appSwitchGrace: TimeInterval = 5 * 60
    /// Objetivo diario: aguantar al menos esto sin desbloquear, de día.
    public static let goalSeconds: TimeInterval = 60 * 60

    public static var milestonesString: String {
        Milestone.defaultSelection.sorted().map { String(Int($0)) }.joined(separator: ",")
    }

    /// Escribe los valores por defecto la primera vez que se abre la app.
    public static func register(in defaults: UserDefaults = SharedDefaults.shared) {
        defaults.register(defaults: [
            PreferenceKeys.notificationsEnabled: false,
            PreferenceKeys.milestones: milestonesString,
            PreferenceKeys.minimumInterval: minimumInterval,
            PreferenceKeys.appSwitchGrace: appSwitchGrace,
            PreferenceKeys.goalSeconds: goalSeconds,
            PreferenceKeys.hasOnboarded: false
        ])
    }
}

public extension Set where Element == TimeInterval {
    /// Serializa un conjunto de hitos para guardarlo en `UserDefaults`.
    var milestoneString: String {
        sorted().map { String(Int($0)) }.joined(separator: ",")
    }

    /// Lee un conjunto de hitos desde `UserDefaults`.
    static func milestones(from string: String) -> Set<TimeInterval> {
        Set(string.split(separator: ",").compactMap { Double($0) })
    }
}
