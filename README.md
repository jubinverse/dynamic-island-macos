# Dynamic Island for macOS

A Dynamic Island–style overlay for MacBooks with a notch, written in Swift and SwiftUI.
On Macs without a notch, it draws a pill at the top of the screen instead.

## Features

- **Hover to expand.** The notch springs open when the pointer reaches it.
- **Now Playing:** artwork, title, progress and controls for Music, Spotify, browsers and
  anything else that reports to macOS's Now Playing. While something plays, the closed notch
  shows the artwork and a waveform on either side.
- **Notifications:** banners for WhatsApp, Slack, Claude, ChatGPT and any other app, including
  website notifications (for example, Slack in Chrome shows as "Slack"). Incoming calls get a
  pulsing call banner, and a page lists recent notifications. Requires **Full Disk Access**,
  because the app reads Notification Center's database.
- **AirPods:** when AirPods connect, a banner shows the model, name and battery for the left bud,
  right bud and case.
- **Charging animation** when the charger is plugged in.
- **Calendar:** your next events, with a **Join** button for Zoom, Meet, Teams, Webex and
  FaceTime links.
- **File shelf.** Drop files on the notch to keep them handy, and drag them back out later.
- **Pages:** switch with the tabs or a two-finger horizontal swipe.
- **Settings** (⌘, from the menu-bar icon): launch at login and on/off switches for each feature.

## Build and run

Requires macOS 14+ and Xcode.

```bash
./build.sh --run
```

This builds `build/DynamicIsland.app`. You can also open `Package.swift` in Xcode and run the
**DynamicIsland** scheme. Calendar, Bluetooth, notifications and launch at login only work in the
app built by `build.sh`, because they need the app's `Info.plist` and their own permissions.

**Permissions:** give `build/DynamicIsland.app` Full Disk Access (System Settings → Privacy &
Security) for notifications, and allow Bluetooth when asked. Without an Apple Development
certificate, the app is signed ad hoc, so macOS treats every rebuild as a new app and Full Disk
Access must be re-enabled. Add your Apple ID in Xcode → Settings → Accounts, and `build.sh` will
sign with that certificate automatically.

**DMG installer:** `./Scripts/make-dmg.sh` builds the app and packages it as
`build/DynamicIsland-<version>.dmg`. The version comes from `CFBundleShortVersionString` in
`Resources/Info.plist`. Users open the DMG and drag Dynamic Island into Applications. Without
Apple notarization, macOS warns on first launch; users allow it in System Settings → Privacy &
Security → **Open Anyway**.

**Snapshots:** `.build/release/DynamicIsland --snapshot <dir>` renders every island state to PNG
files using sample data. This is useful for checking layout without screen recording.

## How Now Playing works on macOS 15.4+

Since macOS 15.4, the system only gives now-playing information to Apple-signed processes.
The app runs `/usr/bin/perl` (which is Apple-signed) and loads a small helper library,
`Sources/NowPlayingHelper`, into it. The helper reads the private MediaRemote framework and
streams JSON lines back to the app. The app sends playback commands to the helper on its stdin.

## Project layout

| Path | Purpose |
|---|---|
| `Sources/DynamicIsland/NotchWindowController.swift` | Overlay window, mouse tracking, live activities |
| `Sources/DynamicIsland/NotchView.swift` | Island shell, top bar, closed-state wings |
| `Sources/DynamicIsland/IslandStyle.swift` | Shared type scale, spacing, buttons and message card |
| `Sources/DynamicIsland/MediaPage.swift` · `NotificationsPage.swift` · `CalendarPage.swift` · `ShelfPage.swift` | Pages |
| `Sources/DynamicIsland/AirPodsBanner.swift` | AirPods connect banner |
| `Sources/DynamicIsland/*Monitor.swift` · `ShelfStore.swift` | Data sources |
| `Sources/NowPlayingHelper/` | MediaRemote helper, loaded into perl |
| `build.sh` | Builds and packages the `.app` |

## License

[MIT](LICENSE) © 2026 Jubin V Jose ([@jubinverse](https://github.com/jubinverse)). Designed and
developed by @jubinverse.
