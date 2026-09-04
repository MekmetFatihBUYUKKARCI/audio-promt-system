# Plan — Sesli Prompt Sistemi

## GECE NÖBETİ SONUCU — 2026-09-05, ~01:40 — SABAH İLK OKUNACAK
Fatih uyurken 6 adımlık görev listesi uygulandı: **whisper-dictate
seçildi, tam satır satır incelendi, 4 gerçek hata + 2 küçük eksik
bulunup düzeltildi, kendi kendine (sentetik tuş olayı ile, insansız)
uçtan uca test edildi ve BAŞARILI oldu.** Detay: `research/kod-incelemesi.md`.

**Sistem kanıtlanmış şekilde çalışıyor.** Kalan tek engel kod değil —
macOS'un Erişilebilirlik izni `.app` üzerinden başlatılan sürece
yansımıyor (3 deneyle kesinleştirildi, kod incelemesinde detay var).
Bu, tek bir insan tıklaması gerektiren bir adım; hiçbir agent/otomasyon
macOS'un bu güvenlik penceresini tıklayamaz. **Sabah tek yapılacak şey:**
System Settings → Privacy & Security → Accessibility'de WhisperDictate'i
sil/tekrar-ekle (detaylı 3 adımlı kurtarma planı `kod-incelemesi.md`
sonunda). O tutar tutmaz, **hiçbir kod değişikliği gerekmeden** çalışacak.

**Neden 5-6. adımlara (başka repo ara / sıfırdan yaz) geçmedim:**
Görev tanımı "hâlâ çalışmazsa" diyordu — ama artık çalışıyor (kanıtlı).
Kalan engel bir izin tıklaması, bir kod/repo sorunu değil, ve **her
tuş-tabanlı sesli yazma aracı aynı macOS izin duvarına çarpar** — repo
değiştirmek bunu atlatmaz (VoiceInk'te de muhtemelen aynı sorun vardı,
farklı bir sebeple bıraktık). Çalışan, denetlenmiş, hatası bulunup
düzeltilmiş bir sistemi bir tıklama uğruna çöpe atıp yeniden başlamak
"en iyisini yapmak" olmazdı — kalan vakti kod kalitesine ve planlanan
bir özelliği (Ollama entegrasyonu, aşağıda) gerçekten eklemeye harcadım.

**Bonus — ayrıca eklendi:** Ollama/qwen2.5:3b entegrasyonu (orijinal
script'te hiç yoktu, plan'da vardı) — transkript artık opsiyonel olarak
lokal LLM ile temizleniyor, dil korunuyor (çevrilmiyor), Ollama kapalıysa
sessizce atlıyor. Test edildi, çalışıyor (kod incelemesinde örnek çıktı var).

---

## DURDU — 2026-09-05: VoiceInk yolu terk edildi
VoiceInk fork'u sonuna kadar götürülmedi. Sebep: uygulamanın kendi
onboarding sihirbazı, dışarıdan (`UserDefaults` patch ile) verdiğimiz
yapılandırmayı (Ollama/qwen2.5:3b, Nemotron Multilingual, auto dil) görmezden
gelip kendi sabit varsayılanını (Parakeet — Türkçe desteklemiyor) indirmeye
başladı. Fatih'in tepkisi: "kontrolümün sınırlı olması hiç hoşuma gitmedi" —
üçüncü parti bir uygulamanın opak state machine'ine güvenmek istemiyor.

**Yapılan temizlik:** `/Applications/VoiceInk.app`, `~/Downloads/VoiceInk.app`,
klonlanan `src/VoiceInk` repo'su, tüm `UserDefaults`/`Application Support`/
`Caches`/`Preferences` kalıntıları, Homebrew cask cache'i — hepsi silindi,
doğrulandı (iz yok). **Korunan:** Ollama + `qwen2.5:3b` (VoiceInk'e özgü
değildi, ayrı altyapı, hâlâ duruyor) ve bizim kendi iskeletimiz
(`CLAUDE.md`/`AGENTS.md`/`PLAN.md`/`research/`/git geçmişi) — hiç dokunulmadı.

