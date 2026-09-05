# Sesli Prompt Sistemi — "Audio Promt"

Amaç: Fatih'in yazabileceği her yere (özellikle Claude Code terminaline)
klavye yerine **sesle** prompt/metin girebilmesi. Referans: Wispr Flow
(kapalı kaynak, ücretli, bulut tabanlı).

## ⚠️ DOSYA SENKRON PROTOKOLÜ — her oturumda geçerli

`CLAUDE.md` ve `AGENTS.md` **tek ve aynı dosyadır**. `AGENTS.md`,
`CLAUDE.md`'ye sembolik link (`AGENTS.md -> CLAUDE.md`).

**Kural: birine yazılan her şey diğerine de yazılmış olmak zorunda.**
Sembolik link bunu dosya sistemi seviyesinde otomatik sağlar — birini
düzenlemek ikisini birden düzenler. Elle senkron gerekmez, **ama**:

- Sembolik linki asla normal dosyayla değiştirme.
- Şüphelenirsen doğrula: `ls -la AGENTS.md` çıktısı `-> CLAUDE.md`
  göstermeli ve `md5 -q CLAUDE.md AGENTS.md` iki özdeş hash vermeli.
- Link kopmuşsa onar: `ln -sf CLAUDE.md AGENTS.md` (önce hangi dosyanın
  güncel içeriği taşıdığını kontrol et, onu `CLAUDE.md` yap).

Aynı desen vault kökünde de kullanılıyor.

## Durum (2026-09-05) — canlı, her faz bitince güncellenir

İki eski yaklaşım terk edildi (VoiceInk, whisper-dictate — TCC/onboarding
sorunları, bkz. `research/dersler.md`). Üçüncü yaklaşım: sıfırdan native
Swift, izin ihtiyacına göre katmanlanmış mimari, uygulanıyor.

**İlerleme:**
- ✅ **Faz 0** — İskelet: menü çubuğu uygulaması, kendinden imzalı
  kararlı sertifika (Keychain'de, ücretsiz), tek-örnek koruması.
- ✅ **Faz 1** — Kısayol + mikrofon yakalama: **`⌃⌥1`** (Fn istendi ama
  Carbon API'si desteklemiyor + donanımda çalışmıyor; `⌃⌥Space` "berbat"
  bulunup değiştirildi). Erişilebilirlik izni olmadan çalıştığı
  doğrulandı. Kayıt başlama/bitme sesi var (Ping/Pop, kısık).
- ⚠️ **Faz 2** (çekirdek tamam, HUD bekliyor) — WhisperKit ile
  transkripsiyon çalışıyor (`openai_whisper-large-v3-v20240930_turbo`).
  Görsel HUD paneli henüz yok.
- ✅ **Faz 4** (plan sırasının önüne geçti) — **En kritik soru
  cevaplandı: kendinden imzalı sertifika hem Mikrofon hem Erişilebilirlik
  izninde rebuild'lere karşı kalıcı.** İki eski projeyi öldüren duvar
  gerçekten aşıldı.
- ⚠️ **Faz 5** (kısmen, Faz 4 ile birlikte erken yapıldı) — Otomatik
  yapıştırma çalışıyor (Erişilebilirlik izni + `CGEvent` ile ⌘V, pano
  eski haline dönüyor). Basılı-tutma, girişte otomatik başlatma,
  sağlık kontrolü henüz yok.
- ⏳ **Faz 3** (sırada, hiç başlanmadı) — sözlük, Ollama temizleme +
  güvenlik ağı, VAD, geçmiş.

Sistem şu haliyle **günlük kullanılabilir**: `⌃⌥1` → konuş → metin
otomatik yerine düşüyor. Tüm ayrıntı, çıkış kriterleri ve bulunan
hatalar `PLAN.md`'de.

**Her oturumda önce `PLAN.md`'ye bak, orayı güncelle. Her faz
tamamlandığında bu dosyanın "Durum" bölümü de kısa özetle güncellenir —
sadece `PLAN.md`'de bırakılmaz.**

## Planın temel içgörüsü

Önceki iki deneme, macOS Erişilebilirlik (TCC) iznine birinci günde
bağımlı oldukları için öldü. Yeni plan izni en sona bırakır:

- Kısayol için **Carbon `RegisterEventHotKey`** kullanılır — `CGEventTap`
  ve `NSEvent` global monitor'ün aksine **Erişilebilirlik izni istemez**.
- Metin panoya yazılır (izin gerekmez); Erişilebilirlik izni verilmişse
  otomatik ⌘V da basılır (2026-09-05'te doğrulandı: imza sorunu gerçekten
  çözüldü). İzin yoksa/geri alınırsa sessizce panoya yazma tek başına
  yeterli kalır, sistem hiç kırılmaz.

## Bilgi kaynakları

- **`PLAN.md`** — canlı, tek doğruluk kaynağı. Mimari şema, fazlar,
  arayüz şartnamesi, kısayol haritası, riskler, karar noktaları.
- **`research/dersler.md`** — önceki iki denemeden çıkan yol gösterici
  dersler (TCC, klavye donanımı, PyObjC tuzakları, LLM güvenlik ağı).
- **`research/topluluk-arastirmasi.md`** — internet/GitHub/forum
  araştırması: TCC'nin kök nedeni (CDHash kararsızlığı), çözümü, ve
  aynı sorunu çözmüş açık kaynak projeler.

## Makine (doğrulanmış)

Apple Silicon (arm64), macOS 26.6.2, Xcode kurulu (Swift 6.3.3),
Ollama + `qwen2.5:3b` çalışıyor. **Kod imzalama kimliği yok**
(`0 valid identities`). Klavye jenerik Bluetooth (Apple değil) — Globe/Fn
tuşuna güvenilmez. Mikrofon: dahili + ROG Strix Go USB kulaklık.

## GitHub

Private repo: **github.com/MekmetFatihBUYUKKARCI/audio-promt-system**
(`origin` olarak bağlı, lokal `main` dalında commit'ler atılıyor).

## Sabit kurallar

- **Otomatik `git push` yok.** Remote bağlı ve lokal commit'ler atılıyor
  ama uzağa göndermek sadece Fatih söyleyince.
- Bu projenin teknik detayı Jarvis'in genel hafızasına
  (`🔮 850-Companion`, `knowledge/`) otomatik yüklenmez, sadece bu
  klasörde yaşar.
- **Proje kökü kesin olarak `~/audio promt/`.** Başka hiçbir yerde
  (MehmetOS kasası dahil) kopya tutulmaz.
- Yukarıdaki **dosya senkron protokolü** her zaman geçerli.
