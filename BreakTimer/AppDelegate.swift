import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var engine: TimerEngine { AppModel.shared.engine }
    private var settings: SettingsStore { AppModel.shared.settings }

    private var statusItem: NSStatusItem?
    private var overlayPanel: OverlayPanel?
    private var setupWindow: NSWindow?

    func applicationWillFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--self-test") {
            EngineSelfTest.runAndExit()
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
        // 隐藏参数：启动即开始工作（调试/端到端验证用）
        if CommandLine.arguments.contains("--autostart") {
            engine.startWork()
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
        let view = NSHostingView(rootView: BreakOverlayView(
            engine: engine,
            settings: settings,
            onClose: { [weak self] in self?.overlayPrimaryAction() }
        ))
        view.sizingOptions = []
        panel.contentView = view
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        overlayPanel = panel
    }

    private func hideOverlay() {
        overlayPanel?.orderOut(nil)
        overlayPanel = nil
    }

    /// 浮层主操作（完成休息按钮 / Esc / 关闭按钮）
    private func overlayPrimaryAction() {
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

private extension NSMenu {
    func add(_ title: String, target: AnyObject?, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target
        item.isEnabled = true
        addItem(item)
    }
}
