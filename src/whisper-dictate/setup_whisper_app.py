#!/usr/bin/env python3
"""Build WhisperDictate.app — lightweight shell-based .app bundle.

Creates a macOS .app that launches whisper_dictate.py using the conda voice env.
This avoids py2app's recursion issues with mlx while still getting a proper
window server connection (fixing NSPanel visibility).

Usage:
    python setup_whisper_app.py
"""
from __future__ import annotations

import os
import plistlib
import stat
import shutil
import subprocess
import sys

APP_NAME = "WhisperDictate"
APP_DIR = os.path.expanduser(f"~/Applications/{APP_NAME}.app")
CONTENTS = os.path.join(APP_DIR, "Contents")
MACOS = os.path.join(CONTENTS, "MacOS")
RESOURCES = os.path.join(CONTENTS, "Resources")

# Orijinal script bu ikisini yazarın kendi makinesine (~/Scripts,
# ~/miniconda3/envs/voice) sabitlemişti — WHISPER_PYTHON dokümante
# edilmişti ama koda hiç bağlanmamıştı. Artık: script bu dosyanın yanında
# aranıyor, Python da (env override yoksa) bizi çalıştıran yorumlayıcı
# (venv) — nereye klonlanırsa klonlansın doğru çalışsın diye.
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SCRIPT_PATH = os.path.join(SCRIPT_DIR, "whisper_dictate.py")
CONDA_PYTHON = os.environ.get("WHISPER_PYTHON") or sys.executable

PLIST = {
    "CFBundleName": APP_NAME,
    "CFBundleDisplayName": "Whisper Dictate",
    "CFBundleIdentifier": "com.user.whisper-dictate",
    "CFBundleVersion": "2.0.0",
    "CFBundleShortVersionString": "2.0",
    "CFBundleExecutable": APP_NAME,
    "CFBundlePackageType": "APPL",
    "LSUIElement": True,
    "NSMicrophoneUsageDescription": "Whisper Dictate needs microphone access for voice input.",
    "LSMinimumSystemVersion": "13.0",
}

LOG_FILE = os.path.expanduser("~/.config/whisper/app.log")

CRASH_LOG = os.path.expanduser("~/.config/whisper/crash.log")

LAUNCHER = f"""#!/bin/bash
export PATH="/opt/homebrew/bin:$PATH"
# Finder/LaunchServices üzerinden açılan universal2 binary'ler bazen
# Rosetta'ya (x86_64) düşüyor; Terminal'den native arm64 calisiyordu.
# Native mimariyi zorluyoruz, yoksa arm64-only derlenmis .so'lar
# (numpy vb.) "incompatible architecture" hatasi veriyor.
exec arch -arm64 "{CONDA_PYTHON}" -u "{SCRIPT_PATH}" 2>> "{CRASH_LOG}"
"""


def main():
    if os.path.exists(APP_DIR):
        shutil.rmtree(APP_DIR)
        print(f"Removed existing {APP_DIR}")

    os.makedirs(MACOS, exist_ok=True)
    os.makedirs(RESOURCES, exist_ok=True)

    plist_path = os.path.join(CONTENTS, "Info.plist")
    with open(plist_path, "wb") as f:
        plistlib.dump(PLIST, f)
    print(f"Wrote {plist_path}")

    launcher_path = os.path.join(MACOS, APP_NAME)
    with open(launcher_path, "w") as f:
        f.write(LAUNCHER)
    os.chmod(launcher_path, stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IXOTH)
    print(f"Wrote {launcher_path}")

    subprocess.run(["codesign", "-s", "-", "--force", "--deep", APP_DIR], check=True)
    print(f"\n✅ Built and signed {APP_DIR}")
    print(f"   Launch: open ~/Applications/{APP_NAME}.app")
    print(f"   Add to Login Items: System Settings → General → Login Items")
    print(f"   ⚠️  Re-grant Accessibility: System Settings → Privacy → Accessibility → remove & re-add")


if __name__ == "__main__":
    main()
