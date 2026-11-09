#!/usr/bin/env python3
"""Synthesizes the pack-opening and card-merge sound effects.

Usage (from the repo root):  python3 tool/generate_sfx.py

Needs numpy, scipy and ffmpeg (libmp3lame). Writes assets/audio/sfx_*.mp3.
Everything is generated from code with a fixed seed, so the files are
reproducible and every recipe below can be tuned and re-rendered. The
sounds are deliberately synthetic (sweeps, bells, booms): short, clean
and licence-free. Swap any file for a recorded one with the same name and
the game picks it up unchanged.
"""

import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy import signal

SR = 44100
RNG = np.random.default_rng(7)
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


# ---------------------------------------------------------------- helpers
def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def fade(x, a=0.004, r=0.02):
    """Short fade in/out so nothing clicks."""
    n = len(x)
    na, nr = min(int(a * SR), n), min(int(r * SR), n)
    x = x.copy()
    if na:
        x[:na] *= np.linspace(0, 1, na)
    if nr:
        x[-nr:] *= np.linspace(1, 0, nr)
    return x


def chirp_phase(f0, f1, dur, exp=True):
    t = t_axis(dur)
    if exp:
        k = (f1 / f0) ** (1 / dur)
        return 2 * np.pi * f0 * (k**t - 1) / np.log(k)
    return 2 * np.pi * (f0 * t + (f1 - f0) * t**2 / (2 * dur))


def sweep_tone(f0, f1, dur, harmonics=(1.0,), exp=True):
    ph = chirp_phase(f0, f1, dur, exp)
    return sum(a * np.sin((i + 1) * ph) for i, a in enumerate(harmonics))


