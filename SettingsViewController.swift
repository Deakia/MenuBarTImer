import AppKit

protocol SettingsViewControllerDelegate: AnyObject {
    func didSetTimes(start: Date, end: Date?, timerLabel: String,
                     enableShortcut: String, disableShortcut: String,
                     launchAppBundleID: String)
    func didClearTimer()
}

class SettingsViewController: NSViewController {

    weak var delegate: SettingsViewControllerDelegate?

    // MARK: - UI elements
    private var titleLabel: NSTextField!

    private var timerLabelCaption: NSTextField!
    private var timerLabelInput: NSTextField!

    private var startLabel: NSTextField!
    private var startPicker: NSDatePicker!

    private var endLabel: NSTextField!
    private var endPicker: NSDatePicker!
    private var endCheckbox: NSButton!       // "No end time (count up)"

    private var focusHeader: NSTextField!
    private var enableLabel: NSTextField!
    private var enablePopup: NSPopUpButton!
    private var disableLabel: NSTextField!
    private var disablePopup: NSPopUpButton!
    private var appLaunchLabel: NSTextField!
    private var appLaunchPopup: NSPopUpButton!
    private var installedApps: [(name: String, bundleID: String)] = []
    private var refreshButton: NSButton!
    private var focusHint: NSTextField!

    private var errorLabel: NSTextField!
    private var startButton: NSButton!
    private var clearButton: NSButton!
    private var quitButton: NSButton!

