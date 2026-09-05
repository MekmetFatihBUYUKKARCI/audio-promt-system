import WhisperKit
import Foundation

/// WhisperKit modeli bir kez yüklenir ve bellekte tutulur (bkz. PLAN.md
/// bölüm 11 — "model her transkripsiyonda yeniden yüklenmez").
final class Transcriber: @unchecked Sendable {
    private var whisperKit: WhisperKit?
    private let modelName: String

    init(modelName: String) {
        self.modelName = modelName
    }

    func prepare() async throws {
        guard whisperKit == nil else { return }

        _ = try await WhisperKit.download(variant: modelName) { progress in
            let percent = Int(progress.fractionCompleted * 100)
            NSLog("⬇️ Model indiriliyor (\(self.modelName)): yüzde \(percent)")
        }

        let config = WhisperKitConfig(model: modelName)
        whisperKit = try await WhisperKit(config)
    }

    func transcribe(audioPath: String) async throws -> String {
        try await prepare()
        guard let whisperKit else { throw TranscriberError.notReady }

        // language: nil BIRAKILMASI TEK BAŞINA YETMİYOR — WhisperKit'in
        // varsayılanı usePrefillPrompt=true olduğu için detectLanguage de
        // varsayılan olarak false'a düşüyor ve İngilizce'ye sabitleniyor.
        // TR/EN karışık dikte için detectLanguage açıkça true verilmeli.
        let options = DecodingOptions(language: nil, detectLanguage: true)

        let results: [TranscriptionResult] = try await whisperKit.transcribe(audioPath: audioPath, decodeOptions: options)
        let text = results.map(\.text).joined(separator: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum TranscriberError: Error {
    case notReady
}
