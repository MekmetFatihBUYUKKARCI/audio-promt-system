import SwiftUI

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general, model, cleaning, dictionary, shortcuts
    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: return "Genel"
        case .model: return "Model"
        case .cleaning: return "Temizleme"
        case .dictionary: return "Sözlük"
        case .shortcuts: return "Kısayollar"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .model: return "waveform"
        case .cleaning: return "sparkles"
        case .dictionary: return "text.book.closed"
        case .shortcuts: return "keyboard"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var prefs = Preferences.shared
    let historyStore: HistoryStore
    @State private var selectedTab: SettingsTab = .general
    @State private var slideEdge: Edge = .trailing

    /// Sıra her zaman `SettingsTab.allCases`'in tanım sırasına göre —
    /// rastgele değil, sekmenin ekrandaki soldan-sağa konumuna göre kayma
    /// yönü belirleniyor. Yön, animasyon başlamadan ÖNCE, senkron olarak
    /// hesaplanıyor (onChange ile hesaplamak animasyonla yarışıp tutarsız
    /// sonuç veriyordu — bu yüzden seçim burada, tek bir yerden yapılıyor).
    private func selectTab(_ tab: SettingsTab) {
        guard tab != selectedTab else { return }
        let allTabs = SettingsTab.allCases
        let oldIndex = allTabs.firstIndex(of: selectedTab) ?? 0
        let newIndex = allTabs.firstIndex(of: tab) ?? 0
        slideEdge = newIndex > oldIndex ? .trailing : .leading
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedTab = tab
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 20)

            SlidingSegmentedControl(selectedTab: selectedTab, onSelect: selectTab)
                .padding(.horizontal, 28)
                .padding(.bottom, 20)

            ZStack {
                switch selectedTab {
                case .general:
                    GeneralTab(prefs: prefs, historyStore: historyStore)
                        .transition(.asymmetric(
                            insertion: .move(edge: slideEdge).combined(with: .opacity),
                            removal: .move(edge: slideEdge == .trailing ? .leading : .trailing).combined(with: .opacity)
                        ))
                case .model:
                    ModelTab(prefs: prefs)
                        .transition(.asymmetric(
                            insertion: .move(edge: slideEdge).combined(with: .opacity),
                            removal: .move(edge: slideEdge == .trailing ? .leading : .trailing).combined(with: .opacity)
                        ))
                case .cleaning:
                    CleaningTab(prefs: prefs)
                        .transition(.asymmetric(
                            insertion: .move(edge: slideEdge).combined(with: .opacity),
                            removal: .move(edge: slideEdge == .trailing ? .leading : .trailing).combined(with: .opacity)
                        ))
                case .dictionary:
                    DictionaryTab(prefs: prefs)
                        .transition(.asymmetric(
                            insertion: .move(edge: slideEdge).combined(with: .opacity),
                            removal: .move(edge: slideEdge == .trailing ? .leading : .trailing).combined(with: .opacity)
                        ))
                case .shortcuts:
                    ShortcutsTab(prefs: prefs)
                        .transition(.asymmetric(
                            insertion: .move(edge: slideEdge).combined(with: .opacity),
                            removal: .move(edge: slideEdge == .trailing ? .leading : .trailing).combined(with: .opacity)
                        ))
                }
            }
            .clipped()
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Spacer().frame(height: 20)
        }
        .frame(minWidth: 560, idealWidth: 680, minHeight: 480, idealHeight: 640)
        .background(.clear)
    }
}

/// Elle kontrol edilen segmented kontrol — mavi vurgu kendi
/// `.offset`/`.animation`'ıyla kayıyor, AppKit'in kendi (bu bağlamda
/// güvenilir olmayan) segment geçiş animasyonuna bağımlı değil.
private struct SlidingSegmentedControl: View {
    let selectedTab: SettingsTab
    let onSelect: (SettingsTab) -> Void

    private let tabs = SettingsTab.allCases

