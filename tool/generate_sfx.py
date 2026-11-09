#!/usr/bin/env python3
"""Synthesizes the pack-opening and card-merge sound effects.

Usage (from the repo root):  python3 tool/generate_sfx.py

Needs numpy, scipy and ffmpeg (libmp3lame). Writes assets/audio/sfx_*.mp3.
Everything is generated from code with a fixed seed, so the files are
reproducible and every recipe can be tuned and re-rendered. Swap any file
for a recorded one with the same name and the game picks it up unchanged.

Sound design: cinematic and heavy, not playful. Deep sub-bass impacts,
detuned low "brass" stabs, drones that climb into the burst, heartbeat
pulses, dark air whooshes. No bells, no sparkles, no bleeps. The sub is
saturated on purpose: the added harmonics (100-400 Hz) are what a phone
speaker can actually reproduce, so the weight survives without
headphones. Reverb tails are stereo but high-passed, so the low end stays
dry, tight and centred.
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

# Low root: E (41.2 Hz). Chords are built on it.
E1, E2, B2, E3, G3, B3 = 41.2, 82.4, 123.5, 164.8, 196.0, 246.9
F1, F2 = 43.65, 87.3  # a semitone above E: the dissonance of the red pull


# ---------------------------------------------------------------- helpers
def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def _env_apply(x, env):
    return x * env if x.ndim == 1 else x * env[:, None]


def fade(x, a=0.004, r=0.02):
    """Short fade in/out so nothing clicks."""
    n = len(x)
    env = np.ones(n)
    na, nr = min(int(a * SR), n), min(int(r * SR), n)
    if na:
        env[:na] = np.linspace(0, 1, na)
    if nr:
        env[-nr:] *= np.linspace(1, 0, nr)
    return _env_apply(x, env)


def chirp_phase(f0, f1, dur):
    """Phase of an exponential glide f0 -> f1 (up or down)."""
    t = t_axis(dur)
    if abs(f1 - f0) < 1e-9:
        return 2 * np.pi * f0 * t
    k = (f1 / f0) ** (1 / dur)
    return 2 * np.pi * f0 * (k**t - 1) / np.log(k)


def sat(x, drive=2.0):
    """Soft saturation: adds the upper harmonics that give bass its bite."""
    return np.tanh(drive * x) / np.tanh(drive)


def lowpass(x, fc, order=4):
    return signal.sosfilt(signal.butter(order, fc, "low", fs=SR, output="sos"), x)


def highpass(x, fc, order=4):
    return signal.sosfilt(signal.butter(order, fc, "high", fs=SR, output="sos"), x)


def _overlap_blocks(n, blocks):
    hop = n // blocks
    win = np.hanning(2 * hop + 2)
    return hop, win


def swept_noise(dur, f0, f1, q=1.0, blocks=48):
    """Band-passed noise whose centre frequency glides f0 -> f1."""
    n = int(dur * SR)
    noise = RNG.standard_normal(n)
    out = np.zeros(n)
    hop, win = _overlap_blocks(n, blocks)
    for b in range(blocks):
        fc = f0 * (f1 / f0) ** (b / max(blocks - 1, 1))
        lo, hi = fc / (1 + 1 / q), min(fc * (1 + 1 / q), SR / 2 - 100)
        sos = signal.butter(2, [lo, hi], "band", fs=SR, output="sos")
        seg = signal.sosfilt(sos, noise)
        start = b * hop
        end = min(start + len(win), n)
        out[start:end] += seg[start:end] * win[: end - start]
    return out / (np.max(np.abs(out)) + 1e-9)


def sweep_filter(x, cutoffs):
    """Low-pass [x] with a cutoff that follows the list [cutoffs] over time
    (the opening and closing of a brass or synth filter)."""
    n = len(x)
    blocks = len(cutoffs)
    out = np.zeros(n)
    hop, win = _overlap_blocks(n, blocks)
    for b, fc in enumerate(cutoffs):
        sos = signal.butter(2, min(fc, SR / 2 - 100), "low", fs=SR, output="sos")
        seg = signal.sosfilt(sos, x)
        start = b * hop
        end = min(start + len(win), n)
        out[start:end] += seg[start:end] * win[: end - start]
    return out


def curve(points, n):
    """Piecewise-linear curve through (position 0..1, value) points."""
    xs, ys = zip(*points)
    return np.interp(np.linspace(0, 1, n), xs, ys)


def place(buf, x, at):
    i = int(at * SR)
    end = min(i + len(x), len(buf))
    if i < len(buf):
        buf[i:end] += x[: end - i]


def pad(x, dur):
    out = np.zeros(int(dur * SR))
    place(out, x, 0)
    return out


def taper(x, frac=0.35, min_s=0.15):
    """Cosine fade over the last [frac] of the buffer (at least [min_s]):
    a long sub boom must die away, never get cut off mid-ring."""
    n = len(x)
    m = min(n, max(int(frac * n), int(min_s * SR)))
    env = np.ones(n)
    env[-m:] = 0.5 * (1 + np.cos(np.linspace(0, np.pi, m)))
    return x * env


def stereo_reverb(x, tail=1.4, wet=0.3, dark=5000):
    """Stereo reverb whose wet signal is high-passed (150 Hz) and darkened:
    the bass stays dry, tight and centred, the space is in the mids."""
    x = taper(x)
    n = int(tail * SR)
    wets = []
    for _ in range(2):
        ir = RNG.standard_normal(n) * np.exp(-np.linspace(0, 6.5, n))
        ir = highpass(lowpass(ir, dark), 150)
        w = signal.fftconvolve(x, ir)
        wets.append(w / (np.max(np.abs(w)) + 1e-9))
    length = len(wets[0])
    dry = np.pad(x, (0, length - len(x)))
    peak = np.max(np.abs(x))
    return np.stack([dry + wet * peak * w for w in wets], axis=1)


def master(x, peak=0.92, drive=1.25):
    """Gentle limiter, then normalise: loud and heavy without clipping."""
    x = np.tanh(drive * x / (np.max(np.abs(x)) + 1e-9)) / np.tanh(drive)
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def finish(x, peak=0.92, fade_out=0.15):
    return master(fade(x, 0.002, fade_out), peak)


# ---------------------------------------------------------------- voices
def sub_boom(dur, f0=70, f1=28, decay=1.6, drive=1.8):
    """Sine that falls from f0 to f1 and dies away, saturated."""
    t = t_axis(dur)
    return sat(np.sin(chirp_phase(f0, f1, dur)) * np.exp(-decay * t), drive)


def impact(dur, f0=70, f1=27, decay=1.5, roar=0.5):
    """The hit: sub boom + punchy low-mid body + a transient click + a
    dark roaring tail."""
    t = t_axis(dur)
    x = sub_boom(dur, f0, f1, decay, 2.0)
    x += 0.8 * pad(sub_boom(0.6, 150, 55, 7.0, 2.0), dur)
    x += 0.55 * highpass(lowpass(RNG.standard_normal(len(t)), 3500), 40) * np.exp(-90 * t)
    x += roar * highpass(lowpass(RNG.standard_normal(len(t)), 2200), 60) * np.exp(-2.6 * t)
    return x


def brass(notes, dur, attack, cutoffs, decay=1.8, detune=0.004, drive=2.5):
    """Dark detuned saw chord through an opening filter: the low 'brass'
    of a trailer stab or braam."""
    t = t_axis(dur)
    x = np.zeros_like(t)
    for f in notes:
        for d in (-detune, 0.0, detune):
            x += signal.sawtooth(2 * np.pi * f * (1 + d) * t) / 3
    x = sweep_filter(x, cutoffs)
    env = np.minimum(t / max(attack, 1e-3), 1.0) * np.exp(-decay * np.maximum(t - attack, 0))
    return sat(x * env / len(notes) * 2.2, drive)


def heartbeat(dur, rate0, rate1, f0=40, f1=70, sharp=3):
    """A sub tone pumped by a pulse that accelerates (rate0 -> rate1 Hz)."""
    t = t_axis(dur)
    rate = rate0 + (rate1 - rate0) * (t / dur) ** 1.5
    phase = 2 * np.pi * np.cumsum(rate) / SR
    pulse = (0.5 + 0.5 * np.sin(phase)) ** sharp
    return sat(np.sin(chirp_phase(f0, f1, dur)) * pulse, 1.6)


def tension(dur, layers, pulse_to, rumble):
    """The charge: a drone climbing an octave, noise rising behind it, an
    accelerating heartbeat underneath. Everything peaks at the very end
    (the impact cue is triggered at that moment)."""
    t = t_axis(dur)
    env = (t / dur) ** 2.0
    glides = [(E1 * 2, E1 * 4, 1.0), (E1 * 3, E1 * 6, 0.7), (E1, E1 * 2, 0.9)]
    x = np.zeros_like(t)
    for f0, f1, amp in glides[:layers]:
        saw = signal.sawtooth(chirp_phase(f0, f1, dur))
        x += amp * sweep_filter(saw, curve([(0, 250), (1, 3200)], 40))
    x = sat(x * 0.45, 2.0) * env
    x += 0.5 * swept_noise(dur, 150, 7500, q=0.9) * env**1.3
    if pulse_to:
        x += 1.0 * heartbeat(dur, 1.5, pulse_to) * (0.35 + 0.65 * env)
    if rumble:
        x += rumble * sat(np.sin(chirp_phase(30, 66, dur)), 2.0) * env
    return x


# ---------------------------------------------------------------- recipes
def sfx_tick():
    """A tight low 'tock' for the stat count: weight, not a bleep."""
    x = sub_boom(0.14, 98, 62, 26, 2.2)
    t = t_axis(0.14)
    x += 0.5 * lowpass(RNG.standard_normal(len(t)), 2600) * np.exp(-320 * t)
    return finish(x, 0.8, 0.02)


def sfx_thud():
    """Heartbeat / kick: a deep chest hit."""
    t = t_axis(0.75)
    x = sub_boom(0.75, 118, 38, 6.0, 2.3)
    x += 0.6 * lowpass(RNG.standard_normal(len(t)), 1800) * np.exp(-70 * t)
    return finish(x, 0.92, 0.06)


def sfx_whoosh():
    """A dark air-displacement swoosh with a low swell under it."""
    dur = 0.85
    t = t_axis(dur)
    pos = np.clip(t / dur, 0, 1)
    env = np.sin(np.pi * pos**0.8) ** 2
    x = swept_noise(dur, 160, 2800, q=0.9) * env
    x += 0.7 * sat(np.sin(chirp_phase(48, 96, dur)), 1.5) * env
    return finish(x, 0.85, 0.06)


def riser(dur, layers, pulse_to, rumble):
    return finish(tension(dur, layers, pulse_to, rumble), 0.9, 0.012)


def burst(dur, f0, decay, roar, braam=None, echo=False):
    """The pack bursting: a deep impact; premium adds a dissonant braam
    and a delayed second hit for the trailer-style echo."""
    x = impact(dur, f0, 26, decay, roar)
    if braam is not None:
        notes, bdur, level = braam
        place(
            x,
            level * brass(notes, bdur, 0.03, curve([(0, 900), (0.2, 2600), (1, 400)], 24), 2.2),
            0.0,
        )
    if echo:
        place(x, 0.5 * impact(dur * 0.6, f0 * 0.9, 24, decay * 1.4, roar * 0.7), 0.3)
    return finish(stereo_reverb(pad(x, dur), 1.6, 0.3), 0.93, 0.25)


def name_stab(notes, dur, level_sub, tail):
    """The identity lands: a short heavy low stab with a sub drop under it."""
    x = brass(notes, dur, 0.012, curve([(0, 2800), (0.3, 900), (1, 300)], 24), 3.2)
    place(x, level_sub * sub_boom(dur, 62, 34, 2.4, 2.0), 0.0)
    place(x, 0.5 * lowpass(RNG.standard_normal(int(0.03 * SR)), 3000) * np.hanning(int(0.03 * SR)), 0.0)
    return finish(stereo_reverb(x, tail, 0.28), 0.9, 0.2)


def finale():
    """The closing fanfare: a huge low braam swelling in, then a hit."""
    dur = 3.0
    x = brass([E1, E2, B2, E3, B3], dur, 0.9, curve([(0, 220), (0.35, 3400), (1, 700)], 32), 1.1)
    t = t_axis(dur)
    x += 0.4 * swept_noise(dur, 400, 9000, q=0.8) * np.minimum(t / 0.9, 1) ** 2 * np.exp(-1.2 * np.maximum(t - 0.9, 0))
    place(x, 1.0 * impact(2.0, 62, 26, 1.8, 0.4), 0.9)
    return finish(stereo_reverb(x, 1.8, 0.3), 0.93, 0.3)


def merge_charge():
    """Two voices close in from either side and meet in unison, with a
    heartbeat that accelerates into the collision."""
    dur = 1.5
    t = t_axis(dur)
    env = (t / dur) ** 1.8
    low = signal.sawtooth(chirp_phase(E1 * 1.4, E1 * 2.8, dur))
    high = signal.sawtooth(chirp_phase(E1 * 8, E1 * 2.8, dur))
    x = sat(0.55 * sweep_filter(low, curve([(0, 250), (1, 2400)], 32))
            + 0.4 * sweep_filter(high, curve([(0, 2600), (1, 900)], 32)), 2.0) * env
    x += 0.45 * swept_noise(dur, 200, 6500, q=0.9) * env**1.3
    x += 0.95 * heartbeat(dur, 2, 12, 36, 62) * (0.3 + 0.7 * env)
    return finish(x, 0.9, 0.012)


def merge_impact():
    """The two cards colliding: a deep fusion hit with a crack and a drop."""
    dur = 2.8
    t = t_axis(dur)
    x = impact(dur, 78, 24, 1.3, 0.55)
    x += 0.8 * highpass(RNG.standard_normal(len(t)), 1500) * np.exp(-28 * t)
    place(x, 0.7 * sat(np.sin(chirp_phase(260, 30, 0.7)) * np.exp(-3 * t_axis(0.7)), 2.0), 0.0)
    return finish(stereo_reverb(x, 1.6, 0.3), 0.94, 0.25)


def merge_levelup():
    """Level confirmed: a rising power stab, low and solid."""
    dur = 1.9
    x = brass([E2, B2, E3, B3], dur, 0.06, curve([(0, 300), (0.15, 4200), (1, 600)], 28), 1.9)
    place(x, 0.8 * sub_boom(dur, 56, 41, 1.8, 2.0), 0.0)
    return finish(stereo_reverb(x, 1.3, 0.28), 0.9, 0.25)


SOUNDS = {
    "sfx_tick": sfx_tick,
    "sfx_thud": sfx_thud,
    "sfx_whoosh": sfx_whoosh,
    "sfx_pack_riser_normal": lambda: riser(1.6, 1, 0, 0.55),
    "sfx_pack_riser_legend": lambda: riser(2.2, 2, 7, 0.8),
    "sfx_pack_riser_premium": lambda: riser(3.2, 3, 12, 1.0),
    "sfx_pack_burst_normal": lambda: burst(2.2, 72, 1.7, 0.5),
    "sfx_pack_burst_legend": lambda: burst(
        3.0, 68, 1.4, 0.6, braam=([E1, E2, B2], 1.6, 0.55)
    ),
    "sfx_pack_burst_premium": lambda: burst(
        4.0, 64, 1.1, 0.7, braam=([E1, F1, E2, F2, B2], 2.6, 0.75), echo=True
    ),
    "sfx_pack_name_normal": lambda: name_stab([E2, B2, E3], 1.1, 0.7, 0.9),
    "sfx_pack_name_legend": lambda: name_stab([E2, B2, E3, G3], 2.0, 0.85, 1.4),
    "sfx_pack_name_premium": lambda: name_stab([E1, F1, E2, F2, B2], 3.0, 1.0, 1.8),
    "sfx_pack_finale": finale,
    "sfx_merge_charge": merge_charge,
    "sfx_merge_impact": merge_impact,
    "sfx_merge_levelup": merge_levelup,
}


def write_mp3(name, x):
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    channels = 1 if x.ndim == 1 else 2
    with tempfile.TemporaryDirectory() as d:
        wav = os.path.join(d, name + ".wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(channels)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        dest = os.path.join(OUT, name + ".mp3")
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", wav,
             "-codec:a", "libmp3lame", "-b:a", "128k", dest],
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
