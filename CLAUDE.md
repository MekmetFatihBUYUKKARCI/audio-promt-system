# Sesli Prompt Sistemi — "Audio Promt"

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

## Durum (2026-09-05) — canlı, her faz bitince güncellenir

İki eski yaklaşım terk edildi (VoiceInk, whisper-dictate — TCC/onboarding
sorunları, bkz. `research/dersler.md`). Üçüncü yaklaşım (sıfırdan native
Swift, izin ihtiyacına göre katmanlanmış mimari) **tamamlandı ve
üretimde**: Faz 0-5 + UI + kısayollar hepsi bitti, test edildi, GitHub'a
push edildi.

Sistem uçtan uca çalışıyor: `⌃⌥1` (veya basılı-tutma tuşu) → konuş →
otomatik/elle durdur → temizlenmiş metin otomatik yerine düşer →
geçmişe kaydedilir.

**2026-09-05'te PLAN.md, Fatih'in isteğiyle tamamen yeniden yazıldı:**
artık uzun anlatı/gerekçe değil, kısa durum + "Yapılacaklar" checklist'i
+ sıkıştırılmış teknik referans. Eski ayrıntılı araştırma sürümü git
geçmişinde duruyor (`git log -- PLAN.md`), gerekirse oradan bakılır.
Kalan tek açık iş PLAN.md'nin "Yapılacaklar" bölümünde.

**Her oturumda önce `PLAN.md`'ye bak (artık kısa, hızlı okunur), orayı
güncelle. Her ilerlemede bu dosyanın "Durum" bölümü de kısa özetle
güncellenir — sadece `PLAN.md`'de bırakılmaz.**

## Planın temel içgörüsü

Önceki iki deneme, macOS Erişilebilirlik (TCC) iznine birinci günde
bağımlı oldukları için öldü. Yeni plan izni en sona bırakır:

- Kısayol için **Carbon `RegisterEventHotKey`** kullanılır — `CGEventTap`
  ve `NSEvent` global monitor'ün aksine **Erişilebilirlik izni istemez**.
- Metin panoya yazılır (izin gerekmez); Erişilebilirlik izni verilmişse
  otomatik ⌘V da basılır (2026-09-05'te doğrulandı: imza sorunu gerçekten
  çözüldü). İzin yoksa/geri alınırsa sessizce panoya yazma tek başına
  yeterli kalır, sistem hiç kırılmaz.

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

Repo (public, MIT): **github.com/MekmetFatihBUYUKKARCI/audio-promt-system**
(`origin` olarak bağlı, lokal `main` dalında commit'ler atılıyor).

## Sabit kurallar

- **Plan sırası kırılmaz — asla sormadan atlama.** Bir özellik isteği
  PLAN.md'nin "Yapılacaklar" sırasıyla çakışırsa **önce çakışmayı söyle,
  onay bekle** — isteği doğrudan uygulayıp sırayı kendiliğinden kırma.
- **Otomatik `git push` yok.** Remote bağlı ve lokal commit'ler atılıyor
  ama uzağa göndermek sadece Fatih söyleyince.
- **Proje kökü kesin olarak `~/audio promt/`.** Başka hiçbir yerde
  (MehmetOS kasası dahil) kopya tutulmaz.
- Yukarıdaki **dosya senkron protokolü** her zaman geçerli.
- **PLAN.md'nin içeriğini büyük ölçüde/yapısal olarak değiştirmeden
  önce onay al** (2026-09-05 dersi: bölüm 6.4/6.5'e "yazılmayacak" notu
  eklerken önce sormadan yazmıştım, Fatih'in tepkisi: "planı zırt pırt
  güncelleme, onay almadan önceden oluşturduğumuza dokunma, bir ton
  araştırma yaptık." — aynı gün, 2026-09-05, Fatih PLAN.md'nin tamamen
  kısa/checklist formatına yeniden yazılmasını **açıkça istedi**, o
  onayla bugünkü kısa format ortaya çıktı). Durum/ilerleme takibi
  ("Durum" bölümü, "Yapılacaklar" checkbox'ları) her zamanki gibi
  serbestçe güncellenir — kısıtlanan, yapısal/kapsamlı bir yeniden
  yazımı Fatih'in açık isteği olmadan kendiliğinden yapmak.
