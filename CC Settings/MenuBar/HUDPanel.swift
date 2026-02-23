import AppKit
import SwiftUI

@MainActor
class HUDPanel: NSPanel {
    private let hudState: HUDState
    private let hostingView: NSHostingView<HUDContentView>

    private static let positionXKey = "HUDPanel.positionX"
    private static let positionYKey = "HUDPanel.positionY"
    private static let isExpandedKey = "HUDPanel.isExpanded"

    init() {
        let isExpanded = UserDefaults.standard.bool(forKey: HUDPanel.isExpandedKey)
        hudState = HUDState(isExpanded: isExpanded)
        let swiftUIContent = HUDContentView(hudState: hudState)
        hostingView = NSHostingView(rootView: swiftUIContent)

        let initialSize = isExpanded
            ? NSSize(width: 260, height: 200)
            : NSSize(width: 200, height: 44)

        let initialFrame = NSRect(origin: .zero, size: initialSize)

        super.init(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .utilityWindow

        hostingView.frame = self.contentView?.bounds ?? initialFrame
        hostingView.autoresizingMask = [.width, .height]
        self.contentView?.addSubview(hostingView)

        restorePosition()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove(_:)),
            name: NSWindow.didMoveNotification,
            object: self
        )
    }

    var isExpanded: Bool {
        get { hudState.isExpanded }
        set {
            hudState.isExpanded = newValue
            UserDefaults.standard.set(newValue, forKey: HUDPanel.isExpandedKey)
            updateSize(animated: true)
        }
    }

    func toggleExpanded() {
        isExpanded.toggle()
    }

    /// Called from SwiftUI when the expand/collapse button is tapped.
    func updateForExpandedState() {
        UserDefaults.standard.set(hudState.isExpanded, forKey: HUDPanel.isExpandedKey)
        updateSize(animated: true)
    }

    private func updateSize(animated: Bool) {
        let newSize = hudState.isExpanded
            ? NSSize(width: 260, height: 200)
            : NSSize(width: 200, height: 44)

        var newFrame = frame
        newFrame.size = newSize

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().setFrame(newFrame, display: true)
            }
        } else {
            setFrame(newFrame, display: true)
        }
    }

    private func restorePosition() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: HUDPanel.positionXKey) != nil {
            let x = defaults.double(forKey: HUDPanel.positionXKey)
            let y = defaults.double(forKey: HUDPanel.positionYKey)
            setFrameOrigin(NSPoint(x: x, y: y))
        } else if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - frame.width - 20
            let y = screenFrame.maxY - frame.height - 20
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    private func savePosition() {
        let defaults = UserDefaults.standard
        defaults.set(frame.origin.x, forKey: HUDPanel.positionXKey)
        defaults.set(frame.origin.y, forKey: HUDPanel.positionYKey)
    }

    @objc private func windowDidMove(_ notification: Notification) {
        savePosition()
    }
}
