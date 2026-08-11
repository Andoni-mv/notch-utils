import AppKit

/// Vigila la posición del ratón globalmente y notifica cada movimiento.
///
/// Usa un monitor global (dispara cuando la app NO está activa, el caso normal
/// para una app agente) y uno local (por si el panel recibe el foco).
final class HoverMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let onMove: (NSPoint) -> Void

    init(onMove: @escaping (NSPoint) -> Void) {
        self.onMove = onMove
    }

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.onMove(NSEvent.mouseLocation)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.onMove(NSEvent.mouseLocation)
            return event
        }
    }

    func stop() {
        if let g = globalMonitor { NSEvent.removeMonitor(g) }
        if let l = localMonitor { NSEvent.removeMonitor(l) }
        globalMonitor = nil
        localMonitor = nil
    }

    deinit { stop() }
}
