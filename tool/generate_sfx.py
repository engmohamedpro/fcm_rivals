#!/usr/bin/env python3
"""Synthesizes the pack-opening and card-merge sound effects.

Usage (from the repo root):  python3 tool/generate_sfx.py

Needs numpy, scipy and ffmpeg (libmp3lame). Writes assets/audio/sfx_*.mp3.
Everything is generated from code with a fixed seed, so the files are
reproducible and every recipe can be tuned and re-rendered. Swap any file
for a recorded one with the same name and the game picks it up unchanged.

Sound design: the polished "reveal" language of FIFA / eFootball pack
openings. No drums, no music, no melody.
  - AIR: filtered-noise whooshes and blasts that sweep and bloom,
  - ENERGY: a charge that builds from a fluttering shimmer, a rising
    metallic whine and a swelling sub — tension without a beat,
  - IMPACT: a deep cinematic sub hit with a soft air slam: felt more than
    heard, saturated so a phone speaker still carries it,
  - SHINE: bright, inharmonic metallic "shings" and showers of crystalline
    sparkle — random pings, never a tune,
  - SPACE: stereo reverb whose wet signal is high-passed, so the low end
    stays dry, tight and centred.
Each tier (normal / legend / premium) is the same language, bigger.
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


def _env_apply(x, env):
    return x * env if x.ndim == 1 else x * env[:, None]


def fade(x, a=0.004, r=0.02):
    n = len(x)
    env = np.ones(n)
    na, nr = min(int(a * SR), n), min(int(r * SR), n)
    if na:
        env[:na] = np.linspace(0, 1, na)
    if nr:
        env[-nr:] *= np.linspace(1, 0, nr)
    return _env_apply(x, env)


def chirp_phase(f0, f1, dur):
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


def bandpass(x, lo, hi, order=2):
    hi = min(hi, SR / 2 - 200)
    return signal.sosfilt(signal.butter(order, [lo, hi], "band", fs=SR, output="sos"), x)


def noise(dur):
    return RNG.standard_normal(int(dur * SR))


def place(buf, x, at, gain=1.0):
    i = int(at * SR)
    if i >= len(buf) or i < 0:
        return
    end = min(i + len(x), len(buf))
    buf[i:end] += gain * x[: end - i]


def blank(dur):
    return np.zeros(int(dur * SR))


def taper(x, frac=0.35, min_s=0.15):
    """Cosine fade over the last [frac] of the buffer: a long boom must die
    away, never get cut off mid-ring."""
    n = len(x)
    m = min(n, max(int(frac * n), int(min_s * SR)))
    env = np.ones(n)
    env[-m:] = 0.5 * (1 + np.cos(np.linspace(0, np.pi, m)))
    return x * env


def stereo_reverb(x, tail=1.4, wet=0.3, dark=6000):
    """Stereo reverb whose wet signal is high-passed (150 Hz): the bass
    stays dry, tight and centred, the space is in the mids and highs."""
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


def trim_tail(x, thr=0.003, pad_s=0.05):
    """Drop the silent padding after a reverb tail has died away."""
    level = np.abs(x) if x.ndim == 1 else np.abs(x).max(axis=1)
    idx = np.nonzero(level > thr)[0]
    end = min(len(x), (idx[-1] + int(pad_s * SR)) if len(idx) else len(x))
    return x[:end]


def finish(x, peak=0.92, fade_out=0.15):
    return master(fade(x, 0.002, fade_out), peak)


def swept_noise(dur, f0, f1, q=1.0, blocks=48):
    """Band-passed noise whose centre frequency glides f0 -> f1."""
    n = int(dur * SR)
    src = RNG.standard_normal(n)
    out = np.zeros(n)
    hop = n // blocks
    win = np.hanning(2 * hop + 2)
    for b in range(blocks):
        fc = f0 * (f1 / f0) ** (b / max(blocks - 1, 1))
        lo, hi = fc / (1 + 1 / q), min(fc * (1 + 1 / q), SR / 2 - 100)
        seg = signal.sosfilt(signal.butter(2, [lo, hi], "band", fs=SR, output="sos"), src)
        start = b * hop
        end = min(start + len(win), n)
        out[start:end] += seg[start:end] * win[: end - start]
    return out / (np.max(np.abs(out)) + 1e-9)


# ---------------------------------------------------------------- voices
def drop_sine(dur, f0, f1, tau, decay, drive=2.0):
    """A sine whose pitch falls fast from f0 to f1 (time constant tau) and
    dies away: the body of every deep impact."""
    t = t_axis(dur)
    f = f1 + (f0 - f1) * np.exp(-t / tau)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return sat(np.sin(ph) * np.exp(-decay * t), drive)


def sub_hit(dur, f0=95, f1=34, decay=2.2, drive=1.8):
    """A deep sub thump: pitch drops from f0 to f1 and rings out."""
    return drop_sine(dur, f0, f1, 0.07, decay, drive)


def slam(dur=0.35, fc=900, decay=14):
    """The soft air slam riding an impact: dark noise, fast decay."""
    t = t_axis(dur)
    return lowpass(noise(dur), fc) * np.exp(-decay * t) * np.minimum(t / 0.002, 1.0)


def impact(dur, depth=1.0):
    """Cinematic impact: sub hit + air slam + a breath of bright air."""
    x = blank(dur)
    place(x, sub_hit(dur, 100, 33, 1.9 / max(depth, 0.6), 1.9), 0, 1.0)
    place(x, 0.55 * sub_hit(dur, 52, 30, 1.2, 1.6), 0, 0.8)
    place(x, slam(0.4, 1100, 11), 0, 0.7)
    place(x, air_blast(0.9, 7000, 600, 6.0), 0, 0.28 * depth)
    return x


def air_blast(dur, f0, f1, decay):
    """The burst of air outward: bright noise sweeping DOWN as it fades."""
    t = t_axis(dur)
    env = np.exp(-decay * t) * np.minimum(t / 0.003, 1.0)
    return swept_noise(dur, f0, f1, q=0.8) * env


def air_swell(dur, f0, f1, power=2.4):
    """Noise sweeping UP and swelling toward the end (a reverse whoosh)."""
    t = t_axis(dur)
    return swept_noise(dur, f0, f1, q=0.9) * (t / dur) ** power


# metallic, inharmonic partial ratios (a struck plate, not a bell tune)
_METAL = (1.0, 2.76, 5.40, 8.93, 13.34)
_METAL_AMP = (1.0, 0.7, 0.45, 0.3, 0.18)


def shing(base=2300.0, dur=1.0, vel=1.0):
    """A bright metallic strike: sharp attack, inharmonic ring, a flash of
    rising air on the front."""
    t = t_axis(dur)
    x = np.zeros_like(t)
    for r, a in zip(_METAL, _METAL_AMP):
        f = base * r
        if f > SR / 2 - 1000:
            continue
        x += a * np.sin(2 * np.pi * f * t + RNG.uniform(0, 6.28)) * np.exp(-(4.5 + 2.5 * r) * t)
    x *= np.minimum(t / 0.0012, 1.0)
    flash = swept_noise(0.3, 2500, 12000, q=0.8) * np.exp(-11 * t_axis(0.3))
    place(x, flash, 0.0, 0.7)
    return vel * x / (np.max(np.abs(x)) + 1e-9)


def sparkle(dur, count, fmin=3200, fmax=11500, tau=None, bias=1.0, glint=0.4):
    """A shower of crystalline pings: random brief high sines (some
    gliding upward like a glint) scattered through [dur]. Their pitches
    are random on purpose — sparkle, not melody. [tau] fades the shower
    over time; [bias] > 1 crowds the pings toward the start, < 1 toward
    the end."""
    out = blank(dur)
    tau = tau or dur * 0.6
    for _ in range(count):
        at = (RNG.random() ** bias) * (dur - 0.15)
        f = RNG.uniform(fmin, fmax)
        n = int(RNG.uniform(0.05, 0.22) * SR)
        tt = np.arange(n) / SR
        if RNG.random() < glint:
            ph = 2 * np.pi * f * (tt + 0.5 * 0.25 * tt**2 / (n / SR))
        else:
            ph = 2 * np.pi * f * tt
        ping = np.sin(ph) * np.exp(-RNG.uniform(28, 85) * tt)
        ping *= np.minimum(tt / 0.0006, 1.0)
        place(out, ping, at, RNG.uniform(0.25, 0.9) * np.exp(-at / tau))
    return out


def shimmer(dur, level=1.0):
    """A soft airy bloom: band-passed noise breathing in and out."""
    t = t_axis(dur)
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 2
    return level * bandpass(noise(dur), 3500, 12500) * env


def rumble(dur, amount=1.0):
    """A sub swell that climbs into the end of a charge."""
    t = t_axis(dur)
    return amount * sat(np.sin(chirp_phase(30, 66, dur)), 2.0) * (t / dur) ** 2


def crackle(dur, count, level=0.5):
    """Energy arcing: tiny sharp electric ticks that get denser."""
    out = blank(dur)
    for at in dur * np.sort(RNG.random(count)) ** 0.6:
        n = int(RNG.uniform(0.002, 0.009) * SR)
        c = bandpass(RNG.standard_normal(n), 2500, 11000) * np.exp(-np.arange(n) / SR * 500)
        place(out, c, min(at, dur - 0.02), level * (0.25 + 0.75 * at / dur) * RNG.uniform(0.5, 1.0))
    return out


def whine(dur, f0, f1, level=1.0, power=2.0):
    """A rising metallic whine: a few inharmonic partials gliding f0 -> f1
    and swelling. Tension, not a note."""
    t = t_axis(dur)
    x = np.zeros_like(t)
    for r, a in zip(_METAL[:4], _METAL_AMP[:4]):
        if f1 * r > SR / 2 - 1500:
            continue
        x += a * np.sin(chirp_phase(f0 * r, f1 * r, dur))
    return level * x / 2.2 * (t / dur) ** power


def flutter(dur, r0, r1, f_lo=2200, f_hi=9500):
    """Shimmering band noise whose tremolo speeds up (r0 -> r1 Hz): the
    charge getting more insistent without ever becoming a beat."""
    t = t_axis(dur)
    rate = r0 + (r1 - r0) * (t / dur) ** 1.5
    am = 0.55 + 0.45 * np.sin(2 * np.pi * np.cumsum(rate) / SR)
    return bandpass(noise(dur), f_lo, f_hi) * am * (t / dur) ** 1.4


# ---------------------------------------------------------------- recipes
def sfx_tick():
    """The stat-count tick: a crisp, tiny glass-like blip."""
    t = t_axis(0.12)
    blip = np.sin(2 * np.pi * 2600 * t) * np.exp(-45 * t) * np.minimum(t / 0.0008, 1.0)
    click = bandpass(noise(0.12), 3000, 9000) * np.exp(-260 * t)
    return finish(blip + 0.5 * click, 0.7, 0.02)


def sfx_thud():
    """A soft deep pulse: felt in the chest, no click, no drum."""
    x = sub_hit(0.7, 78, 36, 5.2, 1.6)
    place(x, slam(0.2, 500, 28), 0, 0.25)
    return finish(x, 0.85, 0.08)


def sfx_whoosh():
    """Clean air-displacement swoosh with a low swell and a bright edge."""
    dur = 0.85
    t = t_axis(dur)
    env = np.sin(np.pi * np.clip(t / dur, 0, 1) ** 0.8) ** 2
    x = swept_noise(dur, 220, 4200, q=0.9) * env
    x += 0.5 * sat(np.sin(chirp_phase(52, 110, dur)), 1.4) * env
    return finish(x, 0.85, 0.06)


def charge(dur, tier):
    """The energy charge: a fluttering shimmer, a rising metallic whine, an
    air swell and a climbing sub, all peaking at the very end where the
    burst lands. Normal is a clean build; legendary adds a faster flutter
    and crackle; premium is the full surge with a sparkle rain at the top."""
    x = blank(dur)
    s = {"normal": 0, "legend": 1, "premium": 2}[tier]
    x += (0.8 + 0.1 * s) * air_swell(dur, 260, 9000 + 1500 * s)
    x += (0.45 + 0.1 * s) * whine(dur, 380 + 60 * s, 1500 + 400 * s, 1.0, 2.2)
    x += (0.55 + 0.2 * s) * flutter(dur, 5 + 2 * s, 20 + 8 * s)
    x += rumble(dur, 0.55 + 0.25 * s)
    if s >= 1:
        x += (0.35 + 0.15 * s) * crackle(dur, 24 + 26 * s)
    if s >= 2:
        x += 0.55 * sparkle(dur, 60, bias=0.45, tau=dur * 5)
    return finish(x, 0.9, 0.012)


def burst(dur, level):
    """The pack opening in a flash of light: a deep impact, a blast of air
    and a metallic strike, then a shower of sparkle falling away. Each tier
    hits bigger; premium adds a second strike and a wider shower."""
    x = blank(dur)
    place(x, impact(dur, 1.0 + 0.15 * level), 0, 1.0)
    place(x, air_blast(1.3 + 0.4 * level, 11000, 500, 4.0), 0, 0.55)
    place(x, shing(2100 + 150 * level, 1.4 + 0.5 * level), 0, 0.6)
    place(x, sparkle(dur - 0.2, 45 + 35 * level, bias=1.6, tau=1.3 + 0.5 * level), 0.03, 0.5)
    if level >= 1:
        place(x, shing(3100, 1.3), 0.09, 0.45)
    if level >= 2:
        place(x, shing(4300, 1.2), 0.2, 0.38)
        place(x, shimmer(2.2, 0.5), 0.1, 0.5)
        place(x, sparkle(2.4, 40, bias=1.0, tau=1.2), 0.5, 0.4)
    return finish(stereo_reverb(x, 1.6, 0.3), 0.93, 0.25)


def phrase(hits, dur, tail):
    """A short layered reveal: [(time, [(voice, gain), ...]), ...]."""
    x = blank(dur)
    for at, voices in hits:
        for v, g in voices:
            place(x, v, at, g)
    return finish(stereo_reverb(x, tail, 0.28), 0.9, 0.2)


def name_normal():
    return phrase(
        [(0.0, [(shing(2600, 0.9), 0.8), (sub_hit(0.6, 80, 40, 4.0), 0.7),
                (air_blast(0.5, 9000, 900, 9), 0.4)]),
         (0.05, [(sparkle(1.1, 14, tau=0.5), 0.6)])],
        1.4, 0.9)


def name_legend():
    return phrase(
        [(0.0, [(air_swell(0.3, 600, 9000, 2.0), 0.55)]),
         (0.3, [(shing(2200, 1.5), 0.85), (impact(1.2, 0.9), 0.8)]),
         (0.38, [(shing(3300, 1.2), 0.5)]),
         (0.34, [(sparkle(1.9, 34, tau=0.9, bias=1.4), 0.6)])],
        2.4, 1.3)


def name_premium():
    return phrase(
        [(0.0, [(air_swell(0.5, 500, 11000, 2.0), 0.6), (whine(0.5, 500, 1800, 0.5, 2.0), 0.5)]),
         (0.5, [(shing(2000, 2.0), 0.9), (impact(2.0, 1.2), 0.9),
                (air_blast(1.0, 10000, 500, 4.5), 0.5)]),
         (0.58, [(shing(3000, 1.6), 0.55)]),
         (0.68, [(shing(4200, 1.4), 0.4)]),
         (0.52, [(sparkle(2.6, 70, tau=1.1, bias=1.3), 0.65)])],
        3.6, 1.7)


def finale():
    """The reveal lands: a bright swell, then a soft impact, a strike and a
    long fall of sparkle in a wide space. No crowd, no drums."""
    dur = 4.2
    x = blank(dur)
    place(x, air_swell(1.0, 400, 11000, 2.2), 0.0, 0.6)
    place(x, whine(1.0, 600, 2200, 0.6, 2.0), 0.0, 0.5)
    place(x, flutter(1.0, 8, 26), 0.0, 0.45)
    hit = 1.0
    place(x, impact(3.0, 1.1), hit, 0.9)
    place(x, air_blast(1.6, 11000, 500, 3.2), hit, 0.5)
    place(x, shing(2300, 2.2), hit, 0.7)
    place(x, shing(3500, 1.8), hit + 0.07, 0.45)
    place(x, shimmer(2.6, 0.55), hit + 0.05)
    place(x, sparkle(3.0, 90, tau=1.5, bias=1.2), hit + 0.04, 0.55)
    return finish(stereo_reverb(x, 1.9, 0.3), 0.93, 0.3)


def merge_charge():
    """Two energy streams close in from the left and right: one whine
    rises, the other falls, and they meet in unison at the very end, with
    arcing crackle, a rising air swell and a climbing sub."""
    dur = 1.5
    t = t_axis(dur)
    ramp = (t / dur) ** 1.6
    a = ramp * sat(np.sin(chirp_phase(300, 1700, dur)), 1.6)
    b = ramp * sat(np.sin(chirp_phase(3400, 1700, dur)), 1.6)
    a2 = ramp * 0.35 * np.sin(chirp_phase(300 * 2.76, 1700 * 2.76, dur))
    b2 = ramp * 0.35 * np.sin(chirp_phase(3400 * 1.5, 1700 * 1.5, dur))
    centre = 0.7 * air_swell(dur, 300, 9500, 2.0) + 0.5 * flutter(dur, 7, 30)
    centre += 0.45 * crackle(dur, 40) + rumble(dur, 0.8)
    left = 0.55 * (a + a2) + 0.2 * (b + b2) + centre
    right = 0.55 * (b + b2) + 0.2 * (a + a2) + centre
    return finish(np.stack([left, right], axis=1), 0.9, 0.012)


def merge_impact():
    """The cards colliding in a flash: a heavy impact, a shockwave of air
    and a double metallic strike, with sparkle scattering outward."""
    dur = 3.0
    x = blank(dur)
    place(x, impact(dur, 1.25), 0, 1.0)
    place(x, air_blast(1.0, 12000, 300, 5.0), 0, 0.6)
    place(x, shing(1900, 1.6), 0, 0.65)
    place(x, shing(2850, 1.4), 0.05, 0.5)
    place(x, shimmer(1.8, 0.45), 0.05)
    place(x, sparkle(2.4, 75, bias=1.5, tau=1.0), 0.03, 0.5)
    return finish(stereo_reverb(x, 1.6, 0.3), 0.94, 0.25)


def merge_levelup():
    """Success: a bright rising swell into a soft sub hit and a high strike,
    with sparkle gliding upward. Uplifting, not heavy."""
    dur = 3.0
    x = blank(dur)
    place(x, air_swell(0.5, 700, 12000, 2.0), 0.0, 0.55)
    place(x, whine(0.5, 700, 2400, 0.55, 2.0), 0.0, 0.5)
    hit = 0.5
    place(x, sub_hit(2.2, 70, 34, 2.0), hit, 0.75)
    place(x, slam(0.3, 1000, 14), hit, 0.4)
    place(x, shing(3000, 1.9), hit, 0.7)
    place(x, shing(4500, 1.5), hit + 0.06, 0.45)
    place(x, shimmer(2.0, 0.5), hit)
    place(x, sparkle(2.3, 60, tau=1.0, bias=1.2, glint=0.8), hit + 0.02, 0.5)
    return finish(stereo_reverb(x, 1.4, 0.28), 0.86, 0.3)


SOUNDS = {
    "sfx_tick": sfx_tick,
    "sfx_thud": sfx_thud,
    "sfx_whoosh": sfx_whoosh,
    "sfx_pack_riser_normal": lambda: charge(1.6, "normal"),
    "sfx_pack_riser_legend": lambda: charge(2.2, "legend"),
    "sfx_pack_riser_premium": lambda: charge(3.2, "premium"),
    "sfx_pack_burst_normal": lambda: burst(2.6, 0),
    "sfx_pack_burst_legend": lambda: burst(3.4, 1),
    "sfx_pack_burst_premium": lambda: burst(4.4, 2),
    "sfx_pack_name_normal": name_normal,
    "sfx_pack_name_legend": name_legend,
    "sfx_pack_name_premium": name_premium,
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
        x = trim_tail(fn())
        assert np.isfinite(x).all(), name
        path = write_mp3(name, x)
        print(f"{name:28s} {len(x) / SR:5.2f}s  {os.path.getsize(path) / 1024:6.1f} KB")
