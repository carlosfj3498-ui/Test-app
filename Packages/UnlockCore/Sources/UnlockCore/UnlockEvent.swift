import Foundation

/// Un desbloqueo registrado del iPhone.
public struct UnlockEvent: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    /// Momento exacto en el que se detectó el desbloqueo.
    public let date: Date
    /// Tiempo que pasó desde el desbloqueo anterior.
    /// Es `nil` en el primer evento registrado, porque no hay con qué compararlo.
    public let gap: TimeInterval?

    public init(id: UUID = UUID(), date: Date, gap: TimeInterval?) {
        self.id = id
        self.date = date
        self.gap = gap
    }

    /// Momento en el que empezó la pausa que terminó con este desbloqueo.
    public var pauseStart: Date? {
        gap.map { date.addingTimeInterval(-$0) }
    }
}

/// Resumen de un día, para las gráficas de historial.
public struct DaySummary: Identifiable, Hashable, Sendable {
    public let day: Date          // inicio del día
    public let unlockCount: Int
    public let longestGap: TimeInterval?
    public let averageGap: TimeInterval?

    public var id: Date { day }

    public init(day: Date, unlockCount: Int, longestGap: TimeInterval?, averageGap: TimeInterval?) {
        self.day = day
        self.unlockCount = unlockCount
        self.longestGap = longestGap
        self.averageGap = averageGap
    }
}

/// Foto fija del estado actual: lo mínimo que necesita el widget.
public struct UnlockSnapshot: Hashable, Sendable {
    /// Último desbloqueo conocido. El widget cuenta hacia arriba desde aquí.
    public let lastUnlock: Date?
    /// Cuánto duró la pausa que terminó en `lastUnlock`.
    public let lastGap: TimeInterval?
    public let unlocksToday: Int
    public let longestGapToday: TimeInterval?

    public init(
        lastUnlock: Date?,
        lastGap: TimeInterval?,
        unlocksToday: Int,
        longestGapToday: TimeInterval?
    ) {
        self.lastUnlock = lastUnlock
        self.lastGap = lastGap
        self.unlocksToday = unlocksToday
        self.longestGapToday = longestGapToday
    }

    public static let placeholder = UnlockSnapshot(
        lastUnlock: Date().addingTimeInterval(-42 * 60),
        lastGap: 2 * 3600 + 14 * 60,
        unlocksToday: 37,
        longestGapToday: 3 * 3600 + 5 * 60
    )

    public static let empty = UnlockSnapshot(
        lastUnlock: nil,
        lastGap: nil,
        unlocksToday: 0,
        longestGapToday: nil
    )
}