    private var shortcuts: [String] = []

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 440))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        loadShortcuts()
        loadInstalledApps()
    }

    // MARK: - Build UI

    private func buildUI() {
        var y: CGFloat = 430

        // Title
        titleLabel = label("", size: 14, bold: true)
        titleLabel.frame = NSRect(x: 20, y: y, width: 300, height: 20)
        y -= 34

        // Timer label row
        timerLabelCaption = label("Timer label:", size: 12, bold: false)
        timerLabelCaption.frame = NSRect(x: 20, y: y, width: 90, height: 20)
        timerLabelInput = NSTextField()
        timerLabelInput.placeholderString = "e.g. Team Meeting"
        timerLabelInput.font = NSFont.systemFont(ofSize: 12)
        timerLabelInput.bezelStyle = .roundedBezel
        timerLabelInput.frame = NSRect(x: 120, y: y - 2, width: 200, height: 24)
        y -= 34

        // Start time row
        startLabel = label("Start time:", size: 12, bold: false)
        startLabel.frame = NSRect(x: 20, y: y, width: 90, height: 20)
        startPicker = makePicker(defaultHour: 18, defaultMinute: 0)
        startPicker.frame = NSRect(x: 120, y: y - 2, width: 120, height: 26)
        y -= 34

        // End time row
        endLabel = label("End time:", size: 12, bold: false)
        endLabel.frame = NSRect(x: 20, y: y, width: 90, height: 20)
        endPicker = makePicker(defaultHour: 20, defaultMinute: 0)
        endPicker.frame = NSRect(x: 120, y: y - 2, width: 120, height: 26)
        y -= 36

        // "No end time" checkbox - sits just below the end picker
        endCheckbox = NSButton(checkboxWithTitle: "No end time (Count up instead)", target: self, action: #selector(endCheckboxToggled))
        endCheckbox.font = NSFont.systemFont(ofSize: 12)
        endCheckbox.frame = NSRect(x: 20, y: y, width: 300, height: 20)
        y -= 32

        // Divider
        let divider = NSBox()
        divider.boxType = .separator
        divider.frame = NSRect(x: 20, y: y, width: 300, height: 1)
        view.addSubview(divider)
        y -= 24

        // Focus section header
        focusHeader = label("Shortcuts", size: 12, bold: true)
        focusHeader.frame = NSRect(x: 20, y: y, width: 220, height: 18)

        refreshButton = NSButton(title: "↻ Refresh", target: self, action: #selector(refreshShortcuts))
        refreshButton.bezelStyle = .rounded
        refreshButton.font = NSFont.systemFont(ofSize: 11)
        refreshButton.frame = NSRect(x: 248, y: y - 2, width: 80, height: 22)
        y -= 32

        // Enable shortcut row
        enableLabel = label("On start:", size: 12, bold: false)
        enableLabel.frame = NSRect(x: 20, y: y, width: 90, height: 20)
        enablePopup = NSPopUpButton()
        enablePopup.frame = NSRect(x: 120, y: y - 2, width: 200, height: 24)
        y -= 32

        // Disable shortcut row
        disableLabel = label("On end:", size: 12, bold: false)
        disableLabel.frame = NSRect(x: 20, y: y, width: 90, height: 20)
        disablePopup = NSPopUpButton()
        disablePopup.frame = NSRect(x: 120, y: y - 2, width: 200, height: 24)
        y -= 46

        // App launch row
        appLaunchLabel = label("Open app:", size: 12, bold: false)
        appLaunchLabel.frame = NSRect(x: 20, y: y, width: 90, height: 20)

        appLaunchPopup = NSPopUpButton()
        appLaunchPopup.frame = NSRect(x: 120, y: y - 2, width: 200, height: 24)
        y -= 32
        
        // Hint
        focusHint = label("Shortcuts can be managed in the Shortcuts App.", size: 10, bold: false)
        focusHint.textColor = .secondaryLabelColor
        focusHint.lineBreakMode = .byWordWrapping
        focusHint.maximumNumberOfLines = 2
        focusHint.frame = NSRect(x: 20, y: y, width: 300, height: 28)
        y -= 0

        // Error label
        errorLabel = label("", size: 11, bold: false)
        errorLabel.textColor = .systemRed
        errorLabel.frame = NSRect(x: 20, y: y, width: 300, height: 18)
        y -= 32

        // Start / Clear buttons
        startButton = NSButton(title: "Start Countdown", target: self, action: #selector(startTapped))
        startButton.bezelStyle = .rounded
        startButton.frame = NSRect(x: 20, y: y, width: 170, height: 28)
        startButton.keyEquivalent = "\r"

        clearButton = NSButton(title: "Clear", target: self, action: #selector(clearTapped))
        clearButton.bezelStyle = .rounded
        clearButton.frame = NSRect(x: 200, y: y, width: 120, height: 28)
        y -= 38

        // Quit
        quitButton = NSButton(title: "Quit App", target: self, action: #selector(quitTapped))
        quitButton.bezelStyle = .rounded
        quitButton.frame = NSRect(x: 20, y: y, width: 300, height: 28)

        [titleLabel, timerLabelCaption, timerLabelInput,
         startLabel, startPicker,
         endLabel, endPicker, endCheckbox,
         focusHeader, refreshButton,
         enableLabel, enablePopup,
         disableLabel, disablePopup,
         focusHint, errorLabel,
         startButton, clearButton, quitButton, appLaunchLabel, appLaunchPopup].forEach { view.addSubview($0!) }

        // Restore saved values
        let d = UserDefaults.standard
        if let lbl = d.string(forKey: "timerLabel") { timerLabelInput.stringValue = lbl }

        let noEnd = d.bool(forKey: "noEndTime")
        endCheckbox.state = noEnd ? .on : .off
        updateEndPickerState()
    }

    // MARK: - Checkbox

    @objc private func endCheckboxToggled() {
        updateEndPickerState()
    }

    private func updateEndPickerState() {
        let countUp = endCheckbox.state == .on
        endPicker.isEnabled  = !countUp
        endPicker.alphaValue = countUp ? 0.35 : 1.0
        // Also grey out the "On end" focus shortcut since there's no end event
        disableLabel.alphaValue = countUp ? 0.35 : 1.0
        disablePopup.isEnabled  = !countUp
        disablePopup.alphaValue = countUp ? 0.35 : 1.0
    }

    // MARK: - Shortcuts

    private func loadShortcuts() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let list = FocusManager.installedShortcuts()
            DispatchQueue.main.async { self?.populatePopups(with: list) }
        }
    }

    
    private func populatePopups(with list: [String]) {
        shortcuts = list
        let items = ["(None)"] + list
        for popup in [enablePopup!, disablePopup!] {
            popup.removeAllItems()
            popup.addItems(withTitles: items)
        }
        let d = UserDefaults.standard
        if let s = d.string(forKey: "enableShortcut"),  items.contains(s) { enablePopup.selectItem(withTitle: s) }
        if let s = d.string(forKey: "disableShortcut"), items.contains(s) { disablePopup.selectItem(withTitle: s) }

        focusHint.stringValue = list.isEmpty
            ? "No Shortcuts found. Create one in the Shortcuts app, then tap ↻ Refresh."
            : ""
    }

    @objc private func refreshShortcuts() {
        for popup in [enablePopup!, disablePopup!] {
            popup.removeAllItems(); popup.addItem(withTitle: "Loading…")
        }
        loadShortcuts()
    }
    
    private func loadInstalledApps() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let apps = AppLauncher.installedApps()
            DispatchQueue.main.async {
                self?.populateAppPopup(with: apps)
            }
        }
    }

    private func populateAppPopup(with apps: [(name: String, bundleID: String)]) {
        installedApps = apps
        appLaunchPopup.removeAllItems()
        appLaunchPopup.addItem(withTitle: "(None)")
        appLaunchPopup.addItems(withTitles: apps.map { $0.name })

        if let saved = UserDefaults.standard.string(forKey: "launchAppBundleID"),
           let match = apps.first(where: { $0.bundleID == saved }) {
            appLaunchPopup.selectItem(withTitle: match.name)
        }
    }

    // MARK: - Helpers

    private func label(_ text: String, size: CGFloat, bold: Bool) -> NSTextField {
        let tf = NSTextField(labelWithString: text)
        tf.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        tf.textColor = .labelColor
        tf.lineBreakMode = .byTruncatingTail
        return tf
    }

    private func makePicker(defaultHour: Int, defaultMinute: Int) -> NSDatePicker {
        let p = NSDatePicker()
        p.datePickerStyle = .textField
        p.datePickerElements = [.hourMinute]
        p.isBezeled = true
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = defaultHour; comps.minute = defaultMinute; comps.second = 0
        p.dateValue = Calendar.current.date(from: comps) ?? Date()
        return p
    }

    private func resolveDate(from picker: NSDatePicker, after reference: Date? = nil) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.hour, .minute], from: picker.dateValue)
        comps.second = 0
        let base = reference ?? Date()
        var candidate = cal.nextDate(after: base.addingTimeInterval(-1),
                                     matching: comps, matchingPolicy: .nextTime) ?? base
        if candidate < base { candidate = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate }
        return candidate
    }

    private func selectedShortcut(_ popup: NSPopUpButton) -> String {
        let t = popup.titleOfSelectedItem ?? ""; return t == "(None)" ? "" : t
    }

    // MARK: - Actions

    @objc private func startTapped() {
        errorLabel.stringValue = ""
        view.window?.makeFirstResponder(nil)

        let timerLabel      = timerLabelInput.stringValue.trimmingCharacters(in: .whitespaces)
        let enableShortcut  = selectedShortcut(enablePopup)
        let disableShortcut = selectedShortcut(disablePopup)
        let countUp         = endCheckbox.state == .on

        let start = resolveDate(from: startPicker)
        var end: Date? = nil

        if !countUp {
            let resolvedEnd = resolveDate(from: endPicker, after: start)
            if resolvedEnd <= start {
                errorLabel.stringValue = "End time must be after start time."
                return
            }
            end = resolvedEnd
        }

        let d = UserDefaults.standard
        d.set(timerLabel,      forKey: "timerLabel")
        d.set(enableShortcut,  forKey: "enableShortcut")
        d.set(disableShortcut, forKey: "disableShortcut")
        d.set(countUp,         forKey: "noEndTime")

        
        let selectedAppIndex = appLaunchPopup.indexOfSelectedItem
        let launchAppBundleID: String
        if selectedAppIndex > 0 {
            launchAppBundleID = installedApps[selectedAppIndex - 1].bundleID  // offset by 1 for "(None)"
        } else {
            launchAppBundleID = ""
        }
        UserDefaults.standard.set(launchAppBundleID, forKey: "launchAppBundleID")
        
        delegate?.didSetTimes(start: start, end: end, timerLabel: timerLabel,
                              enableShortcut: enableShortcut, disableShortcut: disableShortcut,
                              launchAppBundleID: launchAppBundleID)
    }

    @objc private func clearTapped() { errorLabel.stringValue = ""; delegate?.didClearTimer() }
    @objc private func quitTapped()  { NSApp.terminate(nil) }
}
