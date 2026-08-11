import AppKit
import SwiftUI

/// Panel borderless, no activador, que se dibuja sobre la barra de menús / notch.
final class NotchPanel: NSPanel {
    init(store: NowPlayingStore, spotify: SpotifyController, topInset: CGFloat, notchSize: CGSize) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: NowPlayingView.panelWidth, height: NowPlayingView.contentHeight + topInset),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false   // la sombra la pinta SwiftUI para que escale con la animación
        hidesOnDeactivate = false
        isMovable = false
        // Empieza invisible.
        alphaValue = 0

        let hosting = NSHostingView(rootView: NowPlayingView(store: store, spotify: spotify, settings: AppSettings.shared, topInset: topInset, notchSize: notchSize))
        hosting.frame = contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        contentView?.addSubview(hosting)
    }

    // Un panel borderless normalmente no puede ser key; lo permitimos por si acaso.
    override var canBecomeKey: Bool { true }
}
