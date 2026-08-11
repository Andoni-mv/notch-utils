import AppKit
import SwiftUI

/// Icono en la barra de menús con herramientas: abrir panel, preferencias,
/// arranque al inicio, acerca de y salir.
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let onOpenPanel: () -> Void
    private var prefsWindow: NSWindow?
    private var launchItem: NSMenuItem!

    init(onOpenPanel: @escaping () -> Void) {
        self.onOpenPanel = onOpenPanel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "NotchUtils")
        }

        let menu = NSMenu()
        menu.delegate = self

        menu.addItem(withTitle: "Abrir panel", action: #selector(openPanel), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())

        menu.addItem(withTitle: "Preferencias…", action: #selector(openPreferences), keyEquivalent: ",")
            .target = self

        launchItem = NSMenuItem(title: "Arrancar al inicio de sesión",
                                action: #selector(toggleLaunch), keyEquivalent: "")
        launchItem.target = self
        menu.addItem(launchItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Acerca de NotchUtils", action: #selector(about), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: "Salir de NotchUtils", action: #selector(quit), keyEquivalent: "q")
            .target = self

        statusItem.menu = menu
    }

    // Refresca el check de "arrancar al inicio" al abrir el menú.
    func menuWillOpen(_ menu: NSMenu) {
        launchItem.state = LoginItem.isEnabled ? .on : .off
    }

    @objc private func openPanel() { onOpenPanel() }

    @objc private func toggleLaunch() {
        LoginItem.setEnabled(!LoginItem.isEnabled)
    }

    @objc private func about() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "NotchUtils"])
    }

    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func openPreferences() {
        NSApp.activate(ignoringOtherApps: true)
        if let w = prefsWindow {
            w.makeKeyAndOrderFront(nil)
            return
        }
        let hosting = NSHostingController(rootView: PreferencesView(settings: AppSettings.shared))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Preferencias — NotchUtils"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        prefsWindow = window
        window.makeKeyAndOrderFront(nil)
    }
}
