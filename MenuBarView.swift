import AppKit

/// A custom view that replaces the default NSStatusBarButton.
/// It renders the timer label and can flash a red background.
class MenuBarView: NSView {

    // MARK: - Public state

    var title: String = "⏱ --:--:--" {
        didSet { needsDisplay = true }
    }

    /// When true the background pulses red at ~1 Hz
    var isFlashing: Bool = false {
        didSet {
            if isFlashing  { startFlash() }
            else           { stopFlash()  }
        }
    }

    // MARK: - Private

    private var flashOn      = false
    private var flashTimer: Timer?

    // Horizontal padding either side of the text
    private let hPad: CGFloat = 6

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Background
        let bg: NSColor = (isFlashing && flashOn) ? flashColour() : .clear
        bg.setFill()
        if isFlashing && flashOn {
            // Rounded rect fill so it looks tidy in the menu bar
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1),
                                    xRadius: 4, yRadius: 4)
            path.fill()
        }

        // Text
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: textColour()
        ]
        let str  = NSAttributedString(string: title, attributes: attrs)
        let size = str.size()
        let x    = (bounds.width  - size.width)  / 2
        let y    = (bounds.height - size.height) / 2
        str.draw(at: NSPoint(x: x, y: y))
    }

    // MARK: - Sizing

    func preferredWidth() -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        ]
        let w = (title as NSString).size(withAttributes: attrs).width
        return ceil(w) + hPad * 2
    }

    // MARK: - Flash animation

    private func startFlash() {
        guard flashTimer == nil else { return }
        flashOn = true
        needsDisplay = true
        flashTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.flashOn.toggle()
            self.needsDisplay = true
        }
        RunLoop.main.add(flashTimer!, forMode: .common)
    }

    private func stopFlash() {
        flashTimer?.invalidate()
        flashTimer = nil
        flashOn    = false
        needsDisplay = true
    }

    // MARK: - Colours

    private func flashColour() -> NSColor {
        // Vivid red that's visible in both Light and Dark menu bars
        return NSColor(red: 0.85, green: 0.08, blue: 0.08, alpha: 1.0)
    }

    private func textColour() -> NSColor {
        if isFlashing && flashOn { return .white }
        // Respect menu bar appearance (light / dark)
        return .labelColor
    }

    // MARK: - Click passthrough

    override func mouseDown(with event: NSEvent) {
        // Forward click to the status item's action
        if let action = statusItemAction, let target = statusItemTarget {
            NSApp.sendAction(action, to: target, from: self)
        }
    }

    var statusItemAction: Selector?
    var statusItemTarget: AnyObject?
}
