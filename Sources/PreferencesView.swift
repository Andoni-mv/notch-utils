import SwiftUI

/// Ventana de preferencias.
struct PreferencesView: View {
    @ObservedObject var settings: AppSettings
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        Form {
            Section("General") {
                Toggle("Arrancar al iniciar sesión", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        LoginItem.setEnabled(newValue)
                    }
            }

            Section("Apariencia") {
                VStack(alignment: .leading) {
                    Text("Intensidad del color: \(Int(settings.gradientIntensity * 100)) %")
                    Slider(value: $settings.gradientIntensity, in: 0...1)
                }
            }

            Section("Comportamiento") {
                VStack(alignment: .leading) {
                    Text("Retardo al ocultar: \(String(format: "%.2f", settings.hoverHideDelay)) s")
                    Slider(value: $settings.hoverHideDelay, in: 0...1)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 360, height: 300)
    }
}
