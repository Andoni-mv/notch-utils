import AppKit

/// Estado de reproducción de Spotify.
enum PlayerState: String {
    case playing
    case paused
    case stopped
    case notRunning   // Spotify no está abierto
}

/// Snapshot de lo que suena. Equatable para evitar refrescos de UI innecesarios.
struct NowPlaying: Equatable {
    var state: PlayerState
    var title: String
    var artist: String
    var album: String
    var artworkURL: String
    var trackID: String
    var position: Double   // segundos transcurridos
    var duration: Double   // segundos totales
    var volume: Double     // 0–100
    var shuffling: Bool
    var repeating: Bool

    static let empty = NowPlaying(
        state: .notRunning,
        title: "",
        artist: "",
        album: "",
        artworkURL: "",
        trackID: "",
        position: 0,
        duration: 0,
        volume: 50,
        shuffling: false,
        repeating: false
    )

    /// Fracción reproducida [0, 1].
    var fraction: Double {
        guard duration > 0 else { return 0 }
        return min(max(position / duration, 0), 1)
    }

    var hasTrack: Bool {
        (state == .playing || state == .paused) && !title.isEmpty
    }
}

/// Store observable compartido entre el controller y la vista SwiftUI.
final class NowPlayingStore: ObservableObject {
    @Published var current: NowPlaying = .empty
    @Published var artwork: NSImage? = nil
    /// Color dominante extraído de la carátula, para tintar el fondo.
    @Published var accent: NSColor? = nil
    /// Abierto = expandido; cerrado = colapsado al tamaño del notch.
    @Published var isOpen: Bool = false
}
