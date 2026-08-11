import SwiftUI

/// Contenido del panel que se despliega bajo el notch.
struct NowPlayingView: View {
    @ObservedObject var store: NowPlayingStore
    let spotify: SpotifyController
    @ObservedObject var settings: AppSettings
    /// Alterna entre tiempo total y restante en la etiqueta de la derecha.
    @State private var showRemaining = false
    /// Espacio reservado arriba para librar el notch.
    var topInset: CGFloat = 0
    /// Tamaño físico del notch: origen de la animación de expansión.
    var notchSize: CGSize = CGSize(width: 180, height: 32)

    /// Alto del contenido (sin contar el hueco del notch).
    static let contentHeight: CGFloat = 120
    static let panelWidth: CGFloat = 500

    /// Radio de los fillets cóncavos superiores. También es cuánto se estrecha
    /// el cuerpo por cada lado, así que el contenido debe ir inset esta cantidad.
    private let cornerFlare: CGFloat = 22

    private var accent: Color {
        store.accent.map(Color.init(nsColor:)) ?? .clear
    }

    /// Esquinas superiores cóncavas (se abren a los lados hacia el borde de la
    /// pantalla) e inferiores convexas: el modal "brota" del borde superior.
    private var panelShape: NotchExpandShape { NotchExpandShape(topRadius: cornerFlare) }

    private var panelHeight: CGFloat { Self.contentHeight + topInset }

    /// Escala colapsada = tamaño del notch respecto al panel (anclada arriba-centro).
    private var collapsedScaleX: CGFloat { notchSize.width / Self.panelWidth }
    private var collapsedScaleY: CGFloat { notchSize.height / panelHeight }