    var body: some View {
        GeometryReader { geometry in
            let segmentWidth = geometry.size.width / CGFloat(tabs.count)
            let selectedIndex = tabs.firstIndex(of: selectedTab) ?? 0

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.4))

                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.accentColor)
                    .frame(width: segmentWidth - 4, height: geometry.size.height - 4)
                    .offset(x: segmentWidth * CGFloat(selectedIndex) + 2, y: 2)

                HStack(spacing: 0) {
                    ForEach(tabs) { tab in
                        Button {
                            onSelect(tab)
                        } label: {
                            Label(tab.label, systemImage: tab.symbol)
                                .font(.body.weight(tab == selectedTab ? .semibold : .regular))
                                .foregroundStyle(tab == selectedTab ? Color.white : Color.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: geometry.size.height)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(height: 32)
    }
}

/// Her sekmenin başındaki büyük, kalın başlık — sistem fontu ama diğer
/// metinlerden belirgin şekilde büyük (visual-style.md: font hiyerarşisi).
private struct TabHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.title2.weight(.bold))
            .padding(.bottom, 6)
    }
}

private extension View {
    /// Form'un kendi opak arka planını kaldırır — cam pencere arkadan görünsün.
    func transparentFormBackground() -> some View {
        self.scrollContentBackground(.hidden)
    }
}

// MARK: - Genel

private struct GeneralTab: View {
    @ObservedObject var prefs: Preferences
    let historyStore: HistoryStore

    @State private var launchAtLoginEnabled = LaunchAtLogin.isEnabled
    @State private var micLevel: Float = 0
    @State private var showClearHistoryConfirm = false
    private let micMonitor = MicLevelMonitor()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TabHeader(title: "Genel")
                .padding(.horizontal, 28)

            Form {
                Toggle("Girişte başlat", isOn: $launchAtLoginEnabled)
                    .font(.body)
                    .onChange(of: launchAtLoginEnabled) { _, newValue in
                        LaunchAtLogin.setEnabled(newValue)
                    }

                Toggle("Sessizlikte otomatik dur", isOn: $prefs.vadEnabled)
                    .font(.body)
                if prefs.vadEnabled {
                    Slider(value: $prefs.vadSilenceDuration, in: 1.0...5.0, step: 0.5) {
                        Text("Sessizlik süresi")
                    } minimumValueLabel: {
                        Text("1s").font(.footnote)
                    } maximumValueLabel: {
                        Text("5s").font(.footnote)
                    }
                    Text("\(prefs.vadSilenceDuration, specifier: "%.1f") saniye sessizlikte otomatik durur")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Sessizlik eşiği")
                        .font(.body)
                    HStack {
                        Slider(value: $prefs.vadThreshold, in: 0.0...0.2)
                        MicLevelBar(level: micLevel)
                            .frame(width: 70, height: 14)
                    }
                }
                .onAppear {
                    micMonitor.onLevelUpdate = { rms in
                        Task { @MainActor in micLevel = rms }
                    }
                    micMonitor.start()
                }
                .onDisappear { micMonitor.stop() }

                Picker("Maksimum kayıt süresi", selection: $prefs.maxRecordingDuration) {
                    Text("30 sn").tag(30.0)
                    Text("60 sn").tag(60.0)
                    Text("120 sn").tag(120.0)
                    Text("5 dk").tag(300.0)
                }
                .font(.body)

                Picker("HUD konumu", selection: $prefs.hudPosition) {
                    ForEach(HUDPosition.allCases) { position in
                        Text(position.displayName).tag(position)
                    }
                }
                .font(.body)

                Button("Geçmişi temizle", role: .destructive) {
                    showClearHistoryConfirm = true
                }
                .buttonStyle(.glass)
                .confirmationDialog(
                    "Tüm dikte geçmişi silinsin mi?",
                    isPresented: $showClearHistoryConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Sil", role: .destructive) { historyStore.clear() }
                    Button("Vazgeç", role: .cancel) {}
                }
            }
            .transparentFormBackground()
            .controlSize(.large)
        }
        .padding(.top, 4)
    }
}

private struct MicLevelBar: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: .quaternaryLabelColor))
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * CGFloat(min(max(level * 6, 0), 1)))
            }
        }
    }
}

// MARK: - Model

private struct ModelTab: View {
    @ObservedObject var prefs: Preferences
    @State private var isDownloaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TabHeader(title: "Model")
                .padding(.horizontal, 28)

