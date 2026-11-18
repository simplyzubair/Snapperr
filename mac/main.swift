// Snapperr for Mac: snap windows with the keyboard. Menu bar app (no Dock icon).
// Build: bash mac/build.sh (on a Mac, needs Xcode command line tools).
//
// Double-tap Control  -> snap mode on for 10 s (voice says "Snap on")
// Triple-tap Control  -> asks how many columns (2-9), then snap mode on
// In snap mode (each key restarts the 10 s, Esc or double-tap Control ends it):
//   Control+Left/Down/Right  thirds, Control+L / Control+; halves
//   Control+Shift+Arrow      move 20 px, Control+Shift+Option+Arrow  resize 20 px
//   Control+1 ... Control+9  column 1..N from the left
// Outside snap mode Snapperr does not take any keys.

import AppKit
import ApplicationServices
import AVFoundation
import Carbon.HIToolbox
import CryptoKit
import ServiceManagement

let appVersion = "0.0.0"   // build.sh writes the real version here (from the VERSION file)
let appRepo = "simplyzubair/Snapperr"
let website = URL(string: "https://snapperr.skillsgeek.com")!
let step: CGFloat = 20
let minSize: CGFloat = 120
let snapSeconds = 10
let tapGap: TimeInterval = 0.35

// MARK: - Moving windows (Accessibility API, top-left screen coordinates)

enum WindowMover {
    static func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let window = value, CFGetTypeID(window) == AXUIElementGetTypeID() else { return nil }
        return (window as! AXUIElement)
    }

    static func frame(of window: AXUIElement) -> CGRect? {
        var pos: CFTypeRef?
        var size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &pos) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &size) == .success,
              let pos, let size else { return nil }
        var point = CGPoint.zero
        var dims = CGSize.zero
        AXValueGetValue(pos as! AXValue, .cgPoint, &point)
        AXValueGetValue(size as! AXValue, .cgSize, &dims)
        return CGRect(origin: point, size: dims)
    }

    static func setPosition(_ window: AXUIElement, _ point: CGPoint) {
        var p = point
        if let v = AXValueCreate(.cgPoint, &p) { AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, v) }
    }

    static func setSize(_ window: AXUIElement, _ size: CGSize) {
        var s = size
        if let v = AXValueCreate(.cgSize, &s) { AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, v) }
    }

    /// Converts a Cocoa screen rect (bottom-left origin) to Accessibility coordinates (top-left origin).
    static func toAX(_ r: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height)
    }

    static func screen(for f: CGRect) -> NSScreen {
        let center = CGPoint(x: f.midX, y: f.midY)
        return NSScreen.screens.first { toAX($0.frame).contains(center) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    static func snap(x xRatio: CGFloat, width widthRatio: CGFloat) {
        guard let w = focusedWindow(), let f = frame(of: w) else { return }
        let area = toAX(screen(for: f).visibleFrame)
        let target = CGRect(x: area.minX + (area.width * xRatio).rounded(), y: area.minY,
                            width: (area.width * widthRatio).rounded(), height: area.height)
        // size, move, size again: some apps refuse a size that does not fit where the window is now
        setSize(w, target.size)
        setPosition(w, target.origin)
        setSize(w, target.size)
    }

    static func move(dx: CGFloat, dy: CGFloat) {
        guard let w = focusedWindow(), let f = frame(of: w) else { return }
        setPosition(w, CGPoint(x: f.minX + dx, y: f.minY + dy))
    }

    static func resize(dw: CGFloat, dh: CGFloat) {
        guard let w = focusedWindow(), let f = frame(of: w) else { return }
        setSize(w, CGSize(width: max(minSize, f.width + dw), height: max(minSize, f.height + dh)))
    }
}

// MARK: - Global hot keys (Carbon), only registered while snap mode is on

final class HotKeys {
    static let shared = HotKeys()
    private var refs: [EventHotKeyRef] = []
    private var actions: [UInt32: (repeats: Bool, run: () -> Void)] = [:]
    private var repeatTimer: Timer?
    private var handler: EventHandlerRef?

    func installHandler() {
        var specs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            HotKeys.shared.fire(id.id, pressed: GetEventKind(event) == UInt32(kEventHotKeyPressed))
            return noErr
        }, specs.count, &specs, nil, &handler)
    }

    func add(_ keyCode: Int, _ modifiers: Int, repeats: Bool = false, _ run: @escaping () -> Void) {
        let id = UInt32(actions.count + 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers),
                                         EventHotKeyID(signature: OSType(0x534E_5052), id: id),
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            refs.append(ref)
            actions[id] = (repeats, run)
        }
    }

    func removeAll() {
        stopRepeat()
        refs.forEach { UnregisterEventHotKey($0) }
        refs = []
        actions = [:]
    }

    private func stopRepeat() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }

    /// Runs the action; move/resize keys keep repeating while held down.
    func fire(_ id: UInt32, pressed: Bool) {
        stopRepeat()
        guard pressed, let action = actions[id] else { return }
        action.run()
        guard action.repeats else { return }
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
            self?.repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in action.run() }
        }
    }
}

