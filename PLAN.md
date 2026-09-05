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
│    ⌃⌥Space  → kayıt aç/kapa                                      │
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

### Faz 0 — İskelet (hedef: yarım gün)

1. **Xcode IDE açılmıyor.** `swift package init --type executable` ile
   SPM paketi kur, `src/AudioPromt/` altına.
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
7. Git: proje `~/audio promt/` altına, `src/AudioPromt/`. `.gitignore`'a
   `.build/`, indirilen modeller.

**Çıkış kriteri:** Menü çubuğunda ikon var, tıklanınca menü açılıyor,
Dock'ta ikon yok, ⌘Tab'de görünmüyor. İki kez arka arkaya `make run`
sonrası `codesign -dv` aynı imza kimliğini gösteriyor.

---

### Faz 1 — Kısayol ve ses yakalama (hedef: 1 gün)

1. `RegisterEventHotKey` sarmalayıcısı yaz (veya `soffes/HotKey` paketini
   SPM ile ekle). `⌃⌥Space` kaydet.
2. **Doğrulama testi — bu fazın asıl amacı:** Erişilebilirlik izni
   VERİLMEMİŞ haldeyken kısayol çalışıyor mu? Sistem Ayarları →
   Gizlilik ve Güvenlik → Erişilebilirlik listesinde Audio Promt **olmamalı**
   ve kısayol yine de tetiklemeli. Çalışmıyorsa **derhal dur** — bu planın
   temel varsayımı yanlış demektir, mimariyi baştan gözden geçir.
3. `AVAudioEngine` ile mikrofon tap'i. İlk açılışta mikrofon izni istenir.
4. 48kHz stereo → 16kHz mono Float32 dönüşümü (`AVAudioConverter`).
5. Halka tampon, tavan 120 sn.
6. Kısayola bas → kaydet, tekrar bas → dur, sesi geçici `.wav` olarak diske
   yaz.

**Çıkış kriteri:** Erişilebilirlik izni yokken kısayol çalışıyor; 10
saniyelik konuşma kaydedilip QuickTime'da düzgün dinlenebiliyor.

---

### Faz 2 — Transkripsiyon ve HUD (hedef: 1–2 gün)

1. WhisperKit'i SPM ile ekle. İlk açılışta model indirme + ilerleme
   göstergesi.
2. Kayıt bitince transkribe et. **`language` parametresini verme**
   (dersler.md md.6).
3. Sonucu `NSPasteboard`'a yaz.
4. HUD panelini yaz — bölüm 6'daki şartnameye göre.
5. **Odak testi (kritik):** Claude Code terminalinde yazarken kısayola bas,
   konuş, bitir. Terminaldeki imleç yanıp sönmeye devam ediyor mu? ⌘V
   basınca metin terminale mi düşüyor? Odak kaçıyorsa `NSPanel`
   ayarlarını düzelt, geçmeden ilerleme.
6. `⌃⌥V` — son transkripti tekrar panoya koy.

**Çıkış kriteri:** Terminale odaklıyken konuş → ⌘V → metin terminale
düşüyor, odak hiç kaçmadı. TR/EN karışık bir cümle doğru çıkıyor.
**Bu noktada sistem gerçekten kullanılabilir hale gelmiştir.**

---

### Faz 3 — Kalite katmanı (hedef: 1 gün)

1. **Sözlük** (`vocabulary.json`): `{"yanlış": "doğru"}` eşlemeleri.
   Başlangıç seti: `Claude Code`, `Ollama`, `Whisper`, `Xcode`, `Swift`,
   `React`, `commit`, `repo`, `terminal`, `Fatih`. Hem regex sonrası düzeltme
   olarak hem de Whisper'a initial prompt olarak beslenir.
2. **Ollama temizleme** — `POST localhost:11434/api/generate`, model
   `qwen2.5:3b`. Sistem promptu: "Aşağıdaki dikte metnini düzelt. Sadece
   noktalama, büyük harf ve dolgu kelimeleri (ee, ııı, yani, işte)
   düzelt. ASLA çevirme. ASLA özetleme. ASLA yorum ekleme. Sadece
   düzeltilmiş metni döndür."