            Form {
                Picker("Whisper modeli", selection: $prefs.whisperModel) {
                    ForEach(WhisperModelOption.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .font(.body)
                .onChange(of: prefs.whisperModel) { _, _ in refreshDownloadStatus() }

                HStack {
                    Text(isDownloaded ? "İndirildi" : "İndirilmedi")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if isDownloaded {
                        Button("Sil", role: .destructive) { deleteModel() }
                            .buttonStyle(.glass)
                    } else {
                        Text("İlk dikte sırasında otomatik indirilir")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Picker("Dil", selection: $prefs.languageMode) {
                    ForEach(LanguageMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .font(.body)
                Text("Otomatik, Türkçe–İngilizce karışık konuşmayı cümle cümle doğru ayırır.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Picker("Mikrofon cihazı", selection: $prefs.microphoneDeviceUID) {
                    Text("Sistem varsayılanı").tag(String?.none)
                    ForEach(AudioDeviceUtility.listInputDevices()) { device in
                        Text(device.name).tag(String?.some(device.uid))
                    }
                }
                .font(.body)
            }
            .transparentFormBackground()
            .controlSize(.large)
        }
        .padding(.top, 4)
        .onAppear { refreshDownloadStatus() }
    }

    private func modelDirectory(for model: WhisperModelOption) -> URL? {
        guard let home = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return home
            .appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml")
            .appendingPathComponent(model.rawValue)
    }

    private func refreshDownloadStatus() {
        guard let dir = modelDirectory(for: prefs.whisperModel) else { isDownloaded = false; return }
        isDownloaded = FileManager.default.fileExists(atPath: dir.path)
    }

    private func deleteModel() {
        guard let dir = modelDirectory(for: prefs.whisperModel) else { return }
        try? FileManager.default.removeItem(at: dir)
        refreshDownloadStatus()
    }
}

// MARK: - Temizleme

private struct CleaningTab: View {
    @ObservedObject var prefs: Preferences
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var availableModels: [String] = []
    @State private var promptExpanded = false
    @State private var thresholdsExpanded = false

    enum ConnectionStatus {
        case unknown, connected(String), disconnected
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TabHeader(title: "Temizleme")
                .padding(.horizontal, 28)

            Form {
                Toggle("Ollama ile temizle", isOn: $prefs.ollamaEnabled)
                    .font(.body)
                TextField("Ollama adresi", text: $prefs.ollamaAddress)
                    .font(.body)

                if availableModels.isEmpty {
                    TextField("Model", text: $prefs.ollamaModel)
                        .font(.body)
                } else {
                    Picker("Model", selection: $prefs.ollamaModel) {
                        ForEach(availableModels, id: \.self) { Text($0).tag($0) }
                    }
                    .font(.body)
                }

                HStack {
                    statusView
                    Spacer()
                    Button("Yeniden dene") { Task { await checkConnection() } }
                        .buttonStyle(.glass)
                }

                DisclosureGroup("Sistem promptu (ileri düzey)", isExpanded: $promptExpanded) {
                    TextEditor(text: $prefs.ollamaSystemPrompt)
                        .frame(height: 140)
                        .font(.system(.body, design: .monospaced))
                    Button("Varsayılana dön") { prefs.resetOllamaSystemPrompt() }
                        .buttonStyle(.glass)
                }
                .font(.subheadline)

                DisclosureGroup("Güvenlik eşikleri", isExpanded: $thresholdsExpanded) {
                    Stepper("Kelime kaybı üst sınırı: %\(Int(prefs.maxWordLossPercent))", value: $prefs.maxWordLossPercent, in: 0...100, step: 5)
                        .font(.body)
                    Stepper("Benzerlik alt sınırı: %\(Int(prefs.minSimilarityPercent))", value: $prefs.minSimilarityPercent, in: 0...100, step: 5)
                        .font(.body)
                    Stepper("Zaman aşımı: \(prefs.ollamaTimeout, specifier: "%.1f") sn", value: $prefs.ollamaTimeout, in: 0.5...10, step: 0.5)
                        .font(.body)
                    Text("Bu sınırlar aşılırsa temizlenmiş metin atılır ve ham transkript kullanılır. Küçük modeller bazen çeviri yapıyor ya da harf yutuyor.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
            .transparentFormBackground()
            .controlSize(.large)
        }
        .padding(.top, 4)
        .task { await checkConnection() }
    }

    @ViewBuilder
    private var statusView: some View {
        switch connectionStatus {
        case .unknown:
            Label("Kontrol ediliyor…", systemImage: "circle.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .connected(let model):
            Label("bağlı — \(model) hazır", systemImage: "circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
        case .disconnected:
            Label("Ollama çalışmıyor", systemImage: "circle.fill")
                .font(.subheadline)
                .foregroundStyle(.red)
        }
    }

    private func checkConnection() async {
        guard let url = URL(string: prefs.ollamaAddress)?.appendingPathComponent("api/tags") else {
            connectionStatus = .disconnected
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            struct TagsResponse: Decodable { struct Model: Decodable { let name: String }; let models: [Model] }
            let decoded = try JSONDecoder().decode(TagsResponse.self, from: data)
            availableModels = decoded.models.map(\.name)
            connectionStatus = .connected(prefs.ollamaModel)
        } catch {
            connectionStatus = .disconnected
        }
    }
}

// MARK: - Sözlük

private struct DictionaryTab: View {
    @ObservedObject var prefs: Preferences
    @State private var rows: [(wrong: String, right: String)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TabHeader(title: "Sözlük")
                .padding(.horizontal, 28)

            VStack(alignment: .leading, spacing: 10) {
                Toggle("Terimleri Whisper'a ipucu olarak da ver", isOn: $prefs.vocabularyHintsEnabled)
                    .font(.body)

                HStack {
                    Text("Duyulan").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    Text("Yazılacak").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                }
                List {
                    ForEach(rows.indices, id: \.self) { index in
                        HStack {
                            TextField("", text: bindingWrong(for: index))
                                .font(.body)
                            TextField("", text: bindingRight(for: index))
                                .font(.body)
                        }
                    }
                }
                .scrollContentBackground(.hidden)

                HStack {
                    Button("+") { rows.append(("", "")); commit() }
                        .buttonStyle(.glass)
                    Button("−") {
                        if !rows.isEmpty { rows.removeLast(); commit() }
                    }
                    .buttonStyle(.glass)
                    Spacer()
                }
            }
            .padding(28)
            .padding(.top, -8)
        }
        .padding(.top, 4)
        .onAppear {
            rows = prefs.vocabularyCorrections.map { ($0.key, $0.value) }
        }
    }

    private func bindingWrong(for index: Int) -> Binding<String> {
        Binding(
            get: { rows.indices.contains(index) ? rows[index].wrong : "" },
            set: { newValue in
                guard rows.indices.contains(index) else { return }
                rows[index].wrong = newValue
                commit()
            }
        )
    }

    private func bindingRight(for index: Int) -> Binding<String> {
        Binding(
            get: { rows.indices.contains(index) ? rows[index].right : "" },
            set: { newValue in
                guard rows.indices.contains(index) else { return }
                rows[index].right = newValue
                commit()
            }
        )
    }

    private func commit() {
        var dict: [String: String] = [:]
        for row in rows where !row.wrong.isEmpty {
            dict[row.wrong] = row.right
        }
        prefs.vocabularyCorrections = dict
    }
}

// MARK: - Kısayollar

private struct ShortcutsTab: View {
    @ObservedObject var prefs: Preferences

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TabHeader(title: "Kısayollar")
                .padding(.horizontal, 28)

            Form {
                Section("Sabit kısayollar") {
                    LabeledContent("Kayıt başlat/durdur", value: "⌃⌥1")
                        .font(.body)
                    LabeledContent("Son metni yapıştır", value: "⌃⌥V")
                        .font(.body)
                    Text("Bu kısayollar şu an sabit, yeniden atanamıyor.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline.weight(.semibold))

                Section("Basılı-tutma") {
                    Picker("Tetikleme modu", selection: $prefs.pushToTalkMode) {
                        ForEach(TriggerMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .font(.body)
                    if prefs.pushToTalkMode == .hold {
                        Picker("Tuş", selection: $prefs.pushToTalkKey) {
                            ForEach(PushToTalkKeyOption.allCases) { key in
                                Text(key.displayName).tag(key)
                            }
                        }
                        .font(.body)
                        Text("Basılı tutma, Erişilebilirlik izni gerektirir.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline.weight(.semibold))
            }
            .transparentFormBackground()
            .controlSize(.large)
        }
        .padding(.top, 4)
    }
}
