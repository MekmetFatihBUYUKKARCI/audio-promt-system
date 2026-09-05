import AppKit
import SwiftUI

@MainActor
final class HUDController {
    private let state = HUDState()
    private var panel: NSPanel?
    private var durationTimer: Timer?
    private var recordingStart: Date?
    private var hideWorkItem: DispatchWorkItem?

    func showRecording() {
        hideWorkItem?.cancel()
        recordingStart = Date()
        state.duration = 0
        state.levels = Array(repeating: 0, count: 16)
        state.phase = .recording
        ensurePanel()

        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.recordingStart else { return }
                self.state.duration = Date().timeIntervalSince(start)
            }
        }
    }

    nonisolated func updateLevel(_ rms: Float) {
        // RMS değerleri konuşmada tipik olarak küçük (~0.01-0.3) — 8x
        // ölçekleyip 0...1 aralığına sıkıştırıyoruz, dalga formu bunu
        // 4-40pt yüksekliğe çeviriyor (bkz. HUDContentView).
        let normalized = min(max(rms * 8, 0), 1)
        Task { @MainActor in
            self.state.levels.removeFirst()
            self.state.levels.append(normalized)
        }
    }

    func showTranscribing() {
        durationTimer?.invalidate()
        state.phase = .transcribing
        ensurePanel()
    }

    func showResult(text: String, autoPasted: Bool) {
        state.resultText = text
        state.autoPasted = autoPasted
        state.phase = .result
        ensurePanel()
        scheduleHide(after: 1.5)
    }

    func showError(_ message: String) {
        durationTimer?.invalidate()
        state.errorText = message
        state.phase = .error
        ensurePanel()
        scheduleHide(after: 3.0)
    }

    func hide() {
        durationTimer?.invalidate()
        hideWorkItem?.cancel()
        state.phase = .hidden
        panel?.orderOut(nil)
    }

    private func scheduleHide(after seconds: TimeInterval) {
        hideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: workItem)
    }

    private func ensurePanel() {
        guard Preferences.shared.hudPosition != .hidden else {
            panel?.orderOut(nil)
            return
        }
        if panel == nil {
            let newPanel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 72),
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )
            newPanel.isOpaque = false
            newPanel.backgroundColor = .clear
            newPanel.level = .floating
            newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            newPanel.hasShadow = false
            newPanel.ignoresMouseEvents = true
            newPanel.isMovableByWindowBackground = false
            newPanel.hidesOnDeactivate = false
            newPanel.contentView = NSHostingView(rootView: HUDContentView(state: state))
            panel = newPanel
        }
        positionPanel()
        panel?.orderFrontRegardless()
    }

    private func positionPanel() {
        guard let panel, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - panel.frame.width / 2

        let y: CGFloat
        switch Preferences.shared.hudPosition {
        case .bottomCenter, .hidden:
            y = screenFrame.minY + 24
        case .topCenter:
            y = screenFrame.maxY - panel.frame.height - 24
        case .belowMenuBar:
            y = screenFrame.maxY - panel.frame.height - 4
        }
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
