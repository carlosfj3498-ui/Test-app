import Foundation

/// Un tramo horario del día, para la gráfica de barras.
public struct HourBucket: Identifiable, Hashable, Sendable {
    public let hour: Int          // 0...23
    public let count: Int
    public var id: Int { hour }

    public init(hour: Int, count: Int) {
        self.hour = hour
        self.count = count
    }
}

/// Todo lo que la app enseña sobre tus desbloqueos, calculado de una pasada.
public struct UnlockStats: Sendable {
    public let unlocksToday: Int
    /// Hora a la que agarraste el teléfono por primera vez hoy.
    public let firstUnlockToday: Date?
    /// La pausa más larga que terminó hoy. Normalmente es la noche.
    public let longestGapToday: TimeInterval?
    /// La pausa más larga sin contar la primera del día, es decir, sin la noche.
    public let longestDaytimeGapToday: TimeInterval?
    public let averageGapToday: TimeInterval?
    public let medianGapToday: TimeInterval?
    /// El récord de todo el historial guardado.
    public let longestGapEver: TimeInterval?
    public let hourly: [HourBucket]
    public let lastSevenDays: [DaySummary]
    /// Media de desbloqueos por día en los últimos 7 días con datos.
    public let averageUnlocksPerDay: Double?

    public static let empty = UnlockStats(
        unlocksToday: 0,
        firstUnlockToday: nil,
        longestGapToday: nil,
        longestDaytimeGapToday: nil,
        averageGapToday: nil,
        medianGapToday: nil,
        longestGapEver: nil,
        hourly: (0..<24).map { HourBucket(hour: $0, count: 0) },
        lastSevenDays: [],
        averageUnlocksPerDay: nil
    )

    public init(
        unlocksToday: Int,
        firstUnlockToday: Date?,
        longestGapToday: TimeInterval?,
        longestDaytimeGapToday: TimeInterval?,
        averageGapToday: TimeInterval?,
        medianGapToday: TimeInterval?,
        longestGapEver: TimeInterval?,
        hourly: [HourBucket],
        lastSevenDays: [DaySummary],
        averageUnlocksPerDay: Double?
    ) {
        self.unlocksToday = unlocksToday
        self.firstUnlockToday = firstUnlockToday
        self.longestGapToday = longestGapToday
        self.longestDaytimeGapToday = longestDaytimeGapToday
        self.averageGapToday = averageGapToday
        self.medianGapToday = medianGapToday
        self.longestGapEver = longestGapEver
        self.hourly = hourly
        self.lastSevenDays = lastSevenDays
        self.averageUnlocksPerDay = averageUnlocksPerDay
    }

    /// Calcula todas las métricas a partir del historial.
    /// - Parameter events: ordenados de más antiguo a más reciente.
    public static func compute(
        events: [UnlockEvent],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> UnlockStats {
        guard !events.isEmpty else { return .empty }

        let startOfToday = calendar.startOfDay(for: now)
        let todays = events.filter { $0.date >= startOfToday && $0.date <= now }
        let todayGaps = todays.compactMap(\.gap).filter { $0 > 0 }
        // La primera pausa del día es la noche: la dejamos fuera del dato "de día".
        let daytimeGaps = todays.dropFirst().compactMap(\.gap).filter { $0 > 0 }

        var hourCounts = Array(repeating: 0, count: 24)
        for event in todays {
            let hour = calendar.component(.hour, from: event.date)
            if hour >= 0 && hour < 24 { hourCounts[hour] += 1 }
        }

        var days: [DaySummary] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: startOfToday) else { continue }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { continue }
            let inDay = events.filter { $0.date >= day && $0.date < nextDay }
            let gaps = inDay.compactMap(\.gap).filter { $0 > 0 }
            days.append(
                DaySummary(
                    day: day,
                    unlockCount: inDay.count,
                    longestGap: gaps.max(),
                    averageGap: gaps.isEmpty ? nil : gaps.reduce(0, +) / Double(gaps.count)
                )
            )
        }

        let daysWithData = days.filter { $0.unlockCount > 0 }
        let averagePerDay = daysWithData.isEmpty
            ? nil
            : Double(daysWithData.reduce(0) { $0 + $1.unlockCount }) / Double(daysWithData.count)

        return UnlockStats(
            unlocksToday: todays.count,
            firstUnlockToday: todays.first?.date,
            longestGapToday: todayGaps.max(),
            longestDaytimeGapToday: daytimeGaps.max(),
            averageGapToday: todayGaps.isEmpty ? nil : todayGaps.reduce(0, +) / Double(todayGaps.count),
            medianGapToday: median(of: todayGaps),
            longestGapEver: events.compactMap(\.gap).filter { $0 > 0 }.max(),
            hourly: (0..<24).map { HourBucket(hour: $0, count: hourCounts[$0]) },
            lastSevenDays: days,
            averageUnlocksPerDay: averagePerDay
        )
    }

    private static func median(of values: [TimeInterval]) -> TimeInterval? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}
