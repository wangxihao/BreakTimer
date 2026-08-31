import SwiftUI

@main
struct BreakTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SetupView(engine: AppModel.shared.engine, settings: AppModel.shared.settings)
        }
    }
}

/// 应用内共享模型：设置 + 计时引擎，全部窗口共用同一份。
final class AppModel {
    static let shared = AppModel()
    let settings = SettingsStore()
    lazy var engine = TimerEngine(settings: settings)
    private init() {}
}
