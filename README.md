# Audio Promt

macOS menü çubuğu uygulaması — her yere (özellikle Claude Code
terminaline) klavye yerine sesle metin girer. Tamamen yerel: ses
kaydı, Whisper transkripsiyon (WhisperKit) ve LLM temizleme (Ollama)
hiçbiri bu bilgisayarın dışına çıkmaz. Sunucu yok, bulut yok, telemetri
yok, para gerektirmez.

> **Sadece macOS, sadece Apple Silicon.** Windows/Linux desteği yok ve
> planlanmıyor — kısayol (Carbon), ses kaydı (AVFoundation),
> transkripsiyon hızlandırma (CoreML/Apple Neural Engine), izin sistemi
> (TCC) ve arayüz (AppKit/SwiftUI) hepsi Apple'a özel API'ler. Apple
> Silicon (M1/M2/M3/M4...) üzerinde geliştirildi ve test edildi; Intel
> Mac'lerde denenmedi.

Aşağıdaki adımları **sırayla, atlamadan** takip et. Her adımda tek bir
kod bloğu var — onu kopyala, Terminal'e yapıştır, Enter'a bas, bir
sonrakine geç. Terminal'i açmak için: `⌘+Space` → "Terminal" yaz →
Enter.

---

## 0. Önce şunu kontrol et

Bu iki şart sağlanmalı:

- **macOS 26 (Tahoe) veya üzeri.** Kontrol:  `Apple menüsü → Bu Mac
  Hakkında`.
- **Apple Silicon Mac** (M1, M2, M3, M4 — Intel değil). Kontrol: aynı
  pencerede "Çip" yazan yerde `Apple M...` görünmeli.

İkisi de tutmuyorsa bu uygulama bu bilgisayarda çalışmaz, devam etme.

---

## 1. Xcode'u kur (derleyici için)

App Store'dan **Xcode**'u kur (birkaç GB, biraz zaman alır). Kurulum
bitince bir kere aç, lisans onayını geç, kapat. Projenin kendisiyle
Xcode arayüzünde hiç uğraşmayacaksın — sadece derleyiciyi (Swift 6.3+)
sisteme kurmuş oluyorsun.

Kurulumu terminalden doğrula:

```
xcode-select -p
```

Bir dosya yolu yazdırdıysa (`/Applications/Xcode.app/...` gibi) tamamsın,
sıradaki adıma geç.

---

## 2. Homebrew'u kur (paket yöneticisi)

Zaten kuruluysa bu adımı atla — kontrol için:

```
brew --version
```

Bir versiyon numarası görüyorsan atla, adım 3'e geç. Görmüyorsan kur:

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Kurulum sonunda ekrana çıkan (genelde `PATH` ile ilgili) 1-2 satırlık
talimatı da terminale yapıştırıp çalıştır — Homebrew bunu kurulumun
sonunda kendisi gösterir.

---

## 3. Ollama'yı kur ve bir model indir

**Ollama** — bu makinede çalışan, ücretsiz, açık kaynak bir yapay zeka
motoru. Audio Promt onu, senin dikte ettiğin ham metni (doldurma
kelimeleri, noktalama hatalarını) düzeltmek için kullanır. Hiçbir veri
internete çıkmaz, hepsi kendi bilgisayarında kalır.

Kur:

```
brew install ollama
```

Arka planda çalıştır (bu komut çalışmaya devam eder, terminali kapatma
ya da yeni bir sekme aç):

```
ollama serve
```

**Yeni bir Terminal sekmesi aç** (⌘+T) ve modeli indir:

```
ollama pull qwen2.5:3b
```

### Hangi modeli seçmeliyim?

Bu proje varsayılan olarak **`qwen2.5:3b`** kullanır (yukarıdaki komut).
Bunu seçme sebebi:

| Özellik | Neden önemli |
|---|---|
| **~2 GB boyut** | İndirmesi hızlı, diskte az yer kaplar |
| **3 milyar parametre** | Herhangi bir Apple Silicon Mac'te (8 GB RAM dahil) rahat çalışır, cevap ~1 saniye |
| **Çok dilli (TR/EN dahil)** | Türkçe dikteyi düzeltirken yanlışlıkla İngilizce'ye çevirmiyor (küçük modellerde bu sık görülen bir hata) |

Daha iyi bir Mac'in varsa (16 GB+ RAM) ve düzeltme kalitesini biraz
daha arttırmak istersen, alternatif olarak şunu da deneyebilirsin:

```
ollama pull qwen2.5:7b
```

