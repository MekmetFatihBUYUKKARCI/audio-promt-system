import AppKit

if let bundleID = Bundle.main.bundleIdentifier {
    let currentPID = ProcessInfo.processInfo.processIdentifier
    let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        .filter { $0.processIdentifier != currentPID }
    if let existing = others.first {
        existing.activate()
        exit(0)
    }
}

let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
