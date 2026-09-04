---
title: Araştırma Notları — Sesli Prompt Sistemi
tags: [research, voice, claude-code]
---

# Kaynak video

- OnurTirpan — "Claude Code'u nasıl kullanıyorum? Sıfırdan AI destekli uygulama geliştiriyoruz!"
- https://youtu.be/EIoPt1ry6ng — 1sa53dk (6795sn)
- Repo (demo app, araç değil): https://github.com/onurtirpan/todo-yt
- Kanal: Kick, Twitch, IG, LinkedIn, Twitter — hepsi @onurtirpan / OnurTirpan

## Bölüm haritası (video açıklamasından)
- 00:00 Giriş: Stack (Go + React + SQLite), Opus 4.8 Max Thinking, Caveman modu
- 06:10 **Setup: Sesli komut, çift Claude hesabı, MCP'ler (Context7, SuperPower, Playwright)**
- 09:30 3 sub-agent paralel (DB/API/Frontend) + orchestrator
- 33:30 İlk test, UI beğenmedi
- 38:00 5 farklı UI tasarımı → "Frost" seçimi
- 1:00:40 Intent Detection (GPT-5.4)
- 1:10:50 Debug Event Overlay (LLM maliyet/süre log)
- 1:17:20 AI Research Pipeline (Firecrawl)
- 1:28:30 GPT-5.4 Mini vs Medium maliyet karşılaştırma
- 1:38:10 Codex ile ikinci görüş (security tarama)

Kullandığı skill/pluginler (açıklamadan): `/frontend-design`, `/caveman`, `/brainstorming`, `context7`.

