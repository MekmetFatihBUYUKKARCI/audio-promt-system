# Audio Promt — PLAN

> Eski, ayrıntılı araştırma sürümü git geçmişinde duruyor
> (`git log -- PLAN.md`). Bu sürüm 2026-09-05'te Fatih'in isteğiyle
> tak-tak-tak çalıştırılabilir bir göreve indirgendi — anlatı/gerekçe
> metni çıkarıldı, sadece durum + yapılacaklar kaldı.

## Durum: sistem tamamlandı, çalışıyor, üretimde

Faz 0-5 + bölüm 6-8 (UI, kısayollar, dosya yapısı) tamam. Acımasız
3 turlu test + tüm dosyaları baştan aşağı temizlik turu yapıldı.
`main` GitHub'a push edildi. Aşağıdaki "Yapılacaklar" dışında açık iş
yok.

---

## Yapılacaklar (sırayla, her biri bağımsız — birini bitir, işaretle, sıradakine geç)

- [x] **1. TR/EN karışık tek cümle testi — YAPILDI, GEÇTİ (2026-09-05).**
      Fatih "Push etmek, Pull etmek, Reverse etmek, Return etmek I love
      you, Sen love beni" ve "Tamam bunu pushlayalım." dedi, Whisper
      ikisini de doğru ayırdı/transkribe etti (dil kodu karıştırmadı,
      anlamsız çıktı üretmedi). Fatih onayladı: "okey çalışıyor."
- [ ] **2. Gerçek reboot testi.** Bilgisayar yeniden başlatılıp Audio
      Promt'un kendiliğinden açıldığı doğrulanmalı. Agent bunu tek
      başına yapamaz (oturumu bitirir) — Fatih uygun zamanında yapsın,
      sonucu burada kaydet.
- [ ] **3. (opsiyonel, düşük öncelik) Whisper sözlük ipucu — tekrar
      denenebilir.** 2026-09-05'te `promptTokens` denendi, WhisperKit'in
      `usePrefillCache=true` varsayılanı sabit prompt'la art arda
      çağrılarda kirli önbellek bıraktığı düşünülüyor (bkz. git log:
      "Whisper sözlük ipucu... özelliğini geri al"). Tekrar denemeden
      önce: WhisperKit GitHub issue'larında `usePrefillCache` + tekrarlı
      çağrı hatası aranmalı; ya da her çağrıda `usePrefillCache: false`
      ile deneyip performans kaybını ölç. **Kanıtlanmadan tekrar
      üretime sürme** — en az 5 art arda gerçek push-to-talk denemesiyle
      doğrula.

Yeni bir madde geldiğinde: önce hangi bölümle çakıştığını söyle, onay
al, sonra buraya sırayla ekle — plan sırasını sormadan atlama.

---

## Hızlı mimari referans (agent için, gerekçe değil sadece gerçek)

**İzin merdiveni (projenin can alıcı kararı):** kısayol = Carbon
`RegisterEventHotKey` (izin istemez) → metin teslimi = NSPasteboard
(izin istemez), Erişilebilirlik varsa ek olarak CGEvent ile otomatik
⌘V. Push-to-talk = CGEventTap (Erişilebilirlik gerektirir, yoksa
sessizce devre dışı). Kod imzalama: kendinden imzalı sabit sertifika,
rebuild'lerde CDHash değişse de designated requirement sabit kalır —
Mikrofon/Erişilebilirlik izinleri kalıcı.

**Akış:** `⌃⌥1` veya basılı-tutma tuşu → `AudioRecorder` (AVAudioEngine,
16kHz mono WAV) → `Transcriber` (WhisperKit, `large-v3-turbo`, model
açılışta prewarm ediliyor) → `TextCleaner` (sözlük düzeltmesi + Ollama
+ güvenlik ağı: kelime-kaybı/benzerlik/zaman-aşımı, biri patlarsa ham
metin kullanılır) → `TextDelivery` (pano + varsa otomatik yapıştırma)
→ `HistoryStore` (son 50, JSON).

**Durum makinesi (`AppState.Status`):** `idle → starting → recording →
transcribing → idle`. Kısayol sadece `idle`/`recording`'i tetikler,
`starting`/`transcribing` sırasında gelen kısayol yok sayılır.

**Teknoloji:** Swift 6.3, macOS 26+ (Apple Silicon), WhisperKit
(CoreML/ANE), Ollama + `qwen2.5:3b` (yerel, `127.0.0.1:11434` dışına
asla açılmaz), SMAppService (girişte başlatma), Carbon (kısayol),
AppKit + SwiftUI (menü çubuğu + Ayarlar/HUD/onboarding pencereleri,
`.hudWindow` cam malzeme).

**Dosya yapısı:** `Sources/AudioPromt/{main.swift, AppDelegate.swift,
AppState.swift, Core/*, UI/*}`, `Resources/{Info.plist, vocabulary.json,
AppIcon.icns}`, `Makefile` (`build/bundle/sign/run/clean`), `README.md`
(kurulum), bu dosya. Detaylı dosya-dosya açıklama için git geçmişindeki
eski PLAN.md sürümüne bak.

**Kısayollar:** `⌃⌥1` kayıt aç/kapa · basılı-tutma tuşu (Ayarlar'dan
seçilir, varsayılan Sağ Option) · `⌃⌥V` son metni tekrar yapıştır ·
`⌃⌥C` LLM temizlemeyi aç/kapa · `Esc` kayıt sırasında iptal.

---

## Kesin kurallar (değişmez)

- Ücretli hiçbir yol yok, hiçbir zaman.
- Otomatik `git push` yok — sadece Fatih söyleyince.
- Proje kökü kesin `~/audio promt/`, başka yerde kopya tutulmaz.
- `CLAUDE.md`/`AGENTS.md` sembolik link — asla normal dosyayla değiştirme.
- Bu dosyanın (`PLAN.md`) içeriğini büyük ölçüde değiştirmeden önce
  onay al; durum/checkbox güncellemeleri (bu bölüm hariç) her zaman
  serbest.
- Yeni bir özellik isteği yukarıdaki "Yapılacaklar" sırasıyla
  çakışıyorsa önce söyle, onaysız atlama.

---

## Sabit teknik notlar (hızlı referans — "neden böyle" gerekçesi git geçmişinde)

- WhisperKit dil algılama: `detectLanguage: true` açıkça verilmezse
  `usePrefillPrompt=true` varsayılanı yüzünden İngilizce'ye sabitleniyor.
- WhisperKit model adı tam repo klasör adı olmalı (`openai_whisper-large-v3-v20240930_turbo`), kısa isim çözülmüyor.
- `@unchecked Sendable` + gerçek zamanlı ses/event-tap callback'leri
  paylaşılan mutable state'e (`audioFile`, `whisperKit`) her zaman
  `NSLock` ile eriş — kilitsiz erişim iki kez yakalandı (AudioRecorder,
  Transcriber).
- Yeni bir WhisperKit `DecodingOptions` alanı eklerken tek başarılı
  test yeterli değil, en az 3-5 art arda gerçek çağrıyla doğrula
  (prefill-cache olayı bunun için eklendi).
- Ollama zaman aşımı ≥4sn olmalı — soğuk model başlangıcı 2sn'yi aşıyor.
- Halüsinasyon süzgeci (noSpeechProb/avgLogprob eşiği) DENENDİ VE GERİ
  ALINDI — gerçek konuşmayı da eledi. Şu an hiçbir süzgeç yok, bilerek.
