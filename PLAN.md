# Plan — Sesli Prompt Sistemi

Bu dosya tek doğruluk kaynağı. Yaptığım her adım buraya işlenir. Bu proje
Jarvis'in genel hafızasına (`🔮 850-Companion`, `knowledge/`) otomatik
yüklenmez — sadece bu klasörde yaşar.

## Hedef
Klavye yerine sesle prompt/metin girme (özellikle Claude Code terminaline).

## Geçmiş (özet — çıkarılan dersler `research/dersler.md`'de)
İki yol denendi, ikisi de terk edildi:
- **VoiceInk** (Swift fork) — onboarding sihirbazı dışarıdan config'i
  görmezden geldi.
- **whisper-dictate** (Python fork) — kod tamamen çalışır hale getirildi
  ve sentetik testle kanıtlandı, ama macOS Erişilebilirlik izni hiçbir
  şekilde `.app`'e yansımadı (TCC sorunu, kod hatası değil).

Ayrıntılı anlatım silindi, **yol gösterici dersler** `research/dersler.md`'de
korunuyor — sıfırdan başlarken önce onu oku.

Duran altyapı: **Ollama + `qwen2.5:3b`** kurulu, çalışıyor, hiçbir yola
özel değil — hangi yaklaşımı seçersek seçelim kullanılabilir.

## Kesin kurallar (ben aksini söyleyene kadar geçerli)
- **Otomatik `git push` yok.** Sadece Fatih söyleyince.
- Bu projenin teknik detayları Jarvis'in "beyin" hafıza sistemine
  otomatik yazılmaz — hepsi bu dosyada ve proje klasöründe kalır.
- `CLAUDE.md` + `AGENTS.md` (symlink, otomatik senkron) proje kökünde:
  `~/audio promt/CLAUDE.md`.
- **Proje kökü kesin olarak `~/audio promt/`.** Başka hiçbir yerde
  (MehmetOS kasası dahil) kopya tutulmaz.

## Durum
Kemik dosyalar dışında her şey silindi. Sıfırdan başlanıyor — yaklaşım
henüz belirlenmedi.

## Açık soru
Sıradaki yaklaşım ne olacak?
