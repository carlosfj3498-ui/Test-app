import SwiftUI
import UnlockCore

/// Destinos a los que se puede navegar dentro de una pestaña.
enum Route: Hashable {
    case history
}

/// Contenedor de la app: tres pestañas y el enrutado del widget.
struct RootView: View {
    @EnvironmentObject private var tracker: UnlockTracker
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab: Tab = .today
    @State private var todayPath = NavigationPath()

    enum Tab: Hashable {
        case today, history, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $todayPath) {
                TodayView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .history: HistoryView()
                        }
                    }
            }
            .tabItem { Label("Hoy", systemImage: "lock.open") }
            .tag(Tab.today)

            NavigationStack {
                HistoryView()
            }
            .tabItem { Label("Historial", systemImage: "calendar") }
            .tag(Tab.history)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Ajustes", systemImage: "gearshape") }
            .tag(Tab.settings)
        }
        .tint(Palette.accent)
        .task { tracker.start() }
        .onChange(of: scenePhase, initial: true) { _, phase in
            tracker.handleScenePhase(phase)
        }
        .onOpenURL { _ in
            // Llegamos desde el widget: siempre a la pantalla principal.
            todayPath = NavigationPath()
            selectedTab = .today
        }
    }
}
