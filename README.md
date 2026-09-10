# Audio Promt

A macOS menu bar app that types text by voice anywhere you have a cursor
(especially the Claude Code terminal), instead of the keyboard. Fully
local: audio recording, Whisper transcription (WhisperKit) and LLM
cleanup (Ollama) never leave this computer. No server, no cloud, no
telemetry, no cost.

> **macOS only, Apple Silicon only.** No Windows/Linux support, and none
> planned — the hotkey (Carbon), audio capture (AVFoundation),
> transcription acceleration (CoreML/Apple Neural Engine), the permission
> system (TCC) and the UI (AppKit/SwiftUI) are all Apple-only APIs.
> Developed and tested on Apple Silicon (M1/M2/M3/M4...); not tried on
> Intel Macs.

Follow the steps below **in order, without skipping**. Each step has a
single code block — copy it, paste it into Terminal, press Enter, move
to the next. To open Terminal: `⌘+Space` → type "Terminal" → Enter.

---

## 0. Check this first

Both of these must be true:

- **macOS 26 (Tahoe) or newer.** Check: `Apple menu → About This Mac`.
- **Apple Silicon Mac** (M1, M2, M3, M4 — not Intel). Check: the same
  window should show `Apple M...` next to "Chip".

If either is false, this app won't run on this computer — don't continue.

---

## 1. Install Xcode (for the compiler)

Install **Xcode** from the App Store (a few GB, takes a while). Once it
finishes, open it once, accept the license prompt, close it. You won't
touch the Xcode UI for this project at all — you're just getting the
compiler (Swift 6.3+) onto the system.

Verify the install from the terminal:

```
xcode-select -p
```

If it prints a path (something like `/Applications/Xcode.app/...`) you're
set — move to the next step.

---

## 2. Install Homebrew (package manager)

If it's already installed, skip this step — to check:

```
brew --version
```

If you see a version number, skip to step 3. If not, install it:

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

At the end of the install, also paste and run the 1-2 lines of
instructions it prints (usually about `PATH`) — Homebrew shows these
itself when the install finishes.

---

## 3. Install Ollama and download a model

**Ollama** is a free, open-source AI engine that runs on this machine.
Audio Promt uses it to clean up your raw dictation (filler words,
punctuation mistakes). No data goes to the internet; everything stays on
your own computer.

Install:

```
brew install ollama
```

Run it in the background (this command keeps running — don't close the
terminal, or open a new tab):

```
ollama serve
```

**Open a new Terminal tab** (⌘+T) and download the model:

```
ollama pull qwen2.5:3b
```

### Which model should I pick?

This project uses **`qwen2.5:3b`** by default (the command above). The
reasons:

| Property | Why it matters |
|---|---|
| **~2 GB size** | Fast to download, small on disk |
| **3 billion parameters** | Runs comfortably on any Apple Silicon Mac (8 GB RAM included), reply in ~1 second |
| **Multilingual (incl. TR/EN)** | Won't accidentally translate Turkish dictation into English while cleaning it up (a common failure in smaller models) |

If you have a better Mac (16 GB+ RAM) and want to push cleanup quality a
bit further, you can also try:

```
ollama pull qwen2.5:7b
```

After downloading, just change the model name to `qwen2.5:7b` in Audio
Promt's **Settings → Cleanup** tab — no code change needed. Bigger model
= slightly slower but slightly more accurate cleanup. `qwen2.5:3b` is
already enough for most use; we recommend starting with it.

Confirm the model actually downloaded:

```
ollama list
```

You should see `qwen2.5:3b` in the list.

---

## 4. Download and build the project

```
git clone https://github.com/MekmetFatihBUYUKKARCI/audio-promt-system.git
cd audio-promt-system
make bundle sign
```

This can take a few minutes (the first build downloads the WhisperKit
dependency). At the end you'll have `.build/Audio Promt.app`.

---

## 5. Run it

```
open ".build/Audio Promt.app"
```

On first launch macOS may show an **"unidentified developer"** warning
(the app isn't notarized by Apple — a paid path, deliberately not used).
To get past it, one time:

```
xattr -d com.apple.quarantine ".build/Audio Promt.app"
```

then try `open ".build/Audio Promt.app"` again. (Alternative: right-click
the app in Finder → Open.)

Once it's open you'll see a microphone icon in the menu bar (top right of
the screen) — no window opens, the app waits in the background.

---

## 6. Grant permissions

On first use macOS will ask for two permissions:

- **Microphone** — required, no recording without it.
- **Accessibility** — optional. If you grant it, dictated text is pasted
  automatically where your cursor is. If you don't, the system still
  works — it just copies the text to the clipboard and you press ⌘V
  yourself.

Both can be toggled manually under **System Settings → Privacy &
Security**.

---

## 7. (Optional) Permanent install

If you don't want to type `open` in the terminal every time:

```
cp -R ".build/Audio Promt.app" /Applications/
```

Now you can open it from Spotlight (`⌘+Space`, type "Audio Promt") or the
Applications folder, and drag it to the Dock.

If you turn on **"Launch at login"** under Settings → General, it starts
automatically every time the computer boots.

---

## Usage

- **⌃⌥1** — start/stop recording (toggle).
- **Right Option (hold)** — records while held, stops when released. Can
  be changed to a different key in Settings.
- **⌃⌥V** — paste the last transcript again.
- **⌃⌥C** — toggle LLM cleanup on/off.
- **Esc** — cancels recording (discards without transcribing).

The first dictation will be a bit slow (the Whisper model downloads then,
~630 MB, once). On later dictations the model stays in memory and it's
much faster.

## Troubleshooting

- **"No Accessibility permission" / auto-paste not working:** System
  Settings → Privacy & Security → Accessibility must have "Audio Promt"
  checked. If you move the app (e.g. from `.build/` to `/Applications`)
  you may need to grant this permission again for the new location.
- **Ollama connection error / "Ollama not running":** check that a
  terminal window running `ollama serve` is open. Test:
  ```
  curl http://localhost:11434/api/tags
  ```
  If there's no response, Ollama is down. Even while it's down the system
  keeps working — it just skips the cleanup step and uses the raw
  transcript.
- **"command not found: make" or "git":** Xcode Command Line Tools are
  missing — run `xcode-select --install`.

## Privacy

Past dictations are stored as plain JSON under
`~/Library/Application Support/AudioPromt/`, on this machine only. They
can be deleted with **"Clear history"** from the menu or Settings. No
data is sent anywhere over the network.

## Technical detail

For the architecture, design decisions and development process, see
`PLAN.md`.

## License

MIT — see [LICENSE](LICENSE).
