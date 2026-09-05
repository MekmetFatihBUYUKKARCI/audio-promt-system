import Foundation

struct Vocabulary: Decodable {
    let hints: [String]
    let corrections: [String: String]

    static func loadFromBundle() -> Vocabulary {
        guard
            let url = Bundle.main.url(forResource: "vocabulary", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(Vocabulary.self, from: data)
        else {
            return Vocabulary(hints: [], corrections: [:])
        }
        return decoded
    }
}

/// Ollama ile temizleme + güvenlik ağı (PLAN.md bölüm 3 Faz 3 madde 3,
/// dersler.md md.5 — pazarlıksız). LLM çıktısı üç testten birini
/// geçemezse atılır, ham (sözlük düzeltmesi uygulanmış) transkript
/// kullanılır.
struct TextCleaner: Sendable {
    struct Thresholds: Sendable {
        var maxWordLossFraction: Double = 0.20
        var minSimilarity: Double = 0.70
        var timeout: TimeInterval = 4.0
    }

    private static let systemPrompt = """
    Aşağıdaki dikte metnini düzelt. Sadece noktalama, büyük harf ve dolgu \
    kelimeleri (ee, ııı, yani, işte) düzelt. ASLA çevirme. ASLA özetleme. \
    ASLA yorum ekleme. Sadece düzeltilmiş metni döndür.
    """

    let vocabulary: Vocabulary
    let thresholds: Thresholds
    let ollamaBaseURL: URL
    let ollamaModel: String
    let enabled: Bool

    init(
        vocabulary: Vocabulary = .loadFromBundle(),
        thresholds: Thresholds = Thresholds(),
        ollamaBaseURL: URL = URL(string: "http://localhost:11434")!,
        ollamaModel: String = "qwen2.5:3b",
        enabled: Bool = true
    ) {
        self.vocabulary = vocabulary
        self.thresholds = thresholds
        self.ollamaBaseURL = ollamaBaseURL
        self.ollamaModel = ollamaModel
        self.enabled = enabled
    }

    func applyDictionary(_ text: String) -> String {
        var result = text
        for (wrong, right) in vocabulary.corrections {
            result = result.replacingOccurrences(of: wrong, with: right, options: .caseInsensitive)
        }
        return result
    }

    /// Döndürülen `wasLLMCleaned == false` ise güvenlik ağı LLM çıktısını
    /// eledi (ya da temizleme kapalı) — `text` sözlük-düzeltmeli ham
    /// transkripttir.
    func clean(rawTranscript: String) async -> (text: String, wasLLMCleaned: Bool) {
        let dictionaryApplied = applyDictionary(rawTranscript)

        guard enabled, !dictionaryApplied.isEmpty else {
            return (dictionaryApplied, false)
        }

        do {
            let cleaned = try await requestOllamaCleanup(text: dictionaryApplied)
            if passesSafetyNet(raw: dictionaryApplied, cleaned: cleaned) {
                return (cleaned, true)
            } else {
                NSLog("⚠️ Ollama çıktısı güvenlik ağını geçemedi, ham transkript kullanılıyor")
                return (dictionaryApplied, false)
            }
        } catch {
            NSLog("⚠️ Ollama temizleme başarısız (\(error)), ham transkript kullanılıyor")
            return (dictionaryApplied, false)
        }
    }

    private func passesSafetyNet(raw: String, cleaned: String) -> Bool {
        let rawWords = raw.split(separator: " ").count
        let cleanedWords = cleaned.split(separator: " ").count
        guard rawWords > 0, !cleaned.isEmpty else { return false }

        let wordLoss = Double(max(0, rawWords - cleanedWords)) / Double(rawWords)
        guard wordLoss <= thresholds.maxWordLossFraction else { return false }

        guard similarityRatio(raw, cleaned) >= thresholds.minSimilarity else { return false }

        return true
    }

    private func requestOllamaCleanup(text: String) async throws -> String {
        struct Request: Encodable {
            let model: String
            let prompt: String
            let stream: Bool
        }
        struct Response: Decodable {
            let response: String
        }

        var request = URLRequest(url: ollamaBaseURL.appendingPathComponent("api/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = thresholds.timeout

        let body = Request(model: ollamaModel, prompt: "\(Self.systemPrompt)\n\n\(text)", stream: false)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// difflib.SequenceMatcher'a benzer, Levenshtein tabanlı basit bir
    /// benzerlik oranı (0...1).
    private func similarityRatio(_ a: String, _ b: String) -> Double {
        let aChars = Array(a)
        let bChars = Array(b)
        if aChars.isEmpty && bChars.isEmpty { return 1.0 }

        let m = aChars.count
        let n = bChars.count
        var previous = Array(0...n)
        var current = Array(repeating: 0, count: n + 1)

        for i in 1...max(m, 1) where m > 0 {
            current[0] = i
            for j in 1...n {
                if aChars[i - 1] == bChars[j - 1] {
                    current[j] = previous[j - 1]
                } else {
                    current[j] = 1 + min(previous[j - 1], previous[j], current[j - 1])
                }
            }
            previous = current
        }

        let distance = m == 0 ? n : previous[n]
        let maxLen = max(m, n)
        guard maxLen > 0 else { return 1.0 }
        return 1.0 - Double(distance) / Double(maxLen)
    }
}