    var body: some View {
        ZStack {
            // Fondo: se escala desde el tamaño del notch hasta el panel completo.
            ZStack {
                panelShape.fill(Color.black)
                LinearGradient(
                    colors: [accent.opacity(0.0), accent.opacity(settings.gradientIntensity)],
                    startPoint: .top, endPoint: .bottom
                )
                .clipShape(panelShape)
                .animation(.easeInOut(duration: 0.4), value: store.accent)
            }
            .shadow(color: .black.opacity(0.45), radius: 12, y: 5)
            .scaleEffect(
                x: store.isOpen ? 1 : collapsedScaleX,
                y: store.isOpen ? 1 : collapsedScaleY,
                anchor: .top
            )

            // Contenido: aparece al expandir, se desvanece al colapsar.
            content
                .padding(.horizontal, cornerFlare + 12)   // dentro del cuerpo estrechado
                .padding(.top, 10 + topInset)              // libera el notch
                .padding(.bottom, 10)
                .opacity(store.isOpen ? 1 : 0)
                .scaleEffect(store.isOpen ? 1 : 0.92, anchor: .top)
                .blur(radius: store.isOpen ? 0 : 6)
        }
        .frame(width: Self.panelWidth, height: panelHeight)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: store.isOpen)
    }

    @ViewBuilder
    private var content: some View {
        if store.current.hasTrack {
            HStack(spacing: 12) {
                artwork   // columna izquierda: solo la carátula
                VStack(alignment: .leading, spacing: 6) {   // columna central
                    Button(action: { spotify.openTrack() }) {
                        VStack(alignment: .leading, spacing: 2) {
                            MarqueeText(text: store.current.title,
                                        font: .system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(store.current.artist)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.75))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { h in
                        if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                    controls
                        .frame(maxWidth: .infinity)   // centrado en la columna
                    progressBar
                }
                volumeColumn   // columna derecha: volumen vertical
            }
        } else {
            HStack(spacing: 10) {
                Image(systemName: "music.note")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.5))
                Text(emptyMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Controles

    private var controls: some View {
        HStack(spacing: 6) {
            ControlButton(symbol: "shuffle", size: 11, active: store.current.shuffling) {
                spotify.toggleShuffle()
            }
            ControlButton(symbol: "backward.fill", size: 12) { spotify.previousTrack() }
            ControlButton(symbol: store.current.state == .playing ? "pause.fill" : "play.fill",
                          size: 15) { spotify.playPause() }
            ControlButton(symbol: "forward.fill", size: 12) { spotify.nextTrack() }
            ControlButton(symbol: "repeat", size: 11, active: store.current.repeating) {
                spotify.toggleRepeat()
            }
        }
    }

    // MARK: - Progreso (scrubbing)

    private var progressBar: some View {
        VStack(spacing: 3) {
            DraggableBar(fraction: store.current.fraction) { f in
                spotify.seek(toFraction: f)
            }
            HStack {
                Text(timeString(store.current.position))
                Spacer()
                Button(action: { showRemaining.toggle() }) {
                    Text(showRemaining
                         ? "-" + timeString(max(store.current.duration - store.current.position, 0))
                         : timeString(store.current.duration))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { h in
                    if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.white.opacity(0.5))
            .monospacedDigit()
        }
    }

    private func timeString(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - Volumen (columna vertical)

    private var volumeColumn: some View {
        VStack(spacing: 6) {
            VerticalBar(fraction: store.current.volume / 100.0) { f in
                spotify.setVolume(f * 100.0)
            }
            Image(systemName: volumeSymbol)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.55))
                .frame(height: 12)
        }
        .frame(width: 22)
    }

    private var volumeSymbol: String {
        switch store.current.volume {
        case ..<1:  return "speaker.slash.fill"
        case ..<40: return "speaker.wave.1.fill"
        case ..<75: return "speaker.wave.2.fill"
        default:    return "speaker.wave.3.fill"
        }
    }

    // MARK: - Estado vacío / carátula

    private var emptyMessage: String {
        store.current.state == .notRunning ? "Spotify no está abierto" : "Nada sonando"
    }

    private var artwork: some View {
        ArtworkButton(image: store.artwork) { spotify.openApp() }
    }
}

/// Carátula clicable: abre Spotify. Muestra overlay y cursor de mano al hover.
private struct ArtworkButton: View {
    let image: NSImage?
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Group {
                if let img = image {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundStyle(.white.opacity(0.4))
                        )
                }
            }
            .frame(width: 88, height: 88)
            .overlay {
                // Realce al pasar el ratón: oscurece y muestra el icono de Spotify.
                ZStack {
                    Color.black.opacity(hovering ? 0.35 : 0)
                    Image(systemName: "arrow.up.forward.app.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                        .opacity(hovering ? 0.95 : 0)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .scaleEffect(hovering ? 1.03 : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in
            hovering = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .animation(.easeOut(duration: 0.14), value: hovering)
    }
}

/// Barra horizontal arrastrable (0–1). Soporta clic para saltar y arrastre.
private struct DraggableBar: View {
    var fraction: Double
    var onCommit: (Double) -> Void

    @State private var dragFraction: Double? = nil
    @State private var hovering = false

    var body: some View {
        GeometryReader { geo in
            let f = min(max(dragFraction ?? fraction, 0), 1)
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.18))
                Capsule().fill(Color.white.opacity(0.85))
                    .frame(width: w * f)
                // Tirador visible al pasar el ratón o al arrastrar.
                Circle()
                    .fill(.white)
                    .frame(width: 9, height: 9)
                    .offset(x: w * f - 4.5)
                    .opacity(hovering || dragFraction != nil ? 1 : 0)
            }
            .frame(height: 4)
            .frame(maxHeight: .infinity)          // amplía el área táctil vertical
            .contentShape(Rectangle())
            .onHover { h in
                hovering = h
                if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        dragFraction = min(max(v.location.x / w, 0), 1)
                    }
                    .onEnded { v in
                        let ff = min(max(v.location.x / w, 0), 1)
                        dragFraction = nil
                        onCommit(ff)
                    }
            )
            .animation(.easeOut(duration: 0.12), value: hovering)
        }
        .frame(height: 12)
    }
}

/// Forma del panel: fillets cóncavos arriba (se abren hacia los lados, como si
/// el modal saliera del borde superior de la pantalla) y esquinas convexas abajo.
private struct NotchExpandShape: Shape {
    var topRadius: CGFloat = 22
    var bottomRadius: CGFloat = 16

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let rt = max(min(topRadius, w / 2, h / 2), 0)
        let rb = max(min(bottomRadius, w / 2, h / 2), 0)

        var p = Path()
        // Punto superior-izquierdo (pegado al borde de la pantalla).
        p.move(to: CGPoint(x: 0, y: 0))
        // Borde superior a todo lo ancho.
        p.addLine(to: CGPoint(x: w, y: 0))
        // Fillet cóncavo superior-derecho: baja hacia el lateral del cuerpo.
        p.addArc(center: CGPoint(x: w, y: rt), radius: rt,
                 startAngle: .degrees(-90), endAngle: .degrees(180), clockwise: true)
        // Lateral derecho.
        p.addLine(to: CGPoint(x: w - rt, y: h - rb))
        // Esquina convexa inferior-derecha.
        p.addArc(center: CGPoint(x: w - rt - rb, y: h - rb), radius: rb,
                 startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        // Borde inferior.
        p.addLine(to: CGPoint(x: rt + rb, y: h))
        // Esquina convexa inferior-izquierda.
        p.addArc(center: CGPoint(x: rt + rb, y: h - rb), radius: rb,
                 startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        // Lateral izquierdo.
        p.addLine(to: CGPoint(x: rt, y: rt))
        // Fillet cóncavo superior-izquierdo: sube hacia el borde de la pantalla.
        p.addArc(center: CGPoint(x: 0, y: rt), radius: rt,
                 startAngle: .degrees(0), endAngle: .degrees(-90), clockwise: true)
        p.closeSubpath()
        return p
    }
}

/// Barra vertical arrastrable (0–1). El relleno crece desde abajo.
private struct VerticalBar: View {
    var fraction: Double
    var onCommit: (Double) -> Void

    @State private var dragFraction: Double? = nil
    @State private var hovering = false

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let f = min(max(dragFraction ?? fraction, 0), 1)
            ZStack(alignment: .bottom) {
                Capsule().fill(Color.white.opacity(0.18))
                Capsule().fill(Color.white.opacity(0.85))
                    .frame(height: h * f)
                // Tirador al pasar el ratón o arrastrar.
                Circle()
                    .fill(.white)
                    .frame(width: 9, height: 9)
                    .offset(y: -(h * f) + 4.5)
                    .opacity(hovering || dragFraction != nil ? 1 : 0)
            }
            .frame(width: 4)
            .frame(maxWidth: .infinity)          // amplía el área táctil horizontal
            .contentShape(Rectangle())
            .onHover { hover in
                hovering = hover
                if hover { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        dragFraction = min(max(1 - v.location.y / h, 0), 1)
                    }
                    .onEnded { v in
                        let ff = min(max(1 - v.location.y / h, 0), 1)
                        dragFraction = nil
                        onCommit(ff)
                    }
            )
            .animation(.easeOut(duration: 0.12), value: hovering)
        }
    }
}

