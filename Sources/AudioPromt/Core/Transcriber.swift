import WhisperKit
import Foundation

/// WhisperKit modeli yüklenip bellekte tutulur (bkz. PLAN.md bölüm 11 —
/// "model her transkripsiyonda yeniden yüklenmez"). Model Ayarlar'dan
/// değiştirilirse bir sonraki transkripsiyonda yeniden yüklenir.
final class Transcriber: @unchecked Sendable {
    /// `WhisperKit` kendisi `Sendable` değil — `Task<WhisperKit, Error>`
    /// sınır ötesi geçiş için tip düzeyinde Sendable istiyor, bu kutu onu
    /// karşılıyor (tek bir immutable referans taşıyor, güvenli).
    private final class WhisperKitBox: @unchecked Sendable {
        let value: WhisperKit
        init(_ value: WhisperKit) { self.value = value }
    }

    private let stateLock = NSLock()
    private var whisperKit: WhisperKit?
    private var loadedModelName: String?
    private var inFlightLoad: (modelName: String, task: Task<WhisperKitBox, Error>)?

    /// Uygulama açılışında arka planda çağrılır — model belleğe ilk
    /// dikteden önce yüklenir. İlk dikte ~10-20sn sürüyordu (CoreML
    /// derlemesi/model yükleme), bu bekleme kullanıcı fark etmeden
    /// açılışa taşınıyor.
    func prewarm(modelName: String) {
        Task {
            do {
                _ = try await ensureLoaded(modelName: modelName)
                NSLog("✅ Whisper modeli önceden yüklendi (\(modelName))")
            } catch {
                NSLog("⚠️ Model ön yükleme başarısız: \(error)")
            }
        }
    }

    func transcribe(audioPath: String, modelName: String, languageCode: String?) async throws -> String {
        let whisperKit = try await ensureLoaded(modelName: modelName)

        // language: nil BIRAKILMASI TEK BAŞINA YETMİYOR — WhisperKit'in
        // varsayılanı usePrefillPrompt=true olduğu için detectLanguage de
        // varsayılan olarak false'a düşüyor ve İngilizce'ye sabitleniyor.
        // TR/EN karışık dikte için detectLanguage açıkça true verilmeli
        // (dil sabitlenmediği sürece).
        let options = DecodingOptions(language: languageCode, detectLanguage: languageCode == nil)

        let results: [TranscriptionResult] = try await whisperKit.transcribe(audioPath: audioPath, decodeOptions: options)

        // Sessizlik/ortam gürültüsünde Whisper bazen halüsinasyon üretiyor
        // (2026-09-05 acımasız testte gözlendi: yanlış dilde uydurma cümleler
        // dahil). OpenAI Whisper'ın kendi sessizlik sezgisiyle aynı mantık:
        // bir sonucun TÜM segmentleri hem yüksek noSpeechProb hem çok düşük
        // avgLogprob gösteriyorsa gerçek konuşma değildir, atılır. Segment
        // metni değil, sonucun kendi (zaten temizlenmiş) `.text`'i kullanılır
        // — segment.text bazen ham özel token'ları içerebiliyor.
        let text = results
            .filter { result in
                guard !result.segments.isEmpty else { return true }
                return !result.segments.allSatisfy { $0.noSpeechProb > 0.6 && $0.avgLogprob < -1.0 }
            }
            .map(\.text)
            .joined(separator: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Aynı modeli eşzamanlı isteyen birden fazla çağıran (ör. açılıştaki
    /// `prewarm()` ile hemen ardından gelen gerçek bir dikte) aynı yükleme
    /// `Task`'ını paylaşır — 2026-09-05 acımasız testte yakalanan gerçek
    /// hata: ikisi de `whisperKit == nil` görüp modeli iki kez, kilitsiz
    /// eşzamanlı yazarak yüklüyordu.
    private func ensureLoaded(modelName: String) async throws -> WhisperKit {
        enum Existing {
            case ready(WhisperKit)
            case inFlight(Task<WhisperKitBox, Error>)
            case none
        }

        let existing: Existing = stateLock.withLock {
            if let whisperKit, loadedModelName == modelName { return .ready(whisperKit) }
            if let inFlightLoad, inFlightLoad.modelName == modelName { return .inFlight(inFlightLoad.task) }
            return .none
        }

        switch existing {
        case .ready(let whisperKit):
            return whisperKit
        case .inFlight(let task):
            return try await task.value.value
        case .none:
            break
        }

        let task = Task<WhisperKitBox, Error> {
            _ = try await WhisperKit.download(variant: modelName) { progress in
                let percent = Int(progress.fractionCompleted * 100)
                NSLog("⬇️ Model indiriliyor (\(modelName)): yüzde \(percent)")
            }
            let config = WhisperKitConfig(model: modelName)
            return WhisperKitBox(try await WhisperKit(config))
        }
        stateLock.withLock { inFlightLoad = (modelName, task) }

        do {
            let result = try await task.value
            stateLock.withLock {
                whisperKit = result.value
                loadedModelName = modelName
                inFlightLoad = nil
            }
            return result.value
        } catch {
            stateLock.withLock { inFlightLoad = nil }
            throw error
        }
    }
}
