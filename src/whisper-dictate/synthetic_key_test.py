#!/usr/bin/env python3
"""Otonom oz-test: fiziksel tus basisi olmadan, Sag Command'i sentetik
CGEvent ile basip birakarak whisper-dictate'in tam zincirini (tetikleyici ->
kayit -> transkript) dogrular. Gozetimsiz calisir, log dosyasina yazar."""
import time
import Quartz

RIGHT_CMD_KEYCODE = 54


def post_flags_changed(keycode, is_down):
    event = Quartz.CGEventCreateKeyboardEvent(None, keycode, is_down)
    if is_down:
        Quartz.CGEventSetFlags(event, Quartz.kCGEventFlagMaskCommand)
    else:
        Quartz.CGEventSetFlags(event, 0)
    Quartz.CGEventSetType(event, Quartz.kCGEventFlagsChanged)
    Quartz.CGEventPost(Quartz.kCGSessionEventTap, event)


print("Sag Command basiliyor (sentetik)...")
post_flags_changed(RIGHT_CMD_KEYCODE, True)
time.sleep(2.5)
print("Sag Command birakiliyor (sentetik)...")
post_flags_changed(RIGHT_CMD_KEYCODE, False)
print("Gonderildi. app.log kontrol edilecek.")
