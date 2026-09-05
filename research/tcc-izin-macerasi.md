---
title: macOS Erişilebilirlik (TCC) izin macerası — öğrenilenler
tags: [macos, tcc, accessibility, debugging, whisper-dictate]
---

# Ne öğrendik (2026-09-05 sabahı, ~2 saatlik uğraş)

whisper-dictate'in kodu tamamen doğru ve çalışır durumda (sentetik testle
kanıtlı — bkz. `kod-incelemesi.md`). Ama **gerçek fiziksel tuşla asla
çalıştıramadık** çünkü `.app` üzerinden başlatılan süreç hiçbir şekilde
macOS Erişilebilirlik güvenini kazanamadı. Bu dosya, denenen her şeyi ve
neden işe yaramadığını kaydediyor — ileride benzer bir araçla uğraşırken
zaman kaybetmemek için.

## Kesin gözlemler (`AXIsProcessTrusted()` ile ölçüldü)

| Başlatma yolu | Sonuç |
|---|---|
| Bu terminalden (`claude` CLI barındıran ortam) direkt `python3 script.py` | **True** |
| `open WhisperDictate.app` | **False** — hiçbir denemede değişmedi |
| `launchd` LaunchAgent, sarmalayıcısız direkt python | **False** |

## Denenen ve işe yaramayan düzeltmeler (sırayla)
1. **WhisperDictate.app'i Accessibility listesine ekle** — tutmadı.
2. **Sistemde gerçekte çalışan ikilinin `org.python.python` (Python.app,
   `/Library/Frameworks/Python.framework/Versions/3.14/Resources/`)
   olduğunu keşfedip onu ekle** — venv Python'un GUI erişimi için kendi
   içinde bu Python.app'e yeniden exec ettiği `lsof` ile doğrulandı.
   Yine de tutmadı.
3. **Sistemde AYNI isimli iki "Python.app" olduğunu keşfet** —
   `/Library/Developer/CommandLineTools/.../Python3.framework/.../Python.app`
   (Apple'ın kendi, `com.apple.python3`, Python 3.9) vs bizim gerçek
   `org.python.python` (3.14). İkisi de Finder'da sadece "Python" diye
   görünüyor, ayırt edilemiyor — Fatih muhtemelen ilk seferinde yanlışını
   eklemişti. Doğrusunu tam yolla (`Cmd+Shift+G` + tam `.app` yolu) tekrar
   eklettik — yine tutmadı.
4. **`tccutil reset` ile tam temiz sıfırlama + sadece WhisperDictate.app
   tek başına ekleme** (hiçbir Python girdisi karıştırmadan, resmi README
   talimatına birebir uyarak) — yine `False`.
5. **`log stream --predicate 'subsystem == "com.apple.TCC"'` ile canlı
   izleme** — uygulamayı başlatırken bizim PID'imizden **hiçbir** TCC
   isteği görünmedi. Bu, `AXIsProcessTrusted()`'ın her çağrıda tccd'ye
   canlı IPC yapmadığını, muhtemelen yerel bir cache/hızlı-yol
   kullandığını düşündürüyor — ama bu da neden tutmadığını açıklamıyor.
6. **Teori: `.app`'in çalıştırılabilir dosyası bash script, derlenmiş
   Mach-O değil — TCC bazı sürümlerde script-tabanlı exec zincirinde
   kimliği doğru bağlayamıyor olabilir.** Küçük bir C launcher
   (`execv` ile python'u çağıran) yazıp derledik, `.app`'in
   `Contents/MacOS/WhisperDictate`'ini bununla değiştirip yeniden
   imzaladık. **Bu adım gerçek testten önce (izin yeniden eklenip
   denenmeden) Fatih'in "yeter, sıfırla" demesiyle yarım kaldı — sonuca
   varılamadı, ileride denenmeye değer.**
7. **Kararlı kendinden-imzalı sertifika ile imzalama** (ad-hoc yerine)
   — güvenlik sınıflandırıcısı tarafından haklı olarak engellendi
   (kullanıcının gerçek keychain'ine dokunuyor, onun bilgisi/onayı
   olmadan yapılmadı).

## Sonuç / durum
Tüm Accessibility TCC kayıtları (WhisperDictate, her iki Python.app)
`tccutil reset` ile temizlendi, sistem sıfır izin durumunda bırakıldı.
Fatih bu turu burada bıraktı ("sıkıldım, sıfırdan baştan yaparız").
Kod tarafında hiçbir sorun yok — bu tamamen macOS'un TCC/Accessibility
alt sisteminin bu spesifik kurulumda (ad-hoc imzalı, venv Python,
script-tabanlı `.app`) neden güven vermediğine dair çözülmemiş bir
gizem. **Not: bu, whisper-dictate'e özgü değil — aynı yapıyı (Python +
PyObjC + ad-hoc `.app`) kullanan HERHANGİ bir araç aynı duvara çarpar.**

## İleride denenecek fikirler (henüz denenmedi)
- Yukarıdaki 6. adımı (derlenmiş Mach-O launcher) gerçek izin ekleme +
  test döngüsüyle sonuna kadar götürmek.
- Ücretsiz bir Apple ID ile Xcode'a giriş yapıp gerçek (ad-hoc değil)
  bir "Apple Development" imzalama kimliği edinmek — bu, VoiceInk'in de
  `make local` sırasında otomatik kullandığı, TCC'nin daha güvenilir
  bulduğu yol. Bir kere Apple ID girişi (insan gerektirir) sonrası
  tamamen otomatikleştirilebilir.
- Swift/Xcode ile (VoiceInk gibi) gerçek bir `.app` yazmak — Python +
  PyObjC yerine native Swift, script-exec-zinciri sorununu baştan
  ortadan kaldırır. Daha büyük iş ama TCC açısından çok daha az sürpriz.
- Native macOS "Uygulama Kısayolları" / Shortcuts.app üzerinden bir
  kısayol tetikleyici olarak dictation başlatmak — TCC'nin zaten
  güvendiği sistem bileşenlerini (Shortcuts) kullanmak.
