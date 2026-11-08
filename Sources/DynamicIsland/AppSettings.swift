import Foundation
import ServiceManagement

/// User preferences, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var showMediaActivity: Bool { didSet { save(showMediaActivity, "showMediaActivity") } }
    @Published var showChargingAnimation: Bool { didSet { save(showChargingAnimation, "showChargingAnimation") } }
    @Published var showCalendarPage: Bool { didSet { save(showCalendarPage, "showCalendarPage") } }
    @Published var showShelfPage: Bool { didSet { save(showShelfPage, "showShelfPage") } }
    @Published var showNotifications: Bool { didSet { save(showNotifications, "showNotifications") } }
    @Published var showAirPods: Bool { didSet { save(showAirPods, "showAirPods") } }

    @Published private(set) var launchAtLogin: Bool
    @Published private(set) var launchAtLoginError: String?

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            "showMediaActivity": true,
            "showChargingAnimation": true,
            "showCalendarPage": true,
            "showShelfPage": true,
            "showNotifications": true,
            "showAirPods": true,
        ])
        showNotifications = defaults.bool(forKey: "showNotifications")
        showAirPods = defaults.bool(forKey: "showAirPods")
        showMediaActivity = defaults.bool(forKey: "showMediaActivity")
        showChargingAnimation = defaults.bool(forKey: "showChargingAnimation")
        showCalendarPage = defaults.bool(forKey: "showCalendarPage")
        showShelfPage = defaults.bool(forKey: "showShelfPage")
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            launchAtLoginError = "Only available when running the built app (./build.sh), not from Xcode."
            return
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
        if SMAppService.mainApp.status == .requiresApproval {
            launchAtLoginError = "Approve Dynamic Island in System Settings → General → Login Items."
        }
    }

    private func save(_ value: Bool, _ key: String) {
        defaults.set(value, forKey: key)
    }
}
