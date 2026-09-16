import SwiftUI
import UnlockCore
import WidgetKit

struct UnlockGapWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppIdentifiers.widgetKind, provider: UnlockGapProvider()) { entry in
            UnlockGapWidgetView(entry: entry)
                .widgetURL(AppIdentifiers.deepLink)
        }
        .configurationDisplayName("Tiempo sin desbloquear")
        .description("Cuánto llevas sin desbloquear el iPhone y cuánto duró tu última pausa.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

struct UnlockGapWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: UnlockEntry

    private var since: Date { entry.snapshot.lastUnlock ?? entry.date }

    /// Rango que llena el anillo: desde el último desbloqueo hasta el objetivo.
    private var goalRange: ClosedRange<Date> {
        since...since.addingTimeInterval(entry.goal)
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            inlineView
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .systemMedium:
            mediumView.containerBackground(.fill.tertiary, for: .widget)
        default:
            smallView.containerBackground(.fill.tertiary, for: .widget)
        }
    }

    // MARK: - Pantalla de bloqueo

    private var inlineView: some View {
        Label {
            Text(since, style: .timer)
        } icon: {
            Image(systemName: "hourglass")
        }
    }

    private var circularView: some View {
        ProgressView(timerInterval: goalRange, countsDown: false) {
            Image(systemName: "hourglass")
        } currentValueLabel: {
            Text(since, style: .timer)
                .font(.system(size: 13, design: .rounded))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
        }
        .progressViewStyle(.circular)
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("SIN DESBLOQUEAR")
                .font(.caption2.weight(.semibold))
                .widgetAccentable()

            Text(since, style: .timer)
                .font(.title3.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(entry.snapshot.lastGap == nil
                 ? "Primer registro"
                 : "Pausa anterior: \(DurationText.compact(entry.snapshot.lastGap))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: - Pantalla de inicio

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "hourglass")
                Text("Sin desbloquear")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            Text(since, style: .timer)
                .font(.system(.title, design: .rounded).weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                if let gap = entry.snapshot.lastGap {
                    Text("Antes: \(DurationText.compact(gap))")
                }
                Text("\(entry.snapshot.unlocksToday) desbloqueos hoy")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mediumView: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Sin desbloquear")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(since, style: .timer)
                    .font(.system(size: 40, design: .rounded).weight(.bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text(entry.snapshot.lastGap == nil
                     ? "Tu primer registro"
                     : "Tu última pausa duró \(DurationText.long(entry.snapshot.lastGap))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                metric(
                    value: "\(entry.snapshot.unlocksToday)",
                    label: "hoy",
                    icon: "lock.open.fill"
                )
                metric(
                    value: DurationText.compact(entry.snapshot.longestGapToday),
                    label: "pausa más larga",
                    icon: "moon.zzz.fill"
                )
            }
            .frame(maxWidth: 110, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metric(value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(value, systemImage: icon)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

#Preview(as: .systemSmall) {
    UnlockGapWidget()
} timeline: {
    UnlockEntry(date: .now, snapshot: .placeholder, goal: 3600)
}

#Preview(as: .accessoryRectangular) {
    UnlockGapWidget()
} timeline: {
    UnlockEntry(date: .now, snapshot: .placeholder, goal: 3600)
}
