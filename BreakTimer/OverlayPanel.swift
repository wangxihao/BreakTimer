import AppKit

/// 休息提醒浮层：无边框、不抢焦点、盖在包括全屏应用在内的所有窗口之上。
final class OverlayPanel: NSPanel {
    init(screenFrame: NSRect) {
        super.init(contentRect: screenFrame,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = false
        becomesKeyOnlyIfNeeded = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }

    /// Esc 关闭浮层
    var onEsc: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            onEsc?()
        } else {
            super.keyDown(with: event)
        }
    }
}
