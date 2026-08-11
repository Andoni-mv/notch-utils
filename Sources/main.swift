import AppKit
import Darwin

/// Evita instancias duplicadas (que causarían paneles superpuestos).
/// Usa un flock sobre un archivo de lock; si otra instancia lo tiene, salimos.
private func ensureSingleInstance() {
    let lockPath = NSTemporaryDirectory() + "notchutils.lock"
    let fd = open(lockPath, O_CREAT | O_RDWR, 0o644)
    guard fd >= 0 else { return }
    if flock(fd, LOCK_EX | LOCK_NB) != 0 {
        // Ya hay otra instancia corriendo.
        FileHandle.standardError.write(Data("[NotchUtils] ya hay una instancia en ejecución, saliendo.\n".utf8))
        exit(0)
    }
    // fd se mantiene abierto durante toda la vida del proceso (lock activo).
}

/// App agente (sin icono en Dock). Todo el UI vive en el NSPanel del notch.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: NotchController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = NotchController()
        controller?.start()
    }
}

ensureSingleInstance()

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// .accessory => sin icono en Dock, no roba foco.
app.setActivationPolicy(.accessory)
app.run()