3. **Güvenlik ağı (dersler.md md.5 — pazarlıksız):** LLM çıktısı şu üç
   testten birini geçemezse **atılır, ham transkript kullanılır**:
   - kelime sayısı %20'den fazla düştü (asıl güvenilir belirti)
   - `difflib` benzerliği < %70
   - 2 saniye içinde dönmedi
   Her elenme menü çubuğu geçmişinde küçük bir uyarı ikonuyla işaretlenir.
4. **VAD (sessizlik algılama):** RMS 2.0 sn boyunca eşiğin altındaysa
   otomatik dur. Ayarlanabilir, kapatılabilir.
5. **Geçmiş:** son 50 transkript JSON'da, menüden erişilir, tıklayınca
   panoya kopyalar.

**Çıkış kriteri:** Uzun ve dolgu kelimeli bir konuşma temiz çıkıyor, ve
LLM'i kasten bozacak bir girdide (çok kısa cümle) ham transkript
korunuyor.

---

### Faz 4 — Kalıcılık: imza ve TCC (hedef: yarım gün + bekleme)

Bu faz, önceki iki projeyi öldüren duvarı yıkar. **Yol 1'in imza kısmı
(kendinden imzalı kararlı sertifika) Faz 0'a öne çekildi** ve o zamandan
beri Faz 1-3'ün onlarca rebuild'inden geçti — **Mikrofon izni** için
kararlılık zaten kanıtlı. Ama **Erişilebilirlik** izni Faz 1-3'te hiç
istenmedi (bilerek — bkz. bölüm 1), o yüzden asıl sınav burada:

