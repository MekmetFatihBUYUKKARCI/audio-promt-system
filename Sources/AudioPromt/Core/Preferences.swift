import Foundation
import Combine

enum WhisperModelOption: String, CaseIterable, Identifiable {
    case base = "openai_whisper-base"
    case largeTurbo = "openai_whisper-large-v3-v20240930_turbo"
    case large = "openai_whisper-large-v3-v20240930"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .base: return "base (hızlı, ~150 MB)"
        case .largeTurbo: return "large-v3-turbo (varsayılan, ~630 MB)"
        case .large: return "large-v3 (en iyi, ~1.5 GB)"
        }
    }
}

enum LanguageMode: String, CaseIterable, Identifiable {
    case auto, turkish, english

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Otomatik algıla (önerilen)"
        case .turkish: return "Türkçe"
        case .english: return "İngilizce"
        }
    }

    /// WhisperKit'e verilecek dil kodu — nil ise detectLanguage devrede.
    var whisperLanguageCode: String? {
        switch self {
        case .auto: return nil
        case .turkish: return "tr"
        case .english: return "en"
        }
    }
}

enum HUDPosition: String, CaseIterable, Identifiable {
    case bottomCenter, topCenter, belowMenuBar, hidden

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bottomCenter: return "Alt orta (varsayılan)"
        case .topCenter: return "Üst orta"
        case .belowMenuBar: return "Menü çubuğunun altı"
        case .hidden: return "Kapalı"
        }
    }
}

enum PushToTalkKeyOption: String, CaseIterable, Identifiable {
    case rightOption, rightCommand

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rightOption: return "Sağ Option"
        case .rightCommand: return "Sağ Command"
        }
    }

    /// macOS sanal tuş kodları.
    var keyCode: Int64 {
        switch self {
        case .rightOption: return 61
        case .rightCommand: return 54
        }
    }
}

enum TriggerMode: String, CaseIterable, Identifiable {
    case toggle, hold

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .toggle: return "Aç/kapa"
        case .hold: return "Basılı tut"
        }
    }
}

