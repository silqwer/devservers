# DevServers

**English** · [한국어](README.ko.md)

A macOS menu bar app that shows which local dev servers (`next dev`, `vite`, `storybook` …) are running, **which project each one belongs to and which port it's on** — and lets you stop them in one click.

It's built around a server-rack theme: the menu bar icon lights up one LED per running server, and blinks faster the more CPU your servers use.

<p align="center">
  <img src="docs/assets/menubar.gif" alt="Menu bar rack icon: a green LED lights up for each server that starts, while red activity LEDs blink" height="72">
</p>

**[Website](https://silqwer.github.io/devservers/en/) · [Download (DevServers.zip)](https://github.com/silqwer/devservers/releases/latest/download/DevServers.zip)**

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-FFDD00?logo=buymeacoffee&logoColor=000)](https://buymeacoffee.com/silqwers)

## Features

- **Menu bar icon**: a 3-unit server rack
  - Green power LEDs: one per running server, filled from the top (up to 3)
  - Red activity LEDs: blink in proportion to your servers' total CPU usage (0% → every 0.9 s, 100%+ → every 0.07 s)
- **Server panel**: each server is shown as a 1U rack unit
  - Project name (`name` from `package.json`, or the folder name), kind (Next.js / Vite / Storybook …), port, PID
  - Click the port display → opens `http://localhost:<port>`
  - 🧭 Open in browser · 📁 Reveal in Finder (the tooltip shows the path) · ⏻ Stop server
- **Stop**: sends `SIGTERM` to the process group, then `SIGKILL` if it's still alive after 3 seconds
- **Stop all**: stops every listed server after a confirmation strip
- **ALL PROCS switch**: shows only node processes by default; turn it on to list every process that's listening on a TCP port
- Refreshes when the panel opens and every 3 seconds (scans run in the background)
- No Dock icon (`LSUIElement`); LED blinking stops when "Reduce motion" is on in System Settings

## Requirements

- macOS 14 or later
- To build from source: Xcode or a Swift 5.10+ toolchain (check with `xcode-select -p`)

## Install

### Homebrew

```bash
brew install --cask silqwer/tap/devservers
```

Update with `brew upgrade --cask devservers`. The upgrade quits the running app, so open it again afterwards.

To launch it at login, add `/Applications/DevServers.app` under **System Settings → General → Login Items**.

### Manual

1. Download [DevServers.zip](https://github.com/silqwer/devservers/releases/latest/download/DevServers.zip), unzip it, and move `DevServers.app` to `/Applications`. (Universal: Apple Silicon and Intel)
2. Open it. On first launch macOS asks to confirm an app downloaded from the internet — click **Open**.

Releases are signed with a Developer ID and notarized by Apple, so there's no "unidentified developer" warning.

## Build & run

```bash
git clone https://github.com/silqwer/devservers.git
cd devservers
./build.sh                     # creates build/DevServers.app
open build/DevServers.app
```

To launch it at login, copy `build/DevServers.app` to `/Applications` and add it under **System Settings → General → Login Items**.

Quit the app with the **⏏ QUIT** button at the bottom right of the panel, or `⌘Q`. Running servers keep running after the app quits.

### Scan from the terminal

```bash
swift run devservers-scan          # node servers only
swift run devservers-scan --all    # every process listening on a TCP port
```

```
PID     PGID    PORTS          KIND        CPU%   PROJECT                    PATH
38272   38236   3001           Next.js     0.0    my-blog                    ~/…/my-blog
        └ next-server (v15.5.24)
```

### Release

```bash
# 1. bump CFBundleShortVersionString / CFBundleVersion in Resources/Info.plist
./scripts/package.sh       # 2. universal build → sign with Developer ID → notarize → dist/DevServers.zip
# 3. tag vX.Y.Z and upload dist/DevServers.zip to a GitHub release
./scripts/update-cask.sh   # 4. update version and sha256 in silqwer/homebrew-tap (--dry-run to preview)
```

`package.sh` signs with the first **Developer ID Application** certificate in your keychain (or `SIGN_IDENTITY`), then notarizes and staples the app. Store the notary credentials once — `notarytool` asks for an app-specific password:

```bash
xcrun notarytool store-credentials devservers-notary --apple-id <Apple ID> --team-id <TEAMID>
```

Without a Developer ID certificate it falls back to an ad-hoc signed, un-notarized zip.

### Demo / screen recording

To demo the app without showing your real project names and paths, start the demo servers and run the app in demo mode:

```bash
./scripts/demo-servers.sh   # my-blog(:3001) · landing-page(:5173) · @acme/design-system(:6006)
DEVSERVERS_DEMO_ROOT=/tmp/devservers-demo ./build/DevServers.app/Contents/MacOS/DevServers
```

When `DEVSERVERS_DEMO_ROOT` is set, only servers started under that folder are shown.

## How it works

| Step | Command | Purpose |
|---|---|---|
| 1 | `lsof -iTCP -sTCP:LISTEN -n -P` | Collect listening ports and PIDs (grouped by PID) |
| 2 | `lsof -a -p <PID,…> -d cwd -Fpn` | Find each process's working directory |
| 3 | `<cwd>/package.json` | Read the project name |
| 4 | `ps -o pid=,pgid=,%cpu=,command= -p <PID,…>` | Process group, CPU and command line → kind label |

PIDs are batched into a single comma-separated query, so one scan takes about 0.3 seconds.

Because it has to inspect and stop other processes, **the app does not use App Sandbox**. It never signals its own process group or system groups (PGID ≤ 1) as a group; in those cases it stops only the individual PID.

## Project structure

```
Sources/
├─ DevServersCore/    scanning and stopping logic (no UI)
├─ devservers-scan/   CLI for checking scan results in the terminal
└─ DevServers/        SwiftUI menu bar app (MenuBarExtra .window)
Resources/Info.plist  bundle settings such as LSUIElement
build.sh              builds the .app bundle + signing (Developer ID with SIGN_IDENTITY, otherwise ad-hoc; UNIVERSAL=1 for a universal binary)
scripts/              package.sh (release zip) · update-cask.sh (Homebrew cask) · demo-servers.sh (demo servers)
docs/                 GitHub Pages website
```

## Support

DevServers is free and open source. If it saves you time, you can support its development with a coffee ☕

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-FFDD00?logo=buymeacoffee&logoColor=000)](https://buymeacoffee.com/silqwers)

## License

[MIT](LICENSE)
