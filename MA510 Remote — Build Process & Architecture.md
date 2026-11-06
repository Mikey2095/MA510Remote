# MA510 Remote — Build Process & Architecture

Nov 5, 2026 · @Mikey

## Overview

MA510 Remote is a native SwiftUI iPhone app that controls a JBL MA510 AV receiver directly over home Wi-Fi, and it is now installed and running on Mikey's iPhone. It started as a web prototype (HTML/CSS/JS plus a Node bridge) and became a native app so the phone could talk to the receiver with no computer running.

- **Goal:** control the real receiver (power, volume, inputs, surround modes, tone) from a remote that matches the pearl silver, brushed aluminum, black glass design concept.
- **Outcome:** the app builds in Xcode, installs on the iPhone, and connects to the receiver over JBL's IP control protocol (TCP port 50000).
- **Key decision:** native SwiftUI over web + bridge, because a web page cannot open the raw TCP connection the receiver needs.
- **Trade-off accepted:** with a free Apple ID the app must be re-signed from Xcode every 7 days.

## Build process

The build ran in eight phases over two days. Each phase below lists what happened and what it decided.

1. **Review the web prototype (Nov 4).** The starting point was a web app (index.html, styles.css, app.js) plus a Node bridge (server.mjs, bridge.mjs, protocol.mjs). Its protocol codes matched JBL's official IP Control v1.7 spec.
2. **Choose the platform.** A browser cannot open raw TCP sockets, so three options were weighed: native iPhone app, web app + home bridge, or a wrapped web app. Native SwiftUI was chosen, built on an iPhone + Mac.
3. **Write the code.** The protocol layer, the persistent TCP connection, network scan, app state and all SwiftUI views were written, plus unit tests and an Xcode project file. The design screenshot was the visual reference.
4. **First Xcode attempt (Intel iMac, Nov 5).** The original web folder was opened by mistake. After the correct project was opened, Xcode crashed on every click. The likely cause is a known Xcode crash on Intel Macs running macOS 26.5+ (Code Signature Invalid). The 2020 Intel iMac was dropped for this work.
5. **Move to the laptop.** Xcode on the laptop opened the project normally.
6. **Signing.** A unique bundle identifier was set (com.mikeytorres.ma510remote.home). Signing then failed with "Your team has no devices" until the iPhone was connected and selected as the run destination.
7. **Fix compile errors.** Xcode flagged nested `self` captures in RemoteStore.swift; adding `[weak self]` fixed them. A later attempt at the live-only edits broke the build (an extra `}` plus notes typed outside comments), so the files were reverted to the last working version.
8. **Install and finish.** The app ran in the iPhone 17 Simulator, then on the real iPhone after trusting the developer profile. An app icon was added from three generated options.

## File architecture

The project has 11 Swift files in five folders, plus an asset catalog and a test target. Design changes happen in Views; Protocol and Network rarely need edits.

```
MA510Remote/
├── MA510Remote.xcodeproj        Xcode project: targets, signing, build settings
├── MA510Remote/                 the app
│   ├── MA510RemoteApp.swift     entry point
│   ├── Protocol/
│   │   └── MAProtocol.swift     bytes the receiver understands
│   ├── Network/
│   │   ├── ReceiverConnection.swift   live TCP link
│   │   └── NetworkScanner.swift       finds the receiver
│   ├── Model/
│   │   └── RemoteStore.swift    app state + every action
│   ├── Views/
│   │   ├── ContentView.swift    page layout, top bar, toasts
│   │   ├── RemoteView.swift     the handset
│   │   ├── ControlPanel.swift   the cards beside the handset
│   │   ├── ConnectionSheet.swift  connect + preferences
│   │   └── Theme.swift          colors, gradients, shared styles
│   └── Assets.xcassets          AppIcon, AccentColor
├── MA510RemoteTests/
│   └── MAProtocolTests.swift    byte-level protocol tests
└── README.md                    setup guide
```

