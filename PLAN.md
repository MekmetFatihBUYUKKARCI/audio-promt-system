# Plan — Sesli Prompt Sistemi ("Audio Promt")

Bu dosya tek doğruluk kaynağı. Yapılan her adım buraya işlenir. Bu proje
Jarvis'in genel hafızasına (`🔮 850-Companion`, `knowledge/`) otomatik
yüklenmez — sadece bu klasörde yaşar.

**Geçmiş:** İki deneme terk edildi (VoiceInk fork, whisper-dictate fork).
Çıkarılan dersler `research/dersler.md`, topluluk araştırması
`research/topluluk-arastirmasi.md`. Bu plan ikisinin üstüne kuruldu.

---

## 0. Hedef ve başarı tanımı

Fatih'in yazabildiği her yere — özellikle Claude Code terminaline — klavye
yerine sesle metin girmesi.

Sistem şu üç şeyi yaptığında **bitti** sayılır:

1. Kısayola basılır, konuşulur, tekrar basılır → metin imlecin olduğu yere
   düşer. Odak hiçbir noktada çalınmaz (terminalde yazıyorsan terminalde
   kalırsın).
2. Türkçe–İngilizce karışık konuşma doğru ayrılır ("bu component'i refactor
   et" gibi cümleler bozulmaz).
3. Makine yeniden başlatıldığında hiçbir şey elle onarılmadan çalışmaya
   devam eder. **Önceki iki denemenin öldüğü yer tam olarak burası.**

**Kapsam notu (2026-09-05):** Bu proje **macOS'a özel** yazılıyor
(AppKit, Carbon, TCC, WhisperKit'in CoreML/ANE bağımlılığı) — Windows'ta
çalışmaz. Fatih'in çevresinde Windows kullanan kişiler de var; onlar için
ayrı bir yol (muhtemelen farklı bir uygulama/yaklaşım) **ileride, ayrı bir
konu** olarak ele alınacak. Şimdilik kapsam sadece Fatih'in Mac'i.

---

## 1. Temel içgörü — İzin Merdiveni

Önceki iki deneme, macOS Erişilebilirlik (Accessibility/TCC) iznine
**birinci günde** bağımlı olacak şekilde tasarlandığı için öldü. İzin
alınamayınca proje tamamen çalışmaz durumdaydı; ilerleme yoktu, sadece
izinle boğuşma vardı.

Bu planın omurgası şu: **sistemi izin ihtiyacına göre katmanlara ayır ve
en tehlikeli izni en sona bırak.** Her katman kendi başına kullanılabilir
bir ürün.

| Katman | Ne yapar | Gereken izin | Risk |
|---|---|---|---|
| **A. Yakalama** | Mikrofondan ses al | Mikrofon (`NSMicrophoneUsageDescription`) | Düşük — kullanıcıya sorulur, reddedilirse görünür hata verir, sessizce ölmez |
| **B. Tetikleme** | Sistem geneli kısayol tuşu | **HİÇBİRİ** | Yok |
| **C. Teslim (v1)** | Metni panoya koy | **HİÇBİRİ** | Yok |
| **D. Teslim (v2)** | Metni otomatik yapıştır | **Erişilebilirlik** | Yüksek — projeyi iki kez öldüren izin |

### Kritik teknik gerçek: kısayol için Erişilebilirlik izni GEREKMİYOR

Önceki denemeler global kısayol için `CGEventTap` veya
`NSEvent.addGlobalMonitorForEvents` kullandı. **İkisi de Erişilebilirlik
izni ister.**

Carbon'un `RegisterEventHotKey` API'si ise istemez. Ham tuş olaylarını biz
dinlemiyoruz — sistem belirli bir kombinasyonu bizim adımıza yakalayıp bize
tek bir callback gönderiyor. Klavye dinlemesi olmadığı için TCC devrede
değil. (`soffes/HotKey`, `MASShortcut` gibi yaygın Swift kütüphaneleri bu
API'nin üstünde çalışır ve izin istemezler.)

**Bedeli:** Gerçek bir tuş kombinasyonu gerekir (`⌃⌥Space` gibi). Çıplak bir
modifier tuşuna basılı tutma (push-to-talk) yapılamaz — o `CGEventTap`
ister. Bu yüzden v1 **aç/kapa (toggle)** modeliyle çalışır, basılı-tutma
Faz 5'e ertelenir.

### Teslimde de aynı mantık

Metni imlece yazdırmanın her yolu (`CGEvent.post` ile sentetik tuş,
AppleScript `System Events`, Accessibility API ile doğrudan yazma)
Erişilebilirlik izni ister. **Ama panoya yazmak (`NSPasteboard`) hiçbir izin
istemez.**

v1'de metin panoya düşer, HUD "hazır — ⌘V" der, Fatih kendi basar. Bu
Wispr Flow'un "Paste last transcript" davranışının aynısı ve **sıfır izinle
bugün çalışır.** Otomatik yapıştırma bunun üstüne, imza sorunu çözüldükten
sonra eklenir — çözülemezse sistem yine de kullanılabilir kalır.

---

## 2. Şema — sistem mimarisi

```
┌──────────────────────────────────────────────────────────────────┐
│  TETİKLEME KATMANI                     (izin gerekmez)           │
│  Carbon RegisterEventHotKey                                      │
│    ⌃⌥1      → kayıt aç/kapa                                      │
│    ⌃⌥V      → son metni tekrar panoya koy                        │
│    Esc      → (sadece kayıt sırasında kayıtlı) iptal             │
└────────────────────────────┬─────────────────────────────────────┘
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│  SES KATMANI                           (Mikrofon izni)           │
│  AVAudioEngine inputNode tap                                     │
│    → 48kHz stereo'dan 16kHz mono Float32'ye dönüştür             │
│    → halka tampon (ring buffer), tavan 120 sn                    │
│    → RMS seviyesi → HUD dalga formuna canlı besleme              │
│    → sessizlik algılama (VAD): 2.0 sn sessizlik = otomatik dur    │
└────────────────────────────┬─────────────────────────────────────┘
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│  TRANSKRIPSIYON KATMANI                (izin gerekmez, offline)  │
│  WhisperKit (CoreML → Apple Neural Engine)                       │
│    model: large-v3-turbo (kuantize), ilk açılışta indirilir      │
│    language: BOŞ BIRAK  ← dersler.md md.6: auto-detect zaten     │
│                            TR/EN karışığı doğru ayırıyor         │
│    initial prompt: sözlükteki terimler (Claude Code, Ollama...)  │
└────────────────────────────┬─────────────────────────────────────┘
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│  TEMİZLEME KATMANI                     (opsiyonel, kapatılabilir)│
│  1. Sözlük değiştirme (regex, anında, her zaman açık)            │
│  2. Ollama qwen2.5:3b — dolgu kelime/noktalama düzeltme          │
│     GÜVENLİK AĞI (dersler.md md.5):                              │
│       kelime sayısı %20'den fazla düştüyse → LLM çıktısını AT    │
│       benzerlik < %70 ise → LLM çıktısını AT                     │
│       2 sn'de dönmediyse → LLM çıktısını AT                      │
│     Her elemede ham transkripti kullan. LLM asla tek yol değil.  │
└────────────────────────────┬─────────────────────────────────────┘
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│  TESLİM KATMANI                                                  │
│  v1 (izin gerekmez):  NSPasteboard'a yaz + HUD "⌘V" der          │
│  v2 (Erişilebilirlik): CGEvent ile ⌘V bas, sonra eski panoyu     │
│                        geri yükle                                │
└──────────────────────────────────────────────────────────────────┘

YAN SİSTEMLER
  • Menü çubuğu ikonu (NSStatusItem) — durum göstergesi + menü
  • HUD paneli (NSPanel, .nonactivatingPanel) — ODAK ÇALMAZ
  • Geçmiş deposu — son 50 transkript, JSON, ~/Library/Application Support
  • Ayarlar penceresi (SwiftUI)
```

### Odak çalmama şartı (pazarlıksız)

HUD `NSPanel` olmalı, `styleMask` içinde `.nonactivatingPanel`,
`canBecomeKey = false`, `canBecomeMain = false`, `level = .floating`,
`collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`.

Uygulama `LSUIElement = true` (Dock'ta ikon yok, ⌘Tab'de görünmez).

Bu ikisi olmadan Claude Code terminaline yazarken HUD açılınca odak
terminalden kaçar ve ⌘V yanlış yere gider. Faz 2'nin çıkış kriteri tam
olarak bunun test edilmesidir.

---

## 3. Teknoloji seçimleri ve gerekçeleri

| Karar | Seçim | Neden |
|---|---|---|
| Dil / çatı | **Native Swift + SwiftUI**, SPM paketi (Xcode IDE değil) | dersler.md md.1: Python+PyObjC+script-exec zinciri TCC güvenini hiç kazanamadı. topluluk-arastirmasi.md md.6: sorunu çözmüş projelerin **hepsi** native Swift. Ollama zaten ayrı bir süreç, Python'a ihtiyaç yok |
| Konuşma tanıma | **WhisperKit** (argmaxinc) | Saf Swift paketi (SPM), CoreML üzerinden Apple Neural Engine kullanır, tamamen offline. Alternatif whisper.cpp C köprüsü gerektirir, gereksiz karmaşa |
| Model | `large-v3-turbo` kuantize (~600–700 MB) | TR/EN karışığında en iyi denge. Geliştirme sırasında `base` ile hızlı döngü, teslimde turbo |
| Kısayol | **Carbon `RegisterEventHotKey`** | Bölüm 1: izin gerektirmeyen tek yol |
| Metin teslimi v1 | `NSPasteboard` | İzin gerektirmez |
| Metin teslimi v2 | Pano + `CGEvent` ⌘V | En uyumlu yöntem; her uygulamada çalışır. Karakter karakter yazma yavaş ve terminalde bozuluyor |
| LLM temizleme | **Ollama + qwen2.5:3b** | Zaten kurulu ve çalışıyor, HTTP ile `localhost:11434`. Yeniden kurulum yok |
| Depolama | JSON, `~/Library/Application Support/AudioPromt/` | Basit, elle okunabilir, veritabanı gereksiz |
| Derleme sistemi | **Swift Package Manager + Makefile**, Xcode IDE hiç açılmaz | Aşağıda ayrıntılı |
| Paketleme | Makefile `.app` paketini elle kurar, kararlı imzayla | Faz 4'te ayrıntılı |

### Neden Xcode IDE kullanmıyoruz (2026-09-05 kararı)

Ayrım: **Xcode.app (IDE)** ile **toolchain** (`swiftc`, SPM, `codesign`,
macOS SDK) farklı şeyler. Derlemek için toolchain şart, IDE değil. SwiftUI,
AppKit, AVFoundation, Carbon hepsi sistem framework'ü — `swift build` ile
linklenir, `.app` paketini Makefile elle kurar.

Xcode zaten kurulu olduğu için disk kazancı yok; fayda kontrolde:

- Her şey düz metin → programatik düzenlenebilir, git'te okunur diff.
  `.xcodeproj/project.pbxproj` buna düşman.
- Derleme tek komut (`make run`), tıklanacak arayüz yok.
- **İmzalama Makefile'da açıkça görünür.** Xcode imza/provisioning'i arka
  planda kendi bildiği gibi yapar — VoiceInk dersi (dersler.md md.7) tam
  olarak buydu. Faz 4 imza duvarında her satırın görünür olması gerekiyor.
- `make run` ile terminalden başlatma, izin mirasını da çözüyor
  (topluluk-arastirmasi.md md.3, vocamac'in önerdiği yöntem).

Referans: `VocaHQ/vocamac` (`make run`), `per-simmons/murmur-youtube`
(Makefile'da `security find-identity` ile imza kimliğini otomatik bulur).

Kaybedilenler ve neden önemsiz: Interface Builder (SwiftUI kodla yazılıyor),
Instruments (gerekmiyor), IDE debugger (terminalden `lldb` veya print yeter).

Xcode.app diskte kalır — SDK sağlayıcısı olarak gerekli, ama hiç açılmaz.

### Neden hazır bir projeyi fork'lamıyoruz

dersler.md md.7: VoiceInk gibi olgun ve "kendi fikri olan" bir uygulamayı
fork'lamak, onboarding/state-machine'inin bizim config'imizi yok sayması
riskini taşıyor — bir kez yaşandı. Buradaki kod miktarı zaten küçük
(~1500–2000 satır Swift). Sıfırdan yazmak hem daha hızlı hem tam kontrol.

**Ama referans olarak kullanacağız.** `topluluk-arastirmasi.md` md.6'daki
projeler (özellikle `VocaHQ/vocamac` ve `per-simmons/murmur-youtube`) tıkanan
her noktada açılıp bakılacak kaynak — kopyalamak için değil, çözümü görmek
için.

---

## 4. Makinenin doğrulanmış durumu (2026-09-05)

Bunlar tahmin değil, komutla kontrol edildi:

- **Xcode:** kurulu (`/Applications/Xcode.app`), Swift **6.3.3**,
  hedef `arm64-apple-macosx26.0` ✅
- **macOS:** 26.6.2, **arm64** (Apple Silicon) ✅
- **Kod imzalama kimliği:** `security find-identity -v -p codesigning` →
  **`0 valid identities found`** ⚠️ Xcode'a hiçbir Apple ID girilmemiş.
  Faz 4'ün kilit noktası
- **Ollama:** `/opt/homebrew/bin/ollama`, `qwen2.5:3b` yüklü (1.9 GB) ✅
- **Klavye:** Bluetooth, sistemde jenerik **"Bluetooth Keyboard"** olarak
  görünüyor (Apple değil). dersler.md md.2'yi teyit eder — Globe/Fn tuşuna
  güvenilmez
- **Mikrofon:** dahili (1 kanal) + **ROG Strix Go** USB kulaklık (2 kanal).
  Kulaklık mikrofonu dikte için belirgin biçimde daha iyi; ayarlarda cihaz
  seçimi olmalı

---

## 5. Fazlar

Her fazın **çıkış kriteri** var. Kriter karşılanmadan sonraki faza
geçilmez. Her faz sonunda commit atılır (push yok — bkz. Kesin kurallar).

### Faz 0 — İskelet ✅ TAMAMLANDI (2026-09-05)

Kurulanlar: SPM paketi proje kökünde, `AppDelegate.swift` (`NSStatusItem`
+ menü), `Resources/Info.plist` (`LSUIElement`, mikrofon açıklaması),
`Makefile` (`build`/`bundle`/`sign`/`run`/`clean`), kendinden imzalı
sertifika (`Audio Promt Local Signing`) Anahtar Zinciri'nde kuruldu ve
Makefile'a bağlandı.

**Kararlılık testi yapıldı ve geçti:** İki ayrı derleme arasında CDHash
değişti (`d52a521c...` → `fc0a8f13...`, beklenen) ama designated
requirement sabit kaldı (`certificate leaf = H"ce518df3..."`) — Faz 4'ün
en kritik belirsizliği (imza kararlılığı) burada, Mikrofon izni için
kanıtlandı.

**Çalışma testi yapıldı:** Uygulama gerçekten çalıştırıldı, menü çubuğu
ikonu göründü (kapatılınca kayboldu — doğrulanmış), Dock'ta/⌘Tab'de
görünmedi (`osascript` ile background-only doğrulandı).

**İkinci test turu (2026-09-05, Fatih'in isteğiyle) — 1 hata bulundu ve
düzeltildi:**
- Menü gerçekten açılıyor mu, "Çık" gerçekten kapatıyor mu:
  `osascript`/System Events ile fiilen tıklanarak doğrulandı (ekran
  görüntüsüyle: menü "Çık ⌘Q" gösteriyor; tıklanınca süreç gerçekten
  sonlanıyor). ✅
- **Bulunan hata:** Uygulama iki kez art arda başlatılınca **iki ayrı
  süreç birden çalışıyordu** (tek-örnek koruması yoktu — bölüm 11 madde 3
  planda yazılıydı ama kodda unutulmuştu). Kazara çift açılma ihtimali
  `LSUIElement` uygulamalarda normalden yüksek (Dock'ta fark edilmiyor).
- **Düzeltme:** `main.swift`'e `NSRunningApplication.runningApplications
  (withBundleIdentifier:)` ile açılışta aynı bundle id'den başka süreç
  var mı kontrolü eklendi; varsa mevcut örnek öne çıkarılır, yeni süreç
  sessizce kendini kapatır (`exit(0)`). Tekrar test edildi: çift açılışta
  artık tek süreç kalıyor. ✅

Aşağıdaki orijinal adım listesi referans için duruyor:

1. **Xcode IDE açılmıyor.** `swift package init --type executable` ile
   SPM paketi kur, **doğrudan proje köküne** (`~/audio promt/`) — ayrı bir
   `src/` katmanı yok, kod `Package.swift`/`Sources/`/`Tests/` olarak
   `CLAUDE.md`/`PLAN.md` ile aynı seviyede durur (2026-09-05 kararı: tek
   klasör, katmanlı yapı istenmiyor).
   `Package.swift`'te `platforms: [.macOS(.v14)]`, framework bağımlılıkları
   (AppKit, SwiftUI, AVFoundation, Carbon) sistem kütüphaneleri olarak
   linklenir, ek paket gerekmez.
2. Elle `Info.plist`:
   - `LSUIElement = YES` (Dock ikonu yok)
   - `NSMicrophoneUsageDescription` = "…, konuştuğunuzu metne çevirmek
     için mikrofonu kullanır. Ses cihazınızdan çıkmaz."
3. `AppDelegate` + `NSStatusItem` menü çubuğu ikonu (`mic` SF Symbol).
4. Menüden çıkılabiliyor.
5. **Kararlı imza kimliği — Faz 4'ten öne çekildi (2026-09-05 düzeltmesi):**
   Ad-hoc imza (`codesign -s -`) her derlemede CDHash'i değiştirir; bu
   sadece Erişilebilirlik'i değil **Mikrofon** iznini de sıfırlar —
   Faz 1-3 boyunca her `make run` sonrası izin yeniden sorulurdu. Bunun
   yerine hemen şimdi: Anahtar Zinciri Erişimi → Sertifika Yardımcısı →
   **kendinden imzalı, "Kod İmzalama" türü** bir sertifika üret
   ("Audio Promt Local Signing", ücretsiz, 5 dakika). Faz 4 Yol 1'in
   mantığı burada uygulanır: sabit sertifika → designated requirement
   artık CDHash yerine leaf hash'e dayanır → rebuild'lerde bozulmaz.
   Bu şekilde Faz 1-3'ün onlarca rebuild'i, Faz 4'ün en kritik
   belirsizliğini ("tutuyor mu?") bedavaya, haftalar önceden test etmiş
   olur.
6. **Makefile** yaz — üç hedef yeterli:
   - `make run` — `swift build` + `.app` paketini
     `Contents/MacOS/`, `Contents/Resources/`, `Info.plist` ile elle kur
     + `codesign -s "Audio Promt Local Signing"` + terminalden başlat
     (izin mirası için, topluluk-arastirmasi.md md.3)
   - `make sign` — imzalama mantığı burada, madde 5'teki kimlikle
   - `make clean`
7. `.gitignore`'a `.build/`, indirilen modeller (zaten güncellendi).

**Çıkış kriteri:** Menü çubuğunda ikon var, tıklanınca menü açılıyor,
Dock'ta ikon yok, ⌘Tab'de görünmüyor. İki kez arka arkaya `make run`
sonrası `codesign -dv` aynı imza kimliğini gösteriyor.

---

### Faz 1 — Kısayol ve ses yakalama ✅ TAMAMLANDI (2026-09-05)

**Kısayol `⌃⌥Space` değil `⌃⌥1` oldu** (Fatih'in kararı, session
içinde). `RegisterEventHotKey` ile `Core/HotKeyManager.swift`,
`Core/AudioRecorder.swift` (`AVAudioEngine` + `AVAudioConverter`, 16kHz
mono Float32'ye dönüşüm), `AppState.swift` (durum makinesi:
idle/starting/recording, bölüm 11'e uygun). Kayıt başlarken/biterken
sesli geri bildirim eklendi (`Core/SoundFeedback.swift` — Ping/Pop,
%40 ses düzeyi, "Tink" ilk denemede "berbat" bulunup değiştirildi).

**Doğrulama testi geçti:** Erişilebilirlik izni hiç verilmemişken
(TCC listesinde uygulama hiç yok, çünkü Erişilebilirlik API'sine hiç
dokunulmuyor) kısayol çalışıyor — `osascript`/System Events ile
sistem çapında tuş gönderilerek doğrulandı.

**Bulunan ve düzeltilen 2 gerçek hata:**
1. **Çökme:** `AudioRecorder` ilk yazımda `@MainActor` işaretlenmişti.
   `installTap`'in callback'i CoreAudio'nun gerçek zamanlı ses
   thread'inde çalıştığı için, Swift'in eşzamanlılık çalışma zamanı
   bunu izolasyon ihlali sayıp `SIGTRAP` ile çöktürüyordu
   (`dispatch_assert_queue_fail`). Düzeltme: `@MainActor` yerine
   `@unchecked Sendable` — sınıf kendi thread-safety'sini kendi yönetir,
   tıpkı `AVAudioEngine`'in kendisi gibi.
2. **Yanlış varsayılan giriş cihazı (kod hatası değil, ortam hatası):**
   İlk birkaç testte kayıt hep sessiz (tam sıfır genlik) çıktı. Uzun bir
   teşhis sürecinden sonra (TCC izni kontrol edildi — sorunsuzdu; imza/
   launch yöntemi (`open` vs doğrudan çalıştırma) denendi — fark
   etmedi) gerçek sebep bulundu: Fatih'in sisteminde varsayılan giriş
   cihazı "MacBook Air Mikrofonu" (dahili) seçiliyken kendisi ROG Strix
   Go (USB kulaklık) mikrofonuna konuşuyordu. Sistem Ayarları → Ses →
   Giriş'ten ROG Strix Go seçilince kayıt anında gerçek ses aldı (tepe
   genlik ~%21, konuşma paternine uygun dalgalanma). **Ders:** kod her
   zaman sistemin o anki varsayılan giriş cihazını otomatik kullanıyor
   — bu doğru davranış; cihaz seçimi arayüzü (bölüm 6.4'te zaten
   planlanmış "Mikrofon cihazı" picker'ı) bu karışıklığı Faz 3'te
   önleyecek.

**Çıkış kriteri karşılandı:** Erişilebilirlik izni yokken kısayol
çalışıyor ✅; gerçek konuşma kaydedildi, format doğru (16kHz mono
Float32), genlik paterni gerçek ses ✅.

---

### Faz 2 — Transkripsiyon ve HUD ✅ TAMAMLANDI (2026-09-05)

**Yapılan:** WhisperKit SPM ile eklendi (`argmaxinc/WhisperKit`, `0.18.0`
çözümlendi). `Core/Transcriber.swift` — model bir kez yüklenip bellekte
tutuluyor. Model: **`openai_whisper-large-v3-v20240930_turbo`** (632MB) —
kısa isim `"large-v3-turbo"` repo'da eşleşmiyordu, tam model klasör adı
kullanılmalı. `Core/TextDelivery.swift` — panoya yaz + (Faz 5'ten öne
çekilen) otomatik ⌘V. `⌃⌥V` son transkripti tekrar teslim ediyor.

**Kritik bulgu — dersler.md md.6 WhisperKit için eksik çıktı:**
`language: nil` bırakmak WhisperKit'te TEK BAŞINA otomatik algılama
yapmıyor. Varsayılan `usePrefillPrompt=true` olduğu için `detectLanguage`
de varsayılan `false`'a düşüyor ve dil belirtilmezse **İngilizce'ye
sabitleniyor**. Çözüm: `DecodingOptions(language: nil, detectLanguage:
true)` açıkça verilmeli. (dersler.md md.6, orijinal Python `openai-whisper`
kütüphanesi için doğruydu, WhisperKit'in Swift sarmalayıcısı farklı
varsayılan seçmiş.)

**Test bulgusu:** "base" modelle sessiz/çok kısa girişte tamamen yanlış
dilde saçma metin üretti (halüsinasyon — Arapça harflerle anlamsız
çıktı). `large-v3-turbo`'ya geçilince aynı sessiz girişte boş string
döndü (doğru davranış). **Ders:** küçük modeller zayıf sinyalde
halüsinasyon riski taşıyor, teslim modeli asla `base` olmamalı.

**Gerçek konuşmayla test edildi:** Türkçe bir tekerleme
("Bir çıvciv, bir çıvciv ve gel veralar berber dükkânı açalım demiş.")
`large-v3-turbo` ile doğru ve anlaşılır çıktı, panoya yazıldı.

**Odak testi geçti:** Claude Code terminaline odaklıyken dikte edildi,
otomatik yapıştırma metni doğru yere düşürdü — odak hiç kaçmadı (henüz
HUD olmadığı için zaten çalınacak bir şey yok, ama Faz 5'in odak
gereksinimi de böylece dolaylı doğrulanmış oldu).

**HUD paneli yazıldı ve test edildi:** `UI/HUDContentView.swift` (SwiftUI
içerik) + `UI/HUDController.swift` (`NSPanel`, bölüm 6.3'e uygun:
300×72pt, `.ultraThinMaterial`, `.nonactivatingPanel`,
`ignoresMouseEvents`). Kayıt durumunda kırmızı nabız noktası + 16 çubuklu
gerçek zamanlı dalga formu (RMS'ten, `AudioRecorder.onLevelUpdate` ile
beslenen) + süre sayacı — ekran görüntüsüyle doğrulandı, spesifikasyona
görsel olarak uyuyor. Transkripsiyon durumu ("Yazıya çevriliyor…" +
progress indicator) da ekran görüntüsüyle doğrulandı. Sonuç/hata
durumları aynı SwiftUI deseniyle yazıldı ama 1.5sn'lik pencere +
150ms pano geri yükleme çok dar olduğu için ekran görüntüsüyle
yakalanamadı — kod incelemesiyle güvenilir, ayrı bir doğrulama borcu
olarak not edildi.

**Menü çubuğu ikonu da bölüm 6.1'e göre dinamikleşti**
(`UI/MenuBarIconController.swift`): boşta/kayıtta (kırmızı, nabız)/
transkribe (accent) durumları arasında geçiş yapıyor, hata durumunda
turuncu ikonla 3sn gösterip boşa dönüyor. "LLM temizliyor" ve "Model
iniyor" durumları Faz 3'e ertelendi (henüz Ollama/indirme entegrasyonu
yok).

**Basitleştirmeler (bilerek, ileride gözden geçirilebilir):** Panel
giriş/çıkış animasyonu spec'teki `.spring` yerine anlık gösterim/gizleme
(görsel fark küçük). Transkripsiyon ikonunda `.variableColor.iterative`
sembol efekti yerine sabit accent renk (AppKit'te NSButton üzerinde bu
efekti denemedim, riske değmedi).

**Çıkış kriteri (orijinal metin, referans için):** Terminale odaklıyken
konuş → metin terminale düşüyor, odak hiç kaçmadı ✅. TR/EN karışık bir
cümle doğru çıkıyor ✅ (Türkçe test edildi; TR/EN karışık cümle ayrıca
test edilmedi, bkz. bölüm 15). **Sistem şu haliyle gerçekten
kullanılabilir.**

---

### Faz 3 — Kalite katmanı ✅ TAMAMLANDI (2026-09-05)

**Sözlük:** `Resources/vocabulary.json` — `hints` (Whisper'a ipucu
listesi, şu an sadece veri olarak duruyor) + `corrections` (regex bazlı
düzeltme, birkaç makul tahminle dolduruldu: "klod kod"→"Claude Code",
"olama"→"Ollama" vb — gerçek kullanım verisi birikince güncellenmeli).
`Core/TextCleaner.applyDictionary()` transkript üzerinde case-insensitive
bul-değiştir uyguluyor.

**Basitleştirme (bilerek):** Whisper'a metin tabanlı "initial prompt"
verme özelliği atlandı — WhisperKit bunu token ID'leri üzerinden istiyor
(ham metin promptu yok), tokenizer'a inmek gerekiyordu, riske değmedi.
`hints` alanı JSON'da duruyor ama şu an kullanılmıyor.

**Ollama temizleme + güvenlik ağı:** `Core/TextCleaner.swift` —
`POST localhost:11434/api/generate`, `qwen2.5:3b`, plandaki sistem
promptuyla birebir. Güvenlik ağı üç eşiği de uyguluyor (kelime kaybı
>%20, benzerlik <%70 — Levenshtein tabanlı, zaman aşımı 2.0sn).

**Gerçek testte üçü de gözlemlendi:**
- Ollama soğuk başlangıçta 2sn'yi aştı → zaman aşımı yakalandı, ham
  transkript kullanıldı (`history.json`'da `wasLLMCleaned: false`
  doğrulandı).
- Isındıktan sonra başarılı temizleme oldu (`wasLLMCleaned: true`) —
  ama LLM bir seferinde "İyi misin?"i "İyi misiniz?"e çevirerek
  talimata rağmen resmiyet değiştirdi; güvenlik ağı bunu yakalamadı
  (kelime sayısı/benzerlik eşiklerini geçti). Küçük bir stil sapması,
  anlamı bozmuyor — bilinen bir LLM itaatsizliği, kabul edilebilir.
- Bir seferinde güvenlik ağı LLM çıktısını gerçekten eledi (benzerlik/
  kelime testi başarısız), ham transkript korundu — güvenlik ağı
  fiilen çalıştığı kanıtlandı.

**VAD:** `AudioRecorder.onLevelUpdate` (RMS, Faz 2 HUD ile paylaşılan
aynı mekanizma) → `AppState.handleLevelForVAD`. Gerçek testte hiç
kısayola dokunulmadan, sadece sessizlik bırakılarak kayıt otomatik
durduruldu ve doğru şekilde boş transkript üretti. Menüden "Sessizlikte
otomatik dur" onay kutusuyla açılıp kapatılabiliyor.

**Geçmiş:** `Core/HistoryStore.swift` — son 50 kayıt,
`~/Library/Application Support/AudioPromt/history.json`. Menüde "Geçmiş"
alt menüsü (son 10, ⚠ işareti LLM'in elendiğini gösteriyor), tıklayınca
`AppState.pasteHistoryEntry()` ile tekrar teslim ediyor. "Geçmişi
temizle" menü öğesi de var.

**Basitleştirme (bilerek):** PLAN.md bölüm 6.4'teki tam 5 sekmeli
Ayarlar penceresi (Genel/Model/Temizleme/Sözlük/Kısayollar) **yazılmadı.**
Hiçbir fazın çıkış kriteri bunu doğrudan şart koşmuyordu — Faz 3'ün kendi
madde listesi zaten "menüden erişilir" diyordu (Geçmiş) ve "ayarlanabilir"
diyordu (VAD), ayrı bir pencere şart değildi. Bunun yerine ilgili
kontroller (LLM temizle aç/kapa, VAD aç/kapa, Geçmişi temizle, Geçmiş
listesi) doğrudan menüye eklendi. Sözlük düzenleme arayüzü, model/dil/
mikrofon seçimi, eşik ayarları (kelime kaybı/benzerlik/zaman aşımı) ve
kısayol yeniden atama arayüzü **henüz yok** — kod içinde sabit değerler
olarak duruyor, gerekirse elle `TextCleaner.Thresholds`/`vocabulary.json`
düzenlenerek değiştirilebilir.

**Çıkış kriteri karşılandı:** Uzun ve dolgu kelimeli konuşma temiz çıktı
✅ (bir seferinde). Güvenlik ağının LLM'i kasten/yanlışlıkla bozan
çıktıyı elediği, ham transkriptin korunduğu gerçek testte doğrulandı ✅.

---

### Faz 4 — Kalıcılık: imza ve TCC ✅ TAMAMLANDI (2026-09-05)

**Önceki iki projeyi öldüren duvar gerçekten aşıldı.** Fatih Faz 2
testleri sırasında sabırsızlandı ("ses kaydı otomatik yazılsın istiyorum,
ayrı kısayola basmak istemiyorum") ve Faz 5'in otomatik yapıştırma
özelliğini hemen istedi — bu da Faz 4'ün asıl testini erkene çekmeye
zorladı, plan sırası dışına çıkıldı ama sonuç net:

1. Fatih Sistem Ayarları → Erişilebilirlik'ten Audio Promt'a manuel izin
   verdi.
2. Otomatik yapıştırma (Faz 5 madde 1-2, aşağıda) hemen çalıştı — gerçek
   konuşmayla test edildi, doğru metin doğru yere düştü.
3. **Kararlılık testi:** kodda değişiklik yapılıp rebuild edildi
   (CDHash `cf779127...` → `3bc9928e...`, gerçek bir farklı derleme),
   izin **yeniden verilmeden** otomatik yapıştırma yine çalıştı.
4. **Sonuç: Yol 1 (kendinden imzalı kararlı sertifika, Faz 0'da kurulan)
   hem Mikrofon hem Erişilebilirlik izninde rebuild'lere karşı kalıcı.**
   Yol 2 (kaçış planı) hiç gerekmedi.

Fatih'in gözlemi: küçük bir gecikme var (kabul edilebilir), ilk deneme
daha yavaştı (WhisperKit modelinin süreç belleğine yeniden yüklenmesi —
her `open` sonrası beklenen davranış, bkz. bölüm 11 madde 2).

**Çıkış kriteri karşılandı:** İzin yeniden derlemelerden sağ çıktı.
Yol 2'ye hiç gerek kalmadı — tccutil reset dahi kullanılmadı.

---

### Faz 5 — Otomatik yapıştırma ve cila ✅ TAMAMLANDI (2026-09-05)

**Madde 1-2 (Faz 4 testiyle birlikte erken uygulandı):**
`TextDelivery.requestAccessibilityTrustIfNeeded()` (açılışta izin
kaydını tetikler) + `TextDelivery.deliver(_:)` (izin varsa: eski pano
sakla → yaz → `CGEvent` ile ⌘V → 150ms sonra pano geri yüklenir; izin
yoksa sessizce panoya yazmakla yetinir). `⌃⌥V` ve geçmişten tekrar
teslim de aynı yolu kullanıyor. Gerçek konuşmayla ve rebuild sonrası
test edildi (bkz. Faz 4).

**Madde 3 — Sağlık kontrolü:** `Core/PushToTalkManager.swift` içinde
`CGEventTap` artık gerçekten kullanılıyor (basılı-tutma için, aşağıda).
5 saniyede bir `CGEvent.tapIsEnabled()` kontrol ediliyor, kapalıysa
`tapEnable(enable: true)` ile yeniden açılıyor.

**Madde 4 — Basılı-tutma (push-to-talk):** Sağ Option (keycode 61),
`CGEventTap` ile `flagsChanged` olaylarını dinliyor (`.listenOnly`,
Erişilebilirlik izni gerektiriyor, yoksa sessizce devre dışı kalıp
`⌃⌥1` aç/kapa yolu bozulmadan çalışmaya devam ediyor). **Fatih
tarafından fiziksel olarak test edildi ve doğrulandı** — Sağ Option
basılı tutulup konuşulduğunda, hiç `⌃⌥1`'e dokunmadan doğru transkript
üretildi.

**Madde 5 — Girişte otomatik başlatma:** `Core/LaunchAtLogin.swift`,
`SMAppService.mainApp.register()`. Açılışta çağrılıyor, kullanıcıya
açık bir aç/kapa anahtarı yok (basitleştirme — hiçbir çıkış kriteri
bunu şart koşmuyordu). `sfltool dumpbtm` ile kayıt doğrulandı
(`com.fatih.audiopromt` Background Task Management veritabanında
görünüyor).

**Çıkış kriteri karşılandı:** Konuş → metin kendiliğinden yerine düşüyor
✅. Pano eski haline dönüyor ✅ (kodda var, davranışsal olarak doğru
çalıştığı gözlemlendi — otomatik yapıştırmalar arka arkaya sorunsuz
tekrarlandı, pano bozulmadı). Basılı-tutma ayrı bir tetikleyici olarak
çalışıyor ✅. Girişte otomatik başlatma kaydı doğrulandı ✅ (asıl "reboot
sonrası gerçekten açılıyor mu" testi macOS'u yeniden başlatmayı
gerektirir, yapılmadı — kayıt mekanizması doğru çalıştığından makul
güvenle kabul edildi).

---

## 6. Arayüz tasarım şartnamesi

### 6.1 Menü çubuğu ikonu (`NSStatusItem`)

Durumlar — SF Symbols, `.symbolRenderingMode(.hierarchical)`:

| Durum | Simge | Renk | Animasyon |
|---|---|---|---|
| Boşta | `mic` | `.secondaryLabelColor` | yok |
| Kayıtta | `mic.fill` | sistem kırmızısı | 1.2 sn'lik nabız (opaklık 1.0 ↔ 0.5) |
| Transkribe | `waveform` | accent rengi | `.variableColor.iterative` |
| LLM temizliyor | `sparkles` | accent rengi | hafif parıltı |
| Hata | `exclamationmark.triangle.fill` | sistem turuncusu | 3 sn sonra boştaya döner |
| Model iniyor | `arrow.down.circle` | `.secondaryLabelColor` | yüzde ikonun yanında |

Sol tık → menüyü aç. Sağ tık → hızlı kayıt aç/kapa (kısayola alternatif).

### 6.2 Menü içeriği

```
  ● Kayıt başlat                              ⌃⌥1
  ↻ Son metni yapıştır                        ⌃⌥V
  ─────────────────────────────────────────────────
  Geçmiş ▸    (son 10, her biri ilk 40 karakter)
              ⚠ işareti = LLM temizliği elendi
              tıkla → panoya kopyala
              en altta "Tümünü göster…"
  ─────────────────────────────────────────────────
  ✓ LLM ile temizle                           ⌃⌥C
  ✓ Sessizlikte otomatik dur
  Mikrofon ▸  (dahili / ROG Strix Go / …)
  ─────────────────────────────────────────────────
  Ayarlar…                                       ⌘,
  Audio Promt Hakkında
  Çık                                            ⌘Q
```

### 6.3 HUD paneli — dikte sırasında

**Yerleşim:** ekranın alt-ortası, alt kenardan 24 pt yukarıda, aktif
ekranda. Boyut 300×72 pt, köşe yarıçapı 16 pt.

**Malzeme:** `.ultraThinMaterial` arka plan + 0.5 pt kenarlık
(`.separatorColor`) + yumuşak gölge (yarıçap 20, opaklık 0.15).

**Giriş/çıkış:** 180 ms, opaklık 0 → 1 + aşağıdan 8 pt yukarı kayma,
`.spring(response: 0.3, dampingFraction: 0.8)`.

**Kayıt halindeyken içerik (soldan sağa):**
- 8 pt boşluk
- Kırmızı nokta, 8 pt çap, nabız animasyonlu
- **Dalga formu:** 16 dikey çubuk, her biri 3 pt genişlik, 2 pt aralık,
  yükseklik 4–40 pt arası RMS'e göre, köşeler yuvarlak. Güncelleme 30 Hz.
  Renk: accent. Sessizlikte hepsi 4 pt'de yatay çizgi olur
- **Süre sayacı:** `0:07` monospaced digit, `.secondaryLabelColor`
- 8 pt boşluk

**Transkripsiyon halinde:** dalga formu yerini belirsiz ilerleme çubuğuna
bırakır + "Yazıya çevriliyor…"

**Sonuç halinde (1.5 sn görünüp kaybolur):**
- ✓ yeşil onay ikonu
- Metnin ilk 40 karakteri, tek satır, sonu `…`
- v1'de sağda: **`⌘V`** rozeti (yuvarlak köşeli, `.quaternaryLabelColor`
  zemin) — "şimdi yapıştır" hatırlatması
- v2'de sağda: "yapıştırıldı" yazısı

**Hata halinde:** turuncu ⚠ + kısa mesaj, 3 sn, tıklanınca ayrıntı.

**Pazarlıksız:** `.nonactivatingPanel`, `canBecomeKey = false`. HUD
tıklanabilir olmayacak (fare olaylarını geçirir, `ignoresMouseEvents`),
böylece altındaki pencereyle etkileşim bozulmaz.

### 6.4 Ayarlar penceresi ✅ TAMAMLANDI (2026-09-05)

("Menü yeterli" kararı Fatih tarafından iptal edildi — plan orijinal
haline döndü, tam şartname aşağıdaki gibi inşa edildi.)

`UI/SettingsView.swift` — 5 sekme, `TabView` yerine segmented `Picker`
kullanıldı (TabView'ın sekme çubuğu bu barındırma şeklinde — plain
`NSHostingController` içinde, SwiftUI `App`/`Settings` scene'i olmadan —
hiç görünmüyordu; segmented Picker + manuel `switch` güvenilir çözüm
oldu). Pencere **680×640pt, yeniden boyutlandırılabilir** (minimum
560×480) — orijinal "520×420, boyutlandırılamaz" kararı, Fatih içerik
taştığını görünce büyütülüp esnek yapıldı.

**Liquid Glass (2026-09-05, Fatih'in isteğiyle):** macOS 26'nın yeni
tasarım diline uysun diye pencere gerçek cam malzemeyle inşa edildi —
`NSVisualEffectView` (`.hudWindow`, `.behindWindow` blend) + saydam
başlık çubuğu (`titlebarAppearsTransparent`), SwiftUI içeriği üstte
şeffaf arka planla oturuyor. Düz koyu bir arka plan (ör. kod editörü)
üzerinde belirgin görünmüyor ama masaüstü/renkli pencereler arkasındayken
bulanık cam etkisi net (ekran görüntüsüyle doğrulandı). `.glass`/
`.glassProminent` buton stilleri kullanıldı — bu, `Package.swift`'in
minimum sürümünü `.v14`'ten **`.v26`'ya yükseltmeyi gerektirdi** (proje
zaten sadece Fatih'in kendi makinesinde çalışacağı için sorun değil).

**Font hiyerarşisi (2026-09-05, Fatih'in isteğiyle):** Her sekmenin
başına büyük kalın başlık (`.title2.weight(.bold)`) eklendi, gövde
metni `.body`, ikincil açıklamalar `.footnote`/`.subheadline` — hepsi
sistem fontu (SF Pro) ama artık tek tip değil, visual-style.md'deki
tipografi kuralına uygun.

**visual-style.md** oluşturuldu (proje kökünde) — `visual-style` skill'i
ile, kararları belgeliyor: sistem accent rengi, sistem fontu + boyut
hiyerarşisi, tam native pencere hissi + Liquid Glass malzeme.

Orijinal şartname (aşağıda) referans olarak duruyor; SwiftUI `Settings`
sahnesi kullanılmadı (bu proje `NSApplication`/manuel `main.swift` ile
çalışıyor, SwiftUI `App` yaşam döngüsünde değil).

**Sekme "Genel"**
- `Toggle` — Girişte başlat
- `Toggle` — Sessizlikte otomatik dur → açıkken alt `Slider` 1.0–5.0 sn,
  varsayılan **2.0 sn**
- `Slider` — Sessizlik eşiği (hassasiyet), sağında canlı mikrofon
  seviyesi çubuğu ki Fatih doğru yeri görsün
- `Picker` — Maksimum kayıt süresi: 30 sn / 60 sn / **120 sn** / 5 dk
- `Picker` — HUD konumu: Alt orta (varsayılan) / Üst orta / Menü
  çubuğunun altı / Kapalı
- `Button` **"Geçmişi temizle"** (kırmızı, onay istemeli) — bölüm 12
  madde 1: dikte geçmişi düz JSON olarak diskte duruyor, kullanıcı
  istediğinde tamamen silebilmeli

**Sekme "Model"**
- `Picker` — Whisper modeli: `base` (hızlı, ~150 MB) /
  `large-v3-turbo` (**varsayılan**, ~600 MB) / `large-v3` (en iyi, ~1.5 GB)
- İndirme durumu + `Button` "İndir" / "Sil"
- `Picker` — Dil: **Otomatik algıla (önerilen)** / Türkçe / İngilizce
  → altında açıklama metni: "Otomatik, Türkçe–İngilizce karışık
  konuşmayı cümle cümle doğru ayırır."
- `Picker` — Mikrofon cihazı: Sistem varsayılanı / dahili / ROG Strix Go…

**Sekme "Temizleme"**
- `Toggle` — Ollama ile temizle (varsayılan **açık**)
- `TextField` — Ollama adresi, varsayılan `http://localhost:11434`
- `Picker` — Model: kurulu Ollama modelleri listesi (`/api/tags`'ten)
- Bağlantı durumu: ● yeşil "bağlı — qwen2.5:3b hazır" / ● kırmızı
  "Ollama çalışmıyor" + `Button` "Yeniden dene"
- `TextEditor` — Sistem promptu (ileri düzey, katlanmış `DisclosureGroup`
  içinde), `Button` "Varsayılana dön"
- **Güvenlik eşikleri** (`DisclosureGroup`):
  - `Stepper` — Kelime kaybı üst sınırı: **%20**
  - `Stepper` — Benzerlik alt sınırı: **%70**
  - `Stepper` — Zaman aşımı: **2.0 sn**
  - Altında açıklama: "Bu sınırlar aşılırsa temizlenmiş metin atılır ve
    ham transkript kullanılır. Küçük modeller bazen çeviri yapıyor ya da
    harf yutuyor."

**Sekme "Sözlük"**
- İki sütunlu `Table`: "Duyulan" → "Yazılacak"
- `Button` **+** / **−** altta
- `Toggle` — Terimleri Whisper'a ipucu olarak da ver (varsayılan açık)
- Başlangıç satırları hazır gelir (Faz 3'teki başlangıç setiyle birebir
  aynı): Claude Code, Ollama, Whisper, Xcode, Swift, React, commit,
  repo, terminal, Fatih

**Sekme "Kısayollar"**
- Her satır tıklanınca tuş bekleyen bir `KeyRecorder` alanı
- Çakışma tespiti: başka bir uygulama o kombinasyonu kullanıyorsa
  kırmızı uyarı
- Faz 5'ten sonra ek: `Picker` — Tetikleme modu: **Aç/kapa** / Basılı tut
  → "Basılı tut" seçilirse tuş seçici: Sağ Option / Sağ Command +
  altında uyarı: "Basılı tutma, Erişilebilirlik izni gerektirir."

### 6.5 İlk açılış (onboarding) ✅ TAMAMLANDI (2026-09-05)

("Menü yeterli" kararı iptal edildi, bu da yazıldı — `UI/OnboardingView.swift`,
gerçek testte doğrulandı: mikrofon izni butonu, "Anladım" ile bir daha
görünmüyor.) dersler.md
md.7'deki VoiceInk dersi: **onboarding sihirbazı yapma.** Uygulama
açılır açılmaz çalışır durumda olur. Tek istisna, tek bir karşılama
penceresi:

1. "Audio Promt çalışıyor. `⌃⌥1` ile konuşmaya başla."
2. Mikrofon izni butonu (tek tık)
3. Model indirme ilerleme çubuğu
4. `Button` "Anladım" → kapanır, bir daha görünmez

Hiçbir adım atlanamaz değil, hiçbir durum kilitli değil. Ayarların hepsi
her zaman erişilebilir.

---

## 7. Kısayol haritası — kesin kararlar

| Kısayol | İşlev | Neden bu tuş |
|---|---|---|
| **⌃⌥1** (2026-09-05: `⌃⌥Space`'ten değiştirildi, Fatih'in kararı — "berbat" bulundu) | Kayıt aç/kapa | Fn/Globe denenmedi bile: Carbon `RegisterEventHotKey` modifier olarak Fn'i desteklemiyor, üstelik dersler.md md.2 zaten üçüncü parti klavyede Fn'in çalışmadığını kanıtlamıştı. ⌃⌥1 test edildi ve çalıştığı doğrulandı — Terminal/Spotlight ile çakışmıyor |
| **⌃⌥V** | Son metni tekrar panoya koy | Wispr Flow'un "Paste last transcript" karşılığı. V harfi yapıştırmayı çağrıştırır |
| **Esc** | Kaydı iptal et, at | Sadece kayıt sırasında kaydedilir, kayıt bitince serbest bırakılır — böylece Esc başka zaman çalınmaz |
| **⌃⌥C** | LLM temizlemeyi aç/kapa | Kod dikte ederken temizlemeyi kapatmak isteyeceksin |
| **⌘,** | Ayarlar | macOS standardı |
| Sağ Option (basılı tut) | Push-to-talk | **Faz 5**, Erişilebilirlik izni sonrası. dersler.md md.2: K250'de Globe/Fn çalışmaz, sağ modifier'lar çalışır |

**Faz 1'in ilk işi:** bu kombinasyonların gerçekten boşta olduğunu
doğrulamak. Çakışma çıkarsa yedekler: `⌃⌥D`, `⌃⇧Space`.

---

## 8. Proje dosya yapısı

Tek klasör — plan/araştırma dosyaları ve kod aynı seviyede, `src/` gibi
ayrı bir katman yok (2026-09-05 kararı):

```
~/audio promt/
├── CLAUDE.md              (AGENTS.md → symlink)
├── PLAN.md                (bu dosya)
├── README.md              kullanım, kurulum, Gatekeeper/xattr adımı, gizlilik notu
├── research/
│   ├── dersler.md
│   └── topluluk-arastirmasi.md
├── Package.swift              SPM manifest, IDE gerektirmez (WhisperKit bağımlılığı)
├── Package.resolved
├── Makefile                   build / bundle / sign / run / clean
├── Sources/AudioPromt/
│   ├── main.swift             uygulama girişi, LSUIElement, tek-örnek koruması
│   ├── AppDelegate.swift      NSStatusItem, menü, icon/HUD bağlama, Settings/Onboarding pencereleri
│   ├── AppState.swift         merkezi durum makinesi (idle/starting/recording/transcribing)
│   ├── Core/
│   │   ├── HotKeyManager.swift    Carbon RegisterEventHotKey (⌃⌥1, ⌃⌥V, ⌃⌥C, Esc — kayıt+kaldır)
│   │   ├── AudioRecorder.swift    AVAudioEngine, dönüşüm, RMS callback (HUD+VAD paylaşır)
│   │   ├── Transcriber.swift      WhisperKit sarmalayıcı, model adı çağrı başına, prewarm()
│   │   ├── TextCleaner.swift      sözlük + Ollama + güvenlik ağı (Levenshtein benzerlik)
│   │   ├── TextDelivery.swift     pano (v1) + CGEvent ⌘V (v2, Erişilebilirlik varsa)
│   │   ├── HistoryStore.swift     son 50 kayıt, JSON kalıcılık
│   │   ├── SoundFeedback.swift    Ping/Pop (kayıt başlama/bitme)
│   │   ├── PushToTalkManager.swift  basılı-tutma tuşu (Ayarlar'dan seçilebilir) + sağlık kontrolü
│   │   ├── LaunchAtLogin.swift    SMAppService.mainApp.register()
│   │   ├── Preferences.swift      tüm ayarlar için tek kaynak, UserDefaults tabanlı ObservableObject
│   │   ├── AudioDeviceUtility.swift  CoreAudio giriş cihazı listesi (mikrofon seçimi)
│   │   └── MicLevelMonitor.swift  Ayarlar'daki canlı mikrofon seviyesi için ayrı AVAudioEngine
│   └── UI/
│       ├── HUDContentView.swift      SwiftUI içerik (recording/transcribing/result/error)
│       ├── HUDController.swift       NSPanel yönetimi, .nonactivatingPanel
│       ├── MenuBarIconController.swift  durum bazlı ikon (idle/recording/transcribing/error)
│       ├── SettingsView.swift        5 sekmeli Ayarlar penceresi (Genel/Model/Temizleme/Sözlük/Kısayollar)
│       └── OnboardingView.swift      ilk açılış karşılama penceresi
├── Resources/
│   ├── Info.plist
│   ├── vocabulary.json       sözlük (hints + corrections)
│   └── AppIcon.icns          uygulama ikonu
└── Tests/AudioPromtTests/
```

**Not (2026-09-05):** `WaveformView` ayrı dosya değil, `HUDContentView.swift`
içinde `private struct` olarak duruyor.

---

## 9. Riskler ve kaçış planları

| Risk | Olasılık | Kaçış planı |
|---|---|---|
| `RegisterEventHotKey` de izin isterse | Düşük | Faz 1'in ilk saatinde anlaşılır. O zaman: menü çubuğu ikonuna tıklama tetikleyici olur (izinsiz çalışır), kısayol Faz 5'e ertelenir |
| Kararlı imza tutmazsa (Erişilebilirlik) | Orta | Kaçış planı: manuel ⌘V ile kalıcı yaşa (ücretli yol yok). Sistem her durumda kullanılabilir |
| WhisperKit büyük modelde yavaş | Düşük | `large-v3-turbo` M-serisinde gerçek zamandan hızlı. Yavaşsa `base`'e düş |
| Ollama TR'yi EN'e çeviriyor | **Yüksek** (bir kez yaşandı) | Güvenlik ağı zaten bunun için var. Sürekli eleniyorsa temizlemeyi tamamen kapat, sözlük yeter |
| HUD odak çalıyor | Orta | Faz 2 çıkış kriteri. Çözülemezse HUD'u tamamen kapat, sadece menü çubuğu ikonu durum gösterir |
| Model indirmesi büyük/yavaş | Düşük | Geliştirmede `base` kullan, turbo'yu arka planda indir |

---

## 10. Değerlendirilip elenen alternatifler

- **macOS yerleşik dikte** — TR/EN karışığında zayıf, terminale
  yazarken güvenilmez, özelleştirilemiyor.
- **Raycast eklentisi** — Raycast'in kendi izinlerine bağımlı, pencere
  odağını alıyor, terminale yazma senaryosunda uygun değil.
- **Electron/Tauri uygulama** — dersler.md md.1'deki TCC sorununun aynısını
  farklı bir kılıkta getirir, üstelik 100 MB+ paket.
- **Python + PyObjC** — bir kez denendi, TCC duvarına çarptı (dersler.md
  md.1, md.3, md.4). Tekrar denemek aynı sonucu verir.
- **VoiceInk fork** — bir kez denendi, onboarding kontrolü elimizden aldı
  (dersler.md md.7).
- **Bulut STT (Whisper API, Deepgram)** — çalışır ama ses dışarı çıkar,
  gecikme ekler, ücretli. Offline zaten yeterince iyi.

---

## 11. Eşzamanlılık ve durum makinesi (kodlamaya başlamadan önce sabitlenmeli)

Bu sistemin gerçek "sonradan büyük sıkıntı çıkarır" riski TCC değil —
o zaten katman katman ele alındı. Asıl risk, kayıt/transkripsiyon/
temizleme/teslim zincirinde **durum yönetimi gevşek bırakılırsa** ortaya
çıkar: hızlı art arda kısayol basma, ikinci bir kayıt üstüste binmesi,
model her seferinde yeniden yüklenmesi gibi sorunlar geç fark edilir ve
o zaman her katmana yayılmış olur. Baştan sabitleniyor:

1. **Tek durum makinesi, `AppState` içinde:**
   `idle → recording → transcribing → cleaning → delivering → idle`.
   Kısayol sadece `idle ↔ recording` geçişini tetikler. `transcribing`/
   `cleaning`/`delivering` sırasında gelen kısayol **yok sayılır** (HUD'da
   kısa bir "meşgul" titreşimiyle görünür geri bildirim verilir,
   sessizce kaybolmaz).
2. **WhisperKit modeli bir kez yüklenir.** Uygulama açılışında (veya ilk
   kayıttan hemen sonra) lazy-load edilir ve bellekte tutulur — her
   transkripsiyon çağrısında yeniden yüklenmez. Faz 2'nin çıkış kriterine
   şu eklenir: art arda 3 dikte, üçünde de gecikme farkı yok.
3. **Tek örnek (single instance) koruması.** `NSRunningApplication` ile
   açılışta aynı bundle id'den başka çalışan var mı kontrol edilir, varsa
   yeni süreç onu öne çıkarıp kendi kapanır. `LSUIElement` uygulamalarda
   Dock'tan fark edilmediği için kazara çift açılma ihtimali normalden
   yüksek (özellikle Faz 6'da başkalarına dağıtılınca).
4. **Ollama çağrısı iptal edilebilir olmalı.** Kullanıcı temizleme
   sürerken yeni bir kayıt başlatmaya çalışırsa (durum makinesi bunu zaten
   engelliyor ama) HTTP isteğinin kendisi de 2 sn zaman aşımından önce
   `URLSession` task iptaliyle sonlandırılabilmeli — asılı kalan istek
   olmamalı.

**Çıkış kriteri (Faz 2'ye ek):** Kısayola üst üste hızlı 5 kez basılınca
uygulama çökmüyor, kayıt üstüste binmiyor, HUD tutarlı bir durum
gösteriyor.

---

## 12. Güvenlik ve dağıtım (başkalarına verilecek olması gözetilerek)

**Tehdit modeli özetle iyi durumda: sunucu yok, bulut yok, telemetri
yok.** Tüm işlem (ses yakalama, transkripsiyon, LLM temizleme) tek
makinede kalıyor. Uzaktan "hacklenecek" bir sunucu bileşeni **hiç yok** —
bu, tasarımın kendiliğinden getirdiği en büyük güvenlik avantajı.

1. **Veri gizliliği.** Geçmiş (`HistoryStore`) düz JSON, diskte,
   `~/Library/Application Support/AudioPromt/`. Fatih'in veya
   arkadaşlarının dikte ettiği her şey (yanlışlıkla söylenen şifre,
   özel bilgi dahil) burada düz metin duruyor. Şifreleme şart değil
   (tek kullanıcılı yerel makine, App Sandbox yok) ama:
   - Ayarlar'da **"Geçmişi temizle"** butonu olmalı (şu an planda yok,
     ekleniyor — bkz. bölüm 6.4).
   - README/karşılama ekranında tek cümlelik açık uyarı: "Dikte
     ettiğiniz metinler sadece bu bilgisayarda saklanır, hiçbir yere
     gönderilmez."
2. **Ollama ağ maruziyeti.** Ollama varsayılan olarak sadece
   `127.0.0.1:11434`'te dinler — dışarıdan erişilemez. **Kritik kural:**
   `OLLAMA_HOST=0.0.0.0` gibi bir ortam değişkeniyle bunu asla dışarı
   açma (bazı kurulum rehberleri bunu öneriyor, bizim için gereksiz ve
   tehlikeli — aynı ağdaki biri o zaman yerel LLM'e istek atabilir).
   Varsayılanı değiştirmeden bırakmak yeterli.
3. **Bağımlılık güveni.** WhisperKit (argmaxinc, aktif bakımlı, açık
   kaynak) ve Ollama (açık kaynak, yaygın kullanılan) — ikisi de bilinen
   kötü niyetli geçmişi olmayan, popüler projeler. Model dosyaları
   WhisperKit'in resmi Hugging Face deposundan iniyor, elle indirilen
   şüpheli bir ikili yok.
4. **Dağıtım/Gatekeeper (arkadaşlara verirken asıl fark eden nokta).**
   Uygulama Apple tarafından notarize edilmeyecek (ücretli yol yok).
   Bir arkadaşın Mac'inde ilk açılışta Gatekeeper **"Tanımlanamayan
   geliştirici"** uyarısı verecek — bu bir güvenlik açığı değil, sadece
   Apple'ın imzasız uygulamalara varsayılan tepkisi. Çözümü tek seferlik:
   Finder'da sağ tık → Aç, ya da `xattr -d com.apple.quarantine
   AudioPromt.app`. Bu adım README'ye yazılacak.
5. **Her arkadaşın izinleri kendi makinesinde ayrı.** TCC (Mikrofon,
   Erişilebilirlik) kişi başına, makine başına — biri izin verince
   başkasınınki etkilenmez, paylaşılan bir zafiyet oluşmaz.
6. **Saldırı yüzeyi olarak kalanlar (düşük risk, bilgi amaçlı):**
   global kısayol dinleyicisi (kullanıcı girdisi çalıştırılmıyor, sadece
   tetikleyici), ve dikte edilen metnin Ollama'ya prompt olarak gitmesi
   (teorik prompt injection — ama sonucu yalnızca temizlenmiş metin,
   kod çalıştırma değil; güvenlik ağı zaten anormal çıktıyı atıyor).
   İkisi de gerçek bir yetki yükseltme veya veri sızdırma yolu açmıyor.
7. **Otomatik güncelleme yok (kasıtlı).** Uzaktan kod güncelleme
   mekanizması eklenmedikçe tedarik zinciri saldırısı (kötü niyetli
   güncelleme) için bir giriş noktası da yok. İleride otomatik güncelleme
   eklenirse bu bölüm yeniden gözden geçirilmeli.

---

## 13. Kesin kurallar (Fatih aksini söyleyene kadar)

- **Otomatik `git push` yok.** Lokal commit atılır, uzağa gönderme sadece
  Fatih söyleyince.
- Bu projenin teknik detayları Jarvis'in "beyin" hafıza sistemine otomatik
  yazılmaz — hepsi bu klasörde kalır.
- **Proje kökü kesin olarak `~/audio promt/`.** Başka hiçbir yerde
  (MehmetOS kasası dahil) kopya tutulmaz.
- `CLAUDE.md` + `AGENTS.md` (symlink) proje kökünde.

---

## 14. Fatih'in karar vermesi gereken noktalar

Bunlar teknik değil, tercih kararı — ben veremem:

1. ~~Faz 4, Yol 2: $99/yıl Apple Developer Program~~ — **tamamen elendi
   (2026-09-05).** Ücretli hiçbir yol yok, kullanılmayacak. Faz 4'te
   kendinden imzalı sertifika (ücretsiz) tutmazsa tek seçenek Yol 2:
   sistem kalıcı olarak manuel ⌘V ile çalışır — bu bir başarısızlık
   değil, kabul edilebilir son durum.
2. ~~Uygulama adı~~ — **kesinleşti: "Audio Promt"**, bundle id
   `com.fatih.audiopromt` (2026-09-05). Faz 0'dan sonra değiştirilirse
   bundle id değişir, izinler sıfırlanır — o yüzden bundan sonra
   değiştirmemek gerekir.
3. ~~⌃⌥Space uygun mu?~~ — **kesinleşti: `⌃⌥1`** (2026-09-05, "berbat"
   bulunan `⌃⌥Space`'in yerine). Fn tuşu istendi ama denenmedi bile:
   Carbon `RegisterEventHotKey` API'si Fn'i modifier olarak desteklemiyor
   (yalnızca Control/Option/Command/Shift var), üstelik dersler.md md.2
   zaten üçüncü parti klavyede Fn'in donanım seviyesinde çalışmadığını
   kanıtlamıştı.

---

## 15. Durum ve sıradaki adım

**Faz 0-5 tamamlandı ve test edildi. Bölüm 6.4/6.5 (Ayarlar + onboarding
pencereleri) tam şartnameye göre yazıldı. Bölüm 7 (kısayol haritası)
tamamlandı: Esc (kayıt iptal) ve ⌃⌥C (LLM temizle aç/kapa) eklendi.
Bölüm 8 (dosya yapısı) 2026-09-05'te gerçek koda göre senkronize edildi.**

Sistem uçtan uca çalışıyor: `⌃⌥1` (aç/kapa) veya basılı-tutma tuşu
(Ayarlar'dan seçilebilir) → konuş → sessizlikte otomatik durur ya da
elle durdurulur ya da Esc ile iptal edilir → Whisper transkribe eder
(model açılışta arka planda önceden yükleniyor — bkz. aşağıdaki
performans notu) → sözlük düzeltmesi + Ollama temizleme (güvenlik
ağıyla) uygulanır → Erişilebilirlik izni varsa otomatik yapıştırılır,
yoksa panoya yazılır → geçmişe kaydedilir. HUD paneli ve menü çubuğu
ikonu her aşamada görsel geri bildirim veriyor.

**2026-09-05 canlı test turu — Fatih'in gerçek kullanımıyla bulunup
düzeltilen 3 hata:**
- Basılı-tutma bazen iki basış gerektiriyordu (hızlı bas-bırak,
  mikrofonun async başlamasından önce bırakmayı yakalıyordu) —
  `pendingStopWhileStarting` bayrağıyla düzeltildi.
- VAD, basılı tutma sırasında cümleler arası doğal sessizlikte kaydı
  kendiliğinden kesiyordu — `isPushToTalkHoldSession` bayrağıyla VAD
  basılı-tutma sırasında devre dışı bırakıldı.
- Ollama temizleme 2 sn zaman aşımına sık takılıyordu (soğuk model
  başlatma gecikmesi) — zaman aşımı 4 sn'ye çıkarıldı.

**2026-09-05 gecikme şikayeti ve kısmi çözüm:** İlk dikte, uygulama her
açılışında ~10-20 sn sürüyordu (Whisper modeli o an belleğe yükleniyor).
`Transcriber.prewarm()` eklendi — model artık uygulama açılışında
arka planda önceden yükleniyor. Fatih doğruladı: sonraki testte ilk
dikte ~4-5 sn'ye düştü, ikinci/üçüncü dikteler hızlı ve doğru. Kalan
~4-5 sn'lik ilk-dikte farkı (muhtemelen Apple Neural Engine'in ilk
gerçek çıkarımda ek bir ısınma adımı olması) çözülmedi — Fatih için şu
an kabul edilebilir, ayrıca dokunulmadı.

Bölüm 9-14 (riskler, elenen alternatifler, eşzamanlılık kuralları,
güvenlik, kesin kurallar, karar noktaları) 2026-09-05'te tek tek
gözden geçirildi — hepsi hâlâ geçerli, içerik değişikliği gerekmedi.
Denetimde bölüm 12'de 2 eksik bulundu, ikisi de tamamlandı:
- Onboarding ekranına gizlilik cümlesi eklendi ("Dikte ettiğiniz
  metinler sadece bu bilgisayarda saklanır, hiçbir yere gönderilmez").
- `README.md` yazıldı (kullanım, kurulum, Gatekeeper/`xattr` adımı,
  gizlilik notu).

Bölüm 11'in çıkış kriteri de fiilen doğrulandı: `⌃⌥1`'e 150ms
aralıklarla 5 kez üst üste basıldı (osascript ile sentetik tuş
olayları), uygulama çökmedi, kayıt üst üste binmedi — `.starting`/
`.transcribing` sırasında gelen fazladan basışlar tasarım gereği yok
sayıldı (yalnızca 1 başlat + 1 durdur işlendi), test sonrası normal
tek basış döngüsü sorunsuz çalışmaya devam etti.

Ayrıca uygulamaya ikon eklendi: `Resources/AppIcon.icns`
(mavi gradyan zemin + beyaz mikrofon SF Symbol, macOS squircle
oranında), `Info.plist`'te `CFBundleIconFile` ve `Makefile`'ın
`bundle` hedefinde kopyalanıyor.

**2026-09-05 acımasız benchmark testi (3 tur) ve bulunan 2 gerçek hata
(ikisi de düzeltildi, düzeltme doğrulandı):**
1. **`Transcriber` model yükleme yarış durumu.** Uygulama açılışındaki
   `prewarm()` ile açılıştan hemen sonra (~birkaç saniye içinde)
   başlatılan gerçek bir dikte aynı anda `ensureLoaded()` çağırınca
   ikisi de modeli kilitsiz, eşzamanlı iki kez yüklüyordu (log'da iki
   ayrı thread'den "Model indiriliyor" satırı). Çökme yoktu ama ~6
   saniyelik yükleme boşa iki kez yapılıyordu. Düzeltme: `Transcriber`'a
   `NSLock` korumalı `inFlightLoad` — aynı modeli isteyen ikinci çağıran
   yeni bir yükleme başlatmak yerine birincinin `Task`'ını bekliyor.
   Aynı senaryo düzeltmeden sonra 3 kez tekrar edildi, üçünde de tek
   yükleme oldu.
2. **Whisper halüsinasyonuna karşı süzgeç yoktu.** Sessizlik/ortam
   gürültüsünde Whisper bazen yanlış dilde bile uydurma cümle
   üretiyordu (bir seferinde tam Rusça bir cümle). İlk düzeltme: OpenAI
   Whisper'ın kendi sessizlik sezgisiyle aynı mantık — bir sonucun TÜM
   segmentleri hem yüksek `noSpeechProb` (>0.6) hem çok düşük
   `avgLogprob` (<-1.0) gösteriyorsa o sonuç atılıyor. **Bu süzgeç de
   aynı gün GERİ ALINDI** — gerçek kullanımda Fatih'in gerçek konuşmasını
   da (yanlışlıkla "sessizlik" sayıp) eleyip boş transkript döndürdüğü
   görüldü; halüsinasyonu bazen kaçırmaktan çok daha kötü bir hata
   (gerçek dikteyi sessizce yutmak). Şu an hiçbir halüsinasyon süzgeci
   yok, ham WhisperKit çıktısı olduğu gibi kullanılıyor. Daha sağlam bir
   çözüm (ör. ses enerjisi eşiğiyle Whisper'ı hiç çağırmama) kapsam dışı
   bırakıldı, istenirse ayrı bir iş olarak ele alınabilir.

Ayrıca test sırasında bulunup düzeltilen bir kod-incelemesi hatası:
`AudioRecorder.stop()` ana thread'den `audioFile`'ı nil'lerken ses
thread'indeki `installTap` callback'i hâlâ ona yazıyor olabilirdi
(`removeTap`'in dönmesi çalışan callback'in bittiğini garanti etmiyor)
— `audioFileLock` (`NSLock`) ile korumaya alındı.

Ayrıca doğrulanan güvenlik bulguları: Ollama sadece `127.0.0.1:11434`'te
dinliyor (LAN IP'den erişilemediği doğrulandı), shell/Process çağrısı
veya hardcoded sır yok, güvenlik ağı gerçek testte kötü Ollama çıktısını
3 kez gerçekten eledi.

**2026-09-05, Fatih onay verdikten sonra denenip GERİ ALINAN bir madde:**
- ❌ **Whisper'a metin tabanlı ipucu/prompt verme — denendi, ciddi bir
  gerilemeye yol açtı, tamamen geri alındı.** `whisperKit.tokenizer.encode`
  ile `DecodingOptions.promptTokens` verildi; smoke test (tek deneme)
  geçmiş gibi göründü ama Fatih'in gerçek art arda push-to-talk
  kullanımında **ilk kayıttan sonraki HER kayıt boş transkript döndürmeye
  başladı** — sistem "çalışmıyor" hale geldi. Kök neden kanıtlanamadı ama
  en güçlü şüphe: WhisperKit'in `usePrefillCache=true` varsayılanı sabit
  `promptTokens` ile art arda çağrılarda kirli/bozuk önbellek durumu
  bırakıyor. Kod tamamen geri alındı (`Transcriber.transcribe`'dan
  `promptHints` parametresi kaldırıldı), 3 art arda push-to-talk
  denemesiyle düzeldiği doğrulandı. **Ders:** tek başarılı deneme
  yeterli kanıt değil — art arda gerçek kullanım testi olmadan yeni bir
  WhisperKit `DecodingOptions` alanını üretime sürmemeli. Tekrar
  denenecekse önce WhisperKit'in kendi cache davranışı ayrıca
  araştırılmalı.

**2026-09-05, tüm kaynak dosyaları baştan aşağı okuma/temizlik turu**
(Fatih'in isteği: "gereksiz satırları silelim, boş beleş bir şey
kalmasın"). 20 Swift dosyasının tamamı tek tek okundu. Bulunan 3 gerçek
işlevsel hata düzeltildi (kozmetik değil — kullanıcının deneyimini
sessizce bozan şeyler):
- **Ayarlar'da basılı-tutma tuşu değiştirilince canlı olarak
  uygulanmıyordu.** `AppState.refreshPushToTalkKey()` yazılmıştı ama
  hiçbir yerden çağrılmıyordu (dead code). `SettingsView` → `ShortcutsTab`
  artık `onChange` ile bunu tetikliyor.
- **Ayarlar'daki "Ollama sistem promptu" düzenleyicisi hiçbir işe
  yaramıyordu.** `TextCleaner` kendi sabit (hardcoded) promptunu
  kullanıyordu, `Preferences.ollamaSystemPrompt`'u hiç okumuyordu.
  `TextCleaner`'a `systemPrompt` parametresi eklendi, `AppState` artık
  gerçek tercihi geçiyor.
- **`LaunchAtLogin.registerIfNeeded()` her açılışta çalışıyordu** —
  kullanıcı Ayarlar'dan "girişte başlat"ı kapatsa bile bir sonraki
  açılışta sessizce tekrar açıyordu. Artık sadece ilk kurulumda
  (onboarding tamamlanmamışken) çağrılıyor.

Ayrıca silinen tamamen ölü/işlevsiz kod: `vocabularyHintsEnabled`
tercihi ve Ayarlar'daki karşılığı (geri alınan Whisper-hint özelliğine
bağlıydı, artık hiçbir koda bağlı değildi). `AudioDeviceUtility`'de
tekrar eden cihaz-listeleme kodu tek fonksiyona indirildi.
`MenuBarIconController`'daki Faz 3 öncesi tarihli, artık yanlış olan
bir yorum düzeltildi. Ayarlar'ın Kısayollar sekmesine eksik olan ⌃⌥C
ve Esc satırları eklendi (bölüm 7'de var ama UI'da hiç görünmüyorlardı).

Temizlik sonrası: sıfır derleyici uyarısı, TODO/FIXME/debug kalıntısı
yok, tek bir gerçek dikte döngüsüyle (kayıt→transkript→Ollama güvenlik
ağı) doğrulandı, çökme yok.

**Hâlâ test edilmemiş — bunlar benim tek başıma yapamayacağım, gerçek
kullanıcı eylemi gerektiriyor:**
- TR/EN karışık tek cümle testi (dersler.md md.6'nın asıl senaryosu) —
  gerçek bir insan sesi gerekiyor, Fatih'in bunu bizzat söyleyip test
  etmesi gerekiyor.
- Reboot sonrası girişte gerçekten otomatik açılma — kayıt mekanizması
  `sfltool dumpbtm` ile doğrulandı ama gerçek reboot testi yapılmadı;
  reboot bu oturumu da sonlandıracağı için Fatih'in kendi uygun
  zamanında yapması gerekiyor.

**Sıradaki adım:** Yukarıdaki 2 test Fatih'in eylemini bekliyor,
başka açık iş yok.
