import AppKit
import Combine

/// 休息提醒卡片（纯 AppKit）：护眼图为卡片背景 + 暗色渐变保证可读性。
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
    private var photoView: NSView?
    private var cardView: NSView?

    init(engine: TimerEngine, settings: SettingsStore, onPrimary: @escaping () -> Void) {
        self.engine = engine
        self.settings = settings
        self.onPrimary = onPrimary
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("不支持") }

    override func loadView() {
        // 全屏灰色半透明罩层：均匀一致、不模糊，桌面内容可见但被压暗
        let veil = NSView(frame: NSRect(x: 0, y: 0, width: 1600, height: 1000))
        veil.wantsLayer = true
        veil.layer?.backgroundColor = NSColor(srgbRed: 0.05, green: 0.06, blue: 0.06, alpha: 0.5).cgColor
        view = veil
        buildCard()
        observeEngine()
        update()
    }

    /// 卡片：护眼图作背景（aspectFill），上覆暗色渐变，白色文字。
    private func buildCard() {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.shadowColor = NSColor.black.cgColor
        card.layer?.shadowOpacity = 0.3
        card.layer?.shadowRadius = 36
        card.layer?.shadowOffset = CGSize(width: 0, height: -16)

        let photo = NSView()
        photo.wantsLayer = true
        photo.layer?.cornerRadius = 32
        photo.layer?.masksToBounds = true
        if let image = Self.randomBackgroundImage() {
            photo.layer?.contents = image
            photo.layer?.contentsGravity = .resizeAspectFill
        } else {
            photo.layer?.backgroundColor = NSColor(calibratedRed: 0.13, green: 0.35, blue: 0.22, alpha: 1).cgColor
        }
        photoView = photo
        cardView = card
        photo.alphaValue = 0 // 等待 fadeInPhoto 淡入

        let tint = TintOverlayView(frame: NSRect(x: 0, y: 0, width: 480, height: 300))

        emojiLabel.font = .systemFont(ofSize: 56)
        emojiLabel.alignment = .center
        titleLabel.font = roundedFont(size: 28, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.85)
        subtitleLabel.alignment = .center

        timerLabel.font = roundedFont(size: 78, weight: .bold)
        timerLabel.textColor = .white
        timerLabel.alignment = .center

        progressTrack.wantsLayer = true
        progressTrack.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.25).cgColor
        progressTrack.layer?.cornerRadius = 3
        progressFill.wantsLayer = true
        progressFill.layer?.backgroundColor = NSColor.white.cgColor
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
        restButtons.addArrangedSubview(makeButton("完成休息", isPrimary: true) { [weak self] in
            self?.onPrimary()
        })

        resumeButtons.orientation = .horizontal
        resumeButtons.spacing = 12
        resumeButtons.addArrangedSubview(makeButton("开始工作", isPrimary: true) { [weak self] in
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
        card.addSubview(photo)
        card.addSubview(tint)
        card.addSubview(content)
        photo.translatesAutoresizingMaskIntoConstraints = false
        tint.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 480),
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 320),
            photo.topAnchor.constraint(equalTo: card.topAnchor),
            photo.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            photo.leftAnchor.constraint(equalTo: card.leftAnchor),
            photo.rightAnchor.constraint(equalTo: card.rightAnchor),
            tint.topAnchor.constraint(equalTo: card.topAnchor),
            tint.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            tint.leftAnchor.constraint(equalTo: card.leftAnchor),
            tint.rightAnchor.constraint(equalTo: card.rightAnchor),
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 38),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -38),
            content.leftAnchor.constraint(equalTo: card.leftAnchor, constant: 44),
            content.rightAnchor.constraint(equalTo: card.rightAnchor, constant: -44),
        ])
    }

    private func makeButton(_ title: String, isPrimary: Bool = false,
                            action: @escaping () -> Void) -> NSButton {
        let button = NSButton(title: title, target: self, action: #selector(buttonTapped(_:)))
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.setButtonType(.momentaryPushIn)
        if isPrimary {
            button.bezelColor = .white
        } else {
            button.bezelColor = NSColor(calibratedWhite: 0.08, alpha: 0.5)
        }
        // 用 attributedTitle 把文字颜色写死，避免首帧渲染颜色不确定（白块→黑字闪烁）
        button.attributedTitle = Self.attributedTitle(title, color: isPrimary ? .black : .white)
        buttonActions[button] = action
        return button
    }

    private static func attributedTitle(_ title: String, color: NSColor) -> NSAttributedString {
        NSAttributedString(string: title, attributes: [
            .foregroundColor: color,
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .large), weight: .medium),
        ])
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

    // MARK: - 背景图来源

    /// 图片来源：用户图库（~/Library/Application Support/BreakTimer/backgrounds/）优先，
    /// 其次应用内置背景（Resources/Backgrounds），随机选一张；都没有则用纯绿底色。
    private static func randomBackgroundImage() -> CGImage? {
        let fileManager = FileManager.default
        var directories: [URL] = []
        if let userDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("BreakTimer/backgrounds") {
            directories.append(userDirectory)
        }
        if let resourceDirectory = Bundle.main.resourceURL?.appendingPathComponent("Backgrounds") {
            directories.append(resourceDirectory)
        }
        let extensions = ["jpg", "jpeg", "png", "heic", "webp"]
        for directory in directories {
            let files = ((try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
                .filter { extensions.contains($0.pathExtension.lowercased()) }
            if let file = files.randomElement(),
               let image = NSImage(contentsOf: file),
               let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                Diag.log("background: 使用 \(file.lastPathComponent)")
                return cgImage
            }
        }
        Diag.log("background: 无可用图片，使用纯绿底色")
        return nil
    }

    /// 卡片背景图淡入（在视图进入窗口后调用一次；按钮不受影响）。
    func fadeInPhoto() {
        photoView?.animator().alphaValue = 1
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        Diag.log("overlay layout view=\(view.bounds) photo=\(photoView?.frame ?? .zero) card=\(cardView?.frame ?? .zero)")
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
        if let pause = pauseButton {
            pause.attributedTitle = Self.attributedTitle(engine.isPaused ? "继续" : "暂停", color: .white)
        }
        let fraction = engine.total > 0 ? min(1, max(0, engine.remaining / engine.total)) : 0
        progressFillWidth?.constant = 300 * fraction
        subtitleLabel.stringValue = "今日已完成 \(engine.todayCycles) 轮 · 下一轮工作 \(settings.workMinutes) 分钟"
    }
}

/// 卡片上的暗色渐变罩层：顶部浅、底部深，保证按钮与文字可读。
final class TintOverlayView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let colors = [
            NSColor.black.withAlphaComponent(0.18).cgColor,
            NSColor.black.withAlphaComponent(0.30).cgColor,
            NSColor.black.withAlphaComponent(0.52).cgColor,
        ]
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors as CFArray, locations: [0, 0.55, 1]) else { return }
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: bounds.height),
                                   end: CGPoint(x: 0, y: 0),
                                   options: [])
    }
}

/// 全屏渐变蒙版背景（已被固定灰色半透明罩层取代，保留备用）。
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