## 05:30–10:20 altyazı özeti (sesli komut kısmı)
- Sesli prompt'u **2 aydır** kullanıyor, toplam **~300.000 kelime** söylemiş.
- "Bunu yazmak çok uzun sürüyor... çok kolaylaştırıyor hayatım" — klavye yerine konuşarak prompt veriyor.
- Ayrıca önceden hazırladığı **tek bir sabit prompt** var (API key isimleri, hangi sistemler, dokümantasyon URL'leri) — bunu direkt yapıştırıyor, aramakla uğraşmıyor. Bu voice tool'dan bağımsız, ayrı bir "context primer" pratiği.
- Altyazıda araç adı hiç geçmiyor (konuşarak söylemiyor) — **kare incelemesiyle** bulundu (aşağıya bak).
- 01:48:37 "dikte ettiğim" geçen yer kontrol edildi → **alakasız**, video sonundaki genel kapanış konuşmasının parçası (kelimenin gündelik anlamı, araçla ilgisi yok).

## Bulunan araç: **Wispr Flow**
- Windows'ta (kendisi Windows kullanıyor, `PS C:\dev\ops\note-yt>`) sistem tepsisi (tray) menüsünden teşhis edildi: `Home / Check for updates / Paste last transcript (Alt+Shift+Z) / Shortcuts / Microphone / Languages / Help Center / Talk to support / General feedback / Exit`.
- Bu menü metni birebir Wispr Flow'un resmi dokümantasyonundaki (docs.wisprflow.ai) tray menüsüyle eşleşiyor.
- Dil listesinde İngilizce + Türkçe işaretli, açıklamada da "bazen İngilizce/Türkçeye çeviriyor, Türkçeyi çıkaracağım" diyor — çoklu dil desteği doğrulandı.
- Claude Code terminaline direkt dikte ediyor; bazı terminal/CLI uygulamaları clipboard'u kısıtladığı için Wispr Flow'un "Paste last transcript" (Alt+Shift+Z) özelliğini yedek olarak kullanıyor (bu tam da Wispr Flow'un resmi "Fix text not pasting after dictation" / "Using Flow with Linux, WSL, and Terminal Applications" dokümantasyonunda anlatılan senaryo).
- **Wispr Flow kapalı kaynak, ücretli** (abonelik).

## GitHub taraması — açık kaynak eşleniği
Birebir Wispr Flow klonu yok (kapalı kaynak, klonlanacak repo değil). En yakın **açık kaynak alternatifler**:

| Araç | Platform | Lisans | Not |
|---|---|---|---|
| **VoiceInk** (`beingpax/VoiceInk`) | **macOS** (Apple Silicon) | GPLv3, 3700+ star | En olgun/aktif proje. whisper.cpp ile tamamen lokal. Sistem geneli çalışır, per-app "Power Mode". **Fatih Mac kullanıyor → en uygun aday.** |
| OpenWhispr | macOS/Windows/Linux | MIT | Whisper veya NVIDIA Parakeet, kendi donanımında |
| Voicetypr (`moinulmoin/voicetypr`) | macOS/Windows | - | Global kısayol, push-to-talk, otomatik yapıştırma |
| SpeakoFlow | Win/mac/Linux | açık kaynak | Ekstra: ekranı okuyup soru cevaplayan asistan katmanı var |

## Öneri
Sıfırdan yazmaya gerek yok. **VoiceInk** (github.com/beingpax/VoiceInk) klonlanıp Fatih'in Mac'inde kurulup denenmeli — Wispr Flow'un yaptığı "her yere sesli yazma" işini lokal + ücretsiz + açık kaynak yapıyor. Sonraki adım: repoyu klonla, kur, gerçek kullanımda test et; eksik kalan bir şey varsa (örn. Claude Code terminaline yapıştırma davranışı) üstüne ince ayar/patch yaz — VoiceInk'i fork edip özelleştirmek, sıfırdan yazmaktan çok daha az iş.

## Temizlik
Video/klip/kareler/altyazı öğrenildikten sonra silindi — kalıcı olan sadece bu not dosyası.

## Güvenlik incelemesi (VoiceInk, 2026-09-04)
Repo klonlanıp kaynak kod, bağımlılıklar, entitlement'lar ve GitHub geçmişi tarandı.

**Temiz çıkanlar:**
- Telemetri/analitik/crash-reporting SDK'sı yok (Sentry/Mixpanel/Firebase vb. aranmadı, yok).
- Kod içinde obfuscation/base64 blob şüphesi yok.
- Sparkle otomatik güncelleme **EdDSA imzalı** (`SUPublicEDKey` gömülü) — sahte güncelleme sunulamaz. Otomatik kontrol varsayılan **kapalı** (`SUEnableAutomaticChecks = false`).
- Tüm build hedefleri tek geliştirici ekibiyle (`DEVELOPMENT_TEAM = V6J6A3VWY2`) tutarlı imzalanmış.
- Bağımlılıklar (AXSwift, KeySender, Sparkle, Apple'ın kendi MLX'i, vb.) hepsi tanınan/takip edilebilir açık kaynak, typosquat şüphesi yok.
- Ağ çağrıları sadece: (a) kullanıcı kendi API key'ini girerse bulut STT/LLM sağlayıcıları (OpenAI, Anthropic, Groq...), (b) whisper model indirme (HuggingFace), (c) lisans/destek/Discord linkleri. Lokal Whisper modeliyle çalışınca **sıfır ağ çağrısı**.
- GitHub: 6293 star, 897 fork, 125 açık issue, 2024-10'dan beri aktif, son push 2026-09-02 (2 gün önce). **0 yayınlanmış security advisory.**
- Bilinen malware/güvenlik şikayeti yok (web taraması temiz).
- Lisans: gerçek GPLv3, ek gizli madde yok. Kaynak kod ücretsiz derlenebilir; satın alma sadece otomatik güncelleme + öncelikli destek + iCloud sync için (open-core model, README'de açıkça yazıyor).

**Dikkat edilecek / normal ama not düşülmesi gereken:**
- **App Sandbox kapalı** (`com.apple.security.app-sandbox = false`) — macOS sandbox koruması yok, tam kullanıcı yetkisiyle çalışıyor. Dikte edilen metni her uygulamaya yazabilmesi (Accessibility/AppleEvents) için bu **gerekli ve beklenen** bir tasarım, ama "app bir bug içerirse blast radius büyük" demek.
- `screen-capture` entitlement'ı var — dictation app için sıra dışı, muhtemelen "aktif pencere/website algılama" özelliği için (`NSAppleEventsUsageDescription` bunu doğruluyor: "hangi web sitesinde olduğunu anlamak için tarayıcıyla konuşuyor"). Kötüye kullanım izi yok ama kurulumda bu izni neden istediğini bilerek onayla.
- `network.server` entitlement'ı var (muhtemelen yerel Ollama/XPC servisi içindir), zararlı bir şey görülmedi ama kurulum sonrası Little Snitch/Radar gibi bir araçla ilk açılışta dışarı ne konuştuğunu bir kez gözlemlemek iyi olur.

**Sonuç: Kurulum için güvenli görünüyor.** Şeffaf, aktif, telemetrisiz, imzalı güncellemeli açık kaynak proje. Kalan tek "kör nokta" derlenmiş .dmg'nin GitHub Releases'teki halinin kaynak koduyla birebir eşleştiğini objektif olarak doğrulayamıyor olmamız (reproducible build kanıtı yok) — bu her açık kaynak masaüstü uygulaması için geçerli genel bir sınırlama, VoiceInk'e özgü bir kırmızı bayrak değil. İstenirse kaynaktan kendimiz derleriz, bu riski tamamen sıfırlar.
