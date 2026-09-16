import Charts
import SwiftUI
import UnlockCore

/// Historial completo, agrupado por día.
struct HistoryView: View {
    @EnvironmentObject private var tracker: UnlockTracker

    private let calendar = Calendar.current

    private var grouped: [(day: Date, events: [UnlockEvent])] {
        let buckets = Dictionary(grouping: tracker.events) { calendar.startOfDay(for: $0.date) }
        return buckets
            .keys
            .sorted(by: >)
            .map { day in
                (day: day, events: (buckets[day] ?? []).sorted { $0.date > $1.date })
            }
    }

    var body: some View {
        ZStack {
            CanvasBackground()

            if tracker.events.isEmpty {
                ContentUnavailableView(
                    "Sin historial todavía",
                    systemImage: "calendar",
                    description: Text("Aquí aparecerán tus desbloqueos en cuanto empiece a haberlos.")
                )
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        weekChart

                        ForEach(grouped, id: \.day) { group in
                            daySection(day: group.day, events: group.events)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle("Historial")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var weekChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Últimos 7 días")
                .font(.headline)
                .foregroundStyle(Palette.primaryText)

            Chart(tracker.stats.lastSevenDays) { day in
                BarMark(
                    x: .value("Día", day.day, unit: .day),
                    y: .value("Desbloqueos", day.unlockCount)
                )
                .foregroundStyle(Palette.accent)
                .cornerRadius(5)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
            }
            .frame(height: 140)

            if let average = tracker.stats.averageUnlocksPerDay {
                Text("Media de \(Int(average.rounded())) desbloqueos al día.")
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)
            }
        }
        .card()
    }

    private func daySection(day: Date, events: [UnlockEvent]) -> some View {
        let gaps = events.compactMap(\.gap).filter { $0 > 0 }

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(label(for: day))
                    .font(.headline)
                    .foregroundStyle(Palette.primaryText)
                Spacer()
                Text(events.count == 1 ? "1 desbloqueo" : "\(events.count) desbloqueos")
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)
            }

            if let longest = gaps.max() {
                Text("Pausa más larga: \(DurationText.compact(longest))")
                    .font(.caption)
                    .foregroundStyle(Palette.calm)
            }

            Divider().overlay(Palette.cardBorder)

            ForEach(events) { event in
                UnlockRow(event: event)
            }
        }
        .card()
    }

    private func label(for day: Date) -> String {
        if calendar.isDateInToday(day) { return "Hoy" }
        if calendar.isDateInYesterday(day) { return "Ayer" }
        let text = day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}
