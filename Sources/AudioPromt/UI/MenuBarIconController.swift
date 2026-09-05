import AppKit

/// Bölüm 6.1 şartnamesindeki durum tablosunun basitleştirilmiş bir
/// uygulaması. "LLM temizliyor" ve "Model iniyor" durumları Faz 3'te
/// eklenecek (henüz Ollama/model-indirme entegrasyonu yok).
@MainActor
final class MenuBarIconController {
    private let button: NSStatusBarButton
    private var pulseTimer: Timer?
    private var pulseOn = false

    init(button: NSStatusBarButton) {
        self.button = button
        apply(.idle)
    }

    func apply(_ state: AppState.IconState) {
        pulseTimer?.invalidate()
        pulseTimer = nil
        button.alphaValue = 1.0

        switch state {
        case .idle:
            setSymbol("mic", color: .secondaryLabelColor)
        case .recording:
            setSymbol("mic.fill", color: .systemRed)
            startPulse()
        case .transcribing:
            setSymbol("waveform", color: .controlAccentColor)
        case .error:
            setSymbol("exclamationmark.triangle.fill", color: .systemOrange)
        }
    }

    private func setSymbol(_ name: String, color: NSColor) {
        let config = NSImage.SymbolConfiguration(paletteColors: [color])
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Audio Promt")?
            .withSymbolConfiguration(config)
        button.image = image
    }

    private func startPulse() {
        pulseOn = false
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.pulseOn.toggle()
                self.button.animator().alphaValue = self.pulseOn ? 0.5 : 1.0
            }
        }
    }
}