/// Botón de control con efecto hover y cursor tipo "pointer".
/// `active` resalta el botón (para shuffle/repeat activos).
private struct ControlButton: View {
    let symbol: String
    let size: CGFloat
    var active: Bool = false
    let action: () -> Void

    @State private var hovering = false

    private var tint: Color {
        if active { return Color(nsColor: .systemGreen) }
        return .white.opacity(hovering ? 1.0 : 0.85)
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 30, height: 28)
                .background(
                    Circle().fill(Color.white.opacity(hovering ? 0.18 : 0.0))
                )
                .scaleEffect(hovering ? 1.12 : 1.0)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            hovering = isHovering
            if isHovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

/// Texto en una línea que se desplaza (marquee) si no cabe en su ancho.
private struct MarqueeText: View {
    let text: String
    let font: Font

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    private var overflow: CGFloat { max(textWidth - containerWidth, 0) }

    var body: some View {
        GeometryReader { geo in
            Text(text)
                .font(font)
                .lineLimit(1)
                .fixedSize()
                .background(
                    GeometryReader { t in
                        Color.clear
                            .onAppear {
                                textWidth = t.size.width
                                containerWidth = geo.size.width
                                restart()
                            }
                            .onChange(of: t.size.width) { _, w in
                                textWidth = w
                                containerWidth = geo.size.width
                                restart()
                            }
                    }
                )
                .offset(x: offset)
                .frame(width: geo.size.width, alignment: .leading)
                .clipped()
                .onChange(of: text) { _, _ in restart() }
        }
        .frame(height: fontHeight)
    }

    private var fontHeight: CGFloat { 17 }

    private func restart() {
        offset = 0
        guard overflow > 1 else { return }
        // Desplazamiento ida y vuelta con pausa en los extremos.
        withAnimation(.easeInOut(duration: Double(overflow) / 30 + 1)
            .delay(1.2).repeatForever(autoreverses: true)) {
            offset = -overflow
        }
    }
}
