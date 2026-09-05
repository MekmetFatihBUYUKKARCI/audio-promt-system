import WhisperKit
import Foundation

/// WhisperKit modeli yüklenip bellekte tutulur (bkz. PLAN.md bölüm 11 —
/// "model her transkripsiyonda yeniden yüklenmez"). Model Ayarlar'dan
/// değiştirilirse bir sonraki transkripsiyonda yeniden yüklenir.
final class Transcriber: @unchecked Sendable {
    private var whisperKit: WhisperKit?
    private var loadedModelName: String?

    func transcribe(audioPath: String, modelName: String, languageCode: String?) async throws -> String {
        try await ensureLoaded(modelName: modelName)
        guard let whisperKit else { throw TranscriberError.notReady }

        // language: nil BIRAKILMASI TEK BAŞINA YETMİYOR — WhisperKit'in
        // varsayılanı usePrefillPrompt=true olduğu için detectLanguage de
        // varsayılan olarak false'a düşüyor ve İngilizce'ye sabitleniyor.
        // TR/EN karışık dikte için detectLanguage açıkça true verilmeli
        // (dil sabitlenmediği sürece).
        let options = DecodingOptions(language: languageCode, detectLanguage: languageCode == nil)

        let results: [TranscriptionResult] = try await whisperKit.transcribe(audioPath: audioPath, decodeOptions: options)
        let text = results.map(\.text).joined(separator: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func ensureLoaded(modelName: String) async throws {
        if whisperKit != nil, loadedModelName == modelName { return }

        _ = try await WhisperKit.download(variant: modelName) { progress in
            let percent = Int(progress.fractionCompleted * 100)
            NSLog("⬇️ Model indiriliyor (\(modelName)): yüzde \(percent)")
        }

        let config = WhisperKitConfig(model: modelName)
        whisperKit = try await WhisperKit(config)
        loadedModelName = modelName
    }
}

enum TranscriberError: Error {
    case notReady
}
