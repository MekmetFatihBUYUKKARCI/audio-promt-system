# Sesli Prompt Sistemi

Amaç: Fatih'in yazabileceği her yere (özellikle Claude Code terminaline)
klavye yerine **sesle** prompt/metin girebilmesi. Referans: OnurTirpan'ın
videosunda kullandığı **Wispr Flow** (kapalı kaynak, ücretli, Windows'ta
sistem tepsisinden çalışıyor, "Paste last transcript" ile terminale metin
basıyor).

## Karar
Sıfırdan yazmıyoruz. **VoiceInk** (github.com/beingpax/VoiceInk) —
Wispr Flow'un en olgun açık kaynak Mac eşleniği — fork/kur, sonra eksik
kalan davranışları (örn. Claude Code terminaline yapıştırma) üstüne
yamala. Detaylı araştırma ve alternatif kıyası: `research/notlar.md`.

Fatih'in makinesi: Apple Silicon (arm64), macOS 26.6.2 — VoiceInk'in
gereksinimini (Apple Silicon + macOS 14.4+) rahat karşılıyor.

## Durum / canlı plan
Ayrıntılı adım adım plan ve ilerleme: **`PLAN.md`** — her oturumda önce
oraya bak, orayı güncelle. Özet: araştırma + güvenlik incelemesi bitti,
brew sürümü (lisans kilidi + yanlış dil modeli yüzünden) tamamen kaldırıldı,
şimdi kaynaktan `make local` ile temiz derleme aşamasındayız. Açık soru:
Fatih'in kurduğu local LLM hangisi (Ollama/LM Studio/başka) — `PLAN.md`
adım 6.

## Sabit kurallar
- **Otomatik `git push` yok**, private repo açılsa bile — sadece Fatih söyleyince.
- Bu projenin teknik detayı Jarvis'in genel hafızasına (`🔮 850-Companion`,
  `knowledge/`) otomatik yüklenmez, sadece bu klasörde yaşar.

## Notlar dosyası
`research/notlar.md` — video araştırması + güvenlik incelemesi (bitti).
`PLAN.md` — canlı, sürekli güncellenen adım listesi.

## Dosya senkronu
Bu dosya (`CLAUDE.md`) tek kaynak. `AGENTS.md` ona sembolik link —
biri değişince diğeri otomatik değişmiş olur (dosya sistemi seviyesinde,
elle senkron gerekmez). Vault kökünde de aynı desen kullanılıyor.
