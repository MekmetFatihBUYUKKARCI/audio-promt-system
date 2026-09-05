# Önceki denemelerden çıkan dersler (sıfırdan başlarken kullanılacak)

## 1. TCC/Erişilebilirlik izni — en kritik ders
Ad-hoc imzalı, Python/PyObjC tabanlı bir `.app` (script + venv python) hiçbir
şekilde macOS Erişilebilirlik güvenini kazanamadı — 7 farklı yöntem denendi
(WhisperDictate.app ekleme, doğru/yanlış Python.app ekleme, tam sıfırlama +
tek başına ekleme, derlenmiş Mach-O launcher), hiçbiri tutmadı. Terminalden
direkt çalıştırınca güven vardı (`AXIsProcessTrusted=True`), ama `.app`/
`launchd` üzerinden başlatılan hiçbir süreç bunu miras almadı.

**Kök neden sonradan bulundu** (`topluluk-arastirmasi.md` md.1): ad-hoc
imzada TCC uygulamayı yalnızca kod digest'i (**CDHash**) ile tanıyor, CDHash
her derlemede değişiyor, izin sessizce düşüyor. Çözüm: **kararlı bir imza
kimliği**.

> ⚠️ **DÜZELTME (2026-09-05):** Aşağıdaki "ücretsiz Apple ID yeter" fikri
> **yanlış çıktı.** Ücretsiz Apple ID'nin verdiği "Personal Team" imzası bu
> kararlılığı sağlamıyor. Kanıtlanmış çözüm ücretli Developer ID
> ($99/yıl) + notarization. Ücretsiz denenecek alternatif: Anahtar
> Zinciri'nden **kendinden imzalı kararlı kod imzalama sertifikası** —
> mantık doğru ama henüz doğrulanmadı (bkz. `PLAN.md` Faz 4, Yol 1).

**Sıfırdan başlarken:** Bu ihtimali en başta ele al, sona bırakma.
- ~~Önce gerçek bir (ücretsiz) Apple ID ile Xcode'a giriş yapıp kararlı bir
  "Apple Development" imza kimliği edinmeyi dene~~ — bkz. yukarıdaki
  düzeltme, bu yol yetmiyor.
- Ya da tamamen native Swift/Xcode ile yaz (Python+PyObjC+script-exec
  zincirinden kaçın) — VoiceInk'in kendisi native'di ve derleyip
  çalıştırdığımızda (kod açısından) sorunsuzdu, sorun onboarding'indeydi.
- ~~Global klavye kancası gerektiren HERHANGİ bir yaklaşım bu duvara
  çarpar~~ — **kısmen yanlış.** `CGEventTap` ve `NSEvent` global monitor
  izin ister, ama Carbon'un **`RegisterEventHotKey`**'i istemez (ham tuş
  olaylarını biz dinlemiyoruz, sistem tek bir kombinasyonu yakalayıp bize
  callback gönderiyor). Bedeli: çıplak modifier'a basılı tutma
  (push-to-talk) yapılamaz, gerçek bir kombinasyon gerekir. Yeni planın
  omurgası bu (bkz. `PLAN.md` bölüm 1).

## 2. Klavye donanımı — varsayım yapma, önce kontrol et
Fatih'in klavyesi **Logitech K250** (Bluetooth, Apple değil). Apple'ın
Globe/Fn tuşu bayrağı (`kCGEventFlagMaskSecondaryFn`) üçüncü parti
klavyelerde hiç tetiklenmiyor — klavye firmware'inde yerel olarak işleniyor.
**Sıfırdan başlarken:** tetikleyici tuş olarak Sağ Command (keycode 54) veya
Sağ Option (keycode 61) kullan, ya da en başta `system_profiler
SPBluetoothDataType` ile gerçek klavye markasını kontrol et.

## 3. PyObjC / CGEventTap ömür hatası (Python'a dönülürse)
`CGEventTapCreate`'in döndürdüğü `tap`, `source`, `callback` nesneleri
(ve `NSEvent` global monitor + handler) bir thread fonksiyonunda **yerel
değişken** olarak bırakılırsa, fonksiyon bitince Python çöp topluyor —
macOS tarafı bunu saymadığı için tap sessizce ölüyor, hiçbir olay gelmiyor.
Hepsi `self.` altında saklanmalı.

## 4. Apple Silicon'da Rosetta tuzağı
Elle paketlenmiş (py2app olmayan) bir `.app`, Finder/`open` üzerinden
açılınca bazen Rosetta'ya (x86_64) düşüp arm64-only derlenmiş kütüphanelerle
(`numpy`, `mlx`) çöküyor. Çözüm: launcher'da `exec arch -arm64 ...` ile
mimariyi zorla.

## 5. Lokal LLM ile transkript temizleme — çalışan altyapı, tekrar kurulabilir
**Ollama + `qwen2.5:3b` zaten kurulu ve çalışıyor** (`brew services list`
ile doğrula) — hangi yaklaşımı seçersek seçelim yeniden kurmaya gerek yok.
Küçük modeller (3B) nadiren ya harf yutuyor ("Thank you." → "Thakyou.") ya
da "asla çevirme" talimatına uymuyor. Karakter benzerliği
(`difflib.SequenceMatcher`) bunu YAKALAMIYOR (%89 benzer çıkabiliyor) —
**kelime sayısının düşmesi** asıl güvenilir belirti. İki kontrolü birlikte
kullan: kelime-sayısı-düşüşü + benzerlik eşiği.

## 6. Whisper dil ayarı
`language=` parametresi hiç verilmezse Whisper native auto-detect yapıyor,
TR/EN karışık konuşmayı cümle cümle doğru ayırt ediyor. Sabit dile zorlamaya
gerek yok, varsayılan zaten doğru davranış.

## 7. Hazır uygulama fork'lamanın riski (VoiceInk deneyiminden)
Özellik dolu, "kendi fikri olan" (opinionated) bir uygulamayı fork'lamak
(VoiceInk gibi) onboarding/state-machine'inin dışarıdan verilen config'i
görmezden gelmesi riskini taşıyor — kontrolü tam olarak elimize almıyoruz.
Küçük/sade bir script (whisper-dictate gibi) bu riski taşımıyor ama TCC
sorununa daha açık olabiliyor (bkz. madde 1). İkisi arası bir denge lazım:
büyük ölçüde bizim yazdığımız/kontrol ettiğimiz, ama gerçek bir imza
kimliğiyle paketlenmiş bir şey.
