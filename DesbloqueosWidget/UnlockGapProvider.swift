import UnlockCore
import WidgetKit

struct UnlockEntry: TimelineEntry {
    let date: Date
    let snapshot: UnlockSnapshot
    /// Objetivo de pausa, para el anillo de la pantalla de bloqueo.
    let goal: TimeInterval
}

struct UnlockGapProvider: TimelineProvider {

    private let store = UnlockStore.shared

    func placeholder(in context: Context) -> UnlockEntry {
        UnlockEntry(date: Date(), snapshot: .placeholder, goal: PreferenceDefaults.goalSeconds)
    }

    func getSnapshot(in context: Context, completion: @escaping (UnlockEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UnlockEntry>) -> Void) {
        let entry = currentEntry()
        // El contador se dibuja solo con `Text(style: .timer)`, así que solo
        // hace falta volver por aquí para refrescar los contadores del día.
        let next = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> UnlockEntry {
        let goal = SharedDefaults.shared.object(forKey: PreferenceKeys.goalSeconds) as? Double
            ?? PreferenceDefaults.goalSeconds
        return UnlockEntry(date: Date(), snapshot: store.snapshot(), goal: max(60, goal))
    }
}
