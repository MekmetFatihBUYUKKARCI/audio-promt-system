# Audio Promt

macOS menü çubuğu uygulaması — her yere (özellikle Claude Code
terminaline) klavye yerine sesle metin girer. Tamamen yerel: ses
kaydı, Whisper transkripsiyon (WhisperKit) ve LLM temizleme (Ollama)
hiçbiri bu bilgisayarın dışına çıkmaz. Sunucu yok, bulut yok, telemetri
yok.

## Kullanım

- **⌃⌥1** — kayıt başlat/durdur (aç/kapa).
- **Sağ Option (basılı tut)** — basılı tuttuğun sürece kaydeder,
  bırakınca durur. Ayarlar'dan farklı bir tuşa değiştirilebilir.
- **⌃⌥V** — son transkripti tekrar yapıştır.
- **⌃⌥C** — LLM ile temizlemeyi aç/kapa.
- **Esc** — kayıt sırasında iptal eder (transkribe etmeden atar).

Konuşma bitince metin otomatik olarak panoya yazılır; Erişilebilirlik
izni verilmişse otomatik olarak (⌘V ile) da yapıştırılır.

## Kurulum

```
make bundle sign
open .build/AudioPromt.app
```

İlk açılışta macOS **"Tanımlanamayan geliştirici"** uyarısı verebilir
(uygulama Apple tarafından notarize edilmedi — ücretli yol yok, kasıtlı
tercih). Bunu aşmak için tek seferlik:

```
xattr -d com.apple.quarantine .build/AudioPromt.app
```

ya da Finder'da uygulamaya sağ tık → Aç.

Mikrofon ve (istersen otomatik yapıştırma için) Erişilebilirlik izni
ilk kullanımda sistem tarafından sorulur.

## Gizlilik

Geçmiş dikteler `~/Library/Application Support/AudioPromt/` altında düz
JSON olarak, sadece bu makinede tutulur. Menüden veya Ayarlar'dan
**"Geçmişi temizle"** ile silinebilir. Hiçbir veri ağ üzerinden başka
bir yere gönderilmez.

## Teknik detay

Mimari ve geliştirme süreci için `PLAN.md`'ye bakın.