| File | Layer | What it does | Edit it when |
| --- | --- | --- | --- |
| MA510RemoteApp.swift | App | Launches the app, creates the shared RemoteStore, reconnects when the app returns to the foreground and disconnects in the background | Rarely |
| MAProtocol.swift | Protocol | Encodes commands into JBL packets, parses replies, holds the MA510 code tables (inputs, surround modes, remote keys, streaming services) | JBL changes the protocol or an input label is wrong |
| ReceiverConnection.swift | Network | Keeps one TCP connection open: handshake (0x50), keepalive every 15 s, streams every reply back, drops and reports when the receiver goes quiet | Connection behavior changes |
| NetworkScanner.swift | Network | Reads the phone's Wi-Fi subnet and probes every address on port 50000 to find receivers; validates private IP addresses | Discovery changes |
| RemoteStore.swift | Model | The app's brain: receiver state, saved settings, demo vs live, every action (power, volume, input, mode, tone, favorite), auto-reconnect, toasts | Adding a feature or changing behavior |
| ContentView.swift | Views | Page layout (stacked on iPhone, two columns on iPad), top bar and status chip, toast overlay, opens the connection sheet | Layout changes |
| RemoteView.swift | Views | The handset: glass display, visualizer, nav pad, function keys, volume and input rockers, mute, media row, footer shortcuts | Handset design changes |
| ControlPanel.swift | Views | Room header, sound field map, quick modes, master level slider, sound tuning, control log | Card design changes |
| ConnectionSheet.swift | Views | Demo/Live switch, IP field, Find My Receiver, connect/disconnect, volume limit, room name | Connection screen changes |
| Theme.swift | Views | Color palette, metal and glass gradients, press style, round keys, card style | Colors or shared styles change |
| Assets.xcassets | Resources | App icon (1024 px) and accent color | New icon |
| MAProtocolTests.swift | Tests | Checks command bytes and reply parsing against JBL's spec examples (run with Cmd+U) | After any protocol edit |

## Protocol reference

The app speaks JBL's MA-Series IP Control v1.7 over TCP port 50000, the same codes the web prototype used. Every message is a few bytes framed like this:

- **Phone to receiver:** `0x23` · command ID · data length · data · `0x0D`
- **Receiver to phone:** `0x02 0x23` · command ID · response code · data length · data · `0x0D`
- **Query:** send `0xF0` as the data to read a setting's current value.
- **Handshake:** send `0x50` with `0xF0` right after connecting; the receiver answers with its model (`0x01` = MA510).

| Command | ID | Data the app sends |
| --- | --- | --- |
| Power | 0x00 | 0x00 standby, 0x01 on |
| Display dim | 0x01 | 0 full, 1 50%, 2 25%, 3 off |
| Remote key (simulated IR) | 0x04 | 0x01 0x0E + key code (up, down, left, right, OK, menu, back) |
| Input | 0x05 | 0x01 TV (ARC), 0x02 to 0x05 HDMI 1 to 4, 0x08 Coax, 0x09 Optical, 0x0A/0x0B Analog 1/2, 0x0D Bluetooth, 0x0E Network |
| Volume | 0x06 | 0 to 99; the app caps at 65 by default |
| Mute | 0x07 | 0x00 off, 0x01 on |
| Surround mode | 0x08 | 0x03 Stereo 2.0, 0x04 Stereo 2.1, 0x05 All Stereo, 0x06 Native, 0x07 ProLogic II |
| Treble / Bass | 0x0B / 0x0C | −12 to +12 dB |
| Room EQ | 0x0D | 0x00 off, 0x01 EZ Set EQ |
| Dialog enhancement | 0x0E | 0x00 off, 0x01 on |
| Streaming state | 0x11 | service ID + 0x01 play / 0x02 pause |
| Init / keepalive | 0x50 | 0xF0, every 15 seconds |

