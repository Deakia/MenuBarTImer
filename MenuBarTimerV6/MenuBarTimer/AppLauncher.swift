import AppKit

/// Opens an app by its bundle identifier using NSWorkspace.
struct AppLauncher {

    /// Opens the app with the given bundle ID. No-op if bundleID is empty.
    static func launch(bundleID: String) {
        guard !bundleID.isEmpty else { return }
        DispatchQueue.main.async {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                NSWorkspace.shared.openApplication(at: url, configuration: config)
            }
        }
    }

    /// Returns all user-visible apps in /Applications and ~/Applications,
    /// sorted alphabetically, as (name, bundleID) tuples.
    static func installedApps() -> [(name: String, bundleID: String)] {
        let fm = FileManager.default
        let searchPaths = [
            "/Applications",
            (NSHomeDirectory() as NSString).appendingPathComponent("Applications")
        ]

        var results: [(name: String, bundleID: String)] = []
        var seen = Set<String>()

        for dir in searchPaths {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items where item.hasSuffix(".app") {
                let fullPath = (dir as NSString).appendingPathComponent(item)
                let bundle   = Bundle(path: fullPath)
                guard let bid = bundle?.bundleIdentifier, !seen.contains(bid) else { continue }
                let name = (item as NSString).deletingPathExtension
                results.append((name: name, bundleID: bid))
                seen.insert(bid)
            }
        }

        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
