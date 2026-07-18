#!/usr/bin/env bash
# calibrate.sh — Protos audio calibration (no sudo needed)
set -euo pipefail

NC='\033[0m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'
log()  { printf "  %s\n" "$*"; }

cd "$(dirname "$0")"
PYTHON="python3"
[ -f "venv/bin/python" ] && PYTHON="venv/bin/python"

${PYTHON} << 'PYEOF'
import sounddevice as sd
import numpy as np
import sys

def measure(device, seconds, label):
    info = sd.query_devices(device)
    sr = int(info['default_samplerate'])
    frames = int(seconds * sr)
    print(f"  {label} ({seconds}s)...", end=" ", flush=True)
    audio = sd.rec(frames, samplerate=sr, channels=1, device=device, blocking=True)
    rms = float(np.sqrt(np.mean(audio ** 2)))
    peak = float(np.max(np.abs(audio)))
    db = 20 * np.log10(rms + 1e-10)
    bar = "█" * int(min(rms * 800, 40))
    print(f"{rms:.4f} RMS ({db:.0f} dB)  {bar}")
    return rms, peak, audio.flatten()

default_in = sd.default.device[0]
info = sd.query_devices(default_in)
sr = int(info['default_samplerate'])

print()
print("  Protos Audio Calibration")
print("  " + "-" * 50)
print(f"  Input:  device {default_in} ({info['name']}) @ {sr} Hz")
print(f"  Output: device {sd.default.device[1]}")
print("  " + "-" * 50)

# 1) Pure silence
input("  [ENTER] when ready (silence)...")
noise_rms, _, _ = measure(default_in, 3, "  Silence")

# 2) Whisper
input("  [ENTER] then whisper: 'uno dos tres...'")
whisper_rms, _, _ = measure(default_in, 2, "  Whisper")

# 3) Normal voice
input("  [ENTER] then say NORMAL: 'Hola Protos, esta es mi voz normal'")
norm_rms, _, _ = measure(default_in, 3, "  Normal")

# 4) Loud
input("  [ENTER] then say LOUD: 'HOLA PROTOS! FUNCIONA EL MICROFONO!'")
loud_rms, _, _ = measure(default_in, 2, "  Loud")

# 5) Background noise
input("  [ENTER] and stay silent 3s with ambient noise...")
ambient_rms, _, _ = measure(default_in, 3, "  Ambient")

print()
print("  " + "-" * 50)
print("  RESULTS")
print("  " + "-" * 50)
print(f"  Noise floor: {noise_rms:.4f}")
print(f"  Whisper:     {whisper_rms:.4f}")
print(f"  Normal:      {norm_rms:.4f}")
print(f"  Loud:        {loud_rms:.4f}")
print(f"  Ambient:     {ambient_rms:.4f}")

# Optimal thresholds
noise_floor = min(noise_rms, ambient_rms)
speech_floor = max(whisper_rms, norm_rms * 0.3)

vad = "0.04"
ratio = norm_rms / max(noise_floor, 0.0001)
if ratio > 15:
    vad = "0.08"
elif ratio > 8:
    vad = "0.06"
elif ratio < 3:
    vad = "0.02"

energy_gate = max(noise_floor * 1.8, 0.003)
silence_gate = noise_floor * 2.5

print()
print("  " + "-" * 50)
print("  RECOMMENDED .env")
print("  " + "-" * 50)
print(f"  PROTOS_VAD_THRESHOLD={vad}")
print(f"  # PROTOS_MAX_RECORD_SEC=5")
print(f"  # PROTOS_INPUT_DEVICE={default_in}")
print(f"  # PROTOS_OUTPUT_DEVICE=<see below>")
print(f"  # SNR: {20 * np.log10(ratio):.0f} dB  ({ratio:.1f}x)")

if ratio < 2:
    print("  ⚠  Mic too quiet. Move closer or raise gain.")
elif ratio < 5:
    print("  ⚠  Low volume. Usable if quiet environment.")

print()
print("  Output devices (add to PROTOS_OUTPUT_DEVICE):")
for i, d in enumerate(sd.query_devices()):
    if d['max_output_channels'] > 0:
        mark = "  ← default" if i == sd.default.device[1] else ""
        print(f"    {i:>2}: {d['name']}{mark}")
print()
PYEOF