# Topluluk araştırması — TCC/Accessibility sorunu ve benzer projeler

**Özet:** TCC/Accessibility izninin `.app`'e yansımama sorunu bilinen ve
adı konmuş bir macOS davranışı — kök neden **ad-hoc imza her derlemede
CDHash'i değiştirmesi**, çözüm de **kararlı bir imza kimliği** (ideal:
ücretli Developer ID + notarization). Ayrıca aynı problemi çözmüş, ortalama
düzeyde kod tabanına sahip **çok sayıda native Swift açık kaynak dictation
projesi** var — sıfırdan yazmak yerine biri fork/referans alınabilir.

## 1. TCC sorununa somut çözüm (en kritik bulgu)

**Kök neden:** Ad-hoc imzalı (`TeamIdentifier=not set`) bir `.app`'te macOS
TCC, uygulamayı yalnızca kod digest'i (**CDHash**) ile tanıyor. CDHash her
derlemede değişiyor. Sonuç: Sistem Ayarları'nda toggle "açık" görünüyor ama
`csreq` doğrulaması sessizce başarısız oluyor — tam olarak PLAN.md'de
yaşanan belirti.
Kaynak: [Hermes.app TCC issue](https://github.com/NousResearch/hermes-agent/issues/49110), [Daniel Raffel — CGEvent Taps and Code Signing](https://danielraffel.me/til/2026/02/19/cgevent-taps-and-code-signing-the-silent-disable-race/)

**Çözüm:** Uygulamayı **Apple Developer ID Application sertifikası** ile
imzala + notarize et. Bu sabit bir `TeamIdentifier` verir, TCC bunu
güncellemeler arasında tanır, izin kalıcı olur. VS Code, Slack, Discord gibi
büyük Electron uygulamaları da bunu kullanıyor — standart CI/CD süreci.
Kaynak: [Hermes.app issue](https://github.com/NousResearch/hermes-agent/issues/49110)

**Önemli kısıt:** Developer ID sertifikası **sadece ücretli Apple Developer
Program üyeliğiyle** ($99/yıl) alınabilir. Ücretsiz Apple ID ile Xcode'un
verdiği "Apple Development" / Personal Team imzası Gatekeeper'ı geçemez ve
CDHash kararlılığı garantisi aynı değil. Yani "gerçek bir ücretsiz Apple
ID'yle kararlı imza" fikri (dersler.md madde 1'de yazan) tam doğru değilmiş —
kalıcı çözüm için muhtemelen $99/yıl ödemek gerekecek.
Kaynak: [Apple Developer ID resmi sayfa](https://developer.apple.com/developer-id/), [Apple Forums — Personal Team sınırları](https://developer.apple.com/forums/thread/117098)

## 2. Ara/geçici çözüm: `tccutil reset`

Kalıcı imza çözümüne geçmeden önce, açık kaynak **VoiceInk** projesinin
resmi dokümante ettiği pratik workaround:
```
tccutil reset Accessibility <bundle-id>
tccutil reset ScreenCapture <bundle-id>
```
Sonra uygulamayı kapat/aç, izin yeniden istenir ve o build için çalışır
(sonraki rebuild'de yine bozulur — kalıcı değil, geliştirme sırasında hızlı
tekrar-izin vermek için).
Kaynak: [VoiceInk Common Issues](https://tryvoiceink.com/docs/common-issues), [VoiceInk Issue #530](https://github.com/Beingpax/VoiceInk/issues/530)

## 3. Geliştirme sırasında pratik workaround (native projelerden)

**VocaHQ/vocamac** (native Swift, WhisperKit/Parakeet/sherpa-onnx tabanlı
offline dictation app) kaynaktan derlerken şunu öneriyor: **Terminal.app'e
bir kez izin ver, sonra `make run` ile çalıştır** — terminalden başlatılan
süreç izni miras alıyor (tam olarak dersler.md madde 1'in doğruladığı
davranış: "Terminalden direkt çalıştırınca güven vardı"). Resmi
dağıtımları ise Developer ID ile imzalı + notarize edilmiş.
Kaynak: [github.com/VocaHQ/vocamac](https://github.com/VocaHQ/vocamac)

**per-simmons/murmur-youtube** (native Swift push-to-talk dictation):
Makefile'ı `security find-identity` ile mevcut Developer ID'yi otomatik
buluyor, böylece yeniden derleme+kurulumdan sonra da izinler korunuyor.
Ayrıca **izinlerin bundle ID'ye kayıtlı olduğunu, yola değil** teyit ediyor.
Kaynak: [github.com/per-simmons/murmur-youtube](https://github.com/per-simmons/murmur-youtube)

## 4. Runtime doğrulama — "tap var" ≠ "tap sağlıklı"

Daniel Raffel'in bulgusu: `CGEvent.tapCreate()` başarıyla dönebilir (nil
değil) ama callback hiç tetiklenmeyebilir — bu sinyal, kod imzalama/izin
sorununun belirtisi. Çözüm: `tapIsEnabled()` düzenli aralıklarla kontrol
edilmeli, devre dışıysa tap yeniden kurulmalı. Ayrıca Input Monitoring için:
```swift
if !CGPreflightListenEventAccess() {
    CGRequestListenEventAccess()
}
```
Doğrudan Mach-O ikili çalıştırmak (`ManagedApp.app/Contents/MacOS/App`)
LaunchServices üzerinden açmaktan daha güvenilir bulunmuş.
Kaynak: [Daniel Raffel — CGEvent Taps and Code Signing](https://danielraffel.me/til/2026/02/19/cgevent-taps-and-code-signing-the-silent-disable-race/)

## 5. Fn/Globe tuşu sorunu — bağımsız doğrulama

`murmur-youtube` projesi de aynı sınırlamayı doğruluyor: `NSEvent.
addGlobalMonitorForEvents` ve Carbon API'ler fn tuşu ile sol/sağ modifier
ayrımını desteklemiyor — bu yüzden proje `CGEventTap` kullanmak zorunda
kalmış. dersler.md madde 2'deki "3. parti klavye Globe/Fn tetiklemiyor"
notuyla aynı kök sorunun farklı bir yansıması.
Kaynak: [github.com/per-simmons/murmur-youtube](https://github.com/per-simmons/murmur-youtube)

## 6. Fork/referans alınabilecek hazır native Swift projeler

Sıfırdan yazmak yerine incelemeye değer, hepsi TCC sorununu bir şekilde
çözmüş (Developer ID imzalı resmi build dağıtıyorlar):

- **VocaHQ/vocamac** — offline, WhisperKit/Parakeet/sherpa-onnx,
  clipboard+Cmd+V ile metin enjeksiyonu, AGPL-3.0.
  [github.com/VocaHQ/vocamac](https://github.com/VocaHQ/vocamac)
- **per-simmons/murmur-youtube** — native Swift push-to-talk, macOS+Windows
  ortak davranış sözleşmesi, HUD overlay `.nonactivatingPanel` ile odak
  çalmıyor. [github.com/per-simmons/murmur-youtube](https://github.com/per-simmons/murmur-youtube)
- **Starmel/OpenSuperWhisper** ve **bcharleson/opensuperwhisper** — native
  Swift menu bar, Apple Silicon optimize.
- **altic-dev/FluidVoice** — hybrid, çoklu motor (Parakeet/Whisper/Apple
  Speech/Cohere), GPLv3, `brew install --cask fluidvoice`.
- **epicenter-so/whispering** — MIT, local-first, ses hep cihazda kalıyor,
  Show HN'de tanıtıldı (Eylül 2025).
- **Beingpax/VoiceInk** — zaten incelediğimiz proje, native Swift, en
  olgun/dokümante edilmiş codebase; building.md + common-issues sayfası
  code-signing sorunlarını adım adım anlatıyor.
  [tryvoiceink.com/docs/common-issues](https://tryvoiceink.com/docs/common-issues)
- **primaprashant/awesome-voice-typing** — 18+ macOS aracını (native,
  Tauri, Electron karışık) listeleyen küratörlü liste, hızlı tarama için
  iyi bir hub. [github.com/primaprashant/awesome-voice-typing](https://github.com/primaprashant/awesome-voice-typing)

## 7. Ticari ürünler nasıl çalışıyor (referans için)

- **Wispr Flow** — bulut tabanlı (offline ÇALIŞMIYOR), ses sunucuya
  gidiyor, LLM ile temizleniyor (dolgu kelime temizleme, format düzeltme).
  OS seviyesinde metin enjekte ediyor (herhangi bir uygulamaya). Mimari
  detayları açık değil, resmi mühendislik blogu bulunamadı.
  Kaynak: [wisprflow.ai](https://wisprflow.ai/), [Wikipedia](https://en.wikipedia.org/wiki/Wispr_Flow)
- **Superwhisper** — tek geliştirici (Neil Chudleigh), VC almadan
  bootstrap edilmiş, whisper.cpp üzerine native, Apple Silicon Neural
  Engine kullanıyor, tamamen offline çalışabiliyor (Parakeet de destekli).
  Kaynak: [superwhisper.com](https://superwhisper.com/)
- **MacWhisper** — Jordi Bruin'in whisper.cpp üzerine yazdığı native app,
  Parakeet desteği eklendi (300x realtime).
  Kaynak: [X — Jordi Bruin](https://x.com/jordibruin/status/1938651550043222396)

## 8. Reddit/forum — kapsam notu

Doğrudan `site:reddit.com` aramaları bu konuda somut bir thread getirmedi
(arama motoru indexlemesi zayıf olabilir). Apple Developer Forums'ta
benzer TCC/CGEventTap şikayetleri var ama çoğu genel "izin sıfırlanıyor"
tartışması, ek somut bilgi Hermes/VoiceInk issue'larının ötesine geçmiyor.
X (Twitter) tarafında indie geliştiricilerin "kendi whisper hotkey'imi
yazdım" paylaşımları bol (bkz. madde 6-7), ama TCC'ye özel teknik detay
paylaşan tweet bulunamadı — bu bilgi ağırlıkla GitHub issue/blog
kaynaklarından geliyor.
