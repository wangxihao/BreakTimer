import SwiftUI

/// 休息提醒浮层内容：柔和暗色蒙版 + 毛玻璃卡片，Esc 可关闭。
struct BreakOverlayView: View {
    @ObservedObject var engine: TimerEngine
    @ObservedObject var settings: SettingsStore
    var onClose: () -> Void

    private var progress: Double {
        guard engine.total > 0 else { return 0 }
        return min(1, max(0, engine.remaining / engine.total))
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [
                Color(red: 0.05, green: 0.07, blue: 0.13).opacity(0.52),
                Color(red: 0.07, green: 0.10, blue: 0.17).opacity(0.44),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()

            Group {
                if engine.phase == .rest {
                    restCard
                } else {
                    resumeCard
                }
            }
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.25), value: engine.phase)
        .onExitCommand { onClose() }
    }

    // MARK: 休息倒计时卡片

    private var restCard: some View {
        VStack(spacing: 24) {
            Text("☕️")
                .font(.system(size: 60))
            VStack(spacing: 6) {
                Text("休息一下")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text("离开屏幕 · 远眺放松 · 活动肩颈")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Text(clockText(engine.remaining))
                .font(.system(size: 84, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.teal)
                .frame(minWidth: 300)
            progressBar
                .frame(width: 280, height: 6)
            HStack(spacing: 12) {
                Button {
                    engine.extendCurrent(byMinutes: 2)
                } label: {
                    Label("多歇 2 分", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)

                Button {
                    engine.togglePause()
                } label: {
                    Label(engine.isPaused ? "继续" : "暂停",
                          systemImage: engine.isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.bordered)

                Button {
                    onClose()
                } label: {
                    Label("完成休息", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            Text("今日已完成 \(engine.todayCycles) 轮 · 下一轮工作 \(settings.workMinutes) 分钟")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(44)
        .background(cardBackground)
    }

    // MARK: 休息结束 / 等待开始下一轮卡片

    private var resumeCard: some View {
        VStack(spacing: 22) {
            Text("🌿")
                .font(.system(size: 60))
            Text("休息结束")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
            Text("准备好就开始下一轮工作吧")
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button {
                    engine.startWork()
                } label: {
                    Label("开始工作", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .keyboardShortcut(.defaultAction)

                Button {
                    engine.startRest()
                    engine.extendCurrent(byMinutes: 2)
                } label: {
                    Text("再歇 2 分钟")
                }
                .buttonStyle(.bordered)

                Button("关闭") { onClose() }
                    .buttonStyle(.bordered)
            }
            .controlSize(.large)
            Text("按 Esc 或「关闭」收起提示 · 计时可在菜单栏 🍅 控制")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(44)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(Color(white: 0.97).opacity(0.88))
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: .black.opacity(0.30), radius: 36, y: 16)
    }

    /// 自绘进度条（离屏渲染友好）。
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.teal.opacity(0.18))
                Capsule().fill(Color.teal.gradient)
                    .frame(width: max(6, geo.size.width * progress))
            }
        }
    }
}
