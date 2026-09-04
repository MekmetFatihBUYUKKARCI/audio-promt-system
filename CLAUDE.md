# Sesli Prompt Sistemi

Amaç: Fatih'in yazabileceği her yere (özellikle Claude Code terminaline)
klavye yerine **sesle** prompt/metin girebilmesi. Referans: OnurTirpan'ın
videosunda kullandığı **Wispr Flow** (kapalı kaynak, ücretli, Windows'ta
sistem tepsisinden çalışıyor, "Paste last transcript" ile terminale metin
basıyor).

## Karar (2026-09-05, güncel)
İlk denenen **VoiceInk** (Swift/Xcode) terk edildi — onboarding sihirbazı
dışarıdan verdiğimiz config'i görmezden geliyordu, Fatih'in "kontrolüm
sınırlı" tepkisi üzerine tamamen kaldırıldı (detay: PLAN.md'nin "DURDU"
bölümü). Yerine **whisper-dictate** (github.com/Scarlettofu/whisper-dictate,
MIT, tek Python dosyası, MLX Whisper) seçildi — basit, opak state machine'i
yok, tamamen bizim elimizde. Kaynak kod satır satır incelendi, 4 gerçek hata
bulunup düzeltildi, kendi kendine (sentetik tuş olayıyla) uçtan uca test
edilip **çalıştığı kanıtlandı**. Detay: `research/kod-incelemesi.md`.

Fatih'in makinesi: Apple Silicon (arm64), macOS 26.6.2. Klavyesi **Logitech
K250** (Apple değil) — bu önemli, kodda buna göre özel bir düzeltme var.

## Durum / canlı plan
Ayrıntılı adım adım plan ve ilerleme: **`PLAN.md`** — her oturumda önce
oraya bak, orayı güncelle. Özet: sistem çalışıyor (kanıtlı), kalan tek engel
macOS Erişilebilirlik izninin `.app`'e yansımaması — kod değil, Fatih'in tek
bir tıklaması gerekiyor (`research/kod-incelemesi.md` sonunda kesin adımlar).

## GitHub
Private repo: **github.com/MekmetFatihBUYUKKARCI/audio-promt-system**
(`origin` olarak bağlı, lokal `main` dalında commit'ler atılıyor). Sadece
bizim dosyalarımız takip edilir (`CLAUDE.md`, `AGENTS.md`, `PLAN.md`,
`research/`) — vendored `src/whisper-dictate/` kaynağı `.gitignore`'da.

## Sabit kurallar
- **Otomatik `git push` yok.** Remote bağlı ve lokal commit'ler atılıyor
  ama uzağa göndermek sadece Fatih söyleyince.
- Bu projenin teknik detayı Jarvis'in genel hafızasına (`🔮 850-Companion`,
  `knowledge/`) otomatik yüklenmez, sadece bu klasörde yaşar.

## Notlar dosyası
`research/notlar.md` — video araştırması + güvenlik incelemesi (bitti).
`PLAN.md` — canlı, sürekli güncellenen adım listesi.

## Dosya senkronu
Bu dosya (`CLAUDE.md`) tek kaynak. `AGENTS.md` ona sembolik link —
biri değişince diğeri otomatik değişmiş olur (dosya sistemi seviyesinde,
elle senkron gerekmez). Vault kökünde de aynı desen kullanılıyor.
