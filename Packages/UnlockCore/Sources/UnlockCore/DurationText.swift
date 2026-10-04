import Foundation

/// Formateo de duraciones en español.
///
/// Está hecho a mano en vez de con `DateComponentsFormatter` para controlar
/// exactamente cuántas unidades se enseñan y cómo suenan ("2 horas y 14
/// minutos" en vez de "2 h 14 min 3 s").
public enum DurationText {

    /// Versión corta, de una o dos unidades: "2 h 14 min", "45 s", "1 d 3 h".
    public static func compact(_ seconds: TimeInterval?) -> String {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return "—" }
        let total = Int(seconds.rounded())

        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        let secs = total % 60

        if days > 0 {
            return hours > 0 ? "\(days) d \(hours) h" : "\(days) d"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours) h \(minutes) min" : "\(hours) h"
        }
        if minutes > 0 {
            return "\(minutes) min"
        }
        return "\(secs) s"
    }

    /// Versión larga y legible: "2 horas y 14 minutos".
    public static func long(_ seconds: TimeInterval?) -> String {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return "—" }
        let total = Int(seconds.rounded())

        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        let secs = total % 60

        var parts: [String] = []
        if days > 0 { parts.append(plural(days, "día", "días")) }
        if hours > 0 { parts.append(plural(hours, "hora", "horas")) }
        if days == 0 && minutes > 0 { parts.append(plural(minutes, "minuto", "minutos")) }
        if parts.isEmpty { parts.append(plural(secs, "segundo", "segundos")) }

        if parts.count == 1 { return parts[0] }
        return parts.dropLast().joined(separator: ", ") + " y " + parts[parts.count - 1]
    }

    /// Versión mínima para espacios muy estrechos (widget en línea): "2h 14m".
    public static func tiny(_ seconds: TimeInterval?) -> String {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return "—" }
        let total = Int(seconds.rounded())
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60

        if days > 0 { return hours > 0 ? "\(days)d \(hours)h" : "\(days)d" }
        if hours > 0 { return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h" }
        if minutes > 0 { return "\(minutes)m" }
        return "\(total)s"
    }

    /// Hora del día: "14:32".
    public static func clock(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(date: .omitted, time: .shortened)
    }

    private static func plural(_ value: Int, _ singular: String, _ plural: String) -> String {
        "\(value) \(value == 1 ? singular : plural)"
    }
}
