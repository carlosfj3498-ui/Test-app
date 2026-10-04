import Charts
import SwiftUI
import UnlockCore

/// Pantalla principal: lo que quieres ver justo después de desbloquear.
struct TodayView: View {
    @EnvironmentObject private var tracker: UnlockTracker

    @AppStorage(PreferenceKeys.goalSeconds, store: SharedDefaults.shared)
    private var goalSeconds: Double = PreferenceDefaults.goalSeconds

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            CanvasBackground()

            if tracker.events.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle("Hoy")
        .navigationBarTitleDisplayMode(.large)
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 14) {
                PauseHeadline(gap: tracker.lastGap, unlockedAt: tracker.lastUnlock)
                LiveCounter(since: tracker.lastUnlock)

                if tracker.lastGap != nil {
                    GoalRing(gap: tracker.lastGap, goal: goalSeconds)
                }

                SectionTitle(text: "Tu día", systemImage: "chart.bar.fill")
                statsGrid

                SectionTitle(text: "A qué horas lo coges", systemImage: "clock.fill")
                hourlyChart

                SectionTitle(text: "Últimos desbloqueos", systemImage: "list.bullet")
                recentList
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            StatTile(
                icon: "lock.open.fill",
                title: "Desbloqueos hoy",
                value: "\(tracker.stats.unlocksToday)",
                tint: Palette.accent
            )
            StatTile(
                icon: "moon.zzz.fill",
                title: "Pausa más larga del día",
                value: DurationText.compact(tracker.stats.longestDaytimeGapToday),
                tint: Palette.calm
            )
            StatTile(
                icon: "gauge.with.dots.needle.33percent",
                title: "Pausa media entre desbloqueos",
                value: DurationText.compact(tracker.stats.averageGapToday),
                tint: Palette.accent
            )
            StatTile(
                icon: "sunrise.fill",
                title: "Primera vez hoy",
                value: DurationText.clock(tracker.stats.firstUnlockToday),
                tint: Palette.alert
            )
        }
    }

    private var hourlyChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            if tracker.stats.unlocksToday == 0 {
                Text("Todavía no hay desbloqueos registrados hoy.")
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
            }

            Chart(tracker.stats.hourly) { bucket in
                BarMark(
                    x: .value("Hora", bucket.hour),
                    y: .value("Desbloqueos", bucket.count),
                    width: .fixed(7)
                )
                .foregroundStyle(Palette.accent)
                .cornerRadius(3)
            }
            .chartXScale(domain: 0...23)
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                    AxisValueLabel {
                        if let hour = value.as(Int.self) {
                            Text(String(format: "%02d", hour))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
            }
            .frame(height: 130)

            Text("Cada barra son los desbloqueos de esa hora del día.")
                .font(.caption)
                .foregroundStyle(Palette.secondaryText)
        }
        .card()
    }

    private var recentList: some View {
        VStack(spacing: 0) {
            let recent = Array(tracker.events.reversed().prefix(6))
            ForEach(recent) { event in
                UnlockRow(event: event)
                if event.id != recent.last?.id {
                    Divider().overlay(Palette.cardBorder)
                }
            }

            NavigationLink(value: Route.history) {
                HStack {
                    Text("Ver todo el historial")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(Palette.accent)
                .padding(.top, 12)
            }
        }
        .card()
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Aún no hay nada que contar", systemImage: "lock.iphone")
        } description: {
            Text("""
            Acabo de anotar este momento como punto de partida. \
            La próxima vez que desbloquees tu iPhone te diré cuánto tiempo aguantaste sin hacerlo.
            """)
        } actions: {
            Text("Añade el widget a la pantalla de bloqueo para verlo sin abrir la app.")
                .font(.footnote)
                .foregroundStyle(Palette.secondaryText)
                .multilineTextAlignment(.center)
        }
    }
}
