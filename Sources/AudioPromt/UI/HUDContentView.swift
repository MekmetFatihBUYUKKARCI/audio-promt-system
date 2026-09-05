import SwiftUI

@MainActor
final class HUDState: ObservableObject {
    enum Phase {
        case hidden
        case recording
        case transcribing
        case result
        case error
    }

    @Published var phase: Phase = .hidden
    @Published var duration: TimeInterval = 0
    @Published var levels: [Float] = Array(repeating: 0, count: 16)
    @Published var resultText: String = ""
    @Published var errorText: String = ""
    @Published var autoPasted: Bool = false
}

struct HUDContentView: View {
    @ObservedObject var state: HUDState

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.15), radius: 20)

            content
        }
        .frame(width: 300, height: 72)
    }

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case .hidden:
            EmptyView()
        case .recording:
            recordingView
        case .transcribing:
            transcribingView
        case .result:
            resultView
        case .error:
            errorView
        }
    }

    private var recordingView: some View {
        HStack(spacing: 8) {
            PulsingDot()
            WaveformView(levels: state.levels)
            Text(formattedDuration)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
    }

    private var transcribingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Yazıya çevriliyor…")
                .foregroundStyle(.secondary)
        }
    }

    private var resultView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(previewText)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            Text(state.autoPasted ? "yapıştırıldı" : "⌘V")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(nsColor: .quaternaryLabelColor))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
    }

    private var errorView: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(state.errorText)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
    }

    private var previewText: String {
        if state.resultText.count > 40 {
            return String(state.resultText.prefix(40)) + "…"
        }
        return state.resultText
    }

    private var formattedDuration: String {
        let total = Int(state.duration)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct PulsingDot: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 8, height: 8)
            .opacity(isPulsing ? 0.5 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

private struct WaveformView: View {
    let levels: [Float]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor)
                    .frame(width: 3, height: 4 + CGFloat(level) * 36)
            }
        }
        .frame(height: 40)
    }
}