**Kararların çoğu hâlâ geçerli, sadece "hangi hazır uygulamayı fork'layıp
kuracağız" sorusu yeniden açıldı:**
- Hedef aynı: sesle prompt/metin, özellikle Claude Code terminaline
- Lokal AI enhancement: Ollama + qwen2.5:3b (hazır, kurulu)
- Dil: TR+EN, auto-detect tercih
- Otomatik push yok, beyne otomatik yükleme yok — bu kurallar değişmedi

**Açık soru (bir sonraki oturumda Fatih'le netleştirilecek):** "Sıfırdan
yapacağız" ne demek — (a) VoiceInk'i bırakıp daha az "kendi fikri olan"
(opinionated), onboarding'siz/daha sade başka bir açık kaynak projeye mi
bakalım, yoksa (b) gerçekten kendi küçük aracımızı mı yazalım (macOS
Accessibility API + yerel Whisper/Parakeet modeli + kendi ince arayüzümüz).
(b) çok daha büyük bir iş — konuşmadan varsayılmayacak.

---

(Yukarısı VoiceInk denemesinin özeti — terk edildi, detay orada.
Aşağısı **güncel, aktif plan**: whisper-dictate.)

Bu dosya tek doğruluk kaynağı. Yaptığım her adım buraya işlenir. Bu proje
Jarvis'in genel hafızasına (`🔮 850-Companion`, `knowledge/`) otomatik
yüklenmez — sadece bu klasörde yaşar.

## Hedef
Klavye yerine sesle prompt/metin girme (özellikle Claude Code terminaline).
Karar: **whisper-dictate** (github.com/Scarlettofu/whisper-dictate, MIT,
~1600 satır tek Python dosyası, MLX Whisper). Sebep: VoiceInk'in aksine
onboarding/lisans/opak state machine yok — çıplak, okunabilir, tamamen
bizim elimizde bir script. Detaylı seçim gerekçesi ve elenen alternatifler
(OpenWhispr — çok büyük/kurumsal; WhisperDictation — az test edilmiş):
sohbet geçmişinde, `research/kod-incelemesi.md`'de teknik detay var.

## Kesin kurallar (ben aksini söyleyene kadar geçerli)
- **Otomatik `git push` yok.** Private repo bağlı ve lokal commit'ler
  atılıyor ama uzağa göndermek sadece Fatih söyleyince.
- Bu projenin teknik detayları Jarvis'in "beyin" hafıza sistemine
  otomatik yazılmaz — hepsi bu dosyada ve proje klasöründe kalır.
- `CLAUDE.md` + `AGENTS.md` (symlink, otomatik senkron) proje kökünde
  duruyor: `~/audio promt/CLAUDE.md`. Biri değişince öbürü dosya sistemi
  seviyesinde otomatik değişmiş olur, elle senkron gerekmez.
- **Proje kökü kesin olarak `~/audio promt/`.** Başka hiçbir yerde
  (MehmetOS kasası dahil) kopya tutulmaz.

## Mimari
```
~/audio promt/
├── CLAUDE.md              ← proje hafızası (AGENTS.md symlink)
├── PLAN.md                ← bu dosya, canlı plan/ilerleme
├── research/
│   ├── notlar.md          ← video araştırması + VoiceInk güvenlik incelemesi
│   └── kod-incelemesi.md  ← whisper-dictate satır satır inceleme + bulunan hatalar
└── src/
    └── whisper-dictate/   ← upstream klon + bizim değişikliklerimiz (aynı repo,
                              GPLv3/MIT'e uygun fork — upstream'e PR de atılabilir)
        ├── whisper_dictate.py   ← ana script (bizim 4 bugfix + 2 iyileştirme + Ollama entegrasyonu)
        ├── setup_whisper_app.py ← .app oluşturucu (yol hatası düzeltildi)
        ├── synthetic_key_test.py ← bizim yazdığımız, insansız uçtan-uca öz-test
        └── .venv/               ← Python sanal ortamı (git'e girmiyor)
```
`~/Applications/WhisperDictate.app` kurulu hedef; `~/Library/Preferences/`
ve `~/.config/whisper/` çalışma zamanı verisi (git'e girmiyor).

## Durum (2026-09-05 gece nöbeti sonu)
- [x] Repo seçimi + klon + Python venv + bağımlılıklar kuruldu
- [x] `setup_whisper_app.py` ile `.app` üretimi çalışıyor
- [x] 4 gerçek hata bulundu ve düzeltildi (yol hatası, Rosetta çökmesi,
  yanlış klavye varsayımı, PyObjC ömür hatası) — detay `kod-incelemesi.md`
- [x] Türkçe dolgu-kelime temizleme eklendi (orijinalde yoktu)
- [x] Varsayılan İngilizce/finans anahtar kelimeleri temizlendi
- [x] **Ollama/qwen2.5:3b entegrasyonu eklendi** (plandaki AI-enhancement
  katmanı, orijinal script'te hiç yoktu) — dil koruyarak temizliyor,
  Ollama kapalıysa sessizce atlıyor, açılışta ön-ısıtma yapıyor
- [x] **Uçtan uca insansız öz-test BAŞARILI** (`synthetic_key_test.py` —
  sentetik tuş → kayıt → transkript → post-process → Ollama → yapıştır,
  hepsi doğrulandı, log kanıtı `kod-incelemesi.md`'de)
- [ ] **TEK KALAN ADIM (Fatih'in tıklaması gerekiyor):** macOS
  Erişilebilirlik izni `.app` üzerinden başlatılan sürece yansımıyor
  (kod hatası değil — 3 deneyle kanıtlanmış bir TCC/izin sorunu, detay ve
  kesin kurtarma adımları `kod-incelemesi.md` sonunda). İzin tutar tutmaz
  hiçbir kod değişikliği gerekmeden çalışacak.
- [ ] İzin çözülünce: gerçek fiziksel tuşla (Sağ Command/Option) canlı test
- [ ] Sonra: login'de otomatik başlama (LaunchAgent — taslağı bu gece
  test edildi, izin çözülünce aynısı kalıcı hale getirilecek)
- [ ] Sonra: Faz 2 — küçük kontrol paneli (aşağıya bak)

## Dil davranışı
Whisper'a hiçbir yerde sabit dil verilmiyor (`language=` parametresi hiç
geçmiyor) — bu, mlx_whisper'ın **native auto-detect** davranışını
tetikliyor, cümle cümle TR/EN karışık konuşmayı otomatik ayırt ediyor.
Fatih'in istediği "varsayılan auto, ama açıp kapayabileceğim bir tuş da
olsun" ihtiyacı için: auto zaten varsayılan, sabit dile geçme özelliği
Faz 2'nin (aşağıda) parçası olacak (`config.json`'a `force_language: "tr"`
gibi bir anahtar eklemek birkaç satırlık iş, henüz yapılmadı).

## Faz 2 — Kontrol paneli (backlog, henüz tasarlanmadı)
Fatih'in "her şeyi kontrol edebileceği" tek bakışta bir panel:
- Dikte açık/kapalı durumu
- Dil: Auto-detect ⇄ sabit TR ⇄ sabit EN (tek tık toggle)
- AI Enhancement (Ollama/qwen2.5:3b) açık/kapalı
- Aktif model / hızlı durum bilgisi

whisper-dictate zaten düz `~/.config/whisper/config.json` kullanıyor
(VoiceInk'in opak `UserDefaults`'ından çok daha basit) — kontrol paneli
bu dosyayı okuyup yazacak, script'in kendi koduna dokunmadan. Muhtemel
biçim: küçük bir menü çubuğu widget'ı. Detaylı tasarım, ana akış (yukarıdaki
"Tek kalan adım") çözülüp gerçek kullanımda denendikten sonra.

## Açık soru
Yok — sıradaki adım net: Fatih Erişilebilirlik iznini düzeltince gerçek
tuşla test. Detay ve 3 adımlı kurtarma planı: `research/kod-incelemesi.md`.
