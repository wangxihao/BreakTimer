import AppKit
import SwiftUI

/// `--render-marketing <目录>`：离屏渲染公众号图文素材（真实 UI 视图 → PNG）。
@MainActor
enum MarketingRenderer {
    static func runAndExit(_ outDir: String) -> Never {
        NSApp.setActivationPolicy(.prohibited)
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

        // 固定“今日轮数”示意值，保证出图稳定
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        UserDefaults.standard.set(3, forKey: "cycles-\(formatter.string(from: Date()))")

        let settings = SettingsStore()
        settings.workMinutes = 25
        settings.breakMinutes = 5
        settings.autoStartOnLaunch = true
        settings.autoStartNext = true
        settings.warnBeforeBreak = true
        settings.soundOn = true
        let engine = TimerEngine(settings: settings)

        // 1. 封面 2.35:1
        render(coverView, size: CGSize(width: 1170, height: 498), scale: 2,
               to: "\(outDir)/1-封面.png")

        // 2. 设置窗口（仿窗口外观）
        render(fakeWindow { SetupView(engine: engine, settings: settings).frame(width: 440, height: 620) },
               size: CGSize(width: 560, height: 760), scale: 2,
               to: "\(outDir)/2-设置窗口.png")

        // 3. 休息提醒浮层：debugSpeed 调节使初始剩余恰为 4:37
        settings.breakMinutes = 5
        engine.debugSpeed = 300.0 / 277.0
        engine.startRest()
        render(overlayWrapper(BreakOverlayView(engine: engine, settings: settings, onClose: {})),
               size: CGSize(width: 1600, height: 1000), scale: 1,
               to: "\(outDir)/3-休息提醒.png")

        // 4. 休息结束卡片（idle 引擎 → resumeCard）
        let idleEngine = TimerEngine(settings: settings)
        render(overlayWrapper(BreakOverlayView(engine: idleEngine, settings: settings, onClose: {})),
               size: CGSize(width: 1600, height: 1000), scale: 1,
               to: "\(outDir)/4-休息结束.png")

        // 5. 开发流程图
        render(flowView, size: CGSize(width: 1500, height: 540), scale: 2,
               to: "\(outDir)/5-开发流程.png")

        // 6. 付费墙对比图
        render(compareView, size: CGSize(width: 1400, height: 860), scale: 2,
               to: "\(outDir)/6-对比.png")

        print("marketing render done -> \(outDir)")
        exit(0)
    }

    // MARK: - 视图

    private static var coverView: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.10, green: 0.55, blue: 0.50),
                                    Color(red: 0.27, green: 0.33, blue: 0.72)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Mac 上没有免费好用的番茄钟？")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("我花了一个晚上，让 AI 给我手搓了一个")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.94))
                    Text("自定义时长 · 全屏柔和提醒 · 菜单栏常驻 · 开源")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                }
                Spacer()
                Text("🍅")
                    .font(.system(size: 150))
                    .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
            }
            .padding(.horizontal, 64)
        }
        .frame(width: 1170, height: 498)
    }

    private static func fakeWindow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color(white: 0.90)
            VStack(spacing: 0) {
                ZStack {
                    Color(white: 0.96)
                    HStack(spacing: 8) {
                        Circle().fill(Color(red: 1.0, green: 0.39, blue: 0.38)).frame(width: 12, height: 12)
                        Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 12, height: 12)
                        Circle().fill(Color(red: 0.20, green: 0.78, blue: 0.35)).frame(width: 12, height: 12)
                        Spacer()
                        Text("BreakTimer").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                        Spacer()
                        Color.clear.frame(width: 60, height: 12)
                    }
                    .padding(.horizontal, 14)
                }
                .frame(height: 34)
                content()
            }
            .frame(width: 480, height: 690)
            .background(Color(white: 0.98))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 24, y: 14)
        }
        .frame(width: 560, height: 760)
    }

    private static func overlayWrapper(_ content: some View) -> some View {
        content.frame(width: 1600, height: 1000)
    }

    private static var flowView: some View {
        VStack(spacing: 28) {
            Text("一个晚上，AI 编码的完整闭环")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            HStack(spacing: 14) {
                step("🗣️", "提需求", "工作/休息时长\n自定义，到点提醒")
                arrow
                step("🤖", "AI 写码", "SwiftUI + AppKit\n一次构建通过")
                arrow
                step("🔍", "我验收", "窗口尺寸异常\n当场发现")
                arrow
                step("🧪", "自测抓虫", "14 项引擎自测\n揪出真实并发坑")
                arrow
                step("📦", "端到端验证", "无人值守跑通\n弹窗→关闭→计数")
            }
        }
        .frame(width: 1500, height: 540)
        .background(Color(white: 0.96))
    }

    private static var arrow: some View {
        Text("→").font(.system(size: 30, weight: .bold)).foregroundStyle(.secondary)
    }

    private static func step(_ emoji: String, _ title: String, _ detail: String) -> some View {
        VStack(spacing: 10) {
            Text(emoji).font(.system(size: 44))
            Text(title).font(.system(size: 22, weight: .bold, design: .rounded))
            Text(detail)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(22)
        .frame(width: 246, height: 240)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
    }

    private static var compareView: some View {
        VStack(spacing: 26) {
            Text("同样是“工作 45 休息 15”，差别在哪")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            HStack(spacing: 28) {
                compareColumn("应用商店的免费版", color: .gray, rows: [
                    ("自定义工作时长", "🔒 付费解锁"),
                    ("自定义休息时长", "🔒 付费解锁"),
                    ("提醒界面", "系统弹窗"),
                    ("全屏应用之上提醒", "❌ 做不到"),
                    ("源代码", "❌ 闭源"),
                ])
                compareColumn("我手搓的 BreakTimer", color: Color(red: 0.13, green: 0.55, blue: 0.62), rows: [
                    ("自定义工作时长", "✅ 5–120 分钟免费调"),
                    ("自定义休息时长", "✅ 1–30 分钟免费调"),
                    ("提醒界面", "✅ 全屏毛玻璃柔和卡片"),
                    ("全屏应用之上提醒", "✅ 不抢焦点盖在全屏上"),
                    ("源代码", "✅ 开源，想改就改"),
                ])
            }
            Text("不是它做得不好，是“自定义时长”刚好被划进了付费墙。")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(width: 1400, height: 700)
        .background(Color(white: 0.96))
    }

    private static func compareColumn(_ title: String, color: Color, rows: [(String, String)]) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.0).font(.system(size: 17, weight: .medium))
                    Spacer()
                    Text(row.1).font(.system(size: 17, weight: .semibold))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                Divider()
            }
        }
        .frame(width: 600)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
    }

    // MARK: - 渲染

    private static func render<V: View>(_ view: V, size: CGSize, scale: CGFloat, to path: String) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(size)
        guard let cgImage = renderer.cgImage else {
            FileHandle.standardError.write(Data("render 失败: \(path)\n".utf8))
            exit(1)
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
        try? png.write(to: URL(fileURLWithPath: path))
        print("rendered \(path) (\(cgImage.width)x\(cgImage.height))")
    }
}
