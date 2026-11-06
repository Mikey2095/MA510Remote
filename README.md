# MA510 Remote — native iPhone app

A SwiftUI remote for the JBL MA510 that matches the Remote Studio design (pearl silver, brushed aluminum, black glass). It connects **directly** to the receiver over your home Wi-Fi using JBL's published IP control protocol on TCP port 50000. You don't need a computer, bridge or cloud account.

## Install on your iPhone (about 10 minutes)

1. **Install Xcode** (16 or newer) from the Mac App Store.
2. Unzip this folder and double-click **`MA510Remote.xcodeproj`**.
3. Choose the blue **MA510Remote** project in the left sidebar, then the **MA510Remote** target, then **Signing & Capabilities**:
   - **Team:** select your Apple ID. You can add it with *Add an Account…*; a free Apple ID works.
   - **Bundle Identifier:** if Xcode reports a conflict, change `com.mikeytorres.MA510Remote` to something unique.
4. Plug in your iPhone, or use the same Wi-Fi with wireless debugging. Pick the iPhone in the device menu at the top of the window.
5. On the iPhone, turn on **Settings › Privacy & Security › Developer Mode** (iOS asks once and restarts).
6. Press **⌘R** (Run). The first time, approve the developer profile on the iPhone under **Settings › General › VPN & Device Management**.

> **Free Apple ID vs. paid developer account:** with a free Apple ID, the app stops opening after **7 days**. Plug in your iPhone and press ⌘R again to renew it. A paid Apple Developer Program membership ($99/yr) gives you a one-year signature, and you can install through TestFlight.

## First connection

1. Make sure the MA510 is **on** and on your Wi-Fi or Ethernet. *Green* standby turns network control off, so wake the receiver with its power button first.
2. Open the app and tap the **DEMO MODE** chip at the top right, then **LIVE**.
3. Tap **FIND MY RECEIVER**. The app scans your network for anything answering on port 50000. You can also type the IP address from your router's device list.
   - The first time, iOS asks for **Local Network** access. Tap **Allow**, then scan again.
4. Tap **CONNECT TO RECEIVER**. The chip turns green (**LAN CONNECTED**).

The app saves the IP address and reconnects automatically every time you open it.

## What's live

| Control | Protocol |
|---|---|
| Power / standby | `0x00` |
| Volume (+/− hold to repeat, slider) | `0x06`, capped at your safety limit (default 65 of 99) |
| Mute | `0x07` |
| Inputs (quick keys, INPUT rocker, tap the source name for the full list) | `0x05` |
| Surround: All Stereo, Native, Stereo 2.0, ProLogic II, Stereo 2.1 | `0x08` |
| Nav pad, OK, BACK, MENU | `0x04` simulated IR |
| Bass / treble ±12 dB, Dialog enhancement, Room EQ, front display dim | `0x0C` `0x0B` `0x0E` `0x0D` `0x01` |
| Play / pause for network streams (Spotify, AirPlay, etc.) | `0x11` streaming state |

- **Two-way sync:** changes you make with the volume knob or the original remote show up in the app right away. Pull down on the screen, or tap **SYNC STATE**, to re-read everything.
- **FAV:** tap it to recall your saved input, mode and volume. Long-press it to save the current setup.
- **Track skip** has no command in JBL's IP protocol, so it only works in demo mode. Skip tracks in your music app.
- The **speaker map** shows expected routing for the current mode. It is not a speaker test.

## App icon

Open `MA510Remote/Assets.xcassets › AppIcon` in Xcode and drag in a **1024 × 1024 PNG** with no transparency and no rounded corners (iOS adds the corners). The Dark and Tinted slots are optional. Then run ⌘R again.

## Tests

Press **⌘U** to run the protocol tests. They check the byte encoding and parsing against the examples in JBL's spec.

## Troubleshooting

- **"Connection refused" or no answer:** the receiver is probably in Green standby or on a different network. Wake it and confirm its IP address.
- **Scan finds nothing:** check that Local Network access is on in **Settings › MA510 Remote**, and that the iPhone isn't on a guest Wi-Fi network.
- **An HDMI input is mislabeled:** in the protocol, TV (ARC) is code 1 and HDMI 1 to 4 are codes 2 to 5. If a label doesn't match the back panel, tell me which input is which and I'll remap it.

## Files

```
MA510Remote/
  MA510RemoteApp.swift          app entry, reconnects on foreground
  Protocol/MAProtocol.swift     packet encode/parse + MA510 code tables
  Network/ReceiverConnection.swift  persistent TCP session (handshake, keepalive, live updates)
  Network/NetworkScanner.swift  finds receivers on your Wi-Fi subnet
  Model/RemoteStore.swift       state + every action (demo and live)
  Views/                        RemoteView, ControlPanel, ConnectionSheet, ContentView, Theme
MA510RemoteTests/               protocol unit tests
```

Personal-use remote. Not affiliated with JBL or HARMAN. Protocol reference: *JBL MA-Series IP Control v1.7*.
