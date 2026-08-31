import AppKit
import Combine

/// 休息提醒卡片（纯 AppKit）：毛玻璃卡片 + 渐变蒙版。
/// 交互走 NSButton 标准事件链路，保证在无边框置顶面板上可点击。
final class OverlayCardController: NSViewController {
    private let engine: TimerEngine
    private let settings: SettingsStore
    private let onPrimary: () -> Void
    private var cancellables: Set<AnyCancellable> = []

    // 卡片元素
    private let emojiLabel = NSTextField(labelWithString: "☕️")
    private let titleLabel = NSTextField(labelWithString: "休息一下")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let timerLabel = NSTextField(labelWithString: "00:00")
    private let progressTrack = NSView()
    private let progressFill = NSView()
    private var progressFillWidth: NSLayoutConstraint?
    private let timerSection = NSStackView()
    private let restButtons = NSStackView()
    private let resumeButtons = NSStackView()
    private var pauseButton: NSButton?
    private var buttonActions = [NSButton: () -> Void]()

    init(engine: TimerEngine, settings: SettingsStore, onPrimary: @escaping () -> Void) {
        self.engine = engine
        self.settings = settings
        self.onPrimary = onPrimary
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("不支持") }

    override func loadView() {
        view = GradientBackgroundView(frame: NSRect(x: 0, y: 0, width: 1600, height: 1000))
        buildCard()
        observeEngine()
        update()
    }

    // MARK: - 界面搭建

    private func buildCard() {
        let card = NSVisualEffectView()
        card.material = .popover
        card.blendingMode = .behindWindow
        card.state = .active
        card.wantsLayer = true
        card.layer?.cornerRadius = 32
        card.layer?.shadowColor = NSColor.black.cgColor
        card.layer?.shadowOpacity = 0.3
        card.layer?.shadowRadius = 36
        card.layer?.shadowOffset = CGSize(width: 0, height: -16)

        emojiLabel.font = .systemFont(ofSize: 56)
        emojiLabel.alignment = .center
        titleLabel.font = roundedFont(size: 28, weight: .semibold)
        titleLabel.alignment = .center
        subtitleLabel.font = .systemFont(ofSize: 15)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center

        timerLabel.font = roundedFont(size: 80, weight: .bold)
        timerLabel.textColor = NSColor.systemTeal
        timerLabel.alignment = .center

        progressTrack.wantsLayer = true
        progressTrack.layer?.backgroundColor = NSColor.systemTeal.withAlphaComponent(0.18).cgColor
        progressTrack.layer?.cornerRadius = 3
        progressFill.wantsLayer = true
        progressFill.layer?.backgroundColor = NSColor.systemTeal.cgColor
        progressFill.layer?.cornerRadius = 3

        timerSection.orientation = .vertical
        timerSection.alignment = .centerX
        timerSection.spacing = 20
        timerSection.addArrangedSubview(timerLabel)
        timerLabel.widthAnchor.constraint(equalToConstant: 320).isActive = true
        timerSection.addArrangedSubview(progressTrack)
        progressTrack.translatesAutoresizingMaskIntoConstraints = false
        progressTrack.widthAnchor.constraint(equalToConstant: 300).isActive = true
        progressTrack.heightAnchor.constraint(equalToConstant: 6).isActive = true
        progressTrack.addSubview(progressFill)
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor).isActive = true
        progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor).isActive = true
        progressFill.leftAnchor.constraint(equalTo: progressTrack.leftAnchor).isActive = true
        progressFillWidth = progressFill.widthAnchor.constraint(equalToConstant: 300)
        progressFillWidth?.isActive = true

        restButtons.orientation = .horizontal
        restButtons.spacing = 12
        restButtons.addArrangedSubview(makeButton("多歇 2 分") { [weak self] in
            self?.engine.extendCurrent(byMinutes: 2)
        })
        let pause = makeButton("暂停") { [weak self] in
            self?.engine.togglePause()
            self?.update()
        }
        pauseButton = pause
        restButtons.addArrangedSubview(pause)
        restButtons.addArrangedSubview(makeButton("完成休息", tint: .systemTeal, isPrimary: true) { [weak self] in
            self?.onPrimary()
        })

        resumeButtons.orientation = .horizontal
        resumeButtons.spacing = 12
        resumeButtons.addArrangedSubview(makeButton("开始工作", tint: .systemIndigo, isPrimary: true) { [weak self] in
            Diag.log("resumeCard 开始工作 按下")
            self?.engine.startWork()
        })
        resumeButtons.addArrangedSubview(makeButton("再歇 2 分钟") { [weak self] in
            self?.engine.startRest()
            self?.engine.extendCurrent(byMinutes: 2)
        })
        resumeButtons.addArrangedSubview(makeButton("关闭") { [weak self] in
            self?.engine.dismissChoice()
            self?.onPrimary()
        })

        let content = NSStackView(views: [emojiLabel, titleLabel, subtitleLabel, timerSection, restButtons, resumeButtons])
        content.orientation = .vertical
        content.alignment = .centerX
        content.spacing = 18

        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)
        card.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 480),
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 40),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -40),
            content.leftAnchor.constraint(equalTo: card.leftAnchor, constant: 44),
            content.rightAnchor.constraint(equalTo: card.rightAnchor, constant: -44),
        ])
    }

    private func makeButton(_ title: String, tint: NSColor? = nil, isPrimary: Bool = false,
                            action: @escaping () -> Void) -> NSButton {
        let button = NSButton(title: title, target: self, action: #selector(buttonTapped(_:)))
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.setButtonType(.momentaryPushIn)
        if isPrimary {
            button.bezelColor = tint
            button.contentTintColor = .white
        }
        buttonActions[button] = action
        return button
    }

    @objc private func buttonTapped(_ sender: NSButton) {
        Diag.log("overlay button tapped: \(sender.title)")
        buttonActions[sender]?()
    }

    private func roundedFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: descriptor, size: size) ?? base
    }

    // MARK: - 状态刷新

    private func observeEngine() {
        engine.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.update() }
            .store(in: &cancellables)
    }

    private func update() {
        let resting = engine.phase == .rest
        emojiLabel.stringValue = resting ? "☕️" : "🌿"
        titleLabel.stringValue = resting ? "休息一下" : "休息结束"
        subtitleLabel.stringValue = resting ? "离开屏幕 · 远眺放松 · 活动肩颈" : "准备好就开始下一轮工作吧"
        timerSection.isHidden = !resting
        restButtons.isHidden = !resting
        resumeButtons.isHidden = resting
        guard resting else { return }
        timerLabel.stringValue = clockText(engine.remaining)
        if pauseButton != nil {
            pauseButton?.title = engine.isPaused ? "继续" : "暂停"
        }
        let fraction = engine.total > 0 ? min(1, max(0, engine.remaining / engine.total)) : 0
        progressFillWidth?.constant = 300 * fraction
        subtitleLabel.stringValue = "今日已完成 \(engine.todayCycles) 轮 · 下一轮工作 \(settings.workMinutes) 分钟"
    }
}

/// 全屏渐变蒙版背景。
final class GradientBackgroundView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let colors = [
            NSColor(red: 0.05, green: 0.07, blue: 0.13, alpha: 0.52).cgColor,
            NSColor(red: 0.07, green: 0.10, blue: 0.17, alpha: 0.44).cgColor,
        ]
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors as CFArray, locations: [0, 1]) else { return }
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: bounds.height),
                                   end: CGPoint(x: bounds.width, y: 0),
                                   options: [])
    }
}
