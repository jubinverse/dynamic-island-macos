import Combine
import Foundation
import IOBluetooth

struct AirPodsInfo: Equatable, Identifiable {
    enum Model { case airpods, airpodsPro, airpodsMax }

    let id = UUID()
    let name: String
    let model: Model
    var left: Int?
    var right: Int?
    var caseLevel: Int?
    var single: Int? // AirPods Max report one level

    var symbol: String {
        switch model {
        case .airpods: return "airpods"
        case .airpodsPro: return "airpodspro"
        case .airpodsMax: return "airpodsmax"
        }
    }

    var caseSymbol: String {
        model == .airpodsPro ? "airpodspro.chargingcase.wireless.fill" : "airpods.chargingcase.fill"
    }

    /// The lower of the two buds (what you'll run out of first), or the single level.
    var headlineLevel: Int? {
        switch (left, right) {
        case let (l?, r?): return min(l, r)
        case let (l?, nil): return l
        case let (nil, r?): return r
        default: return single
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

/// Announces when AirPods connect, with battery levels for each bud and the case.
///
/// Connection events come from IOBluetooth. Battery levels aren't in a public API, so
/// they're read from `system_profiler SPBluetoothDataType`, which reports them for AirPods.
final class BluetoothMonitor: NSObject {
    let airPodsConnected = PassthroughSubject<AirPodsInfo, Never>()

    private var connectNotification: IOBluetoothUserNotification?
    private let launchDate = Date()
    private let queue = DispatchQueue(label: "DynamicIsland.bluetooth", qos: .utility)

    override init() {
        super.init()
        // Using Bluetooth without a usage description in Info.plist crashes the app,
        // which is what happens when it's run as a bare executable from Xcode.
        guard Bundle.main.object(forInfoDictionaryKey: "NSBluetoothAlwaysUsageDescription") != nil else {
            NSLog("DynamicIsland: Bluetooth disabled (no usage description; run the built app)")
            return
        }
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceConnected(_:device:))
        )
    }

    deinit {
        connectNotification?.unregister()
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        // Registration also reports devices that were already connected at launch; skip those.
        guard Date().timeIntervalSince(launchDate) > 3,
              let name = device.name,
              let model = Self.model(for: name)
        else { return }
        fetchBattery(name: name, model: model, attempt: 0)
    }

    /// Battery levels take a moment to appear after connecting, so retry briefly.
    private func fetchBattery(name: String, model: AirPodsInfo.Model, attempt: Int) {
        queue.asyncAfter(deadline: .now() + (attempt == 0 ? 1.0 : 1.2)) { [weak self] in
            guard let self else { return }
            var info = AirPodsInfo(name: name, model: model)
            if let levels = Self.batteryLevels(forDeviceNamed: name) {
                info.left = levels["device_batteryLevelLeft"]
                info.right = levels["device_batteryLevelRight"]
                info.caseLevel = levels["device_batteryLevelCase"]
                info.single = levels["device_batteryLevelMain"]
            }
            if info.headlineLevel == nil, attempt < 3 {
                self.fetchBattery(name: name, model: model, attempt: attempt + 1)
                return
            }
            DispatchQueue.main.async { self.airPodsConnected.send(info) }
        }
    }

    private static func model(for name: String) -> AirPodsInfo.Model? {
        let lower = name.lowercased()
        guard lower.contains("airpods") else { return nil }
        if lower.contains("max") { return .airpodsMax }
        if lower.contains("pro") { return .airpodsPro }
        return .airpods
    }

    /// Reads `system_profiler` and returns the battery fields for the connected device.
    private static func batteryLevels(forDeviceNamed name: String) -> [String: Int]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sections = root["SPBluetoothDataType"] as? [[String: Any]],
              let connected = sections.first?["device_connected"] as? [[String: Any]]
        else { return nil }

        for entry in connected {
            guard let fields = entry[name] as? [String: Any] else { continue }
            var levels: [String: Int] = [:]
            for (key, value) in fields where key.hasPrefix("device_batteryLevel") {
                if let text = value as? String,
                   let number = Int(text.trimmingCharacters(in: CharacterSet(charactersIn: "% "))) {
                    levels[key] = number
                }
            }
            return levels
        }
        return nil
    }
}
