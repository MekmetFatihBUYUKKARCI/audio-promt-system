import SwiftUI
import AVFoundation

/// PLAN.md bölüm 6.5 — dersler.md md.7'deki VoiceInk dersi: onboarding
/// sihirbazı yapma. Tek pencere, tek seferlik, hiçbir adımı zorunlu değil.
struct OnboardingView: View {
    @ObservedObject var prefs = Preferences.shared
    let onDismiss: () -> Void

    @State private var micAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized

    var body: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 12)

            Image(systemName: "mic.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 4) {
                Text("Audio Promt çalışıyor.")
                    .font(.title.weight(.bold))
                Text("⌃⌥1 ile konuşmaya başla.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task {
                    let granted = await AVCaptureDevice.requestAccess(for: .audio)
                    micAuthorized = granted
                }
            } label: {
                Label(
                    micAuthorized ? "Mikrofon izni verildi" : "Mikrofon izni ver",
                    systemImage: micAuthorized ? "checkmark.circle.fill" : "mic"
                )
                .font(.body.weight(.medium))
            }
            .buttonStyle(.glass)
            .disabled(micAuthorized)

            Text("İlk dikte sırasında Whisper modeli otomatik iner (~630 MB, bir kez).")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Text("Dikte ettiğiniz metinler sadece bu bilgisayarda saklanır, hiçbir yere gönderilmez.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Button("Anladım") {
                prefs.onboardingCompleted = true
                onDismiss()
            }
            .font(.body.weight(.semibold))
            .buttonStyle(.glassProminent)
            .keyboardShortcut(.defaultAction)
            .padding(.top, 4)
        }
        .padding(32)
        .frame(width: 400)
        .background(.clear)
    }
}
