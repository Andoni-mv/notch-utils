import AppKit

/// Gestiona el arranque al inicio de sesión vía los "login items" de System Events.
/// (Consistente con install.sh; la app se controla desde /Applications.)
enum LoginItem {
    private static let name = "NotchUtils"
    private static let path = "/Applications/NotchUtils.app"

    static var isEnabled: Bool {
        let src = "tell application \"System Events\" to get name of every login item"
        guard let out = run(src) else { return false }
        return out.contains(name)
    }

    static func setEnabled(_ enabled: Bool) {
        if enabled {
            guard !isEnabled else { return }
            _ = run("tell application \"System Events\" to make login item at end with properties {path:\"\(path)\", hidden:true}")
        } else {
            _ = run("tell application \"System Events\" to delete (every login item whose name is \"\(name)\")")
        }
    }

    @discardableResult
    private static func run(_ source: String) -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error { NSLog("[NotchUtils] LoginItem error: \(error)") }
        return result?.stringValue
    }
}
