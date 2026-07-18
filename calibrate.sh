#!/usr/bin/env bash
# calibrate.sh — Protos audio calibration (no sudo needed)
set -euo pipefail

NC='\033[0m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'
log()  { printf "  %s\n" "$*"; }
ok()   { printf "${GREEN}  ✓ %s${NC}\n" "$*"; }
info() { printf "${CYAN}  · %s${NC}\n" "$*"; }
warn() { printf "${YELLOW}  ! %s${NC}\n" "$*"; }

cd "$(dirname "$0")"
PYTHON="python3"
[ -f "venv/bin/python" ] && PYTHON="venv/bin/python"

${PYTHON} << 'PYEOF'
import sounddevice as sd
import numpy as np
import time

SR = 48000  # use common rate, let PortAudio resample
BLOCK = 3   # seconds

def measure(device, desc):
    try:
        info = sd.query_devices(device)
        sr = int(info['default_samplerate'])
        audio = sd.rec(int(BLOCK * sr), samplerate=sr, channels=1,
                       device=device, blocking=True)
        rms = float(np.sqrt(np.mean(audio ** 2)))
        peak = float(np.max(np.abs(audio)))
        return rms, peak
    except Exception as e:
        return None, str(e)

print()
print("  " + "-" * 50)
print("  INPUT DEVICES")
print("  " + "-" * 50)
inputs = [(i, d) for i, d in enumerate(sd.query_devices()) if d['max_input_channels'] > 0]
for idx, dev in inputs:
    name = dev['name']
    rms, peak = measure(idx, 'input')
    if rms is not None and rms > 0:
        db = 20 * np.log10(rms + 1e-10)
        bar = "█" * int(min(rms * 500, 40))
        print(f"    {idx:>2}: {name}")
        print(f"         noise: {rms:.4f} RMS ({db:.0f} dB)  {bar}")
    else:
        print(f"    {idx:>2}: {name}  (skip)")

default_in = sd.default.device[0]
print()
print("  " + "-" * 50)
print("  CALIBRATION (default input)")
print("  " + "-" * 50)

try:
    info = sd.query_devices(default_in)
    sr = int(info['default_samplerate'])
    print(f"  Device: {default_in} ({info['name']}) @ {sr} Hz")

    print("  >>> Call 3s for noise measurement...")
    noise = sd.rec(int(BLOCK * sr), samplerate=sr, channels=1,
                   device=default_in, blocking=True)
    noise_rms = float(np.sqrt(np.mean(noise ** 2)))
    noise_db = 20 * np.log10(noise_rms + 1e-10) if noise_rms > 0 else -100
    print(f"  Noise floor: {noise_rms:.4f} RMS ({noise_db:.0f} dB)")

    print("  >>> Now speak normally for 3s...")
    speech = sd.rec(int(BLOCK * sr), samplerate=sr, channels=1,
                    device=default_in, blocking=True)
    speech_rms = float(np.sqrt(np.mean(speech ** 2)))
    speech_db = 20 * np.log10(speech_rms + 1e-10) if speech_rms > 0 else -100
    print(f"  Speech level: {speech_rms:.4f} RMS ({speech_db:.0f} dB)")

    snr = speech_db - noise_db if abs(noise_db) < 100 else 0
    ratio = speech_rms / max(noise_rms, 0.0001)

    print()
    print("  " + "-" * 50)
    print("  RESULT")
    print("  " + "-" * 50)
    print(f"  SNR: {snr:.0f} dB  |  Signal ratio: {ratio:.1f}x")

    if ratio < 2:
        print("  ⚠  Very quiet. Move closer to mic or increase gain.")
    elif ratio < 5:
        print("  ⚠  Quiet but usable. Consider USB headset for better quality.")
    else:
        print("  ✓  Good signal level.")

    vad = "0.04"
    if ratio > 20:
        vad = "0.08"
    elif ratio < 3:
        vad = "0.02"

    print()
    print("  Recommended .env settings:")
    print(f'    PROTOS_VAD_THRESHOLD={vad}')
    print(f'    # PROTOS_INPUT_DEVICE={default_in}  # uncomment to force')
    print(f'    # PROTOS_OUTPUT_DEVICE=<number>')

except Exception as e:
    print(f"  Error: {e}")

print()
print("  Output devices (for PROTOS_OUTPUT_DEVICE):")
for i, d in enumerate(sd.query_devices()):
    if d['max_output_channels'] > 0:
        mark = "  ← default" if i == sd.default.device[1] else ""
        print(f"    {i:>2}: {d['name']}{mark}")
print()
PYEOF