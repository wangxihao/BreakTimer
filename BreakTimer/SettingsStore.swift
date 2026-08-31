import Foundation
import ServiceManagement

final class SettingsStore: ObservableObject {
    @Published var workMinutes: Int {
        didSet { UserDefaults.standard.set(workMinutes, forKey: "workMinutes") }
    }
    @Published var breakMinutes: Int {
        didSet { UserDefaults.standard.set(breakMinutes, forKey: "breakMinutes") }
    }
    @Published var autoStartNext: Bool {
        didSet { UserDefaults.standard.set(autoStartNext, forKey: "autoStartNext") }
    }
    @Published var warnBeforeBreak: Bool {
        didSet { UserDefaults.standard.set(warnBeforeBreak, forKey: "warnBeforeBreak") }
    }
    @Published var soundOn: Bool {
        didSet { UserDefaults.standard.set(soundOn, forKey: "soundOn") }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            guard Self.isBundled else {
                if launchAtLogin { launchAtLogin = false }
                return
            }
            let service = SMAppService.mainApp
            if launchAtLogin, service.status != .enabled { try? service.register() }
            if !launchAtLogin, service.status == .enabled { try? service.unregister() }
        }
    }
    @Published var autoStartOnLaunch: Bool {
        didSet { UserDefaults.standard.set(autoStartOnLaunch, forKey: "autoStartOnLaunch") }
    }

    /// 只有打包成 .app 时登录启动项才可用。
    static let isBundled = Bundle.main.bundleURL.pathExtension == "app"

    init() {
        let d = UserDefaults.standard
        workMinutes = (d.object(forKey: "workMinutes") as? Int) ?? 25
        breakMinutes = (d.object(forKey: "breakMinutes") as? Int) ?? 5
        autoStartNext = (d.object(forKey: "autoStartNext") as? Bool) ?? true
        warnBeforeBreak = (d.object(forKey: "warnBeforeBreak") as? Bool) ?? true
        soundOn = (d.object(forKey: "soundOn") as? Bool) ?? true
        launchAtLogin = Self.isBundled && SMAppService.mainApp.status == .enabled
        autoStartOnLaunch = (d.object(forKey: "autoStartOnLaunch") as? Bool) ?? true
    }
}