// MARK: - Control taps (Control pressed and released alone, quickly)

final class TapDetector {
    private let onTaps: (Int) -> Void
    private var controlDown = false
    private var otherKey = false
    private var count = 0
    private var lastUp = Date.distantPast
    private var finish: DispatchWorkItem?
    private var monitors: [Any] = []

    init(onTaps: @escaping (Int) -> Void) {
        self.onTaps = onTaps
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] in self?.flagsChanged($0) }) { monitors.append(m) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] _ in self?.otherKey = true }) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] e in self?.flagsChanged(e); return e }) { monitors.append(m) }
    }

    private func flagsChanged(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function])
        if flags == .control {
            if !controlDown { controlDown = true; otherKey = false }
            return
        }
        defer { controlDown = false }
        guard controlDown, flags.isEmpty, !otherKey else { count = 0; return }
        let now = Date()
        count = now.timeIntervalSince(lastUp) < tapGap ? count + 1 : 1
        lastUp = now
        finish?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let taps = self.count
            self.count = 0
            self.onTaps(taps)
        }
        finish = item
        DispatchQueue.main.asyncAfter(deadline: .now() + tapGap, execute: item)
    }
}

// MARK: - Popup that shows snap mode is on (never takes focus, clicks pass through)

final class Badge {
    private let panel: NSPanel
    private let headline = NSTextField(labelWithString: "Snap on")
    private let hint = NSTextField(labelWithString: "")

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 280, height: 58),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let box = NSView(frame: panel.contentRect(forFrameRect: panel.frame))
        box.wantsLayer = true
        box.layer?.backgroundColor = NSColor(red: 0.04, green: 0.42, blue: 0.29, alpha: 0.96).cgColor
        box.layer?.cornerRadius = 14
        headline.font = .boldSystemFont(ofSize: 15)
        headline.textColor = .white
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = NSColor(red: 0.82, green: 0.98, blue: 0.90, alpha: 1)
        for (label, y) in [(headline, 28.0), (hint, 9.0)] {
            label.alignment = .center
            label.frame = NSRect(x: 8, y: y, width: 264, height: 20)
            box.addSubview(label)
        }
        panel.contentView = box
    }

    func update(secondsLeft: Int, columns: Int) {
        headline.stringValue = "Snap on  ·  \(secondsLeft) s"
        hint.stringValue = columns > 0 ? "⌃1 to ⌃\(columns) = column  ·  Esc = off" : "⌃ + arrows  ·  Esc = off"
    }

    func show() {
        var screen = NSScreen.main ?? NSScreen.screens[0]
        if let w = WindowMover.focusedWindow(), let f = WindowMover.frame(of: w) { screen = WindowMover.screen(for: f) }
        let area = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: area.midX - panel.frame.width / 2, y: area.maxY - panel.frame.height - 24))
        panel.orderFrontRegardless()
    }

    func hide() { panel.orderOut(nil) }
}

// MARK: - Updates (GitHub releases)

struct Release {
    let version: String
    let url: URL
    let sha256: String?
}

