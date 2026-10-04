import Combine
import SwiftUI
import UIKit
import UnlockCore
import WidgetKit

/// Detecta desbloqueos del iPhone y mantiene el estado que ve la interfaz.
///
/// iOS no ofrece ninguna API que despierte a una app en cada desbloqueo, así
/// que usamos las dos señales que sí existen y las unimos:
///
///  1. `protectedDataDidBecomeAvailable`: el sistema la manda al desbloquear el
///     dispositivo. Llega mientras la app siga en memoria, aunque esté en
///     segundo plano, que es el caso normal si la usas a diario.
///  2. La escena pasando a `.active`: cubre el caso de abrir la app después de
///     que iOS la haya descargado de memoria.
///
/// Las dos pueden dispararse por el mismo desbloqueo, por eso `UnlockStore`
/// descarta los eventos demasiado seguidos.
@MainActor
final class UnlockTracker: ObservableObject {

    @Published private(set) var events: [UnlockEvent] = []
    @Published private(set) var stats: UnlockStats = .empty
    /// Momento del último desbloqueo: el contador en vivo cuenta desde aquí.
    @Published private(set) var lastUnlock: Date?
    /// Cuánto duró la pausa que terminó en ese desbloqueo.
    @Published private(set) var lastGap: TimeInterval?
    /// Última vez que el teléfono se bloqueó, si lo hemos visto.
    @Published private(set) var lockedAt: Date?

    private let store: UnlockStore
    private let notifier: MilestoneNotifier
    /// Marcado `nonisolated(unsafe)` para poder soltarlo en `deinit`, que no es
    /// aislado. Solo se toca desde el hilo principal.
    private nonisolated(unsafe) var observers: [NSObjectProtocol] = []

    /// ¿Hemos visto bloquearse el teléfono desde el último desbloqueo?
    private var sawLockSinceLastUnlock = false
    /// Cuándo se fue la app a segundo plano por última vez.
    private var leftForegroundAt: Date?
    /// El primer paso a `.active` de la sesión sí es un desbloqueo de verdad.
    private var hasRecordedLaunch = false

    init(store: UnlockStore = .shared, notifier: MilestoneNotifier = MilestoneNotifier()) {
        self.store = store
        self.notifier = notifier
        PreferenceDefaults.register()
        reload()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Ciclo de vida

    func start() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default

        observers.append(
            center.addObserver(
                forName: UIApplication.protectedDataDidBecomeAvailableNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.registerUnlock() }
            }
        )

        observers.append(
            center.addObserver(
                forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.deviceDidLock() }
            }
        )

        observers.append(
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.appDidGoToBackground() }
            }
        )

        observers.append(
            center.addObserver(
                forName: .NSCalendarDayChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.reload() }
            }
        )
    }

    /// Llamado desde la vista raíz cuando cambia la fase de la escena.
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            handleBecameActive()
        case .background:
            leftForegroundAt = Date()
            appDidGoToBackground()
        default:
            break
        }
    }

    /// Decide si volver a la app significa que desbloqueaste el teléfono.
    ///
    /// Si solo saltaste a otra app y volviste enseguida, no hubo desbloqueo y
    /// contarlo inflaría las cifras. Pero si estuviste fuera un buen rato, el
    /// bloqueo automático de iOS ya había entrado, así que sí lo contamos.
    private func handleBecameActive() {
        let away = leftForegroundAt.map { Date().timeIntervalSince($0) }
        leftForegroundAt = nil

        if !hasRecordedLaunch {
            hasRecordedLaunch = true
            registerUnlock()
            return
        }

        if sawLockSinceLastUnlock {
            registerUnlock()
            return
        }

        let grace = SharedDefaults.shared.object(forKey: PreferenceKeys.appSwitchGrace) as? Double
            ?? PreferenceDefaults.appSwitchGrace
        if let away, away < grace {
            // Cambio rápido de app: no cuenta.
            return
        }
        registerUnlock()
    }

    // MARK: - Eventos

    /// Anota un desbloqueo. Si resulta ser un duplicado, solo refresca la vista.
    func registerUnlock(at date: Date = Date()) {
        let minimumInterval = SharedDefaults.shared.object(forKey: PreferenceKeys.minimumInterval) as? Double
            ?? PreferenceDefaults.minimumInterval

        let event = store.recordUnlock(at: date, minimumInterval: minimumInterval)
        if event != nil {
            // Ya estás con el teléfono: los avisos pendientes sobran.
            notifier.cancelPending()
            lockedAt = nil
            sawLockSinceLastUnlock = false
        }
        reload()
    }

    private func deviceDidLock(at date: Date = Date()) {
        lockedAt = date
        sawLockSinceLastUnlock = true
        scheduleMilestones()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func appDidGoToBackground() {
        // Última oportunidad de ejecutar código antes de que iOS nos suspenda.
        scheduleMilestones()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func scheduleMilestones() {
        guard let anchor = lastUnlock ?? store.lastUnlockDate() else { return }
        notifier.schedule(from: anchor)
    }

    // MARK: - Estado

    func reload() {
        let all = store.allEvents()
        events = all
        stats = UnlockStats.compute(events: all)
        lastUnlock = all.last?.date ?? store.lastUnlockDate()
        lastGap = all.last?.gap
        WidgetCenter.shared.reloadAllTimelines()
    }

    func resetHistory() {
        store.reset()
        notifier.cancelPending()
        lockedAt = nil
        reload()
    }

    /// Cuánto llevas con el teléfono desde este desbloqueo.
    func elapsedSinceLastUnlock(now: Date = Date()) -> TimeInterval? {
        lastUnlock.map { max(0, now.timeIntervalSince($0)) }
    }
}
