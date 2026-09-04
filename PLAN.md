# Plan — Sesli Prompt Sistemi

## DURDU — 2026-09-05: VoiceInk yolu terk edildi
VoiceInk fork'u sonuna kadar götürülmedi. Sebep: uygulamanın kendi
onboarding sihirbazı, dışarıdan (`UserDefaults` patch ile) verdiğimiz
yapılandırmayı (Ollama/qwen2.5:3b, Nemotron Multilingual, auto dil) görmezden
gelip kendi sabit varsayılanını (Parakeet — Türkçe desteklemiyor) indirmeye
başladı. Fatih'in tepkisi: "kontrolümün sınırlı olması hiç hoşuma gitmedi" —
üçüncü parti bir uygulamanın opak state machine'ine güvenmek istemiyor.

**Yapılan temizlik:** `/Applications/VoiceInk.app`, `~/Downloads/VoiceInk.app`,
klonlanan `src/VoiceInk` repo'su, tüm `UserDefaults`/`Application Support`/
`Caches`/`Preferences` kalıntıları, Homebrew cask cache'i — hepsi silindi,
doğrulandı (iz yok). **Korunan:** Ollama + `qwen2.5:3b` (VoiceInk'e özgü
değildi, ayrı altyapı, hâlâ duruyor) ve bizim kendi iskeletimiz
(`CLAUDE.md`/`AGENTS.md`/`PLAN.md`/`research/`/git geçmişi) — hiç dokunulmadı.

**Kararların çoğu hâlâ geçerli, sadece "hangi hazır uygulamayı fork'layıp
kuracağız" sorusu yeniden açıldı:**
- Hedef aynı: sesle prompt/metin, özellikle Claude Code terminaline
- Lokal AI enhancement: Ollama + qwen2.5:3b (hazır, kurulu)
- Dil: TR+EN, auto-detect tercih
- Otomatik push yok, beyne otomatik yükleme yok — bu kurallar değişmedi

