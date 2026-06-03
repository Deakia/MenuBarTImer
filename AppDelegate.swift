import AppKit

enum TimerPhase {
    case idle
    case countingToStart
    case flashWarning    // last 5 minutes before start
    case countingToEnd
    case countingUp
    case finished
}

/// How many seconds before start the red flash begins
private let warningSeconds: TimeInterval = 5 * 60

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem!
    var menuBarView: MenuBarView!

    var ticker: Timer?
    var startDate: Date?
    var endDate: Date?
    var timerLabel: String  = ""
    var enableShortcut: String  = ""
    var disableShortcut: String = ""
    var phase: TimerPhase = .idle

    var popover: NSPopover!
    var settingsVC: SettingsViewController!
    var launchAppBundleID: String = ""

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Build status item with a fixed initial length; we'll resize dynamically
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Replace the default button with our custom view
        menuBarView = MenuBarView(frame: NSRect(x: 0, y: 0, width: 120, height: 22))
        menuBarView.statusItemAction = #selector(togglePopover)
        menuBarView.statusItemTarget = self
        statusItem.view = menuBarView

        settingsVC = SettingsViewController()
        settingsVC.delegate = self

        popover = NSPopover()
        popover.contentViewController = settingsVC
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 340, height: 440)

        let d = UserDefaults.standard
        if let s = d.object(forKey: "startDate") as? Date {
            let e = d.object(forKey: "endDate") as? Date
            beginCountdown(
                start: s, end: e,
                timerLabel:        d.string(forKey: "timerLabel")        ?? "",
                enableShortcut:    d.string(forKey: "enableShortcut")    ?? "",
                disableShortcut:   d.string(forKey: "disableShortcut")   ?? "",
                launchAppBundleID: d.string(forKey: "launchAppBundleID") ?? ""
            )
        }
    }

    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Anchor to the custom view
            popover.show(relativeTo: menuBarView.bounds, of: menuBarView, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Countdown management

    func beginCountdown(start: Date, end: Date?, timerLabel: String,
                        enableShortcut: String, disableShortcut: String,
                        launchAppBundleID: String) {
        self.startDate       = start
        self.endDate         = end
        self.timerLabel      = timerLabel
        self.enableShortcut  = enableShortcut
        self.disableShortcut = disableShortcut
        self.launchAppBundleID = launchAppBundleID

        let d = UserDefaults.standard
        d.set(start, forKey: "startDate")
        if let end = end { d.set(end, forKey: "endDate") }
        else             { d.removeObject(forKey: "endDate") }
        d.set(timerLabel,      forKey: "timerLabel")
        d.set(enableShortcut,  forKey: "enableShortcut")
        d.set(disableShortcut, forKey: "disableShortcut")
        d.set(launchAppBundleID, forKey: "launchAppBundleID")

        phase = .idle
        ticker?.invalidate()
        updatePhaseAndDisplay()

        ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updatePhaseAndDisplay()
        }
        RunLoop.main.add(ticker!, forMode: .common)
    }

    func clearCountdown() {
        ticker?.invalidate(); ticker = nil
        menuBarView.isFlashing = false
        startDate = nil; endDate = nil
        timerLabel = ""; enableShortcut = ""; disableShortcut = ""
        phase = .idle
        ["startDate","endDate","timerLabel","enableShortcut","disableShortcut","noEndTime","launchAppBundleID"].forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
        setTitle("⏱ --:--:--")
    }

    // MARK: - Display update (called every 0.5 s)

    func updatePhaseAndDisplay() {
        guard let start = startDate else { return }
        let now       = Date()
        let toStart   = start.timeIntervalSince(now)

        if now < start {
            // ── Pre-start ──
            let shouldFlash = toStart <= warningSeconds

            if shouldFlash && phase != .flashWarning {
                phase = .flashWarning
                menuBarView.isFlashing = true
            } else if !shouldFlash && phase != .countingToStart {
                phase = .countingToStart
                menuBarView.isFlashing = false
            }

            setTitle("T- " + formatInterval(toStart))

        } else if let end = endDate {
            // ── Countdown to end ──
            let toEnd = end.timeIntervalSince(now)
            if now < end {
                if phase != .countingToEnd {
                    phase = .countingToEnd
                    menuBarView.isFlashing = false
                    FocusManager.runShortcut(named: enableShortcut)
                    AppLauncher.launch(bundleID: launchAppBundleID)
                    let title = timerLabel.isEmpty ? "No label" : "\(timerLabel)"
                    let body  = timerLabel.isEmpty
                        ? "Event will finish at \(formatTime(end))."
                        : "Event will finish at (\(formatTime(end)))."
                    notify(title: title, body: body)
                }
                setTitle("T- " + formatInterval(toEnd))
            } else {
                if phase != .finished {
                    phase = .finished
                    ticker?.invalidate(); ticker = nil
                    menuBarView.isFlashing = false
                    FocusManager.runShortcut(named: disableShortcut)
                    let title = timerLabel.isEmpty ? "No label" : "\(timerLabel)"
                    notify(title: title, body: "event complete")
                }
                setTitle("End")
            }

        } else {
            // ── Count-up mode ──
            if phase != .countingUp {
                phase = .countingUp
                menuBarView.isFlashing = false
                FocusManager.runShortcut(named: enableShortcut)
                AppLauncher.launch(bundleID: launchAppBundleID)
                let title = timerLabel.isEmpty ? "No label" : "\(timerLabel)"
                notify(title: title, body: "Event started")
            }
            setTitle("T+ " + formatInterval(now.timeIntervalSince(start)))
        }
    }

    // MARK: - Helpers

    private func setTitle(_ text: String) {
        menuBarView.title = text
        // Resize the status item to fit
        let w = menuBarView.preferredWidth()
        menuBarView.frame.size.width = w
        statusItem.length = w
    }

    func formatInterval(_ interval: TimeInterval) -> String {
        let t = Int(abs(interval))
        let h = t / 3600, m = (t % 3600) / 60, s = t % 60
        return h > 0
            ? String(format: "%02d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    func formatTime(_ date: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short; return f.string(from: date)
    }

    func notify(title: String, body: String) {
        let note = NSUserNotification()
        note.title = title; note.informativeText = body
        note.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(note)
    }
}

extension AppDelegate: SettingsViewControllerDelegate {
    func didSetTimes(start: Date, end: Date?, timerLabel: String,
                     enableShortcut: String, disableShortcut: String,
                     launchAppBundleID: String) {
        beginCountdown(start: start, end: end, timerLabel: timerLabel,
                       enableShortcut: enableShortcut, disableShortcut: disableShortcut,
                       launchAppBundleID: launchAppBundleID)
        popover.performClose(nil)
    }
    func didClearTimer() { clearCountdown() }
}