enum Updater {
    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }
        let y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0
            let q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }

    /// Calls back on the main thread with the newer release, nil when up to date, or an error.
    static func check(_ done: @escaping (Result<Release?, Error>) -> Void) {
        var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(appRepo)/releases/latest")!, timeoutInterval: 15)
        req.setValue("Snapperr/\(appVersion)", forHTTPHeaderField: "User-Agent")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: req) { data, response, error in
            let result: Result<Release?, Error> = Result {
                if let error { throw error }
                guard (response as? HTTPURLResponse)?.statusCode == 200, let data,
                      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = json["tag_name"] as? String else { throw err("No release info from GitHub") }
                let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                guard isNewer(version, than: appVersion) else { return nil }
                let assets = json["assets"] as? [[String: Any]] ?? []
                let prefix = "https://github.com/\(appRepo)/releases/download/"
                guard let asset = assets.first(where: { ($0["name"] as? String)?.range(of: #"^Snapperr-[\d.]+-mac\.dmg$"#, options: .regularExpression) != nil }),
                      let link = asset["browser_download_url"] as? String, link.hasPrefix(prefix),
                      let url = URL(string: link) else { throw err("The new release has no Mac download yet") }
                var sha: String?
                if let digest = asset["digest"] as? String, digest.hasPrefix("sha256:") { sha = String(digest.dropFirst(7)).lowercased() }
                return Release(version: version, url: url, sha256: sha)
            }
            DispatchQueue.main.async { done(result) }
        }.resume()
    }

    static func err(_ message: String) -> NSError {
        NSError(domain: "Snapperr", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    /// Downloads the .dmg, checks it, then a small script swaps the app and starts the new one.
    static func install(_ release: Release, failed: @escaping (String) -> Void) {
        URLSession.shared.downloadTask(with: release.url) { tmp, _, error in
            do {
                guard let tmp else { throw error ?? err("Download failed") }
                let dmg = FileManager.default.temporaryDirectory.appendingPathComponent("Snapperr-update.dmg")
                try? FileManager.default.removeItem(at: dmg)
                try FileManager.default.moveItem(at: tmp, to: dmg)
                if let sha = release.sha256 {
                    let digest = SHA256.hash(data: try Data(contentsOf: dmg)).map { String(format: "%02x", $0) }.joined()
                    guard digest == sha else { throw err("The download is damaged (checksum does not match). Please try again.") }
                }
                DispatchQueue.main.async { swapAndRestart(dmg: dmg) }
            } catch {
                DispatchQueue.main.async { failed(error.localizedDescription) }
            }
        }.resume()
    }

    private static func swapAndRestart(dmg: URL) {
        let script = """
        while kill -0 "$3" 2>/dev/null; do sleep 0.2; done
        MNT=$(mktemp -d /tmp/snapperr.XXXXXX)
        if hdiutil attach -nobrowse -readonly -mountpoint "$MNT" "$1" >/dev/null \\
           && rm -rf "$2.new" && ditto "$MNT/Snapperr.app" "$2.new" \\
           && rm -rf "$2.old" && mv "$2" "$2.old" && mv "$2.new" "$2"; then
          rm -rf "$2.old"
          xattr -dr com.apple.quarantine "$2" 2>/dev/null
          tccutil reset Accessibility com.skillsgeek.snapperr >/dev/null 2>&1
          hdiutil detach "$MNT" >/dev/null 2>&1
          open "$2"
        else
          hdiutil detach "$MNT" >/dev/null 2>&1
          [ -d "$2" ] || mv "$2.old" "$2"
          open "$2"
          open "\(website.absoluteString)"
        fi
        rm -f "$1"
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = ["-c", script, "snapperr-update", dmg.path, Bundle.main.bundleURL.path,
                       String(ProcessInfo.processInfo.processIdentifier)]
        do {
            try p.run()
            NSApp.terminate(nil)
        } catch {
            NSWorkspace.shared.open(website)
        }
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let badge = Badge()
    private let voice = AVSpeechSynthesizer()
    private var tapDetector: TapDetector?
    private var snapOn = false
    private var secondsLeft = 0
    private var columns = 0
    private var tick: Timer?
    private var pendingUpdate: Release?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = NSImage(systemSymbolName: "arrow.up.and.down.and.arrow.left.and.right", accessibilityDescription: "Snapperr")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = "Snapperr \(appVersion)"
        buildMenu()

        HotKeys.shared.installHandler()
        tapDetector = TapDetector { [weak self] taps in
            guard let self else { return }
            if taps == 2 { self.snapOn ? self.endSnapMode() : self.startSnapMode() }
            else if taps >= 3 { self.askColumns() }
        }

        setUpLoginItemOnce()
        if !AXIsProcessTrusted() { askForAccessibility() }

        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { self.checkForUpdate(manual: false) }
        Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { [weak self] _ in self?.checkForUpdate(manual: false, quiet: true) }
    }

    // MARK: menu

    private func buildMenu() {
        let menu = NSMenu()
        if let update = pendingUpdate {
            menu.addItem(item("Update to \(update.version)", #selector(installUpdate)))
            menu.addItem(.separator())
        }
        menu.addItem(item("Turn snap mode on", #selector(menuSnapMode)))
        menu.addItem(item("Shortcuts…", #selector(showShortcuts)))
        menu.addItem(item("Check for updates", #selector(menuCheckForUpdate)))
        if #available(macOS 13, *) {
            let login = item("Start at login", #selector(toggleLoginItem))
            login.state = SMAppService.mainApp.status == .enabled ? .on : .off
            menu.addItem(login)
        }
        if !AXIsProcessTrusted() { menu.addItem(item("Allow Accessibility access…", #selector(openAccessibilitySettings))) }
        menu.addItem(item("Website", #selector(openWebsite)))
        menu.addItem(.separator())
        menu.addItem(item("Quit Snapperr", #selector(quit)))
        menu.delegate = self
        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self
        return i
    }

    @objc private func menuSnapMode() { startSnapMode() }
    @objc private func openWebsite() { NSWorkspace.shared.open(website) }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func menuCheckForUpdate() { checkForUpdate(manual: true) }

    @objc private func showShortcuts() {
        alert("Snapperr \(appVersion) shortcuts", """
        Turn on snap mode first:
          Double-tap Control   snap mode on for 10 seconds
          Triple-tap Control   choose how many columns, then snap mode on
          Esc                  snap mode off

        Then:
          ⌃ ← / ↓ / →          left / center / right third
          ⌃ L  /  ⌃ ;          left / right half
          ⌃ ⇧ Arrow            move window 20 px
          ⌃ ⇧ ⌥ Arrow          resize window 20 px (→ ↓ bigger, ← ↑ smaller)
          ⌃ 1 … ⌃ 9            put window in that column (from the left)

        Each key press keeps snap mode on for 10 more seconds.
        If ⌃ ← or ⌃ → switch desktops instead, turn off those shortcuts in
        System Settings → Keyboard → Keyboard Shortcuts → Mission Control.
        """)
    }

    @discardableResult
    private func alert(_ title: String, _ text: String, buttons: [String] = ["OK"]) -> NSApplication.ModalResponse {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        buttons.forEach { a.addButton(withTitle: $0) }
        return a.runModal()
    }

    // MARK: snap mode

    private func startSnapMode(say text: String = "Snap on") {
        guard AXIsProcessTrusted() else { askForAccessibility(); return }
        snapOn = true
        registerSnapKeys()
        voice.stopSpeaking(at: .immediate)
        voice.speak(AVSpeechUtterance(string: text))
        secondsLeft = snapSeconds
        badge.update(secondsLeft: secondsLeft, columns: columns)
        badge.show()
        tick?.invalidate()
        tick = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.secondsLeft -= 1
            if self.secondsLeft <= 0 { self.endSnapMode() } else { self.badge.update(secondsLeft: self.secondsLeft, columns: self.columns) }
        }
    }

    private func endSnapMode() {
        guard snapOn else { return }
        snapOn = false
        tick?.invalidate()
        HotKeys.shared.removeAll()
        badge.hide()
        NSSound(named: "Pop")?.play()
    }

    /// Runs a window action and keeps snap mode on for 10 more seconds.
    private func act(_ action: @escaping () -> Void) -> () -> Void {
        return { [weak self] in
            guard let self else { return }
            self.secondsLeft = snapSeconds
            self.badge.update(secondsLeft: self.secondsLeft, columns: self.columns)
            action()
        }
    }

    private func registerSnapKeys() {
        let hk = HotKeys.shared
        hk.removeAll()
        let ctrl = controlKey, shift = shiftKey, opt = optionKey
        hk.add(kVK_Escape, 0) { [weak self] in self?.endSnapMode() }
        hk.add(kVK_LeftArrow, ctrl, act { WindowMover.snap(x: 0, width: 1.0 / 3) })
        hk.add(kVK_DownArrow, ctrl, act { WindowMover.snap(x: 1.0 / 3, width: 1.0 / 3) })
        hk.add(kVK_RightArrow, ctrl, act { WindowMover.snap(x: 2.0 / 3, width: 1.0 / 3) })
        hk.add(kVK_ANSI_L, ctrl, act { WindowMover.snap(x: 0, width: 0.5) })
        hk.add(kVK_ANSI_Semicolon, ctrl, act { WindowMover.snap(x: 0.5, width: 0.5) })

        let arrows: [(Int, CGFloat, CGFloat)] = [(kVK_LeftArrow, -1, 0), (kVK_RightArrow, 1, 0), (kVK_UpArrow, 0, -1), (kVK_DownArrow, 0, 1)]
        for (key, x, y) in arrows {
            hk.add(key, ctrl | shift, repeats: true, act { WindowMover.move(dx: x * step, dy: y * step) })
            hk.add(key, ctrl | shift | opt, repeats: true, act { WindowMover.resize(dw: x * step, dh: y * step) })
        }

        let digits = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
        if columns >= 2 {
            let n = CGFloat(columns)
            for k in 1...columns {
                hk.add(digits[k - 1], ctrl, act { WindowMover.snap(x: CGFloat(k - 1) / n, width: 1 / n) })
            }
        }
    }

    private func askColumns() {
        guard AXIsProcessTrusted() else { askForAccessibility(); return }
        let previous = NSWorkspace.shared.frontmostApplication
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "How many windows side by side?"
        a.informativeText = "Type a number from 2 to 9."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = String(columns >= 2 ? columns : 3)
        a.accessoryView = field
        a.addButton(withTitle: "OK")
        a.addButton(withTitle: "Cancel")
        a.window.initialFirstResponder = field
        let answer = a.runModal()
        previous?.activate(options: [])
        guard answer == .alertFirstButtonReturn else { return }
        guard let n = Int(field.stringValue.trimmingCharacters(in: .whitespaces)), (2...9).contains(n) else {
            alert("Snapperr", "Please type a number from 2 to 9.")
            previous?.activate(options: [])
            return
        }
        columns = n
        startSnapMode(say: "\(n) columns")
    }

    // MARK: permissions and login item

    private func askForAccessibility() {
        let answer = alert("Snapperr needs Accessibility access",
              "macOS asks for this before an app can move other apps' windows.\n\n"
            + "Click Open Settings, then turn on Snapperr in the list.\n"
            + "If Snapperr is already turned on (for example after an update), select it, remove it with the − button, and add it again.",
              buttons: ["Open Settings", "Later"])
        if answer == .alertFirstButtonReturn {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            openAccessibilitySettings()
        }
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    private func setUpLoginItemOnce() {
        guard #available(macOS 13, *), !UserDefaults.standard.bool(forKey: "loginItemSetUp") else { return }
        try? SMAppService.mainApp.register()
        UserDefaults.standard.set(true, forKey: "loginItemSetUp")
    }

    @objc private func toggleLoginItem() {
        guard #available(macOS 13, *) else { return }
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            alert("Snapperr", "Could not change the login setting.\n\n\(error.localizedDescription)")
        }
        buildMenu()
    }

    // MARK: updates

    private func checkForUpdate(manual: Bool, quiet: Bool = false) {
        Updater.check { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                if manual { self.alert("Could not check for updates", error.localizedDescription) }
            case .success(nil):
                if manual { self.alert("Snapperr", "You have the newest version (\(appVersion)).") }
            case .success(let release?):
                let isNew = self.pendingUpdate?.version != release.version
                self.pendingUpdate = release
                self.buildMenu()
                self.statusItem.button?.toolTip = "Snapperr \(appVersion) (update \(release.version) available)"
                if manual || (!quiet && isNew) { self.askToUpdate() }
            }
        }
    }

    private func askToUpdate() {
        guard let update = pendingUpdate else { return }
        let answer = alert("Snapperr \(update.version) is available",
                           "You have \(appVersion). Update now? It takes a few seconds.\n(You can also update later from the menu bar icon.)",
                           buttons: ["Update now", "Later"])
        if answer == .alertFirstButtonReturn { installUpdate() }
    }

    @objc private func installUpdate() {
        guard let update = pendingUpdate else { return }
        statusItem.button?.toolTip = "Downloading Snapperr \(update.version)…"
        Updater.install(update) { [weak self] message in
            self?.alert("The update failed", message)
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    // Refresh items such as "Allow Accessibility access…" each time the menu opens.
    func menuNeedsUpdate(_ menu: NSMenu) {}
    func menuWillOpen(_ menu: NSMenu) {
        let trusted = AXIsProcessTrusted()
        let showsAccess = menu.items.contains { $0.action == #selector(openAccessibilitySettings) }
        if trusted == showsAccess { DispatchQueue.main.async { self.buildMenu() } }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
