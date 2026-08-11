import AppKit
import CoreImage

/// Lee el estado de Spotify vía AppleScript y actualiza el store.
///
/// No lanza Spotify si no está abierto (se comprueba con NSRunningApplication).
/// Se refresca en vivo escuchando la notificación distribuida
/// `com.spotify.client.PlaybackStateChanged` que Spotify emite en cada cambio.
final class SpotifyController {
    private let store: NowPlayingStore
    private let bundleID = "com.spotify.client"
    private let notificationName = "com.spotify.client.PlaybackStateChanged"

    /// Cola serie dedicada: NSAppleScript bloquea, no debe correr en el hilo principal.
    private let scriptQueue = DispatchQueue(label: "notchutils.spotify.applescript")

    /// Caché de carátula por trackID para no redescargar.
    private var artworkCache: [String: NSImage] = [:]
    /// TrackID de la carátula actualmente publicada (evita re-render en cada poll).
    private var currentArtworkTrackID = ""

    init(store: NowPlayingStore) {
        self.store = store
    }

    func start() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(playbackChanged),
            name: NSNotification.Name(notificationName),
            object: nil
        )
        refresh()
    }

    @objc private func playbackChanged() {
        refresh()
    }

    // MARK: - Controles

    /// Trae Spotify al frente (lo lanza si no está abierto).
    func openApp() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    func playPause() { runCommand("playpause") }
    func nextTrack() { runCommand("next track") }
    func previousTrack() { runCommand("previous track") }

    func toggleShuffle() { runCommand("set shuffling to not shuffling") }
    func toggleRepeat() { runCommand("set repeating to not repeating") }

    /// Abre la canción actual en Spotify (trackID = "spotify:track:...").
    func openTrack() {
        let id = store.current.trackID
        guard !id.isEmpty, let url = URL(string: id) else { openApp(); return }
        NSWorkspace.shared.open(url)
    }

    /// Salta a una fracción [0,1] de la pista (scrubbing).
    func seek(toFraction fraction: Double) {
        let seconds = Int((fraction * store.current.duration).rounded())
        // Actualización optimista para que la barra responda al instante.
        DispatchQueue.main.async { self.store.current.position = Double(seconds) }
        execute("set player position to \(seconds)")
    }

    /// Ajusta el volumen (0–100).
    func setVolume(_ value: Double) {
        let v = Int(min(max(value, 0), 100).rounded())
        DispatchQueue.main.async { self.store.current.volume = Double(v) }
        execute("set sound volume to \(v)")
    }

    /// Ejecuta un comando sin refrescar todo el estado (para scrubbing/volumen).
    private func execute(_ command: String) {
        let running = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID)
            .isEmpty == false
        guard running else { return }
        scriptQueue.async {
            var error: NSDictionary?
            NSAppleScript(source: "tell application \"Spotify\" to \(command)")?
                .executeAndReturnError(&error)
        }
    }

    /// Ejecuta un comando de control y refresca el estado.
    private func runCommand(_ command: String) {
        let running = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID)
            .isEmpty == false
        guard running else { return }

        scriptQueue.async { [weak self] in
            guard let self else { return }
            var error: NSDictionary?
            let src = "tell application \"Spotify\" to \(command)"
            NSAppleScript(source: src)?.executeAndReturnError(&error)
            if let error { NSLog("[NotchUtils] comando '\(command)' error: \(error)") }
            // Spotify emite PlaybackStateChanged, pero refrescamos por si acaso.
            let np = self.runScript()
            let art = self.artwork(for: np)
            self.publish(np, artwork: art)
        }
    }

    /// Consulta Spotify y publica el resultado en el store (en el hilo principal).
    func refresh() {
        // Si Spotify no corre, evitamos ejecutar el script (no queremos lanzarlo).
        let running = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID)
            .isEmpty == false

        guard running else {
            publish(.empty, artwork: nil)
            return
        }

        scriptQueue.async { [weak self] in
            guard let self else { return }
            let np = self.runScript()
            let art = self.artwork(for: np)
            self.publish(np, artwork: art)
        }
    }

    private func publish(_ np: NowPlaying, artwork: NSImage?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.store.current != np {
                self.store.current = np
            }
            // Solo actualizamos la carátula cuando cambia la pista (evita
            // re-render cada segundo durante el sondeo de progreso).
            if np.hasTrack {
                if self.currentArtworkTrackID != np.trackID {
                    self.currentArtworkTrackID = np.trackID
                    self.store.artwork = artwork
                    self.store.accent = artwork.flatMap(Self.accentColor(from:))
                }
            } else {
                self.currentArtworkTrackID = ""
                self.store.artwork = nil
                self.store.accent = nil
            }
        }
    }

    // MARK: - AppleScript

    private static let source = """
    if application "Spotify" is running then
        tell application "Spotify"
            set pState to player state as string
            if pState is "stopped" then return "stopped"
            set trackName to name of current track
            set trackArtist to artist of current track
            set trackAlbum to album of current track
            set trackArt to artwork url of current track
            set trackId to id of current track
            set pos to (player position as integer)
            set dur to duration of current track
            set vol to sound volume
            set shf to shuffling
            set rep to repeating
            return pState & "\\n" & trackName & "\\n" & trackArtist & "\\n" & trackAlbum & "\\n" & trackArt & "\\n" & trackId & "\\n" & (pos as string) & "\\n" & (dur as string) & "\\n" & (vol as string) & "\\n" & (shf as string) & "\\n" & (rep as string)
        end tell
    else
        return "notrunning"
    end if
    """

    private func runScript() -> NowPlaying {
        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: Self.source) else { return .empty }
        let result = script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            NSLog("[NotchUtils] AppleScript error: \(errorInfo)")
            return .empty
        }

        guard let raw = result.stringValue else { return .empty }

        switch raw {
        case "notrunning":
            return .empty
        case "stopped":
            return NowPlaying(state: .stopped, title: "", artist: "", album: "", artworkURL: "", trackID: "", position: 0, duration: 0, volume: 50, shuffling: false, repeating: false)
        default:
            break
        }

        let parts = raw.components(separatedBy: "\n")
        guard parts.count >= 11 else { return .empty }

        // Spotify devuelve la duración en milisegundos y la posición en segundos.
        let posSeconds = Double(parts[6]) ?? 0
        let durSeconds = (Double(parts[7]) ?? 0) / 1000.0
        let volume = Double(parts[8]) ?? 50

        return NowPlaying(
            state: PlayerState(rawValue: parts[0]) ?? .stopped,
            title: parts[1],
            artist: parts[2],
            album: parts[3],
            artworkURL: parts[4],
            trackID: parts[5],
            position: posSeconds,
            duration: durSeconds,
            volume: volume,
            shuffling: parts[9] == "true",
            repeating: parts[10] == "true"
        )
    }

    // MARK: - Carátula

    private func artwork(for np: NowPlaying) -> NSImage? {
        guard np.hasTrack, !np.artworkURL.isEmpty else { return nil }
        if let cached = artworkCache[np.trackID] { return cached }
        guard let url = URL(string: np.artworkURL),
              let data = try? Data(contentsOf: url),
              let image = NSImage(data: data) else { return nil }
        artworkCache[np.trackID] = image
        return image
    }

    // MARK: - Color dominante

    private static let ciContext = CIContext(options: [.workingColorSpace: NSNull()])

    /// Color medio de la carátula, con saturación realzada y brillo acotado
    /// para que sirva como acento agradable sobre fondo oscuro.
    static func accentColor(from image: NSImage) -> NSColor? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let cg = bitmap.cgImage else { return nil }

        let ci = CIImage(cgImage: cg)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ci,
            kCIInputExtentKey: CIVector(cgRect: ci.extent)
        ]), let output = filter.outputImage else { return nil }

        var px = [UInt8](repeating: 0, count: 4)
        ciContext.render(output, toBitmap: &px, rowBytes: 4,
                         bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                         format: .RGBA8, colorSpace: nil)

        let base = NSColor(red: CGFloat(px[0]) / 255, green: CGFloat(px[1]) / 255,
                           blue: CGFloat(px[2]) / 255, alpha: 1)
        guard let rgb = base.usingColorSpace(.deviceRGB) else { return base }

        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rgb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        // Realza saturación y acota brillo para un acento vivo pero legible.
        let s2 = min(s * 1.5, 1.0)
        let b2 = min(max(b, 0.45), 0.8)
        return NSColor(hue: h, saturation: s2, brightness: b2, alpha: 1)
    }
}
