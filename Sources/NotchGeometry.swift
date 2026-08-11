import AppKit

/// Calcula el rectángulo del notch (o un fallback) en coordenadas de pantalla
/// globales, con origen abajo-izquierda (igual que NSScreen.frame y NSEvent.mouseLocation).
enum NotchGeometry {

    /// Ancho aproximado usado como fallback en Macs sin notch.
    private static let fallbackWidth: CGFloat = 220
    /// Altura del área "sensible" cuando no hay notch (alto de la barra de menús).
    private static let fallbackHeight: CGFloat = 24

    /// Altura a reservar arriba para librar el notch (o la barra de menús).
    static var topInset: CGFloat {
        let inset = notchScreen?.safeAreaInsets.top ?? 0
        return inset > 0 ? inset : 24   // fallback sin notch: alto de barra de menús
    }

    /// Tamaño físico real del notch (sin el clamp mínimo de `notchRect`),
    /// usado como origen de la animación de expansión.
    static var physicalNotchSize: CGSize {
        guard let s = notchScreen else { return CGSize(width: 180, height: 32) }
        let top = s.safeAreaInsets.top
        if top > 0 {
            let lw = s.auxiliaryTopLeftArea?.width ?? 0
            let rw = s.auxiliaryTopRightArea?.width ?? 0
            return CGSize(width: max(s.frame.width - lw - rw, 120), height: top)
        }
        return CGSize(width: 180, height: 24)   // fallback sin notch
    }

    /// Pantalla que contiene el notch (la principal con el MacBook).
    static var notchScreen: NSScreen? {
        // La pantalla con safeAreaInsets.top > 0 es la del notch.
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }

    /// Rect del notch en coordenadas de pantalla. `nil` si no hay pantalla.
    static func notchRect() -> CGRect? {
        guard let screen = notchScreen else { return nil }
        let f = screen.frame

        let topInset = screen.safeAreaInsets.top
        if topInset > 0 {
            // Mac con notch real. El hueco horizontal está entre las áreas auxiliares.
            let leftW = screen.auxiliaryTopLeftArea?.width ?? 0
            let rightW = screen.auxiliaryTopRightArea?.width ?? 0
            let notchWidth = max(f.width - leftW - rightW, fallbackWidth)
            let minX = f.minX + leftW
            return CGRect(
                x: minX,
                y: f.maxY - topInset,
                width: notchWidth,
                height: topInset
            )
        } else {
            // Sin notch: zona sensible centrada en la barra de menús.
            let minX = f.midX - fallbackWidth / 2
            return CGRect(
                x: minX,
                y: f.maxY - fallbackHeight,
                width: fallbackWidth,
                height: fallbackHeight
            )
        }
    }
}
