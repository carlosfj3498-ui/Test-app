import Foundation

/// Almacén de desbloqueos compartido entre la app y el widget.
///
/// Guarda dos cosas en el contenedor del App Group:
///  - `unlocks.json`: el historial completo (podado por antigüedad).
///  - Un par de claves en `UserDefaults`: el último desbloqueo y su pausa.
///    El widget solo necesita esas claves, así que puede dibujarse sin leer
///    ni decodificar el historial entero.
public final class UnlockStore: @unchecked Sendable {

    public static let shared = UnlockStore()

    /// Se publica cada vez que el historial cambia (nuevo desbloqueo, borrado…).
    public static let didChangeNotification = Notification.Name("UnlockStore.didChange")

    private enum Keys {
        static let lastUnlock = "lastUnlockDate"
        static let lastGap = "lastGapSeconds"
        static let unlocksToday = "unlocksToday"
        static let longestGapToday = "longestGapToday"
        static let todayStamp = "todayStamp"
    }

    /// Cuántos días de historial se conservan.
    public var retentionDays: Int = 120
    /// Tope duro de eventos, por si alguien desbloquea muchísimo.
    private let maximumEvents = 20_000

    private let defaults: UserDefaults
    private let fileURL: URL
    private let lock = NSLock()
    private var cache: [UnlockEvent]?

    public init(defaults: UserDefaults = SharedDefaults.shared, fileURL: URL? = nil) {
        self.defaults = defaults
        self.fileURL = fileURL ?? Self.defaultFileURL()
    }

    // MARK: - Ubicación en disco

