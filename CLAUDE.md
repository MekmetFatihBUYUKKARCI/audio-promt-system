# Sesli Prompt Sistemi — "Fısıltı"

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

## Durum (2026-09-05)

İki yaklaşım denendi ve terk edildi:
- **VoiceInk** (Swift fork) — onboarding sihirbazı dışarıdan verilen
  config'i yok saydı, kontrol elimizde değildi.
- **whisper-dictate** (Python fork) — kod tamamen çalışır hale getirildi
  ve sentetik testle kanıtlandı, ama macOS Erişilebilirlik izni hiçbir
  şekilde `.app`'e yansımadı (TCC sorunu, kod hatası değil).

Şu an **üçüncü ve son yaklaşımın planı hazır**: sıfırdan native Swift,
izin ihtiyacına göre katmanlanmış mimari. Tüm ayrıntı `PLAN.md`'de.

**Her oturumda önce `PLAN.md`'ye bak, orayı güncelle.**

## Planın temel içgörüsü

Önceki iki deneme, macOS Erişilebilirlik (TCC) iznine birinci günde
bağımlı oldukları için öldü. Yeni plan izni en sona bırakır:

- Kısayol için **Carbon `RegisterEventHotKey`** kullanılır — `CGEventTap`
  ve `NSEvent` global monitor'ün aksine **Erişilebilirlik izni istemez**.
- Metin v1'de **panoya** yazılır (izin gerekmez), Fatih ⌘V basar.
- Otomatik yapıştırma ancak imza sorunu çözülünce eklenir; çözülemezse
  sistem yine tam kullanılabilir kalır.

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
