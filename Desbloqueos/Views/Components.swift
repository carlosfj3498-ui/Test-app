import SwiftUI
import UnlockCore

/// La cifra protagonista: cuánto duró la pausa que acaba de terminar.
struct PauseHeadline: View {
    let gap: TimeInterval?
    let unlockedAt: Date?

    private var pauseStart: Date? {
        guard let gap, let unlockedAt else { return nil }
        return unlockedAt.addingTimeInterval(-gap)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Estuviste sin desbloquear")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Palette.secondaryText)

            if let gap {
                Text(DurationText.long(gap))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.tint(forGap: gap))
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)

                if let pauseStart, let unlockedAt {
                    Label(
                        "De \(DurationText.clock(pauseStart)) a \(DurationText.clock(unlockedAt))",
                        systemImage: "clock"
                    )
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
                }
            } else {
                Text("Primer desbloqueo registrado")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.primaryText)
                Text("A partir del siguiente ya puedo decirte cuánto aguantaste.")
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
            }
        }
        .card()
    }
}

/// Contador que corre solo desde el último desbloqueo.
struct LiveCounter: View {
    let since: Date?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone.gen3")
                .font(.title3)
                .foregroundStyle(Palette.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Desde ese desbloqueo han pasado")
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)

                if let since {
                    Text(since, style: .timer)
                        .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
                        .foregroundStyle(Palette.primaryText)
                } else {
                    Text("—")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(Palette.secondaryText)
                }
            }
            Spacer(minLength: 0)
        }
        .card(padding: 14)
    }
}

/// Anillo que compara la última pausa con el objetivo que te has puesto.
struct GoalRing: View {
    let gap: TimeInterval?
    let goal: TimeInterval

    private var progress: Double {
        guard let gap, goal > 0 else { return 0 }
        return min(1, gap / goal)
    }

    private var reached: Bool { progress >= 1 }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Palette.cardBorder, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: max(0.01, progress))
                    .stroke(
                        reached ? Palette.calm : Palette.accent,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Image(systemName: reached ? "checkmark" : "hourglass")
                    .font(.headline)
                    .foregroundStyle(reached ? Palette.calm : Palette.accent)
            }
            .frame(width: 62, height: 62)
            .animation(.snappy, value: progress)

            VStack(alignment: .leading, spacing: 4) {
                Text(reached ? "Objetivo cumplido" : "Objetivo de pausa")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.primaryText)
                Text(reached
                     ? "La última pausa superó tu objetivo de \(DurationText.long(goal))."
                     : "Te faltaron \(DurationText.compact(max(0, goal - (gap ?? 0)))) para llegar a \(DurationText.long(goal)).")
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .card()
    }
}

/// Una cifra suelta con su etiqueta.
struct StatTile: View {
    let icon: String
    let title: String
    let value: String
    var tint: Color = Palette.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Palette.primaryText)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title)
                .font(.caption)
                .foregroundStyle(Palette.secondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card(padding: 14)
    }
}

/// Fila de un desbloqueo en las listas.
struct UnlockRow: View {
    let event: UnlockEvent

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Palette.tint(forGap: event.gap))
                .frame(width: 8, height: 8)

            Text(DurationText.clock(event.date))
                .font(.system(.subheadline, design: .rounded).weight(.semibold).monospacedDigit())
                .foregroundStyle(Palette.primaryText)
                .frame(width: 58, alignment: .leading)

            if let gap = event.gap {
                Text("tras \(DurationText.compact(gap))")
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
            } else {
                Text("primer registro")
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

/// Encabezado de sección dentro del scroll.
struct SectionTitle: View {
    let text: String
    var systemImage: String?

    var body: some View {
        Label {
            Text(text)
                .font(.headline)
                .foregroundStyle(Palette.primaryText)
        } icon: {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(Palette.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
}
