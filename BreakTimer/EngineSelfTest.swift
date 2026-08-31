import AppKit

/// `--self-test`：无头验证计时引擎的关键流转，通过 exit code 报告结果。
enum EngineSelfTest {
    static func runAndExit() -> Never {
        NSApp.setActivationPolicy(.prohibited)
        var failures: [String] = []

        func check(_ condition: Bool, _ name: String) {
            print(condition ? "  ✓ \(name)" : "  ✗ \(name)")
            if !condition { failures.append(name) }
        }

        func pump(_ seconds: Double) {
            let deadline = Date().addingTimeInterval(seconds)
            while Date() < deadline {
                RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
            }
        }

        print("BreakTimer 引擎自测:")
        // 清掉今日轮数，保证自测可重复（不影响其他设置）
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        UserDefaults.standard.removeObject(forKey: "cycles-\(formatter.string(from: Date()))")

        let settings = SettingsStore()
        let engine = TimerEngine(settings: settings)
        settings.workMinutes = 1
        settings.breakMinutes = 1
        settings.autoStartNext = true
        settings.warnBeforeBreak = false
        settings.soundOn = false
        engine.debugSpeed = 60 // 1 分钟 → 1 秒

        // work 基础流转
        engine.startWork()
        check(engine.phase == .work, "开始工作 → 进入 work")
        check(engine.todayCycles == 0, "初始今日轮数为 0")

        // 暂停/继续
        engine.togglePause()
        check(engine.isPaused, "暂停生效")
        let frozen = engine.remaining
        pump(0.3)
        check(abs(engine.remaining - frozen) < 0.05, "暂停时倒计时冻结")
        engine.togglePause()
        check(!engine.isPaused, "继续生效")

        // 顺延
        let beforeExtend = engine.remaining
        engine.extendCurrent(byMinutes: 2)
        check(engine.remaining >= beforeExtend + 115, "顺延 2 分钟生效")

        // 跳过（不计数）
        engine.skip()
        check(engine.phase == .rest, "提前休息 → 进入 rest")
        check(engine.todayCycles == 0, "跳过不计数")

        // rest 自然结束（≈1s）→ 自动开始下一轮 work；2.6s 时 work（1s）尚未结束
        pump(1.6)
        check(engine.phase == .work, "休息结束自动开始下一轮 work")

        // work 自然结束 → 计一轮 → rest
        pump(1.0)
        check(engine.phase == .rest, "工作结束自动进入 rest")
        check(engine.todayCycles == 1, "完成一轮今日轮数 +1")

        // 停止
        engine.stopAll()
        check(engine.phase == .idle && !engine.isPaused, "停止 → idle")

        // 关闭自动开始：rest 结束后等待用户选择
        settings.autoStartNext = false
        engine.startRest()
        pump(1.6)
        check(engine.phase == .idle && engine.awaitingResumeChoice, "关闭自动开始时 rest 结束等待选择")
        engine.dismissChoice()
        check(!engine.awaitingResumeChoice, "dismissChoice 清除等待状态")

        if failures.isEmpty {
            print("全部通过 ✅")
            exit(0)
        } else {
            print("失败 \(failures.count) 项 ❌")
            exit(1)
        }
    }
}