**Açık soru (bir sonraki oturumda Fatih'le netleştirilecek):** "Sıfırdan
yapacağız" ne demek — (a) VoiceInk'i bırakıp daha az "kendi fikri olan"
(opinionated), onboarding'siz/daha sade başka bir açık kaynak projeye mi
bakalım, yoksa (b) gerçekten kendi küçük aracımızı mı yazalım (macOS
Accessibility API + yerel Whisper/Parakeet modeli + kendi ince arayüzümüz).
(b) çok daha büyük bir iş — konuşmadan varsayılmayacak.

---

(Aşağıdaki bölümler eski VoiceInk denemesinin kaydı, referans için tutuluyor.)

Bu dosya tek doğruluk kaynağı. Yaptığım her adım buraya işlenir. Bu proje
Jarvis'in genel hafızasına (`🔮 850-Companion`, `knowledge/`) otomatik
yüklenmez — sadece bu klasörde yaşar.

## Hedef
Klavye yerine sesle prompt/metin girme (özellikle Claude Code terminaline).
Referans: Wispr Flow (kapalı kaynak, ücretli). Karar: **VoiceInk**
(github.com/Beingpax/VoiceInk, GPLv3) kaynaktan derlenip kişisel/ücretsiz
kullanılacak.

## Kesin kurallar (ben aksini söyleyene kadar geçerli)
- **Otomatik `git push` yok.** Mimari kurulup private repo açıldıktan sonra
  bile, ben demeden push atma.
- Bu projenin teknik detayları Jarvis'in "beyin" hafıza sistemine
  otomatik yazılmaz — hepsi bu dosyada ve proje klasöründe kalır.
- `CLAUDE.md` + `AGENTS.md` (symlink, otomatik senkron) proje kökünde
  duruyor: `~/audio promt/CLAUDE.md`. Biri değişince öbürü dosya sistemi
  seviyesinde otomatik değişmiş olur, elle senkron gerekmez.
- **Proje kökü kesin olarak `~/audio promt/`.** Başka hiçbir yerde
  (MehmetOS kasası dahil) kopya tutulmaz.

## Mimari
```
~/audio promt/
├── CLAUDE.md          ← proje hafızası (AGENTS.md symlink)
├── PLAN.md            ← bu dosya, canlı plan/ilerleme
├── research/
│   └── notlar.md      ← video araştırması + güvenlik incelemesi (bitti)
└── src/
    ├── BUILDING.md    ← upstream'den çekilen resmi derleme talimatı
    └── VoiceInk/       ← (adım 1'de klonlanacak) upstream kaynak + bizim patch'lerimiz
```

## Adımlar
1. [x] Referans araç tespiti (Wispr Flow) — `research/notlar.md`
2. [x] Açık kaynak eşleniği seçimi (VoiceInk) — `research/notlar.md`
3. [x] Güvenlik incelemesi — `research/notlar.md`
4. [x] Denenmiş ve reddedilmiş yol: Homebrew cask kurulumu (7 günlük lisans
   kilidi + yanlış varsayılan model yüzünden kaldırıldı, brew cask + eski
   klon tamamen temizlendi)
5. [x] `BUILDING.md` tek dosya olarak upstream'den taze çekildi (`src/BUILDING.md`)
6. [x] **Local LLM çözüldü.** "NVIDIA model" hatırası gerçek bir kurulum
   değilmiş, başka bir sohbette görülen OpenRouter bulut önerisiymiş
   (`nvidia/nemotron-3.5-lightning:free`) — o lokal değil, kullanmadık.
   `~/.ollama`'da 2025 Mart'tan kalma 3 eski model bulundu (llama3,
   deepseek-r1:7b, llama3.2 — 11GB), Ollama binary'si kurulu değildi.
   Yapılanlar: `brew install ollama`, `brew services start ollama`
   (login'de otomatik başlar), **`qwen2.5:3b`** çekildi (1.9GB, reasoning
   değil düz instruct, Türkçe'de test edildi — çalışıyor), eski 3 model
   silindi (`ollama rm`) → disk 11GB'dan 1.8GB'a düştü. VoiceInk'te
   provider: **Ollama, `http://localhost:11434`, model `qwen2.5:3b`.**
7. [x] `src/VoiceInk` içine upstream temiz klonlandı
8. [x] **`make local` derlemesi BAŞARILI.** İki ek engel çıktı, ikisi de
   çözüldü:
   - `Makefile`'ın kendi `xcodebuild` çağrısında eksik olan
     `-skipPackagePluginValidation` ve `-skipMacroValidation` bayrakları
     elle eklendi (mlx-swift'in `CudaBuild` plugin'i ve `mlx-swift-lm`'in
     `MLXHuggingFaceMacros` makrosu, GUI'de tıklanan "Trust" onayı
     istiyordu, CLI'da bu bayraklarla atlanıyor). Vendored `Makefile`'a
     dokunulmadı, komut elle çalıştırıldı.
   - Metal Toolchain eksikti (`xcodebuild -downloadComponent
     MetalToolchain`, 688MB, resmi Apple bileşeni) — indirildi.
9. [x] `.local-build/.../VoiceInk.app` → `~/Downloads` → `xattr -cr` →
   **`/Applications/VoiceInk.app`**. Doğrulandı: ad-hoc imzalı,
   `TeamIdentifier=not set` (bizim derlememiz, upstream'in resmi
   sertifikasıyla karışmıyor), runtime hardened.
   **Ek sorun + çözüm:** İlk açılışta çöktü — gömülü `whisper.framework`
   başka (gerçek) bir Team ID ile imzalıydı, ad-hoc imzalı ana uygulamayla
   uyuşmadı (`different Team IDs` dyld hatası). Çözüm: tüm paket
   `codesign --force --deep --sign - /Applications/VoiceInk.app` ile tek
   tip ad-hoc imzayla yeniden imzalandı. Artık sorunsuz açılıyor.
10. [x] Mikrofon / Erişilebilirlik / Ekran Kaydı izinleri Fatih tarafından verildi
11. [x] **Model kararı: Parakeet değil, "Nemotron Multilingual" (NVIDIA,
    672MB, streaming, 28 dil, `tr-TR: Turkish` listede açıkça var).**
    Kaynakta doğrulandı (`TranscriptionModelRegistry.swift`,
    `LanguageDictionary.swift`) — Parakeet V3 sadece İngilizce + 25 Avrupa
    dili, Türkçe yok; Fatih'in hatırladığı "NVIDIA model" muhtemelen
    buymuş (LLM değil, bir dinleme/ASR modeliymiş).
12. [x] **Uygulama dışarıdan, elle tıklamadan yapılandırıldı.** VoiceInk
    ayarlarını düz `UserDefaults` tuttuğu için (`com.prakashjoshipax.VoiceInk`)
    app kapatılıp export/patch/import edildi: her 3 mod'da
    (`Dictation`/`Enhancement`/`Email`) `selectedAIProvider: Ollama`,
    `selectedAIModel: qwen2.5:3b`, `selectedTranscriptionModelName:
    nemotron-multilingual-0.6b`, `selectedLanguage: auto` yazıldı; global
    `ollamaBaseURL`/`ollamaSelectedModel` doğrulandı. App yeniden açıldı,
    değerler doğrulandı. **Bu, Faz 2'deki "dışarıdan kumanda" fikrinin
    zaten çalıştığının kanıtı** — VoiceInk'e hiç dokunmadan tam kontrol
    mümkün.
    **Kalan tek elle adım:** Nemotron modelinin asıl dosyaları henüz
    inmedi — indirme, FluidAudio paketinin kendi (VoiceInk'in kaynağında
    olmayan, harici bağımlılık) indirme mantığıyla oluyor, dışarıdan
    güvenle taklit edilemedi. Fatih'in uygulamada bir kez "Download"a
    tıklaması gerekiyor.
13. [ ] Claude Code terminaline gerçek dikte testi (Nemotron indikten sonra)
14. [ ] Her şey oturduktan sonra: GitHub'da **private** repo aç, bizim
    patch'lerimizi (varsa) orada takip et — **push'u sadece Fatih söyleyince** yap

## Dil davranışı (2026-09-04 karar)
- **Varsayılan: Auto-detect.** Kaynakta doğrulandı (`LanguageDictionary.swift`)
  — VoiceInk'in dil seçicisinde gerçek bir "Auto-detect" seçeneği var,
  multilingual modelde her cümlede TR/EN karışık konuşsa da otomatik
  ayırt ediyor (Whisper'ın kendi native özelliği).
  Fatih iki dili karışık kullanıyor, bunu manuel açıp kapamak istemiyor.
- **Ama açma/kapama tuşu da olacak** ("ne olur ne olmaz") — Auto-detect
  yanlış anlarsa tek tuşla sabit TR ya da sabit EN'e geçilebilecek.
  VoiceInk'in native dil dropdown'ı zaten bunu yapıyor (Auto-detect / TR /
  EN arasında seçim), ama adım 15'teki kontrol panelinde bunun için ayrı,
  tek-tık bir toggle da olacak (dropdown'a girmeden).

## Faz 2 — Kontrol paneli (backlog, henüz tasarlanmadı)
15. [ ] **Küçük bir arayüz:** Fatih'in "her şeyi kontrol edebileceği" tek
    bakışta bir panel. İlk taslak fikri (implementasyon öncesi netleşecek):
    - Dikte açık/kapalı durumu
    - Dil: Auto-detect ⇄ sabit TR ⇄ sabit EN (tek tık toggle)
    - AI Enhancement (Ollama/qwen2.5:3b) açık/kapalı
    - Aktif model / hızlı durum bilgisi

    **Karar (2026-09-04): ayrı, kendi mini-app'imiz.** VoiceInk'in kendi
    Settings ekranına gömülmeyecek. Sebep: (1) VoiceInk Settings'i
    geliştirici diliyle dolu, sade/kişisel değil — Fatih'e hitap eden
    kendi arayüzü olacak, kendi adı/tasarımı olabilecek. (2) Upstream'i
    düzenli güncelleyeceğiz (adım 14) — kendi UI'mızı VoiceInk'in kod
    tabanına gömersek her güncellemede merge conflict çıkarır. Ayrı
    tutunca upstream'e hiç dokunmuyoruz, temiz `git pull` kalıyor.

    Teknik bağlantı: VoiceInk ayarlarını düz macOS `UserDefaults` olarak
    tutuyor (kaynakta doğrulandı, örn. `ollamaBaseURL` anahtarı). Ayrı
    mini-app aynı `UserDefaults` alanını (`com.prakashjoshipax.VoiceInk`)
    okuyup yazacak — VoiceInk'in koduna hiç dokunmadan, dışarıdan kumanda.
    Muhtemel biçim: küçük bir menü çubuğu (menu bar) widget'ı.

    Detaylı tasarım/implementasyon **adım 7-14 bitip sistem gerçek
    kullanımda denendikten sonra**, ayrı bir turda netleştirilecek —
    şimdilik yön kararı verildi, kod yazımı henüz başlamadı.

## Açık soru
Yok. Sıradaki adım: `src/VoiceInk` klonu + `make local` derlemesi (adım 7-8).
Faz 2 (kontrol paneli) ana akış çalışana kadar beklemede.
