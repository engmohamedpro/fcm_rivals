#!/usr/bin/env python3
"""Synthesizes the pack-opening and card-merge sound effects.

Usage (from the repo root):  python3 tool/generate_sfx.py

Needs numpy, scipy and ffmpeg (libmp3lame). Writes assets/audio/sfx_*.mp3.
Everything is generated from code with a fixed seed, so the files are
reproducible and every recipe can be tuned and re-rendered. Swap any file
for a recorded one with the same name and the game picks it up unchanged.

Sound design: drums, glass and crowd. No melodic or tonal instruments.
  - kick, snare, floor toms and taiko hits, in rolls that accelerate into
    the burst (the "beat" of the charge),
  - cymbal crashes and reverse-cymbal swells,
  - breaking glass (crack, shards, debris) — the pack and the cards break,
  - win / success: a big drum hit, a crash and a real crowd roar (layered
    from assets/audio/goal_cheers.mp3, the stadium recording already in
    the game),
  - saturated sub-bass underneath everything: the added harmonics are what
    a phone speaker can actually reproduce.
Reverb tails are stereo but high-passed, so the low end stays dry, tight
and centred.
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


# ---------------------------------------------------------------- drums
def drop_sine(dur, f0, f1, tau, decay, drive=2.0):
    """A sine whose pitch falls fast from f0 to f1 (time constant tau) and
    dies away: the body of every drum."""
    t = t_axis(dur)
    f = f1 + (f0 - f1) * np.exp(-t / tau)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return sat(np.sin(ph) * np.exp(-decay * t), drive)


def kick(vel=1.0, dur=0.7):
    t = t_axis(dur)
    body = drop_sine(dur, 175, 44, 0.03, 6.5, 2.4)
    click = lowpass(noise(dur), 4200) * np.exp(-220 * t) * 0.45
    return vel * (body + click)


def tom(freq, vel=1.0, dur=0.9):
    t = t_axis(dur)
    body = drop_sine(dur, freq * 1.7, freq, 0.05, 5.0, 1.6)
    skin = bandpass(noise(dur), 350, 3000) * np.exp(-65 * t) * 0.35
    return vel * (body + skin)


def snare(vel=1.0, dur=0.45):
    t = t_axis(dur)
    tone = 0.7 * drop_sine(dur, 270, 185, 0.02, 24, 1.2)
    wires = highpass(lowpass(noise(dur), 9500), 1200) * np.exp(-17 * t) * 0.95
    crack = highpass(noise(dur), 3200) * np.exp(-95 * t) * 0.6
    return vel * (tone + wires + crack)


def taiko(vel=1.0, dur=2.6):
    """A huge war-drum hit: deep body, long sub tail, slapped skin."""
    t = t_axis(dur)
    body = drop_sine(dur, 125, 54, 0.06, 2.3, 1.8)
    sub = 0.6 * drop_sine(dur, 62, 36, 0.1, 1.6, 2.0)
    skin = bandpass(noise(dur), 300, 2600) * np.exp(-48 * t) * 0.6
    return vel * (body + sub + skin)


def crash(dur=2.8, vel=1.0):
    """Cymbal crash: bright noise with a fast attack and a long shimmer."""
    t = t_axis(dur)
    x = highpass(noise(dur), 3600) * np.exp(-1.7 * t)
    x += 0.5 * bandpass(noise(dur), 6500, 14000) * np.exp(-2.4 * t)
    x *= np.minimum(t / 0.004, 1.0)
    return vel * x


def reverse_swell(dur, vel=1.0):
    """Reverse cymbal: a bright swell that peaks at the very end."""
    t = t_axis(dur)
    x = highpass(noise(dur), 3000) + 0.6 * bandpass(noise(dur), 5000, 13000)
    return vel * x * (t / dur) ** 3


def sub_boom(dur, f0=70, f1=27, decay=1.5, drive=2.0):
    return drop_sine(dur, f0, f1, dur * 0.35, decay, drive)


def rumble(dur, amount=1.0):
    """A sub swell that climbs into the end of a charge."""
    t = t_axis(dur)
    return amount * sat(np.sin(chirp_phase(30, 66, dur)), 2.0) * (t / dur) ** 2


def roll(dur, hit, i0, i1, vel0=0.25, vel1=1.0, hits=None):
    """A drum roll that accelerates (interval i0 -> i1 seconds) and gets
    louder. [hit] is called with a velocity and returns one hit; a list in
    [hits] cycles through several drums (a tom pattern)."""
    out = blank(dur)
    t, i = 0.0, 0
    while t < dur - 0.03:
        frac = t / dur
        vel = (vel0 + (vel1 - vel0) * frac**1.2) * RNG.uniform(0.85, 1.0)
        fn = hits[i % len(hits)] if hits else hit
        place(out, fn(vel), t)
        t += i0 * (i1 / i0) ** frac
        i += 1
    return out


def late_roll(dur, start, hit, i0, i1, vel0=0.2, vel1=1.0):
    """A roll that only begins [start] seconds in, in a [dur]-long buffer."""
    out = blank(dur)
    place(out, roll(dur - start, hit, i0, i1, vel0, vel1), start)
    return out


# ---------------------------------------------------------------- glass
def grain(freq, q, dur, decay):
    t = t_axis(dur)
    return bandpass(noise(dur), freq / (1 + 1 / q), freq * (1 + 1 / q)) * np.exp(-decay * t)


def glass(dur=1.6, size=1.0):
    """A pane breaking: the crack, a spray of brittle shards, the heavy
    thunk of the pane, and sparse debris tinkling down. The shards are
    noisy and short — brittle glass, not bells."""
    out = blank(dur)
    t = t_axis(dur)
    c = int(0.03 * SR)
    place(out, highpass(noise(0.03), 1800) * np.exp(-130 * t_axis(0.03)), 0.0)
    place(out, 0.8 * lowpass(noise(0.35), 700) * np.exp(-26 * t_axis(0.35)), 0.0)
    shards = int(120 * size)
    for _ in range(shards):
        at = min(RNG.exponential(0.2 * size + 0.05), dur - 0.12)
        g = grain(RNG.uniform(2400, 9800), 3.0, RNG.uniform(0.02, 0.07), RNG.uniform(70, 220))
        place(out, g, at, RNG.uniform(0.2, 0.9) * np.exp(-at / (0.55 * size + 0.1)))
    for _ in range(int(16 * size)):
        at = RNG.uniform(0.15, dur * 0.85)
        f = RNG.uniform(3200, 8500)
        n = int(0.18 * SR)
        ping = np.sin(2 * np.pi * f * np.arange(n) / SR) * np.exp(-RNG.uniform(50, 130) * np.arange(n) / SR)
        place(out, ping, at, 0.10 * np.exp(-at / 0.9))
    return out


def cracks(dur, count, level=0.6):
    """Glass straining before it breaks: tiny sharp cracks, ever denser."""
    out = blank(dur)
    times = dur * np.sort(RNG.random(count)) ** 0.5
    for at in times:
        n = int(RNG.uniform(0.004, 0.012) * SR)
        c = highpass(RNG.standard_normal(n), 2200) * np.exp(-np.arange(n) / SR * 400)
        place(out, c, min(at, dur - 0.02), level * (0.3 + 0.7 * at / dur) * RNG.uniform(0.6, 1.0))
    return out


# ---------------------------------------------------------------- crowd
_CHEER = None


def crowd(dur=3.0, gain=1.0):
    """The stadium roar: the game's own goal-cheer recording, trimmed and
    normalised. Real audio — nothing synthesized comes close."""
    global _CHEER
    if _CHEER is None:
        raw = subprocess.run(
            ["ffmpeg", "-loglevel", "error", "-i", os.path.join(OUT, "goal_cheers.mp3"),
             "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
            check=True, capture_output=True,
        ).stdout
        x = np.frombuffer(raw, dtype="<f4").astype(np.float64)
        _CHEER = x / (np.max(np.abs(x)) + 1e-9)
    x = _CHEER[: int(dur * SR)]
    return gain * fade(x, 0.15, 0.4)


# ---------------------------------------------------------------- recipes
def sfx_tick():
    """The stat-count beat: a tight low tom tap."""
    return finish(tom(95, 1.0, 0.16) + 0.4 * kick(0.8, 0.16), 0.8, 0.02)


def sfx_thud():
    """Chest hit: a deep kick."""
    return finish(kick(1.0, 0.75) + 0.5 * sub_boom(0.75, 80, 38, 5.0), 0.92, 0.06)


def sfx_whoosh():
    """Dark air-displacement swoosh with a low swell."""
    dur = 0.85
    t = t_axis(dur)
    env = np.sin(np.pi * np.clip(t / dur, 0, 1) ** 0.8) ** 2
    x = swept_noise(dur, 160, 2800, q=0.9) * env
    x += 0.6 * sat(np.sin(chirp_phase(48, 96, dur)), 1.5) * env
    return finish(x, 0.85, 0.06)


def charge(dur, tier):
    """The beat of the charge: drum rolls that accelerate and swell into
    the burst, a reverse cymbal and a rising sub. Ordinary = snare roll and
    kick pulse; legendary adds a tom pattern and cracking glass; premium is
    the full machine — heavier toms, faster pulse, more cracks."""
    x = blank(dur)
    toms = lambda f: (lambda v: tom(f, v, 0.4))
    if tier == "normal":
        x += 0.9 * roll(dur, lambda v: snare(v, 0.3), 0.17, 0.045, 0.2, 1.0)
        x += 1.0 * roll(dur, lambda v: kick(v, 0.4), 0.42, 0.14, 0.4, 0.95)
        x += 0.45 * reverse_swell(dur)
        x += rumble(dur, 0.6)
    elif tier == "legend":
        x += 1.0 * roll(dur, None, 0.22, 0.07, 0.3, 1.0, hits=[toms(70), toms(92), toms(118)])
        x += 0.75 * late_roll(dur, dur * 0.4, lambda v: snare(v, 0.3), 0.14, 0.04)
        x += 1.0 * roll(dur, lambda v: kick(v, 0.4), 0.52, 0.13, 0.45, 1.0)
        x += 0.55 * reverse_swell(dur)
        x += 0.7 * cracks(dur, 14)
        x += rumble(dur, 0.85)
    else:
        x += 1.1 * roll(dur, None, 0.3, 0.06, 0.3, 1.0, hits=[toms(56), toms(74), toms(98), toms(74)])
        x += 0.8 * late_roll(dur, dur * 0.35, lambda v: snare(v, 0.3), 0.13, 0.035)
        x += 1.1 * roll(dur, lambda v: kick(v, 0.4), 0.5, 0.1, 0.45, 1.0)
        x += 0.7 * reverse_swell(dur)
        x += 0.9 * cracks(dur, 30)
        x += rumble(dur, 1.1)
    return finish(x, 0.9, 0.012)


def burst(dur, level):
    """The pack shattering open: kick, taiko and snare crack, a cymbal
    crash, breaking glass and a long sub boom. Each tier hits bigger;
    premium adds echoing taiko hits and a bigger spray of glass."""
    x = blank(dur)
    place(x, kick(1.0), 0)
    place(x, taiko(1.0 if level == 0 else 1.15), 0, 0.85)
    place(x, snare(1.0), 0, 0.65)
    place(x, crash(min(dur, 2.4 + 0.5 * level), 1.0), 0, 0.7)
    place(x, glass(1.3 + 0.35 * level, 0.8 + 0.4 * level), 0, 0.75)
    place(x, sub_boom(dur, 72 - 4 * level, 26, 1.7 - 0.3 * level, 2.2), 0, 0.95)
    if level >= 1:
        place(x, taiko(0.8), 0.16, 0.55)
    if level >= 2:
        place(x, taiko(0.9), 0.34, 0.6)
        place(x, snare(0.9), 0.17, 0.5)
        place(x, kick(0.8), 0.34, 0.6)
        place(x, glass(2.0, 1.5), 0.05, 0.5)
    return finish(stereo_reverb(x, 1.6, 0.3), 0.93, 0.25)


def phrase(hits, dur, tail):
    """A short drum phrase: [(time, [(voice, gain), ...]), ...]."""
    x = blank(dur)
    for at, voices in hits:
        for v, g in voices:
            place(x, v, at, g)
    return finish(stereo_reverb(x, tail, 0.28), 0.9, 0.2)


def name_normal():
    return phrase(
        [(0.0, [(kick(1.0), 1.0), (snare(0.9), 0.8)]),
         (0.2, [(kick(0.9), 0.9), (tom(80, 1.0), 0.8), (crash(1.2), 0.45)])],
        1.4, 0.9)


def name_legend():
    return phrase(
        [(0.0, [(kick(0.8), 0.9), (snare(0.7), 0.6)]),
         (0.18, [(kick(0.9), 0.95), (snare(0.85), 0.75)]),
         (0.36, [(taiko(1.0), 1.0), (kick(1.0), 1.0), (crash(2.2), 0.7), (glass(0.9, 0.5), 0.5)])],
        2.4, 1.3)


def name_premium():
    return phrase(
        [(0.0, [(kick(0.7), 0.85), (snare(0.65), 0.55)]),
         (0.15, [(kick(0.85), 0.9), (snare(0.8), 0.7)]),
         (0.30, [(kick(1.0), 1.0), (snare(0.95), 0.85), (tom(60, 1.0), 0.8)]),
         (0.55, [(taiko(1.2), 1.0), (kick(1.0), 1.0), (crash(3.0), 0.8),
                 (glass(1.5, 1.0), 0.6), (sub_boom(2.8, 66, 28, 1.4), 0.9)])],
        3.6, 1.7)


def finale():
    """The win: a drum fill into a huge hit, a crash and the stadium roar."""
    dur = 4.2
    x = blank(dur)
    fill = roll(1.0, lambda v: snare(v, 0.3), 0.11, 0.03, 0.25, 1.0)
    place(x, fill, 0.0, 0.9)
    place(x, roll(1.0, lambda v: kick(v, 0.4), 0.3, 0.1, 0.4, 1.0), 0.0, 0.9)
    place(x, reverse_swell(1.0), 0.0, 0.6)
    hit = 1.0
    place(x, kick(1.0), hit)
    place(x, taiko(1.2), hit, 0.95)
    place(x, snare(1.0), hit, 0.7)
    place(x, crash(3.2), hit, 0.8)
    place(x, sub_boom(3.0, 66, 26, 1.5), hit, 0.95)
    place(x, crowd(3.1, 0.9), hit - 0.2)
    return finish(stereo_reverb(x, 1.8, 0.28), 0.93, 0.3)


def merge_charge():
    """Two drum lines close in from the left and right, offset beats that
    tighten until they land together, over a speeding kick pulse."""
    dur = 1.5
    left, right = blank(dur), blank(dur)
    left += roll(dur, lambda v: tom(88, v, 0.35), 0.2, 0.05, 0.3, 1.0)
    place(right, roll(dur - 0.08, lambda v: tom(112, v, 0.35), 0.2, 0.05, 0.3, 1.0), 0.08)
    centre = roll(dur, lambda v: kick(v, 0.4), 0.4, 0.11, 0.4, 1.0)
    centre += 0.5 * reverse_swell(dur) + rumble(dur, 0.8)
    centre += 0.7 * late_roll(dur, dur * 0.4, lambda v: snare(v, 0.3), 0.12, 0.035)
    stereo = np.stack([left + 0.35 * right + centre, right + 0.35 * left + centre], axis=1)
    return finish(stereo, 0.9, 0.012)


def merge_impact():
    """The cards colliding: a heavy hit with a big pane of glass breaking."""
    dur = 3.0
    x = blank(dur)
    place(x, kick(1.1), 0)
    place(x, taiko(1.2), 0, 0.9)
    place(x, snare(1.1), 0, 0.8)
    place(x, crash(2.8), 0, 0.7)
    place(x, glass(2.2, 1.6), 0, 0.95)
    place(x, sub_boom(dur, 78, 24, 1.3, 2.2), 0, 1.0)
    place(x, kick(0.7), 0.22, 0.5)
    return finish(stereo_reverb(x, 1.6, 0.3), 0.94, 0.25)


def merge_levelup():
    """Success: a swell into a deep hit, a crash and a short crowd roar."""
    dur = 3.0
    x = blank(dur)
    place(x, reverse_swell(0.5), 0.0, 0.55)
    hit = 0.5
    place(x, kick(1.0), hit)
    place(x, taiko(1.0), hit, 0.85)
    place(x, crash(2.4), hit, 0.75)
    place(x, sub_boom(2.2, 60, 30, 1.8), hit, 0.85)
    place(x, crowd(2.4, 0.7), hit - 0.05)
    return finish(stereo_reverb(x, 1.4, 0.28), 0.92, 0.3)


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
