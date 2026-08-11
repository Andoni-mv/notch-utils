import Foundation

/// Ajustes de usuario persistidos en UserDefaults. Singleton compartido.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var gradientIntensity: Double {
        didSet { UserDefaults.standard.set(gradientIntensity, forKey: "gradientIntensity") }
    }
    /// Retardo (s) antes de ocultar el panel al salir del notch.
    @Published var hoverHideDelay: Double {
        didSet { UserDefaults.standard.set(hoverHideDelay, forKey: "hoverHideDelay") }
    }

    private init() {
        let d = UserDefaults.standard
        gradientIntensity = d.object(forKey: "gradientIntensity") as? Double ?? 0.6
        hoverHideDelay = d.object(forKey: "hoverHideDelay") as? Double ?? 0.18
    }
}
