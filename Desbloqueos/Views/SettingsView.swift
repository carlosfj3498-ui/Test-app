import SwiftUI
import UIKit
import UnlockCore

/// Ajustes y explicación honesta de cómo se mide todo esto.
struct SettingsView: View {
    @EnvironmentObject private var tracker: UnlockTracker

    @AppStorage(PreferenceKeys.notificationsEnabled, store: SharedDefaults.shared)
    private var notificationsEnabled: Bool = false

    @AppStorage(PreferenceKeys.milestones, store: SharedDefaults.shared)
    private var milestonesRaw: String = PreferenceDefaults.milestonesString

    @AppStorage(PreferenceKeys.appSwitchGrace, store: SharedDefaults.shared)
    private var appSwitchGrace: Double = PreferenceDefaults.appSwitchGrace

    @AppStorage(PreferenceKeys.goalSeconds, store: SharedDefaults.shared)
    private var goalSeconds: Double = PreferenceDefaults.goalSeconds

    @State private var showResetConfirmation = false
    @State private var showPermissionAlert = false

    private let notifier = MilestoneNotifier()

    private var selectedMilestones: Set<TimeInterval> {
        Set<TimeInterval>.milestones(from: milestonesRaw)
    }

    var body: some View {
        ZStack {
            CanvasBackground()

            Form {
                notificationsSection
                goalSection
                detectionSection
                howItWorksSection
                dataSection
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Ajustes")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Los avisos están desactivados", isPresented: $showPermissionAlert) {
            Button("Abrir Ajustes") { openSystemSettings() }
            Button("Ahora no", role: .cancel) {}
        } message: {
            Text("Para recibirlos, activa las notificaciones de Desbloqueos en los Ajustes de iOS.")
        }
        .confirmationDialog(
            "¿Borrar todo el historial?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Borrar historial", role: .destructive) { tracker.resetHistory() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se borran todos los desbloqueos guardados. No se puede deshacer.")
        }
    }

    // MARK: - Secciones

    private var notificationsSection: some View {
        Section {
            Toggle("Avisarme de las pausas largas", isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) { _, isOn in
                    guard isOn else { return }
                    Task {
                        let granted = await notifier.requestAuthorization()
                        if !granted {
                            notificationsEnabled = false
                            showPermissionAlert = true
                        }
                    }
                }

            if notificationsEnabled {
                ForEach(Milestone.all) { milestone in
                    Toggle(
                        milestone.label,
                        isOn: binding(for: milestone)
                    )
                    .font(.subheadline)
                }
            }
        } header: {
            Text("Avisos")
        } footer: {
            Text("""
            Se programan cuando bloqueas el teléfono y se cancelan en cuanto lo desbloqueas, \
            así que te los encuentras esperándote en la pantalla de bloqueo. \
            Si sigues usando el móvil dentro de otras apps, algún aviso puede llegar antes de tiempo.
            """)
        }
    }

    private var goalSection: some View {
        Section {
            Picker("Objetivo de pausa", selection: $goalSeconds) {
                Text("30 minutos").tag(30.0 * 60)
                Text("1 hora").tag(60.0 * 60)
                Text("2 horas").tag(2.0 * 3600)
                Text("4 horas").tag(4.0 * 3600)
            }
        } header: {
            Text("Objetivo")
        } footer: {
            Text("El anillo de la pantalla principal compara tu última pausa con este objetivo.")
        }
    }

    private var detectionSection: some View {
        Section {
            Picker("Tiempo fuera mínimo", selection: $appSwitchGrace) {
                Text("1 minuto").tag(60.0)
                Text("3 minutos").tag(3.0 * 60)
                Text("5 minutos").tag(5.0 * 60)
                Text("10 minutos").tag(10.0 * 60)
            }
        } header: {
            Text("Detección")
        } footer: {
            Text("""
            Si saltas a otra app y vuelves antes de este tiempo, no cuenta como un desbloqueo nuevo: \
            fue un cambio de app. Si estuviste fuera más rato, el bloqueo automático de iOS ya había \
            entrado y sí cuenta. Cuando la app ve el bloqueo del teléfono directamente, este ajuste \
            no hace falta.
            """)
        }
    }

    private var howItWorksSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Widget")
                        .font(.subheadline.weight(.semibold))
                    Text(SharedDefaults.isAppGroupAvailable
                         ? "Conectado: el widget ve los mismos datos que la app."
                         : "Sin configurar: la app funciona, pero el widget no comparte datos. Revisa el App Group en Xcode.")
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                }
            } icon: {
                Image(systemName: SharedDefaults.isAppGroupAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(SharedDefaults.isAppGroupAvailable ? Palette.calm : Palette.alert)
            }
        } header: {
            Text("Cómo funciona")
        } footer: {
            Text("""
            iOS no deja que una app se entere de cada desbloqueo por su cuenta. \
            Desbloqueos usa las dos señales que sí da el sistema: el aviso de que el dispositivo se ha \
            desbloqueado, que llega mientras la app siga en memoria, y el momento en que abres la app. \
            Por eso la cuenta es muy fiable si usas la app o su widget a diario, y puede saltarse algún \
            desbloqueo si pasas días sin abrirla.
            """)
        }
    }

    private var dataSection: some View {
        Section {
            LabeledContent("Desbloqueos guardados", value: "\(tracker.events.count)")
            Button("Borrar historial", role: .destructive) {
                showResetConfirmation = true
            }
        } header: {
            Text("Datos")
        } footer: {
            Text("Todo se queda en tu iPhone. No hay cuentas, ni servidores, ni analíticas.")
        }
    }

    // MARK: - Ayudas

    private func binding(for milestone: Milestone) -> Binding<Bool> {
        Binding(
            get: { selectedMilestones.contains(milestone.seconds) },
            set: { isOn in
                var current = selectedMilestones
                if isOn {
                    current.insert(milestone.seconds)
                } else {
                    current.remove(milestone.seconds)
                }
                milestonesRaw = current.milestoneString
            }
        )
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
