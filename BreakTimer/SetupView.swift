import SwiftUI

/// 主设置/控制窗口。
struct SetupView: View {
    @ObservedObject var engine: TimerEngine
    @ObservedObject var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            rhythmSection
            Divider()
            togglesSection
            Divider()
            controlSection
            Spacer(minLength: 0)
            hint
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: 头部

    private var header: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [.teal, .indigo],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 44, height: 44)
                .overlay(Text("🍅").font(.system(size: 24)))
            VStack(alignment: .leading, spacing: 2) {
                Text("BreakTimer").font(.title3.bold())
                Text("工作 · 休息循环提醒").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(engine.statusTitle)
                .font(.system(.title3, design: .rounded).monospacedDigit().weight(.semibold))
                .foregroundStyle(engine.phase == .rest ? Color.teal : Color.primary)
        }
    }

    // MARK: 节奏

    private var workBinding: Binding<Double> {
        Binding(get: { Double(settings.workMinutes) },
                set: { settings.workMinutes = Int($0.rounded()) })
    }

    private var breakBinding: Binding<Double> {
        Binding(get: { Double(settings.breakMinutes) },
                set: { settings.breakMinutes = Int($0.rounded()) })
    }

    private var rhythmSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("节奏").font(.headline)
            sliderRow("工作时长", value: workBinding, range: 5...120, step: 5)
            sliderRow("休息时长", value: breakBinding, range: 1...30, step: 1)
        }
    }

    private func sliderRow(_ title: String,
                           value: Binding<Double>,
                           range: ClosedRange<Double>,
                           step: Double) -> some View {
        HStack(spacing: 12) {
            Text(title).frame(width: 64, alignment: .leading)
            TimeSlider(value: value, range: range, step: step)
            Text("\(Int(value.wrappedValue.rounded())) 分钟")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)
        }
    }

    // MARK: 提醒选项

    private var togglesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("提醒").font(.headline)
            HStack(spacing: 12) {
                Text("蒙版深浅").frame(width: 64, alignment: .leading)
                TimeSlider(value: $settings.veilOpacity, range: 0.1...1.0, step: 0.05, tint: .gray)
                Text("\(Int(settings.veilOpacity * 100))%")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 72, alignment: .trailing)
            }
            Text("休息时屏幕灰纱的深浅：越浅越能看清屏幕内容（背后亮色窗口处会有明暗差），越深颜色越均匀。休息时打开本窗口可实时预览。")
                .font(.caption2)
                .foregroundStyle(.secondary)
            toggleRow("启动后自动开始第一轮工作", isOn: $settings.autoStartOnLaunch)
            toggleRow("休息结束自动开始下一轮工作", isOn: $settings.autoStartNext)
            toggleRow("工作结束前 10 秒轻提示音", isOn: $settings.warnBeforeBreak)
            toggleRow("播放提示音效", isOn: $settings.soundOn)
            toggleRow("登录时自动启动", isOn: $settings.launchAtLogin,
                      enabled: SettingsStore.isBundled)
            if !SettingsStore.isBundled {
                Text("「登录时自动启动」需要以 .app 应用包方式运行才可用（运行 makeapp.sh 打包）")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>, enabled: Bool = true) -> some View {
        HStack {
            Text(title).foregroundStyle(enabled ? Color.primary : Color.secondary)
            Spacer()
            SwitchToggle(isOn: isOn, isEnabled: enabled)
        }
    }

    // MARK: 控制

    @ViewBuilder
    private var controlSection: some View {
        switch engine.phase {
        case .idle:
            HStack(spacing: 12) {
                Button {
                    engine.startWork()
                } label: {
                    Label("开始工作", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .controlSize(.large)

                Button {
                    engine.startRest()
                } label: {
                    Label("立即休息", systemImage: "cup.and.saucer.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("今日 \(engine.todayCycles) 轮").font(.footnote).foregroundStyle(.secondary)
                    Text("\(settings.workMinutes) / \(settings.breakMinutes) 分钟").font(.caption2).foregroundStyle(.tertiary)
                }
            }
        case .work, .rest:
            VStack(spacing: 12) {
                HStack {
                    Text(engine.phase == .work ? "工作中" : "休息中")
                        .font(.headline)
                        .foregroundStyle(engine.phase == .rest ? Color.teal : Color.primary)
                    Spacer()
                    Text(clockText(engine.remaining))
                        .font(.system(.title2, design: .rounded).monospacedDigit().bold())
                }
                HStack {
                    Button(engine.isPaused ? "继续" : "暂停") { engine.togglePause() }
                        .buttonStyle(.bordered)
                    Button(engine.phase == .work ? "提前休息" : "跳过休息") { engine.skip() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("结束") { engine.stopAll() }
                        .buttonStyle(.bordered)
                        .tint(.red)
                }
            }
            .padding(14)
            .background(.quaternary.opacity(0.4),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var hint: some View {
        Text("提示：关闭窗口后应用仍在菜单栏运行（🍅 图标）。工作结束后会弹出柔和的全屏提醒，按 Esc 或点「完成休息」即可关闭。")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
