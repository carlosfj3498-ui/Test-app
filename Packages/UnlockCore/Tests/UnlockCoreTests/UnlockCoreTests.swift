import XCTest
@testable import UnlockCore

final class UnlockStoreTests: XCTestCase {

    private var store: UnlockStore!
    private var defaults: UserDefaults!
    private var fileURL: URL!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "UnlockCoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).json")
        store = UnlockStore(defaults: defaults, fileURL: fileURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testFirstUnlockHasNoGap() {
        let event = store.recordUnlock(at: Date())
        XCTAssertNotNil(event)
        XCTAssertNil(event?.gap)
        XCTAssertEqual(store.allEvents().count, 1)
    }

    func testSecondUnlockMeasuresTheGap() {
        let start = Date()
        store.recordUnlock(at: start)
        let event = store.recordUnlock(at: start.addingTimeInterval(3600))

        XCTAssertEqual(event?.gap ?? 0, 3600, accuracy: 0.001)
        XCTAssertEqual(store.allEvents().count, 2)
    }

    func testRepeatedNotificationsAreCollapsed() {
        let start = Date()
        store.recordUnlock(at: start, minimumInterval: 8)
        // El sistema nos avisa dos veces del mismo desbloqueo.
        let duplicate = store.recordUnlock(at: start.addingTimeInterval(1), minimumInterval: 8)

        XCTAssertNil(duplicate)
        XCTAssertEqual(store.allEvents().count, 1)
    }

    func testClockGoingBackwardsDoesNotProduceNegativeGap() {
        let start = Date()
        store.recordUnlock(at: start)
        let event = store.recordUnlock(at: start.addingTimeInterval(-3600))

        XCTAssertNotNil(event)
        XCTAssertNil(event?.gap, "Una pausa negativa no significa nada: mejor reiniciar la cuenta")
    }

    func testSnapshotMatchesLastRecordedUnlock() {
        let start = Date()
        store.recordUnlock(at: start)
        store.recordUnlock(at: start.addingTimeInterval(900))

        let snapshot = store.snapshot(now: start.addingTimeInterval(900))
        XCTAssertEqual(snapshot.lastGap ?? 0, 900, accuracy: 0.001)
        XCTAssertEqual(snapshot.lastUnlock?.timeIntervalSince1970 ?? 0,
                       start.addingTimeInterval(900).timeIntervalSince1970,
                       accuracy: 0.001)
    }

    func testResetClearsEverything() {
        store.recordUnlock(at: Date())
        store.reset()

        XCTAssertTrue(store.allEvents().isEmpty)
        XCTAssertNil(store.lastUnlockDate())
        XCTAssertEqual(store.snapshot(), .empty)
    }

    func testHistorySurvivesANewStoreInstance() {
        let start = Date()
        store.recordUnlock(at: start)
        store.recordUnlock(at: start.addingTimeInterval(600))

        let reopened = UnlockStore(defaults: defaults, fileURL: fileURL)
        XCTAssertEqual(reopened.allEvents().count, 2)
    }
}

final class UnlockStatsTests: XCTestCase {

    /// Construye un día con desbloqueos a las horas indicadas.
    private func events(onDayOf reference: Date, hours: [Double], after previousUnlock: Date? = nil) -> [UnlockEvent] {
        let startOfDay = Calendar.current.startOfDay(for: reference)
        var result: [UnlockEvent] = []
        var previous: Date? = previousUnlock
        for hour in hours {
            let date = startOfDay.addingTimeInterval(hour * 3600)
            result.append(UnlockEvent(date: date, gap: previous.map { date.timeIntervalSince($0) }))
            previous = date
        }
        return result
    }

    func testCountsAndLongestGap() {
        let now = Date()
        let stats = UnlockStats.compute(
            events: events(onDayOf: now, hours: [8, 9, 12, 12.5]),
            now: Calendar.current.startOfDay(for: now).addingTimeInterval(13 * 3600)
        )

        XCTAssertEqual(stats.unlocksToday, 4)
        XCTAssertEqual(stats.longestGapToday ?? 0, 3 * 3600, accuracy: 0.001)
        XCTAssertEqual(stats.averageGapToday ?? 0, (3600 + 3 * 3600 + 1800) / 3, accuracy: 0.001)
    }

    func testDaytimeGapIgnoresTheFirstPauseOfTheDay() {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        // Último desbloqueo de ayer a las 23:00, primero de hoy a las 8:00:
        // nueve horas de pausa que son la noche, no un mérito del día.
        let lastNight = startOfDay.addingTimeInterval(-3600)
        var history = [UnlockEvent(date: lastNight, gap: nil)]
        history += events(onDayOf: now, hours: [8, 9, 10], after: lastNight)

        let stats = UnlockStats.compute(
            events: history,
            now: startOfDay.addingTimeInterval(11 * 3600)
        )

        XCTAssertEqual(stats.unlocksToday, 3)
        XCTAssertEqual(stats.longestGapToday ?? 0, 9 * 3600, accuracy: 0.001)
        XCTAssertEqual(stats.longestDaytimeGapToday ?? 0, 3600, accuracy: 0.001)
    }

    func testHourlyBucketsAlwaysCoverTheWholeDay() {
        let now = Date()
        let endOfDay = Calendar.current.startOfDay(for: now).addingTimeInterval(23 * 3600)
        let stats = UnlockStats.compute(events: events(onDayOf: now, hours: [9, 9.2]), now: endOfDay)
        XCTAssertEqual(stats.hourly.count, 24)
        XCTAssertEqual(stats.hourly[9].count, 2)
        XCTAssertEqual(stats.hourly[3].count, 0)
    }

    func testEmptyHistoryIsSafe() {
        let stats = UnlockStats.compute(events: [])
        XCTAssertEqual(stats.unlocksToday, 0)
        XCTAssertNil(stats.longestGapToday)
        XCTAssertEqual(stats.hourly.count, 24)
    }
}

final class DurationTextTests: XCTestCase {

    func testCompactUsesAtMostTwoUnits() {
        XCTAssertEqual(DurationText.compact(45), "45 s")
        XCTAssertEqual(DurationText.compact(120), "2 min")
        XCTAssertEqual(DurationText.compact(2 * 3600 + 14 * 60), "2 h 14 min")
        XCTAssertEqual(DurationText.compact(3600), "1 h")
        XCTAssertEqual(DurationText.compact(25 * 3600), "1 d 1 h")
    }

    func testLongReadsLikeASentence() {
        XCTAssertEqual(DurationText.long(3600), "1 hora")
        XCTAssertEqual(DurationText.long(2 * 3600 + 14 * 60), "2 horas y 14 minutos")
        XCTAssertEqual(DurationText.long(60), "1 minuto")
    }

    func testInvalidValuesFallBackToADash() {
        XCTAssertEqual(DurationText.compact(nil), "—")
        XCTAssertEqual(DurationText.compact(-10), "—")
        XCTAssertEqual(DurationText.long(nil), "—")
    }

    func testMilestoneRoundTrip() {
        let selection: Set<TimeInterval> = [1800, 3600]
        XCTAssertEqual(Set<TimeInterval>.milestones(from: selection.milestoneString), selection)
    }
}
