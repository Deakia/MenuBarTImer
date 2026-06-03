import AppKit

/// Runs a named Shortcut via `shortcuts run "<name>"` in a background process.
/// The Shortcut itself is responsible for enabling/disabling the Focus mode.
struct FocusManager {

    /// Calls `shortcuts run "<shortcutName>"` asynchronously.
    static func runShortcut(named name: String) {
        guard !name.isEmpty else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        task.arguments = ["run", name]
        try? task.run()
    }

    /// Fetch the names of all Shortcuts installed on this Mac.
    /// Returns them sorted alphabetically.
    static func installedShortcuts() -> [String] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        task.arguments = ["list"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError  = Pipe() // suppress errors

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return []
        }

        let data   = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .sorted()
    }
}