İndirdikten sonra Audio Promt'un **Ayarlar → Temizleme** sekmesinden
model adını `qwen2.5:7b` olarak değiştirmen yeterli — kod değişikliği
gerekmez. Daha büyük model = biraz daha yavaş ama biraz daha isabetli
düzeltme. `qwen2.5:3b` çoğu kullanım için zaten yeterli, önce onunla
başlamanı öneririz.

Modelin gerçekten indiğini doğrula:

```
ollama list
```

Listede `qwen2.5:3b` görmelisin.

---

## 4. Projeyi indir ve derle

```
git clone https://github.com/MekmetFatihBUYUKKARCI/audio-promt-system.git
cd audio-promt-system
make bundle sign
```

Bu birkaç dakika sürebilir (ilk derlemede WhisperKit bağımlılığı
indirilir). Sonunda `.build/Audio Promt.app` oluşmuş olacak.

---

## 5. Çalıştır

```
open ".build/Audio Promt.app"
```

Macos ilk açılışta **"Tanımlanamayan geliştirici"** uyarısı verebilir
(uygulama Apple tarafından notarize edilmedi — ücretli bir yol,
bilinçli olarak kullanılmadı). Bunu aşmak için tek seferlik:

```
xattr -d com.apple.quarantine ".build/Audio Promt.app"
```

çalıştır, sonra tekrar `open ".build/Audio Promt.app"` dene. (Alternatif:
Finder'da uygulamaya sağ tık → Aç.)

Açılınca menü çubuğunda (ekranın sağ üstü) bir mikrofon ikonu
göreceksin — pencere açılmaz, uygulama arka planda bekler.

---

## 6. İzinleri ver

İlk kullanımda macOS iki izin soracak:

- **Mikrofon** — zorunlu, olmadan kayıt yapılamaz.
- **Erişilebilirlik** — opsiyonel. Verirsen dikte ettiğin metin
  otomatik olarak imlecin olduğu yere yapıştırılır. Vermezsen sistem
  yine çalışır, sadece metni panoya kopyalar — sen elle ⌘V basarsın.

İkisi de **Sistem Ayarları → Gizlilik ve Güvenlik** altından elle
açılıp kapatılabilir.

---

## 7. (Opsiyonel) Kalıcı kurulum

Her seferinde terminalden `open` yazmak istemiyorsan:

```
cp -R ".build/Audio Promt.app" /Applications/
```

Artık Spotlight'tan (`⌘+Space`, "Audio Promt" yaz) ya da
Applications klasöründen açabilirsin, Dock'a sürükleyebilirsin.

Ayarlar → Genel'den **"Girişte başlat"**ı açarsan, bilgisayar her
açıldığında kendiliğinden çalışmaya başlar.

---

## Kullanım

- **⌃⌥1** — kayıt başlat/durdur (aç/kapa).
- **Sağ Option (basılı tut)** — basılı tuttuğun sürece kaydeder,
  bırakınca durur. Ayarlar'dan farklı bir tuşa değiştirilebilir.
- **⌃⌥V** — son transkripti tekrar yapıştır.
- **⌃⌥C** — LLM ile temizlemeyi aç/kapa.
- **Esc** — kayıt sırasında iptal eder (transkribe etmeden atar).

İlk dikte biraz yavaş olacaktır (Whisper modeli o an iniyor, ~630 MB,
bir kez). Sonraki diktelerde model bellekte kalır, çok daha hızlıdır.

## Sorun giderme

- **"Erişilebilirlik izni yok" / otomatik yapıştırma çalışmıyor:**
  Sistem Ayarları → Gizlilik ve Güvenlik → Erişilebilirlik'te "Audio
  Promt" işaretli olmalı. Uygulamayı taşırsan (ör. `.build/`'den
  `/Applications`'a) bu izni yeni konum için tekrar vermen gerekebilir.
- **Ollama bağlantı hatası / "Ollama çalışmıyor" yazıyor:** `ollama
  serve` çalışan bir terminal penceresi açık mı kontrol et. Test:
  ```
  curl http://localhost:11434/api/tags
  ```
  Cevap gelmiyorsa Ollama kapalıdır. Kapalıyken bile sistem çalışmaya
  devam eder — sadece temizleme adımı atlanır, ham transkript kullanılır.
- **"command not found: make" ya da "git"**: Xcode Command Line
  Tools eksik demektir — `xcode-select --install` çalıştır.

## Gizlilik

Geçmiş dikteler `~/Library/Application Support/AudioPromt/` altında düz
JSON olarak, sadece bu makinede tutulur. Menüden veya Ayarlar'dan
**"Geçmişi temizle"** ile silinebilir. Hiçbir veri ağ üzerinden başka
bir yere gönderilmez.

## Teknik detay

Mimari, tasarım kararları ve geliştirme süreci için `PLAN.md`'ye bakın.
