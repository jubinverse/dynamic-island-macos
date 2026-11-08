import AppKit
import SwiftUI

final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: CGRect(x: 0, y: 0, width: 420, height: 360),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Dynamic Island Settings"
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: SettingsView(settings: .shared))
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                if let error = settings.launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Closed island") {
                Toggle("Show music while playing", isOn: $settings.showMediaActivity)
                Toggle("Charging animation", isOn: $settings.showChargingAnimation)
                Toggle("AirPods connected", isOn: $settings.showAirPods)
            }

            Section("Notifications") {
                Toggle("Show notifications and calls in the island", isOn: $settings.showNotifications)
                Text("Needs Full Disk Access for DynamicIsland (System Settings → Privacy & Security). To avoid seeing each notification twice, set an app's alert style to None in System Settings → Notifications.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Open Full Disk Access Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            Section("Pages") {
                Toggle("Calendar", isOn: $settings.showCalendarPage)
                Toggle("File shelf", isOn: $settings.showShelfPage)
                Text("Swipe left or right with two fingers on the open island to switch pages.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quit Dynamic Island")
                        Text("Closes the island until you open the app again.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Quit", role: .destructive) {
                        NSApp.terminate(nil)
                    }
                    .keyboardShortcut("q", modifiers: .command)
                }
            } footer: {
                CreditFooter()
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Small centred credit line; "@jubinverse" opens the project on GitHub.
private struct CreditFooter: View {
    private static let repoURL = URL(string: "https://github.com/jubinverse/dynamic-island-macos")!
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 3) {
            Text("Designed and Developed by")
                .foregroundStyle(.tertiary)
            Link("@jubinverse", destination: Self.repoURL)
                .foregroundStyle(hovering ? Color.accentColor : Color.secondary)
                .underline(hovering)
                .onHover { hovering = $0 }
                .help(Self.repoURL.absoluteString)
        }
        .font(.system(size: 10))
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }
}
