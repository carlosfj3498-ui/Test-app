import Foundation

/// Identificadores compartidos entre la app y la extensión de widget.
///
/// Si cambias el bundle identifier del proyecto, cambia también `appGroup`
/// (y el App Group correspondiente en las capabilities de ambos targets).
public enum AppIdentifiers {
    public static let appGroup = "group.com.carlosfj3498.desbloqueos"
    public static let widgetKind = "DesbloqueosWidget"

    /// URL que abre la app desde el widget.
    public static let deepLink = URL(string: "desbloqueos://hoy")!
}

/// Acceso a los `UserDefaults` compartidos, con degradación elegante.
///
/// Si el App Group todavía no está configurado (por ejemplo, al abrir el
/// proyecto por primera vez sin equipo de firma), `UserDefaults(suiteName:)`
/// devuelve `nil` o un contenedor inutilizable. En ese caso la app sigue
/// funcionando contra `UserDefaults.standard`; lo único que se pierde es que
/// el widget vea los mismos datos.
public enum SharedDefaults {
    public static let shared: UserDefaults = {
        guard let defaults = UserDefaults(suiteName: AppIdentifiers.appGroup) else {
            return .standard
        }
        return defaults
    }()

    /// `true` cuando el contenedor del App Group existe de verdad en disco.
    public static var isAppGroupAvailable: Bool {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppIdentifiers.appGroup
        ) != nil
    }
}