1. Sistem Ayarları → Erişilebilirlik'te Audio Promt'a manuel izin ver.
2. Minik bir sınama fonksiyonuyla (Faz 5'in tam özelliğini yazmadan önce)
   doğrula: `AXIsProcessTrustedWithOptions` `true` dönüyor mu, kısa bir
   `CGEventTapCreate` çağrısı nil dönmüyor mu?
3. Kodda ufak bir değişiklik yap, rebuild et (aynı imza kimliğiyle),
   tekrar kontrol et — izin hâlâ duruyor mu?
4. **Tuttuysa:** Faz 4 bitti, Faz 5'e geç, orada tam özelliği yaz.
   **Tutmadıysa:** aşağıdaki Yol 2 veya Yol 3'e karar ver.

**Yol 2 — Apple Developer Program ($99/yıl)**

Topluluk araştırmasının kanıtlanmış çözümü: **Developer ID Application
sertifikası + notarization**. Sabit `TeamIdentifier` verir, TCC bunu
güncellemeler arasında tanır. VS Code, Slack, Discord aynı yolu
kullanıyor.

⚠️ **dersler.md md.1'de yazan "ücretsiz Apple ID ile kararlı imza" fikri
yanlış çıktı.** Ücretsiz Apple ID'nin verdiği "Personal Team" imzası bu
kararlılığı sağlamıyor.

**Bu, Fatih'in kararı — para harcaması gerekiyor, ben karar veremem.**

**Yol 3 — Kaçış planı (para harcanmazsa)**

Faz 0–3 zaten Erişilebilirlik izni olmadan çalışıyor. Sistem tam
fonksiyonel kalır, tek fark: otomatik yapıştırma yerine Fatih ⌘V basar.
**Bu kabul edilebilir bir son durumdur, başarısızlık değil.**

Geliştirme sırasındaki hızlı çözüm (topluluk-arastirmasi.md md.2):
```
tccutil reset Accessibility com.fatih.audiopromt
```
sonra uygulamayı kapat/aç.

**Çıkış kriteri:** Ya izin yeniden derlemelerden sağ çıkıyor, ya da Yol 3
bilinçli olarak seçildi ve karar bu dosyaya yazıldı.

---

### Faz 5 — Otomatik yapıştırma ve cila (Faz 4 Yol 1/2 tuttuysa)

1. Erişilebilirlik izni kontrolü: `AXIsProcessTrustedWithOptions`.
2. Yapıştırma: eski pano içeriğini sakla → metni yaz → `CGEvent` ile ⌘V
   → 150 ms sonra eski panoyu geri yükle.
3. **Sağlık kontrolü (topluluk-arastirmasi.md md.4):** `CGEvent.tapCreate`
   nil dönmese bile callback hiç tetiklenmeyebilir. 5 saniyede bir
   `tapIsEnabled()` kontrol et, kapalıysa tap'i yeniden kur.
4. **Basılı-tutma (push-to-talk)** — artık `CGEventTap` kullanılabilir.
   Tuş: **Sağ Option (keycode 61)**, dersler.md md.2'ye göre. Ayarlarda
   toggle/hold seçimi.
5. Girişte başlatma: `SMAppService.mainApp.register()` (launchd plist
   elle yazma, dersler.md'deki launchd sorunlarından kaçın).

**Çıkış kriteri:** Konuş → metin kendiliğinden terminale düşüyor, pano
eski haline dönüyor, yeniden başlatmadan sonra da çalışıyor.

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
  ● Kayıt başlat                              ⌃⌥Space
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

### 6.4 Ayarlar penceresi

SwiftUI `Settings` sahnesi, `TabView` ile 5 sekme. Pencere 520×420 pt,
boyutlandırılamaz.

**Sekme "Genel"**
- `Toggle` — Girişte başlat
- `Toggle` — Sessizlikte otomatik dur → açıkken alt `Slider` 1.0–5.0 sn,
  varsayılan **2.0 sn**
- `Slider` — Sessizlik eşiği (hassasiyet), sağında canlı mikrofon
  seviyesi çubuğu ki Fatih doğru yeri görsün
- `Picker` — Maksimum kayıt süresi: 30 sn / 60 sn / **120 sn** / 5 dk
- `Picker` — HUD konumu: Alt orta (varsayılan) / Üst orta / Menü
  çubuğunun altı / Kapalı

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

### 6.5 İlk açılış (onboarding)

dersler.md md.7'deki VoiceInk dersi: **onboarding sihirbazı yapma.**
Uygulama açılır açılmaz çalışır durumda olur. Tek istisna, tek bir
karşılama penceresi:

1. "Audio Promt çalışıyor. `⌃⌥Space` ile konuşmaya başla."
2. Mikrofon izni butonu (tek tık)
3. Model indirme ilerleme çubuğu
4. `Button` "Anladım" → kapanır, bir daha görünmez

Hiçbir adım atlanamaz değil, hiçbir durum kilitli değil. Ayarların hepsi
her zaman erişilebilir.

---

## 7. Kısayol haritası — kesin kararlar

| Kısayol | İşlev | Neden bu tuş |
|---|---|---|
| **⌃⌥Space** | Kayıt aç/kapa | macOS'ta boşta. Çıplak ⌃Space Spotlight/girdi kaynağı, ⌥Space kesintisiz boşluk — ikisinden de kaçınıldı. K250'de tek elle rahat. Terminal (Terminal.app, iTerm2, Ghostty, Warp) varsayılanlarıyla çakışmıyor |
| **⌃⌥V** | Son metni tekrar panoya koy | Wispr Flow'un "Paste last transcript" karşılığı. V harfi yapıştırmayı çağrıştırır |
| **Esc** | Kaydı iptal et, at | Sadece kayıt sırasında kaydedilir, kayıt bitince serbest bırakılır — böylece Esc başka zaman çalınmaz |
| **⌃⌥C** | LLM temizlemeyi aç/kapa | Kod dikte ederken temizlemeyi kapatmak isteyeceksin |
| **⌘,** | Ayarlar | macOS standardı |
| Sağ Option (basılı tut) | Push-to-talk | **Faz 5**, Erişilebilirlik izni sonrası. dersler.md md.2: K250'de Globe/Fn çalışmaz, sağ modifier'lar çalışır |

**Faz 1'in ilk işi:** bu kombinasyonların gerçekten boşta olduğunu
doğrulamak. Çakışma çıkarsa yedekler: `⌃⌥D`, `⌃⇧Space`.

---

## 8. Proje dosya yapısı

```
~/audio promt/
├── CLAUDE.md              (AGENTS.md → symlink)
├── PLAN.md                (bu dosya)
├── research/
│   ├── dersler.md
│   └── topluluk-arastirmasi.md
└── src/AudioPromt/
    ├── Package.swift              SPM manifest, IDE gerektirmez
    ├── Makefile                   run / sign / clean
    ├── Sources/App/
    │   ├── main.swift             uygulama girişi, LSUIElement
    │   ├── AppState.swift         merkezi durum (ObservableObject)
    │   ├── Core/
    │   │   ├── HotKeyManager.swift   Carbon RegisterEventHotKey
    │   │   ├── AudioRecorder.swift   AVAudioEngine, dönüşüm, RMS, VAD
    │   │   ├── Transcriber.swift     WhisperKit sarmalayıcı
    │   │   ├── TextCleaner.swift     sözlük + Ollama + güvenlik ağı
    │   │   ├── TextDelivery.swift    pano (v1) / CGEvent ⌘V (v2)
    │   │   └── HistoryStore.swift    JSON kalıcılık
    │   └── UI/
    │       ├── MenuBarController.swift
    │       ├── HUDPanel.swift        NSPanel, .nonactivatingPanel
    │       ├── WaveformView.swift    16 çubuk
    │       ├── SettingsView.swift    5 sekme
    │       └── OnboardingView.swift  tek pencere
    └── Resources/
        ├── Info.plist
        └── vocabulary.json       varsayılan sözlük
```

---

## 9. Riskler ve kaçış planları

| Risk | Olasılık | Kaçış planı |
|---|---|---|
| `RegisterEventHotKey` de izin isterse | Düşük | Faz 1'in ilk saatinde anlaşılır. O zaman: menü çubuğu ikonuna tıklama tetikleyici olur (izinsiz çalışır), kısayol Faz 5'e ertelenir |
| Kararlı imza (Yol 1) tutmazsa | Orta | Yol 2 ($99) veya Yol 3 (manuel ⌘V ile yaşa). Sistem her durumda kullanılabilir |
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

## 11. Kesin kurallar (Fatih aksini söyleyene kadar)

- **Otomatik `git push` yok.** Lokal commit atılır, uzağa gönderme sadece
  Fatih söyleyince.
- Bu projenin teknik detayları Jarvis'in "beyin" hafıza sistemine otomatik
  yazılmaz — hepsi bu klasörde kalır.
- **Proje kökü kesin olarak `~/audio promt/`.** Başka hiçbir yerde
  (MehmetOS kasası dahil) kopya tutulmaz.
- `CLAUDE.md` + `AGENTS.md` (symlink) proje kökünde.

---

## 12. Fatih'in karar vermesi gereken noktalar

Bunlar teknik değil, tercih/para kararı — ben veremem:

1. **Faz 4, Yol 2: $99/yıl Apple Developer Program alınacak mı?**
   Yol 1 (ücretsiz kararlı imza) önce denenecek. Tutmazsa: ya $99, ya
   manuel ⌘V ile yaşamak. Karar Faz 4'e gelince verilir, şimdi değil.
2. ~~Uygulama adı~~ — **kesinleşti: "Audio Promt"**, bundle id
   `com.fatih.audiopromt` (2026-09-05). Faz 0'dan sonra değiştirilirse
   bundle id değişir, izinler sıfırlanır — o yüzden bundan sonra
   değiştirmemek gerekir.
3. **⌃⌥Space uygun mu?** Sık kullandığın başka bir uygulama bunu
   kullanıyorsa şimdi söyle.

---

## 13. Sıradaki adım

**Faz 0, madde 1** — `swift package init` ile SPM iskeletini kur. Onay
verilirse başlıyorum.