    private static func defaultFileURL() -> URL {
        let fileManager = FileManager.default
        if let container = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: AppIdentifiers.appGroup
        ) {
            return container.appendingPathComponent("unlocks.json")
        }
        // Sin App Group configurado seguimos funcionando, solo que el widget
        // no verá los mismos datos que la app.
        let support = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory
        return support.appendingPathComponent("unlocks.json")
    }

    // MARK: - Lectura

    /// Historial completo, del más antiguo al más reciente.
    public func allEvents() -> [UnlockEvent] {
        lock.lock()
        defer { lock.unlock() }
        return loadLocked()
    }

    /// Los `limit` desbloqueos más recientes, del más nuevo al más viejo.
    public func recentEvents(limit: Int = 50) -> [UnlockEvent] {
        Array(allEvents().reversed().prefix(limit))
    }

    /// Estado mínimo para el widget. No decodifica el historial.
    public func snapshot(now: Date = Date(), calendar: Calendar = .current) -> UnlockSnapshot {
        let lastUnlockRaw = defaults.double(forKey: Keys.lastUnlock)
        guard lastUnlockRaw > 0 else { return .empty }
        let lastUnlock = Date(timeIntervalSince1970: lastUnlockRaw)

        let gapRaw = defaults.double(forKey: Keys.lastGap)
        let lastGap: TimeInterval? = gapRaw > 0 ? gapRaw : nil

        // Los contadores diarios caducan solos al cambiar de día.
        let storedStamp = defaults.double(forKey: Keys.todayStamp)
        let todayStamp = calendar.startOfDay(for: now).timeIntervalSince1970
        let sameDay = abs(storedStamp - todayStamp) < 1

        let longestRaw = defaults.double(forKey: Keys.longestGapToday)
        return UnlockSnapshot(
            lastUnlock: lastUnlock,
            lastGap: lastGap,
            unlocksToday: sameDay ? defaults.integer(forKey: Keys.unlocksToday) : 0,
            longestGapToday: sameDay && longestRaw > 0 ? longestRaw : nil
        )
    }

    /// Fecha del último desbloqueo conocido, sin tocar el historial.
    public func lastUnlockDate() -> Date? {
        let raw = defaults.double(forKey: Keys.lastUnlock)
        return raw > 0 ? Date(timeIntervalSince1970: raw) : nil
    }

    // MARK: - Escritura

    /// Registra un desbloqueo.
    ///
    /// - Parameters:
    ///   - date: momento del desbloqueo.
    ///   - minimumInterval: dos avisos de desbloqueo separados por menos de
    ///     este intervalo se consideran el mismo evento. Hace falta porque el
    ///     sistema nos avisa por varias vías a la vez (`protectedData` y el
    ///     paso de la escena a `.active`).
    /// - Returns: el evento creado, o `nil` si se descartó por ser repetido.
    @discardableResult
    public func recordUnlock(
        at date: Date = Date(),
        minimumInterval: TimeInterval = 8,
        calendar: Calendar = .current
    ) -> UnlockEvent? {
        lock.lock()

        var events = loadLocked()

        if let previous = events.last {
            let delta = date.timeIntervalSince(previous.date)
            // Reloj movido hacia atrás (cambio de hora, viaje): no inventamos
            // una pausa negativa, empezamos a contar de nuevo. Va antes que el
            // filtro de repetidos, que solo tiene sentido con deltas positivos.
            if delta < 0 {
                let event = UnlockEvent(date: date, gap: nil)
                events.append(event)
                finishWriteLocked(events: events, event: event, calendar: calendar)
                return event
            }
            // Evento repetido: lo ignoramos.
            if delta < minimumInterval {
                lock.unlock()
                return nil
            }
            let event = UnlockEvent(date: date, gap: delta)
            events.append(event)
            finishWriteLocked(events: events, event: event, calendar: calendar)
            return event
        }

        let event = UnlockEvent(date: date, gap: nil)
        events.append(event)
        finishWriteLocked(events: events, event: event, calendar: calendar)
        return event
    }

    /// Borra todo el historial.
    public func reset() {
        lock.lock()
        cache = []
        try? FileManager.default.removeItem(at: fileURL)
        for key in [Keys.lastUnlock, Keys.lastGap, Keys.unlocksToday, Keys.longestGapToday, Keys.todayStamp] {
            defaults.removeObject(forKey: key)
        }
        lock.unlock()
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    /// Sustituye el historial completo. Pensado para pruebas y para la vista previa.
    public func replaceAll(with events: [UnlockEvent], calendar: Calendar = .current) {
        lock.lock()
        let sorted = events.sorted { $0.date < $1.date }
        cache = sorted
        saveLocked(sorted)
        if let last = sorted.last {
            writeFastKeysLocked(events: sorted, event: last, calendar: calendar)
        }
        lock.unlock()
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    // MARK: - Interno

    /// Cierra una escritura: poda, guarda, actualiza claves rápidas y avisa.
    /// Debe llamarse con el `lock` tomado; lo libera antes de volver.
    private func finishWriteLocked(events: [UnlockEvent], event: UnlockEvent, calendar: Calendar) {
        let pruned = prune(events, now: event.date)
        cache = pruned
        saveLocked(pruned)
        writeFastKeysLocked(events: pruned, event: event, calendar: calendar)
        lock.unlock()
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    private func writeFastKeysLocked(events: [UnlockEvent], event: UnlockEvent, calendar: Calendar) {
        let startOfDay = calendar.startOfDay(for: event.date)
        let todays = events.filter { $0.date >= startOfDay }

        defaults.set(event.date.timeIntervalSince1970, forKey: Keys.lastUnlock)
        defaults.set(event.gap ?? 0, forKey: Keys.lastGap)
        defaults.set(todays.count, forKey: Keys.unlocksToday)
        defaults.set(todays.compactMap(\.gap).max() ?? 0, forKey: Keys.longestGapToday)
        defaults.set(startOfDay.timeIntervalSince1970, forKey: Keys.todayStamp)
    }

    private func prune(_ events: [UnlockEvent], now: Date) -> [UnlockEvent] {
        let cutoff = now.addingTimeInterval(-Double(retentionDays) * 86_400)
        var pruned = events.filter { $0.date >= cutoff }
        if pruned.count > maximumEvents {
            pruned = Array(pruned.suffix(maximumEvents))
        }
        return pruned
    }

    private func loadLocked() -> [UnlockEvent] {
        if let cache { return cache }
        guard let data = try? Data(contentsOf: fileURL) else {
            cache = []
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let events = (try? decoder.decode([UnlockEvent].self, from: data)) ?? []
        let sorted = events.sorted { $0.date < $1.date }
        cache = sorted
        return sorted
    }

    private func saveLocked(_ events: [UnlockEvent]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(events) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }
}
