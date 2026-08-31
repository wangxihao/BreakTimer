import Foundation
import AppKit

func clockText(_ interval: TimeInterval) -> String {
    let s = max(0, Int(interval.rounded()))
    if s >= 3600 {
        return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
    return String(format: "%02d:%02d", s / 60, s % 60)
}

/// 计时状态机：idle → work → rest → (自动或手动) → work …
final class TimerEngine: ObservableObject {
    enum Phase: String { case idle, work, rest }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var total: TimeInterval = 0
    @Published private(set) var isPaused = false
    @Published private(set) var todayCycles = 0
    /// 休息结束后等待用户选择是否开始下一轮（关闭自动开始时出现）。
    @Published private(set) var awaitingResumeChoice = false

    let settings: SettingsStore
    var onPhaseChanged: ((Phase) -> Void)?
    var onTick: (() -> Void)?
    /// 调试用：>1 时按倍数加速倒计时（`--self-test` 自测模式使用）。
    var debugSpeed: Double = 1

    private var endAt = Date()
    private var pausedRemaining: TimeInterval = 0
    private var ticker: Timer?
    private var warnedTenSeconds = false

    init(settings: SettingsStore) {
        self.settings = settings
        todayCycles = UserDefaults.standard.integer(forKey: Self.dayKey())
    }

    var statusTitle: String {
        switch phase {
        case .idle: return "🍅"
        case .work: return (isPaused ? "⏸ " : "🍅 ") + clockText(remaining)
        case .rest: return (isPaused ? "⏸ " : "☕️ ") + clockText(remaining)
        }
    }

    var statusDetail: String {
        switch phase {
        case .idle:
            return "未开始 · 工作 \(settings.workMinutes) 分 / 休息 \(settings.breakMinutes) 分"
        case .work:
            return "工作中 · 剩余 \(clockText(remaining))\(isPaused ? "（已暂停）" : "")"
        case .rest:
            return "休息中 · 剩余 \(clockText(remaining))\(isPaused ? "（已暂停）" : "")"
        }
    }

    // MARK: - 对外操作

    func startWork() {
        awaitingResumeChoice = false
        begin(.work, duration: Double(settings.workMinutes) * 60)
    }

    func startRest() {
        awaitingResumeChoice = false
        begin(.rest, duration: Double(settings.breakMinutes) * 60)
    }

    func togglePause() {
        guard phase != .idle else { return }
        if isPaused {
            endAt = Date().addingTimeInterval(pausedRemaining)
            isPaused = false
            remaining = max(0, endAt.timeIntervalSinceNow)
        } else {
            pausedRemaining = remaining
            isPaused = true
        }
        onTick?()
    }

    func skip() {
        switch phase {
        case .work: finishWork(counted: false)
        case .rest: finishRest()
        case .idle: startWork()
        }
    }

    func finishRestEarly() { finishRest() }

    func extendCurrent(byMinutes minutes: Int) {
        guard phase != .idle else { return }
        let delta = Double(minutes) * 60
        if isPaused {
            pausedRemaining += delta
            remaining = pausedRemaining
        } else {
            endAt.addTimeInterval(delta)
            remaining = max(0, endAt.timeIntervalSinceNow)
        }
        total += delta
        onTick?()
    }

    func dismissChoice() { awaitingResumeChoice = false }

    func stopAll() {
        stopTicker()
        phase = .idle
        remaining = 0
        total = 0
        isPaused = false
        awaitingResumeChoice = false
        onPhaseChanged?(.idle)
        onTick?()
    }

    // MARK: - 内部流转

    private func begin(_ newPhase: Phase, duration: TimeInterval) {
        let scaled = duration / debugSpeed
        phase = newPhase
        total = max(1, scaled)
        remaining = scaled
        endAt = Date().addingTimeInterval(scaled)
        isPaused = false
        warnedTenSeconds = false
        startTicker()
        onPhaseChanged?(newPhase)
        onTick?()
    }

    private func finishWork(counted: Bool) {
        stopTicker()
        if counted { recordCycle() }
        chime("Glass")
        startRest()
    }

    private func finishRest() {
        stopTicker()
        chime("Purr")
        if settings.autoStartNext {
            startWork()
        } else {
            phase = .idle
            remaining = 0
            total = 0
            isPaused = false
            awaitingResumeChoice = true
            onPhaseChanged?(.idle)
            onTick?()
        }
    }

    /// 基于“结束时间点”倒推剩余，系统休眠唤醒后自动纠正。
    private func startTicker() {
        stopTicker()
        // Timer 已调度到主线程 RunLoop，闭包直接在主线程执行，无需再派发。
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard phase != .idle, !isPaused else { return }
        remaining = max(0, endAt.timeIntervalSinceNow)
        if settings.warnBeforeBreak, phase == .work, !warnedTenSeconds, remaining > 0, remaining <= 10 {
            warnedTenSeconds = true
            chime("Tink")
        }
        if remaining <= 0 {
            switch phase {
            case .work: finishWork(counted: true)
            case .rest: finishRest()
            case .idle: break
            }
            return
        }
        onTick?()
    }

    private func chime(_ name: String) {
        guard settings.soundOn else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }

    private func recordCycle() {
        todayCycles += 1
        UserDefaults.standard.set(todayCycles, forKey: Self.dayKey())
    }

    private static func dayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "cycles-\(formatter.string(from: Date()))"
    }
}
