import AppKit

/// Coordina geometría, hover, panel y datos de Spotify.
final class NotchController {
    private let store = NowPlayingStore()
    private let panel: NotchPanel
    private let spotify: SpotifyController
    private var hover: HoverMonitor!
    private var menuBar: MenuBarController!

    private var isShown = false
    private var hideWorkItem: DispatchWorkItem?
    /// Oculta la ventana cuando termina la animación de colapso.
    private var hideCompletion: DispatchWorkItem?
    /// Sondeo de progreso mientras el panel está visible.
    private var progressTimer: Timer?
    /// Duración aproximada de la animación de expansión/colapso.
    private let animDuration: TimeInterval = 0.4

    /// Margen extra bajo el notch para facilitar el hover de entrada.
    private let triggerPadding: CGFloat = 6

    init() {
        spotify = SpotifyController(store: store)
        panel = NotchPanel(store: store, spotify: spotify,
                           topInset: NotchGeometry.topInset,
                           notchSize: NotchGeometry.physicalNotchSize)

        hover = HoverMonitor { [weak self] point in
            self?.handleMouse(at: point)
        }

        menuBar = MenuBarController { [weak self] in
            self?.showManually()
        }
    }

    /// Abre el panel a mano (desde el menú de la barra).
    func showManually() {
        show()
    }

    func start() {
        positionPanel()
        panel.orderFrontRegardless()
        panel.alphaValue = 0
        hover.start()
        spotify.start()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screensChanged() {
        positionPanel()
    }

    // MARK: - Posicionamiento

    private func positionPanel() {
        guard let notch = NotchGeometry.notchRect(),
              let screen = NotchGeometry.notchScreen else { return }
        let size = panel.frame.size
        let x = notch.midX - size.width / 2
        // Borde superior pegado al borde superior de la pantalla: el panel se
        // superpone al notch y su padding-top interno libera el contenido.
        let y = screen.frame.maxY - size.height
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Hover

    /// Rect que dispara la apertura: notch expandido ligeramente hacia abajo.
    private var triggerRect: CGRect {
        guard let notch = NotchGeometry.notchRect() else { return .zero }
        return CGRect(
            x: notch.minX,
            y: notch.minY - triggerPadding,
            width: notch.width,
            height: notch.height + triggerPadding
        )
    }

    private func handleMouse(at point: NSPoint) {
        let overTrigger = triggerRect.contains(point)
        let overPanel = isShown && panel.frame.contains(point)

        if overTrigger || overPanel {
            cancelHide()
            show()
        } else {
            scheduleHide()
        }
    }

    private func show() {
        cancelHideCompletion()   // por si estaba colapsando
        guard !isShown else { return }
        isShown = true
        positionPanel()
        panel.alphaValue = 1           // ventana visible al instante
        store.isOpen = true            // SwiftUI anima la expansión desde el notch
        spotify.refresh()
        startProgressPolling()
    }

    /// Refresca posición/estado cada segundo mientras el panel se ve.
    private func startProgressPolling() {
        progressTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.spotify.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        progressTimer = timer
    }

    private func stopProgressPolling() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func scheduleHide() {
        guard isShown, hideWorkItem == nil else { return }
        let item = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + AppSettings.shared.hoverHideDelay, execute: item)
    }

    private func cancelHide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
    }

    private func hide() {
        hideWorkItem = nil
        guard isShown else { return }
        isShown = false
        stopProgressPolling()
        store.isOpen = false           // SwiftUI anima el colapso hacia el notch

        // Ocultar la ventana cuando termine el colapso (si no se reabrió).
        let done = DispatchWorkItem { [weak self] in
            guard let self, !self.isShown else { return }
            self.panel.alphaValue = 0
        }
        hideCompletion = done
        DispatchQueue.main.asyncAfter(deadline: .now() + animDuration, execute: done)
    }

    private func cancelHideCompletion() {
        hideCompletion?.cancel()
        hideCompletion = nil
    }
}