The receiver also sends updates on its own when someone uses the knob or the original remote, which is how the app stays in sync. Green standby turns IP control off. Track skipping has no command in the protocol. Source: [JBL MA-Series IP Control v1.7](https://www.jbl.com.mx/on/demandware.static/-/Sites-masterCatalog_Harman/default/dw59e58897/pdfs/IPControl_MA_Series_v17.pdf).

## Install and maintenance runbook

Installing takes about 10 minutes the first time and 1 minute every 7 days after that (free Apple ID).

**First install**

1. Open `MA510Remote.xcodeproj` in Xcode on the laptop (not the Intel iMac).
2. Click the blue MA510Remote project, then TARGETS › MA510Remote › Signing & Capabilities. Set Team to your Personal Team and Bundle Identifier to `com.mikeytorres.ma510remote.home`. Do the same Team for MA510RemoteTests.
3. Plug in the iPhone, unlock it, tap Trust. Wait for Window › Devices and Simulators to finish preparing it.
4. On the iPhone: Settings › Privacy & Security › Developer Mode › on, then restart.
5. Product › Destination › your iPhone, then click Try Again in Signing if errors remain.
6. Product › Run (Cmd+R).
7. On the iPhone: Settings › General › VPN & Device Management › your Apple ID › Trust.
8. In the app: status chip › Live › Find My Receiver › Allow Local Network › Connect. Start at low volume.

**Every 7 days (free Apple ID)**

1. Plug in the iPhone and open the project.
2. Product › Destination › your iPhone, then Product › Run.

Saved settings (receiver IP, favorite, volume limit) survive the renewal.

**Keep in place**

- Leave Developer Mode on; apps installed from Xcode will not open without it.
- Only trust your own laptop and Apple ID; check VPN & Device Management now and then.

**Useful Xcode locations**

| Task | Where |
| --- | --- |
| Build | Product › Build (Cmd+B) |
| Run on phone or Simulator | Product › Destination, then Product › Run (Cmd+R) |
| See errors | Warning triangle in the left sidebar (Cmd+5) |
| Clean a stuck build | Product › Clean Build Folder (Shift+Cmd+K) |
| Device setup | Window › Devices and Simulators (Shift+Cmd+2) |
| Download simulators | Xcode › Settings › Components › iOS › Get |
| App icon | Assets › AppIcon, drop a 1024 × 1024 PNG in Any Appearance |
| Run protocol tests | Product › Test (Cmd+U) |

## Q&A log

These are the questions raised from setup through install, in the order they came up, with the answer each one landed on.

| # | Question | Answer |
| --- | --- | --- |
| 1 | Would VS Code work, or Xcode? | Xcode. Only Xcode can build, sign and install an iPhone app; VS Code can edit the files but not install them. |
| 2 | What does "set up signing" mean? | The open files were the old web prototype. The iPhone app is the separate MA510Remote.zip; signing is choosing your Apple ID as Team in Signing & Capabilities. |
| 3 | Where is the project? I only see the original folder. | Download MA510Remote.zip, unzip it, and open MA510Remote.xcodeproj (blue blueprint icon). |
| 4 | Xcode closes every time I click a file or the UI. | Not the code: Xcode itself was crashing on the 2020 Intel iMac (macOS Tahoe 26.6.2), matching a reported Intel / macOS 26.5+ code-signature crash. Fixed by switching to the laptop. |
| 5 | What other editor is compatible? | None can install on an iPhone without Xcode's tools. Alternatives: the web app + bridge, Expo with cloud builds ($99 account), or Swift Playgrounds on an iPad. |
| 6 | Step by step, I need a new bundle identifier. | Signing & Capabilities › Bundle Identifier › a unique reverse-domain name such as com.mikeytorres.ma510remote.home. |
| 7 | Still not working ("Your team has no devices"). | A free Personal Team needs a connected iPhone before it can make a profile: plug in, select the phone as destination, Try Again. |
| 8 | Should I register on the developer website instead? | Not with a free account; manual device registration needs the paid program ($99/yr). Plugging in is the free route. |
| 9 | Build failed. | With "Any iOS Device" selected, signing fails before code compiles. Build for a Simulator to test the code alone. |
| 10 | Error: weak ownership of captured self differs. | Add `[weak self]` to the inner closures in RemoteStore.swift (two spots). |
| 11 | In plain terms, what does weak self do? | It lets a saved piece of code point at the app's brain without keeping it alive forever, preventing memory leaks. The fix states what the code already meant. |
| 12 | Stuck on "phone needs to be unlocked". | Trust prompt, Auto-Lock off, wait for Devices and Simulators to finish preparing, Developer Mode on, use a cable. |
| 13 | There is no simulator in the window. | Simulators are optional; download them in Xcode › Settings › Components › iOS. |
| 14 | Those menus are not what you described. | Mapped to the real menu bar: Xcode › Settings, Product › Destination, Product › Run, Window › Devices and Simulators. |
| 15 | Should Demo mode be removed before installing? | Not needed; Demo does not block Live or the install. Live-only is optional (6 edits in RemoteStore and ConnectionSheet). |
| 16 | 143 issues after the edits. | One broken file causes a cascade. Notes typed outside `//` or `/* */` and an extra `}` were the cause; reverting fixed it. Keep notes in a NOTES.md. |
| 17 | It says the app is not trusted. | Settings › General › VPN & Device Management › your Apple ID › Trust. |
| 18 | Can Gerry use it too? | Yes: plug his iPhone into the laptop and run (free, 7 days), or invite him through TestFlight (paid). He must be on the home Wi-Fi. |
| 19 | Why does it stop after 7 days if I'm logged in? | Apple's rule for free accounts: the signing profile lasts 7 days (1 year paid). Login does not extend it. |
| 20 | Can I unplug, turn off Developer Mode and quit Xcode? | Unplug and quit, yes. Keep Developer Mode on or the app will not open. |
| 21 | Is Developer Mode less secure? | Slightly. Apps stay sandboxed; the risk needs physical access or trusting someone else's profile. Trust only your own laptop and Apple ID. |