def swept_noise(dur, f0, f1, q=2.0, blocks=48):
    """Band-passed noise whose centre frequency glides f0 -> f1."""
    n = int(dur * SR)
    noise = RNG.standard_normal(n)
    out = np.zeros(n)
    win = np.hanning(2 * (n // blocks) + 2)
    hop = n // blocks
    for b in range(blocks):
        fc = f0 * (f1 / f0) ** (b / max(blocks - 1, 1))
        lo, hi = fc / (1 + 1 / q), min(fc * (1 + 1 / q), SR / 2 - 100)
        sos = signal.butter(2, [lo, hi], "band", fs=SR, output="sos")
        seg = signal.sosfilt(sos, noise)
        start = b * hop
        end = min(start + len(win), n)
        out[start:end] += seg[start:end] * win[: end - start]
    return out / (np.max(np.abs(out)) + 1e-9)


def lowpass(x, fc, order=4):
    return signal.sosfilt(signal.butter(order, fc, "low", fs=SR, output="sos"), x)


def highpass(x, fc, order=4):
    return signal.sosfilt(signal.butter(order, fc, "high", fs=SR, output="sos"), x)


def reverb(x, tail=1.2, wet=0.3):
    n = int(tail * SR)
    ir = RNG.standard_normal(n) * np.exp(-np.linspace(0, 6, n))
    ir = lowpass(ir, 6000)
    wetsig = signal.fftconvolve(x, ir)
    wetsig /= np.max(np.abs(wetsig)) + 1e-9
    dry = np.pad(x, (0, len(wetsig) - len(x)))
    return dry + wet * wetsig * np.max(np.abs(x))


def bell(freq, dur, decay=4.0, bright=1.0):
    """Additive bell: inharmonic partials with their own decays."""
    t = t_axis(dur)
    parts = [(1.0, 1.0), (2.0, 0.6), (2.76, 0.45 * bright), (5.4, 0.25 * bright)]
    out = np.zeros_like(t)
    for i, (ratio, amp) in enumerate(parts):
        out += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-decay * (1 + i * 0.7) * t)
    return out


def place(buf, x, at):
    i = int(at * SR)
    end = min(i + len(x), len(buf))
    if i < len(buf):
        buf[i:end] += x[: end - i]


def boom(dur, f0=95, f1=32, decay=3.0):
    t = t_axis(dur)
    body = np.sin(chirp_phase(f0, f1, dur)) * np.exp(-decay * t)
    click = lowpass(RNG.standard_normal(len(t)), 900) * np.exp(-60 * t)
    return body + 0.5 * click


def sparkle(dur, count, lo=2500, hi=9000, level=0.35):
    out = np.zeros(int(dur * SR))
    for _ in range(count):
        f = RNG.uniform(lo, hi)
        at = RNG.uniform(0, dur * 0.8)
        ping = np.sin(2 * np.pi * f * t_axis(0.25)) * np.exp(-22 * t_axis(0.25))
        place(out, ping * RNG.uniform(0.3, 1.0) * level, at)
    return out


def norm(x, peak=0.89):
    return x / (np.max(np.abs(x)) + 1e-9) * peak


# ---------------------------------------------------------------- recipes
def sfx_tick():
    t = t_axis(0.09)
    x = (np.sin(2 * np.pi * 1900 * t) + 0.5 * np.sin(2 * np.pi * 2850 * t)) * np.exp(-55 * t)
    return norm(fade(x, 0.001, 0.01), 0.7)


def sfx_thud():
    return norm(fade(boom(0.55, 120, 42, 7.0), 0.002, 0.05), 0.9)


def sfx_whoosh():
    dur = 0.75
    x = swept_noise(dur, 350, 4200, q=1.4)
    t = t_axis(dur)
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 2
    return norm(fade(x * env, 0.01, 0.05), 0.8)


def riser(dur, f1, layers, rumble=False):
    """Charge-up: noise glide + rising tone(s) that peak right at the end
    (the burst sound is triggered at that moment)."""
    t = t_axis(dur)
    env = (t / dur) ** 2.2
    x = 0.8 * swept_noise(dur, 180, f1, q=1.2)
    x += 0.5 * sweep_tone(140, 1100, dur, harmonics=(1.0, 0.4, 0.2))
    if layers >= 2:
        x += 0.4 * sweep_tone(147, 1180, dur, harmonics=(1.0, 0.4))
    if layers >= 3:
        x += 0.35 * sweep_tone(280, 2200, dur, harmonics=(1.0, 0.3))
    x *= env
    if rumble:
        pulse = 0.5 + 0.5 * np.sin(2 * np.pi * (2 + 6 * t / dur) * t)
        x += 0.55 * np.sin(chirp_phase(38, 90, dur)) * env * pulse
    return norm(fade(x, 0.02, 0.012), 0.85)


def burst(dur, sparks, sub=1.0, dark=False):
    t = t_axis(dur)
    x = 1.0 * boom(dur, 95, 30, 2.6) * sub
    crash = lowpass(RNG.standard_normal(len(t)), 7000) * np.exp(-3.2 * t)
    x += 0.55 * crash
    x += sparkle(dur, sparks)
    if dark:  # the red premium pull: a dissonant low stab under the boom
        for f in (55, 58.3, 82.4):
            x += 0.25 * np.tanh(3 * np.sin(2 * np.pi * f * t)) * np.exp(-1.6 * t)
    x = reverb(x, tail=1.0, wet=0.25)
    return norm(fade(x, 0.002, 0.15), 0.92)


def arpeggio(notes, step, decay, bright, tail, wet, dur):
    buf = np.zeros(int(dur * SR))
    for i, f in enumerate(notes):
        place(buf, bell(f, 1.6, decay, bright), i * step)
    return reverb(buf, tail=tail, wet=wet)


C5, E5, G5, C6, E6, G6 = 523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0
A4, C5m, E5m, A5 = 440.0, 523.25, 659.25, 880.0


def name_sting(tier):
    if tier == "normal":
        x = arpeggio([C5, E5, G5, C6], 0.07, 4.5, 1.0, 0.9, 0.25, 1.6)
    elif tier == "legend":
        x = arpeggio([C5, E5, G5, C6, E6], 0.07, 3.4, 1.2, 1.4, 0.35, 2.2)
        place(x, 0.5 * sparkle(2.2, 14, level=0.3), 0)
    else:
        x = arpeggio([A4, C5m, E5m, A5], 0.09, 3.0, 0.8, 1.6, 0.4, 2.4)
        place(x, 0.6 * boom(2.4, 70, 36, 2.2), 0)
    return norm(fade(x, 0.002, 0.2), 0.9)


def finale():
    dur = 2.6
    t = t_axis(dur)
    swell = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.5
    x = np.zeros_like(t)
    for f in (130.8, 196.0, 261.6, 392.0, 523.3):
        for det in (0.996, 1.004):
            saw = signal.sawtooth(2 * np.pi * f * det * t)
            x += lowpass(saw, 2400 + 3000 * swell.mean()) * 0.18
    x *= swell
    bells = arpeggio([C5, G5, C6, E6, G6], 0.12, 2.6, 1.3, 1.6, 0.4, dur)[: len(t)]
    x += 0.9 * bells
    x += 0.4 * boom(dur, 80, 34, 2.0)
    return norm(fade(reverb(x, 1.2, 0.3), 0.01, 0.3), 0.92)


def merge_charge():
    """Two pitches converge from either side and meet at the end."""
    dur = 1.5
    t = t_axis(dur)
    env = (t / dur) ** 1.8
    a = sweep_tone(220, 740, dur, harmonics=(1.0, 0.35, 0.15))
    b = sweep_tone(1480, 740, dur, harmonics=(1.0, 0.3))
    x = (0.6 * a + 0.45 * b) * env
    x += 0.5 * swept_noise(dur, 250, 5200, q=1.3) * env
    x += 0.4 * np.sin(chirp_phase(60, 160, dur)) * env
    return norm(fade(x, 0.02, 0.01), 0.85)


def merge_impact():
    dur = 2.0
    t = t_axis(dur)
    x = 1.1 * boom(dur, 110, 28, 2.4)
    # glass-like shatter: a dense burst of bright pings
    place(x, sparkle(dur * 0.7, 60, 3500, 11000, level=0.28), 0)
    x += 0.45 * highpass(RNG.standard_normal(len(t)), 2500) * np.exp(-9 * t)
    # downward shockwave sweep
    sweep = sweep_tone(3200, 90, 0.55, harmonics=(1.0, 0.3))
    place(x, sweep * np.exp(-3 * t_axis(0.55)) * 0.6, 0.0)
    return norm(fade(reverb(x, 0.9, 0.22), 0.001, 0.2), 0.93)


def merge_levelup():
    x = arpeggio([C5, E5, G5, C6, E6], 0.075, 3.0, 1.2, 1.3, 0.35, 1.9)
    place(x, 0.5 * sparkle(1.9, 16, level=0.3), 0)
    return norm(fade(x, 0.002, 0.2), 0.9)


SOUNDS = {
    "sfx_tick": sfx_tick,
    "sfx_thud": sfx_thud,
    "sfx_whoosh": sfx_whoosh,
    "sfx_pack_riser_normal": lambda: riser(1.6, 5000, 1),
    "sfx_pack_riser_legend": lambda: riser(2.2, 6500, 2),
    "sfx_pack_riser_premium": lambda: riser(3.2, 8000, 3, rumble=True),
    "sfx_pack_burst_normal": lambda: burst(1.5, 18),
    "sfx_pack_burst_legend": lambda: burst(2.3, 34, sub=1.15),
    "sfx_pack_burst_premium": lambda: burst(3.1, 52, sub=1.3, dark=True),
    "sfx_pack_name_normal": lambda: name_sting("normal"),
    "sfx_pack_name_legend": lambda: name_sting("legend"),
    "sfx_pack_name_premium": lambda: name_sting("premium"),
    "sfx_pack_finale": finale,
    "sfx_merge_charge": merge_charge,
    "sfx_merge_impact": merge_impact,
    "sfx_merge_levelup": merge_levelup,
}


def write_mp3(name, x):
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with tempfile.TemporaryDirectory() as d:
        wav = os.path.join(d, name + ".wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        dest = os.path.join(OUT, name + ".mp3")
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", wav,
             "-codec:a", "libmp3lame", "-b:a", "96k", dest],
            check=True,
        )
    return dest


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in SOUNDS.items():
        x = fn()
        assert np.isfinite(x).all(), name
        path = write_mp3(name, x)
        print(f"{name:28s} {len(x) / SR:5.2f}s  {os.path.getsize(path) / 1024:6.1f} KB")
