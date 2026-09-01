import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var engine: TimerEngine { AppModel.shared.engine }
    private var settings: SettingsStore { AppModel.shared.settings }

    private var statusItem: NSStatusItem?
    private var overlayPanel: OverlayPanel?
    private var overlayController: OverlayCardController?
    private var setupWindow: NSWindow?
    /// 休息浮层弹出时设置窗口是否被暂时隐藏（用于结束后恢复）
    private var setupWindowHiddenForOverlay = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--self-test") {
            EngineSelfTest.runAndExit()
        }
        if CommandLine.arguments.contains("--render-marketing") {
            let idx = CommandLine.arguments.firstIndex(of: "--render-marketing")!
            let dir = CommandLine.arguments.count > idx + 1 ? CommandLine.arguments[idx + 1] : "/tmp/bt-marketing"
            MainActor.assumeIsolated {
                MarketingRenderer.runAndExit(dir)
            }
        }
        // 菜单栏应用：不显示 Dock 图标
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        engine.onPhaseChanged = { [weak self] phase in self?.phaseChanged(phase) }
        engine.onTick = { [weak self] in self?.refreshStatusTitle() }
        setupStatusItem()
        showSetupWindow()
        refreshStatusTitle()
        // 调试：--diag-speed N 将倒计时加速 N 倍（不受设置窗口滑块影响）；须在开跑前设置
        if let idx = CommandLine.arguments.firstIndex(of: "--diag-speed"),
           CommandLine.arguments.count > idx + 1, let speed = Double(CommandLine.arguments[idx + 1]) {
            engine.debugSpeed = speed
        }
        // 启动即开始第一轮工作（设置开启，或调试参数 --autostart）
        if settings.autoStartOnLaunch || CommandLine.arguments.contains("--autostart") {
            engine.startWork()
        }
        installClickDiagnosticsIfNeeded()
        // 调试：--show-overlay 启动即显示休息浮层（不计时），用于视觉检查
        if CommandLine.arguments.contains("--show-overlay") {
            engine.startRest()
        }
        // 用户自定义护眼图目录（往里丢 jpg/png 即可在休息时随机显示）
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("BreakTimer/backgrounds") {
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }
    }

    // MARK: - 菜单栏

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        }
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    private func refreshStatusTitle() {
        statusItem?.button?.title = engine.statusTitle
    }

    // MARK: - 阶段切换 → 浮层显隐

    private func phaseChanged(_ phase: TimerEngine.Phase) {
        Diag.log("phaseChanged \(phase.rawValue) awaiting=\(engine.awaitingResumeChoice) overlay=\(overlayPanel != nil)")
        switch phase {
        case .work:
            hideOverlay()
        case .rest:
            showOverlay()
        case .idle:
            if !engine.awaitingResumeChoice {
                hideOverlay()
            }
            // awaitingResumeChoice == true 时保留浮层，内容自动切换为“开始下一轮”卡片
        }
        refreshStatusTitle()
    }

    // MARK: - 休息浮层

    private func showOverlay() {
        hideOverlay()
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }
        let panel = OverlayPanel(screenFrame: screen.frame)
        let controller = OverlayCardController(engine: engine, settings: settings,
                                               onPrimary: { [weak self] in self?.overlayPrimaryAction() })
        controller.view.frame = NSRect(origin: .zero, size: screen.frame.size)
        controller.view.autoresizingMask = [.width, .height]
        panel.contentView = controller.view
        panel.onEsc = { [weak self] in self?.overlayPrimaryAction() }
        panel.makeKeyAndOrderFront(nil)
        panel.makeKey()
        panel.orderFrontRegardless()
        overlayPanel = panel
        // contentView 不会保留 NSViewController，必须自己持有，否则按钮 target 悬空
        overlayController = controller
        // 休息期间隐去设置窗口，结束后再恢复
        if setupWindow?.isVisible == true {
            setupWindow?.orderOut(nil)
            setupWindowHiddenForOverlay = true
            Diag.log("setupWindow 隐藏（休息中）")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { controller.fadeInPhoto() }
        Diag.log("showOverlay screen=\(screen.localizedName) frame=\(screen.frame) key=\(panel.isKeyWindow)")
    }

    private func hideOverlay() {
        let hadPanel = overlayPanel != nil
        Diag.log("hideOverlay panel=\(hadPanel)")
        overlayPanel?.orderOut(nil)
        overlayPanel = nil
        overlayController = nil
        if hadPanel, setupWindowHiddenForOverlay {
            setupWindowHiddenForOverlay = false
            setupWindow?.makeKeyAndOrderFront(nil)
            Diag.log("setupWindow 恢复显示")
        }
    }

    /// 浮层主操作（完成休息按钮 / Esc / 关闭按钮）
    private func overlayPrimaryAction() {
        Diag.log("overlayPrimaryAction phase=\(engine.phase.rawValue)")
        if engine.phase == .rest {
            engine.finishRestEarly()
        } else {
            engine.dismissChoice()
            hideOverlay()
        }
    }

    // MARK: - 设置窗口

    private func showSetupWindow() {
        if setupWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 620),
                                  styleMask: [.titled, .closable, .miniaturizable],
                                  backing: .buffered, defer: false)
            window.title = "BreakTimer"
            window.isReleasedWhenClosed = false
            let hosting = NSHostingView(rootView: SetupView(engine: engine, settings: settings))
            hosting.sizingOptions = []
            window.contentView = hosting
            window.setContentSize(NSSize(width: 440, height: 620))
            window.center()
            setupWindow = window
        }
        // 休息浮层显示期间，设置窗口提到罩层之上（否则会被半透明蒙版盖成幽灵窗）
        setupWindow?.level = overlayPanel != nil ? NSWindow.Level(1001) : .normal
        setupWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - 菜单栏右键/点击菜单

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let head = NSMenuItem(title: engine.statusDetail, action: nil, keyEquivalent: "")
        head.isEnabled = false
        menu.addItem(head)
        menu.addItem(.separator())

        switch engine.phase {
        case .idle:
            menu.add("开始工作", target: self, action: #selector(menuStartWork))
            menu.add("立即休息", target: self, action: #selector(menuStartRest))
        case .work, .rest:
            menu.add(engine.isPaused ? "继续" : "暂停", target: self, action: #selector(menuTogglePause))
            menu.add(engine.phase == .work ? "提前进入休息" : "跳过休息", target: self, action: #selector(menuSkip))
            menu.add("停止计时", target: self, action: #selector(menuStop))
        }

        menu.addItem(.separator())
        menu.add("设置…", target: self, action: #selector(menuSettings))
        menu.addItem(.separator())
        menu.add("退出 BreakTimer", target: self, action: #selector(menuQuit))
    }

    @objc private func menuStartWork() { engine.startWork() }
    @objc private func menuStartRest() { engine.startRest() }
    @objc private func menuTogglePause() { engine.togglePause() }
    @objc private func menuSkip() { engine.skip() }
    @objc private func menuStop() { engine.stopAll() }
    @objc private func menuSettings() { showSetupWindow() }
    @objc private func menuQuit() { NSApp.terminate(nil) }
}

// MARK: - 点击诊断（--diag-click N：等待“开始下一轮”卡片出现 N 秒后，进程内合成一次真实点击）

extension AppDelegate {
    private func installClickDiagnosticsIfNeeded() {
        let args = CommandLine.arguments
        guard let idx = args.firstIndex(of: "--diag-click"),
              args.count > idx + 1, let delay = Double(args[idx + 1]) else { return }
        Diag.log("click-test 安装 delay=\(delay)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.waitAndFireClick(delay: delay)
        }
    }

    private func waitAndFireClick(delay: TimeInterval) {
        let deadline = Date().addingTimeInterval(180)
        while Date() < deadline {
            if engine.phase == .idle && engine.awaitingResumeChoice { break }
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.2))
        }
        guard engine.awaitingResumeChoice else {
            Diag.log("click-test 失败：180s 内未出现等待选择卡片（phase=\(engine.phase.rawValue)）")
            exit(4)
        }
        Diag.log("click-test 卡片已出现，\(delay)s 后发送合成点击")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.fireSyntheticClick()
        }
    }

    /// 在进程内构造真实 NSEvent 并走 NSApp.sendEvent 的正常派发链路。
    private func fireSyntheticClick() {
        guard let panel = overlayPanel, let content = panel.contentView else {
            Diag.log("click-test 失败：面板不存在")
            exit(5)
        }
        func findButton(_ view: NSView, title: String) -> NSButton? {
            if let button = view as? NSButton, button.title == title { return button }
            for subview in view.subviews {
                if let found = findButton(subview, title: title) { return found }
            }
            return nil
        }
        guard let button = findButton(content, title: "开始工作") else {
            Diag.log("click-test 失败：视图树中找不到「开始工作」按钮")
            exit(6)
        }
        let centerInWindow = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: nil)
        let hit = content.hitTest(centerInWindow)
        Diag.log("click-test 按钮 frame=\(button.frame) enabled=\(button.isEnabled) hitTest=\(hit.map { String(describing: type(of: $0)) } ?? "nil") keyWin=\(panel.isKeyWindow)")
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = NSEvent.mouseEvent(with: type,
                                           location: centerInWindow,
                                           modifierFlags: [],
                                           timestamp: ProcessInfo.processInfo.systemUptime,
                                           windowNumber: panel.windowNumber,
                                           context: nil,
                                           eventNumber: 0,
                                           clickCount: 1,
                                           pressure: 1)
            if let event { NSApp.postEvent(event, atStart: false) }
        }
        Diag.log("click-test 已投递 postEvent location=\(centerInWindow)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            if engine.phase == .work {
                Diag.log("click-test 结果: postEvent 成功")
                exit(0)
            }
            Diag.log("click-test postEvent 无效，改用 performClick")
            button.performClick(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self else { return }
                let ok = engine.phase == .work
                Diag.log("click-test 结果: \(ok ? "performClick 成功（事件派发层有问题）" : "仍然失败（action 接线问题）") phase=\(engine.phase.rawValue) panelVisible=\(overlayPanel != nil)")
                exit(ok ? 0 : 3)
            }
        }
    }
}

private extension NSMenu {
    func add(_ title: String, target: AnyObject?, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target
        item.isEnabled = true
        addItem(item)
    }
}