/// Tüm kullanıcı tercihleri — UserDefaults'a kalıcı, uygulama genelinde
/// tek kaynak (bölüm 6.4 Ayarlar penceresinin arkasındaki gerçek veri).
@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private enum Key {
        static let vadEnabled = "vadEnabled"
        static let vadSilenceDuration = "vadSilenceDuration"
        static let vadThreshold = "vadThreshold"
        static let maxRecordingDuration = "maxRecordingDuration"
        static let hudPosition = "hudPosition"
        static let whisperModel = "whisperModel"
        static let languageMode = "languageMode"
        static let microphoneDeviceUID = "microphoneDeviceUID"
        static let ollamaEnabled = "ollamaEnabled"
        static let ollamaAddress = "ollamaAddress"
        static let ollamaModel = "ollamaModel"
        static let ollamaSystemPrompt = "ollamaSystemPrompt"
        static let maxWordLossPercent = "maxWordLossPercent"
        static let minSimilarityPercent = "minSimilarityPercent"
        static let ollamaTimeout = "ollamaTimeout"
        static let vocabularyCorrections = "vocabularyCorrections"
        static let pushToTalkMode = "pushToTalkMode"
        static let pushToTalkKey = "pushToTalkKey"
        static let onboardingCompleted = "onboardingCompleted"
    }

    nonisolated static let defaultOllamaSystemPrompt = """
    Aşağıdaki dikte metnini düzelt. Sadece noktalama, büyük harf ve dolgu \
    kelimeleri (ee, ııı, yani, işte) düzelt. ASLA çevirme. ASLA özetleme. \
    ASLA yorum ekleme. Sadece düzeltilmiş metni döndür.
    """

    private let defaults = UserDefaults.standard

    @Published var vadEnabled: Bool { didSet { defaults.set(vadEnabled, forKey: Key.vadEnabled) } }
    @Published var vadSilenceDuration: Double { didSet { defaults.set(vadSilenceDuration, forKey: Key.vadSilenceDuration) } }
    @Published var vadThreshold: Double { didSet { defaults.set(vadThreshold, forKey: Key.vadThreshold) } }
    @Published var maxRecordingDuration: Double { didSet { defaults.set(maxRecordingDuration, forKey: Key.maxRecordingDuration) } }
    @Published var hudPosition: HUDPosition { didSet { defaults.set(hudPosition.rawValue, forKey: Key.hudPosition) } }

    @Published var whisperModel: WhisperModelOption { didSet { defaults.set(whisperModel.rawValue, forKey: Key.whisperModel) } }
    @Published var languageMode: LanguageMode { didSet { defaults.set(languageMode.rawValue, forKey: Key.languageMode) } }
    @Published var microphoneDeviceUID: String? { didSet { defaults.set(microphoneDeviceUID, forKey: Key.microphoneDeviceUID) } }

    @Published var ollamaEnabled: Bool { didSet { defaults.set(ollamaEnabled, forKey: Key.ollamaEnabled) } }
    @Published var ollamaAddress: String { didSet { defaults.set(ollamaAddress, forKey: Key.ollamaAddress) } }
    @Published var ollamaModel: String { didSet { defaults.set(ollamaModel, forKey: Key.ollamaModel) } }
    @Published var ollamaSystemPrompt: String { didSet { defaults.set(ollamaSystemPrompt, forKey: Key.ollamaSystemPrompt) } }
    @Published var maxWordLossPercent: Double { didSet { defaults.set(maxWordLossPercent, forKey: Key.maxWordLossPercent) } }
    @Published var minSimilarityPercent: Double { didSet { defaults.set(minSimilarityPercent, forKey: Key.minSimilarityPercent) } }
    @Published var ollamaTimeout: Double { didSet { defaults.set(ollamaTimeout, forKey: Key.ollamaTimeout) } }

    @Published var vocabularyCorrections: [String: String] {
        didSet {
            if let data = try? JSONEncoder().encode(vocabularyCorrections) {
                defaults.set(data, forKey: Key.vocabularyCorrections)
            }
        }
    }

    @Published var pushToTalkMode: TriggerMode { didSet { defaults.set(pushToTalkMode.rawValue, forKey: Key.pushToTalkMode) } }
    @Published var pushToTalkKey: PushToTalkKeyOption { didSet { defaults.set(pushToTalkKey.rawValue, forKey: Key.pushToTalkKey) } }

    @Published var onboardingCompleted: Bool { didSet { defaults.set(onboardingCompleted, forKey: Key.onboardingCompleted) } }

    private init() {
        let d = UserDefaults.standard
        vadEnabled = d.object(forKey: Key.vadEnabled) as? Bool ?? true
        vadSilenceDuration = d.object(forKey: Key.vadSilenceDuration) as? Double ?? 2.0
        vadThreshold = d.object(forKey: Key.vadThreshold) as? Double ?? 0.02
        maxRecordingDuration = d.object(forKey: Key.maxRecordingDuration) as? Double ?? 120
        hudPosition = HUDPosition(rawValue: d.string(forKey: Key.hudPosition) ?? "") ?? .bottomCenter

        whisperModel = WhisperModelOption(rawValue: d.string(forKey: Key.whisperModel) ?? "") ?? .largeTurbo
        languageMode = LanguageMode(rawValue: d.string(forKey: Key.languageMode) ?? "") ?? .auto
        microphoneDeviceUID = d.string(forKey: Key.microphoneDeviceUID)

        ollamaEnabled = d.object(forKey: Key.ollamaEnabled) as? Bool ?? true
        ollamaAddress = d.string(forKey: Key.ollamaAddress) ?? "http://localhost:11434"
        ollamaModel = d.string(forKey: Key.ollamaModel) ?? "qwen2.5:3b"
        ollamaSystemPrompt = d.string(forKey: Key.ollamaSystemPrompt) ?? Self.defaultOllamaSystemPrompt
        maxWordLossPercent = d.object(forKey: Key.maxWordLossPercent) as? Double ?? 20
        minSimilarityPercent = d.object(forKey: Key.minSimilarityPercent) as? Double ?? 70
        ollamaTimeout = d.object(forKey: Key.ollamaTimeout) as? Double ?? 4.0

        if let data = d.data(forKey: Key.vocabularyCorrections),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            vocabularyCorrections = decoded
        } else {
            vocabularyCorrections = Vocabulary.loadFromBundle().corrections
        }

        pushToTalkMode = TriggerMode(rawValue: d.string(forKey: Key.pushToTalkMode) ?? "") ?? .hold
        pushToTalkKey = PushToTalkKeyOption(rawValue: d.string(forKey: Key.pushToTalkKey) ?? "") ?? .rightOption

        onboardingCompleted = d.object(forKey: Key.onboardingCompleted) as? Bool ?? false
    }

    func resetOllamaSystemPrompt() {
        ollamaSystemPrompt = Self.defaultOllamaSystemPrompt
    }
}
