#!/usr/bin/env python3
"""Generate the Tidy Nook sound effects as 16-bit mono 44.1 kHz WAV files.

Mirrors tone() and sfx in web-preview/index.html (Web Audio):
  gain 0 at start -> linear ramp to the peak volume at +10 ms -> exponential decay to 0.0001 at +duration.
Uses only the Python standard library. Run from anywhere:  python3 tool/make_sounds.py
All files share one gain so their relative loudness matches the HTML; the loudest sample
of all files is normalised to -6 dBFS.
"""
import math
import os
import struct
import wave

RATE = 44100
ATTACK = 0.01
FLOOR = 0.0001
PEAK_DBFS = -6.0
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sounds")


def wave_value(kind, phase):
    """phase in cycles."""
    x = phase - math.floor(phase)
    if kind == "triangle":
        # Same shape as the Web Audio triangle: 0 -> 1 -> 0 -> -1 -> 0 over one cycle.
        if x < 0.25:
            return 4.0 * x
        if x < 0.75:
            return 2.0 - 4.0 * x
        return 4.0 * x - 4.0
    return math.sin(2.0 * math.pi * x)


def envelope(t, peak, dur):
    if t < 0:
        return 0.0
    if t < ATTACK:
        return peak * t / ATTACK
    if t >= dur:
        return FLOOR
    return peak * (FLOOR / peak) ** ((t - ATTACK) / (dur - ATTACK))


def tone(buf, freq, start, dur, kind, vol):
    """Add tone(freq, start, dur, kind, vol) to buf (list of floats)."""
    n0 = int(round(start * RATE))
    n1 = int(round((start + dur + 0.02) * RATE))
    ensure(buf, n1)
    for n in range(n0, n1):
        t = n / RATE - start
        buf[n] += wave_value(kind, freq * t) * envelope(t, vol, dur)


def sweep(buf, f0, f1, sweep_dur, total_dur, vol_peak, attack, decay_end):
    """Sine with exponential frequency sweep and exponential gain curve (sfx.lid)."""
    n1 = int(round(total_dur * RATE))
    ensure(buf, n1)
    phase = 0.0
    for n in range(n1):
        t = n / RATE
        f = f0 * (f1 / f0) ** (t / sweep_dur) if t < sweep_dur else f1
        phase += f / RATE
        if t < attack:
            g = FLOOR * (vol_peak / FLOOR) ** (t / attack)
        elif t < decay_end:
            g = vol_peak * (FLOOR / vol_peak) ** ((t - attack) / (decay_end - attack))
        else:
            g = FLOOR
        buf[n] += math.sin(2.0 * math.pi * phase) * g


def ensure(buf, n):
    if len(buf) < n:
        buf.extend([0.0] * (n - len(buf)))


def make_all():
    sounds = {}

    b = []
    tone(b, 540, 0, 0.07, "sine", 0.07)
    sounds["pick"] = b

    b = []
    tone(b, 1046, 0, 0.06, "triangle", 0.11)
    tone(b, 1568, 0.05, 0.09, "triangle", 0.09)
    sounds["place"] = b

    b = []
    tone(b, 210, 0, 0.14, "sine", 0.08)
    sounds["miss"] = b

    b = []
    for i, f in enumerate([784, 988, 1175, 1568]):
        tone(b, f, i * 0.09, 0.25, "triangle", 0.09)
    sounds["win"] = b

    b = []
    for i, f in enumerate([660, 880]):
        tone(b, f, 0.3 + i * 0.1, 0.2, "sine", 0.07)
    sounds["deco"] = b

    # sfx.lid(true): 260 -> 520 Hz over 0.22 s; gain 0.0001 -> 0.08 at 0.03 s -> 0.0001 at 0.26 s; stops at 0.3 s
    b = []
    sweep(b, 260, 520, 0.22, 0.3, 0.08, 0.03, 0.26)
    sounds["lid_open"] = b

    # sfx.lid(false): 520 -> 240 Hz, same gain curve, then tone(180, 0.24, 0.12, triangle, 0.1)
    b = []
    sweep(b, 520, 240, 0.22, 0.3, 0.08, 0.03, 0.26)
    tone(b, 180, 0.24, 0.12, "triangle", 0.1)
    sounds["lid_close"] = b

    b = []
    for i, f in enumerate([523, 659, 784, 1046, 1318]):
        tone(b, f, 0.35 + i * 0.08, 0.3, "triangle", 0.08)
    sounds["room"] = b

    b = []
    tone(b, 880, 0, 0.12, "sine", 0.06)
    sounds["hint"] = b

    b = []
    tone(b, 988, 0, 0.1, "triangle", 0.08)
    sounds["toggle"] = b

    return sounds


def main():
    sounds = make_all()
    peak = max(abs(s) for buf in sounds.values() for s in buf)
    gain = (10.0 ** (PEAK_DBFS / 20.0)) / peak
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, buf in sounds.items():
        path = os.path.join(OUT_DIR, name + ".wav")
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(b"".join(
                struct.pack("<h", max(-32768, min(32767, int(round(s * gain * 32767.0))))) for s in buf))
        print("%-10s %.3f s" % (name + ".wav", len(buf) / RATE))
    print("gain %.2f (loudest sample = %.1f dBFS)" % (gain, PEAK_DBFS))


if __name__ == "__main__":
    main()
