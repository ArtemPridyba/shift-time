#!/usr/bin/env python3
"""Sound effects of Shift Time, made by code (task Д8, D179).

Every sound of the game is synthesised here from noise, sines and filters:
no samples from outside, so the files are ours and may be sold with the game.
The result is deterministic (each sound has its own fixed seed): running the
script again gives the same files.

    pip install numpy scipy soundfile pillow          # once
    python3 tools/audio/make_sounds.py                 # every sound into game/assets/audio/
    python3 tools/audio/make_sounds.py door_stop spark # only these
    python3 tools/audio/make_sounds.py --sheet build/audio/sheet.png   # spectrograms
    python3 tools/audio/make_sounds.py --list          # names, lengths, loops

World sounds also get a reversed twin `<name>_rev.ogg`: under Shift the game
plays it, so a clank turns into a swell that ends on the impact (reverb tails
become the swell). Loops are seamless, and so are their reversed twins.
Files are mono OGG Vorbis, 44.1 kHz. Loudness is tuned in the game, in
`game/data/audio.json`; here every file is brought to the same peak.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from scipy import signal
import soundfile as sf

SR = 44100
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "assets" / "audio"
PEAK_DB = -1.0


# --- building blocks ---------------------------------------------------------

def n_of(seconds: float) -> int:
    return int(round(seconds * SR))


def times(n: int) -> np.ndarray:
    return np.arange(n) / SR


def colored(rng, n: int, slope: float = 0.0) -> np.ndarray:
    """Noise with power ~ f^slope: 0 white, -1 pink, -2 brown. Unit RMS."""
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f[0] = f[1]
    spec *= f ** (slope / 2.0)
    x = np.fft.irfft(spec, n)
    return x / (np.std(x) + 1e-12)


def _sos(kind: str, freq, order: int):
    return signal.butter(order, freq, kind, fs=SR, output="sos")


def bandpass(x, lo, hi, order=2):
    return signal.sosfilt(_sos("bandpass", [lo, hi], order), x)


def lowpass(x, f, order=2):
    return signal.sosfilt(_sos("lowpass", f, order), x)


def highpass(x, f, order=2):
    return signal.sosfilt(_sos("highpass", f, order), x)


def resonate(x, freqs, q=12.0, gains=None):
    """A sum of resonant peaks: wood, metal sheets, a pipe."""
    out = np.zeros_like(x)
    for i, f in enumerate(freqs):
        if f >= SR * 0.45:
            continue
        b, a = signal.iirpeak(f, q, fs=SR)
        out += (1.0 if gains is None else gains[i]) * signal.lfilter(b, a, x)
    return out


def decay(n, tau, attack=0.001):
    t = times(n)
    env = np.exp(-t / tau)
    if attack > 0:
        env *= np.clip(t / attack, 0.0, 1.0)
    return env


def swell(n, power=2.0):
    """0 → 1 over n samples: a reversed decay, for swells written forward."""
    return np.linspace(0.0, 1.0, n) ** power


def env_ar(n, attack, release):
    t = times(n)
    up = np.clip(t / max(attack, 1e-4), 0.0, 1.0)
    down = np.exp(-np.maximum(t - attack, 0.0) / max(release, 1e-4))
    return up * down


def sine(freq, n, phase=0.0):
    """A sine of constant or changing frequency (an array per sample)."""
    if np.isscalar(freq):
        return np.sin(2 * np.pi * freq * times(n) + phase)
    return np.sin(2 * np.pi * np.cumsum(freq) / SR + phase)


def modal(rng, n, f0, ratios, decays, amps=None, jitter=0.01):
    """A struck body: damped sines at inharmonic ratios (metal, glass, wood)."""
    t = times(n)
    out = np.zeros(n)
    for i, r in enumerate(ratios):
        f = f0 * r * (1.0 + jitter * rng.uniform(-1.0, 1.0))
        if f >= SR * 0.45:
            continue
        a = 1.0 / (1.0 + i) if amps is None else amps[i]
        out += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 2 * np.pi)) * np.exp(-t / decays[i])
    return out * np.clip(t / 0.0006, 0.0, 1.0)


def burst(rng, n, lo, hi, tau, order=2):
    """A short noise burst: the contact of an impact."""
    return bandpass(rng.standard_normal(n), lo, hi, order) * decay(n, tau, 0.0003)


def thump(n, f_start, f_end, tau):
    """A low body thump whose pitch drops."""
    f = f_end + (f_start - f_end) * np.exp(-times(n) / (tau * 0.7))
    return sine(f, n) * decay(n, tau, 0.0015)


def clank(rng, seconds, f0, bright=1.0, body=1.0, ring=1.0, ratios=None):
    """A metal hit: contact noise, modes and a low thump."""
    n = n_of(seconds)
    ratios = ratios or [1.0, 2.32, 3.94, 5.51, 7.12, 9.37]
    decays = [0.32 * ring, 0.2 * ring, 0.13 * ring, 0.085 * ring, 0.06 * ring, 0.04 * ring]
    amps = [1.0, 0.8, 0.6, 0.45, 0.3 * bright, 0.2 * bright]
    x = modal(rng, n, f0, ratios, decays, amps)
    x += 0.7 * bright * burst(rng, n, 500, 6000, 0.012)
    x += 0.9 * body * thump(n, f0 * 0.55, f0 * 0.35, 0.09)
    return x


def place(out, x, at, gain=1.0):
    """Adds x into out from sample `at` (clipped at the end)."""
    at = int(at)
    if at >= len(out) or at + len(x) <= 0:
        return
    start = max(at, 0)
    end = min(len(out), at + len(x))
    out[start:end] += gain * x[start - at:end - at]


def swept_noise(rng, n, centers, width_oct=0.5, slope=0.0):
    """Noise through a moving band: `centers` is the band's centre per sample (Hz)."""
    size, hop = 2048, 512
    win = np.hanning(size)
    src = colored(rng, n + size, slope)
    out = np.zeros(n + size)
    freqs = np.fft.rfftfreq(size, 1.0 / SR)
    log_f = np.log2(np.maximum(freqs, 1.0))
    centers = np.asarray(centers, dtype=float)
    for start in range(0, n, hop):
        c = centers[min(start + size // 2, n - 1)]
        gain = np.exp(-0.5 * ((log_f - np.log2(max(c, 20.0))) / width_oct) ** 2)
        seg = np.fft.irfft(np.fft.rfft(src[start:start + size] * win) * gain, size) * win
        out[start:start + size] += seg
    out = out[:n]
    return out / (np.std(out) + 1e-12)


def lfo(n, freqs, depth, period=None, rng=None):
    """A smooth wobble 1 ± depth from a few sines; integer cycles over `period` keep loops seamless."""
    t = times(n)
    out = np.zeros(n)
    for f in freqs:
        if period:
            f = max(1, round(f * period)) / period
        out += np.sin(2 * np.pi * f * t + (rng.uniform(0, 2 * np.pi) if rng is not None else 0.0))
    return 1.0 + depth * out / max(len(freqs), 1)


def poisson_times(rng, rate, seconds, start=0.0):
    out = []
    t = start
    while True:
        t += rng.exponential(1.0 / rate)
        if t >= seconds:
            return out
        out.append(t)


def reverb_ir(rng, seconds, tone=3500.0, pre=0.012):
    n = n_of(seconds)
    t = times(n)
    ir = rng.standard_normal(n) * np.exp(-6.9 * t / seconds)
    ir = lowpass(ir, tone, 1)
    ir[: n_of(pre)] = 0.0
    return ir / (np.sqrt(np.sum(ir ** 2)) + 1e-12)


def reverb(x, rng, seconds=1.2, wet=0.25, tone=3500.0, loop=False):
    """A big brick hall: dry + a tail of decaying noise. A loop gets a circular tail."""
    ir = reverb_ir(rng, seconds, tone)
    if loop:
        n = len(x)
        tail = np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir[:n] if len(ir) > n else np.pad(ir, (0, n - len(ir))), n), n)
        return x + wet * tail * 3.0
    tail = signal.fftconvolve(x, ir)
    dry = np.pad(x, (0, len(tail) - len(x)))
    return dry + wet * tail * 3.0


def seamless(x, xfade):
    """x is L + X long; returns L samples that loop without a seam."""
    k = n_of(xfade)
    length = len(x) - k
    out = x[:length].copy()
    w = np.linspace(0.0, 1.0, k)
    out[:k] = x[:k] * np.sin(w * np.pi / 2) + x[length:length + k] * np.cos(w * np.pi / 2)
    return out


def fade(x, fade_in=0.002, fade_out=0.02):
    x = x.copy()
    a, b = n_of(fade_in), n_of(fade_out)
    if a > 0:
        x[:a] *= np.linspace(0.0, 1.0, a)
    if b > 0:
        x[-b:] *= np.linspace(1.0, 0.0, b)
    return x


def trim_tail(x, floor_db=-60.0):
    """Cuts the silent end of a one-shot."""
    level = np.abs(x) / (np.max(np.abs(x)) + 1e-12)
    loud = np.nonzero(level > 10 ** (floor_db / 20))[0]
    return x if len(loud) == 0 else x[: loud[-1] + n_of(0.01)]


def to_peak(x, db=PEAK_DB):
    peak = np.max(np.abs(x))
    return x if peak <= 0 else x * (10 ** (db / 20) / peak)


# --- the sounds --------------------------------------------------------------

SOUNDS: dict[str, dict] = {}


def sound(name: str, loop: float = 0.0, reverse: bool = True, about: str = ""):
    """Registers a sound. `loop` > 0: a seamless loop of that many seconds."""
    def deco(fn):
        SOUNDS[name] = {"fn": fn, "loop": loop, "reverse": reverse, "about": about}
        return fn
    return deco


# Time: what Shift sounds like (played by the time sound and the rewind loop).

@sound("time_rewind_start", reverse=False, about="Shift pressed: the tape catches and spins up backwards")
def time_rewind_start(rng):
    n = n_of(0.6)
    t = times(n)
    up = swell(n, 2.2)
    x = 0.55 * swept_noise(rng, n, np.geomspace(6000, 700, n), 0.55) * up
    boom = thump(n_of(0.7), 70, 42, 0.18)[::-1][-n:]
    x += 0.9 * boom
    f = np.geomspace(240, 1500, n) * (1 + 0.012 * np.sin(2 * np.pi * 9 * t))
    x += 0.18 * (sine(f, n) + 0.35 * sine(f * 2, n)) * swell(n, 1.4)
    catch = clank(rng, 0.12, 2300, bright=0.6, body=0.2, ring=0.15)
    place(x, catch, n - len(catch) + n_of(0.02), 0.35)
    return fade(x, 0.01, 0.006)


@sound("time_rewind_loop", loop=2.4, reverse=False, about="Shift held: tape whir, reversed clock ticks, a low flutter")
def time_rewind_loop(rng):
    length, xf = 2.4, 0.3
    n = n_of(length + xf)
    t = times(n)
    x = np.zeros(n)
    # The spool's whine, wobbling (integer cycles over the loop).
    f = 1150 * (1 + 0.035 * np.sin(2 * np.pi * (5 / length) * t))
    x += 0.07 * (sine(f, n) + 0.4 * sine(f * 2.01, n))
    # Reversed clock ticks every 0.3 s: a swell that ends on the tick.
    tick = clank(rng, 0.16, 3100, bright=0.8, body=0.25, ring=0.12)
    tick = reverb(tick, rng, 0.35, 0.3, 5000)[: n_of(0.3)][::-1]
    step = n_of(0.3)
    for k in range(int(np.ceil(n / step)) + 1):
        place(x, tick, k * step - len(tick) + n_of(0.004), 0.45 if k % 2 else 0.32)
    # Garbled reversed blips: speech of the world run backwards.
    for at in poisson_times(rng, 9.0, length + xf):
        m = n_of(rng.uniform(0.05, 0.12))
        blip = modal(rng, m, rng.choice([520, 660, 780, 990, 1170, 1320]), [1, 2.0, 3.1], [0.04, 0.025, 0.015])
        place(x, blip[::-1] * swell(m, 0.5), n_of(at), 0.1)
    # Air rushing past, trembling.
    air = highpass(colored(rng, n, -1.0), 1800) * lfo(n, [6.0], 0.35, length)
    x += 0.09 * air
    # A low flutter of the whole hall.
    x += 0.12 * (sine(55, n) + 0.5 * sine(110, n)) * lfo(n, [1.25], 0.4, length)
    return seamless(x, xf)


@sound("time_rewind_end", reverse=False, about="Shift released: the world snaps back to play")
def time_rewind_end(rng):
    n = n_of(0.5)
    t = times(n)
    x = 0.6 * swept_noise(rng, n, np.geomspace(900, 5000, n), 0.5) * decay(n, 0.09, 0.004)
    x += 0.8 * thump(n, 95, 55, 0.07)
    f = np.geomspace(1500, 260, n)
    x += 0.15 * (sine(f, n) + 0.3 * sine(f * 2, n)) * decay(n, 0.12, 0.002)
    x += 0.2 * clank(rng, 0.5, 1900, bright=0.5, body=0.0, ring=0.12)
    return fade(x, 0.002, 0.05)


# The heroine (live: always forward, no reversed twin).

def _footstep(rng, weight=1.0):
    n = n_of(0.18)
    pitch = rng.uniform(0.9, 1.12)
    x = 0.9 * weight * thump(n, 115 * pitch, 80 * pitch, 0.022)
    x += 0.45 * burst(rng, n, 700, 4500, 0.008)
    toe = 0.5 * burst(rng, n, 1500, 7000, 0.006) + 0.35 * thump(n, 150 * pitch, 110 * pitch, 0.012)
    place(x, toe, n_of(rng.uniform(0.022, 0.034)))
    x += 0.12 * modal(rng, n, rng.uniform(650, 900), [1, 2.31, 3.9], [0.035, 0.022, 0.012])
    x += 0.08 * bandpass(rng.standard_normal(n), 2500, 8000) * np.exp(-((times(n) - 0.03) / 0.02) ** 2)
    return fade(x, 0.0005, 0.03)


for _i in range(1, 5):
    sound(f"step_{_i}", reverse=False, about="a boot on the brick and iron floor")(lambda rng, w=1.0: _footstep(rng, w))


@sound("jump", reverse=False, about="push off: a cloth swish and a scuff")
def jump(rng):
    n = n_of(0.32)
    x = 0.5 * swept_noise(rng, n, np.geomspace(700, 2600, n), 0.6) * env_ar(n, 0.035, 0.09)
    x += 0.55 * burst(rng, n, 1200, 6500, 0.01)
    x += 0.35 * thump(n, 130, 95, 0.02)
    return fade(x, 0.0005, 0.04)


@sound("land", reverse=False, about="touch down after a fall: a heavy step and the floor rattling")
def land(rng):
    n = n_of(0.45)
    x = 1.0 * thump(n, 90, 52, 0.085)
    x += 0.5 * burst(rng, n, 400, 4000, 0.018)
    x += 0.22 * modal(rng, n, 310, [1, 2.4, 3.95, 5.6], [0.12, 0.08, 0.05, 0.03])
    x += 0.25 * swept_noise(rng, n, np.geomspace(2500, 800, n), 0.6) * decay(n, 0.06, 0.003)
    return reverb(fade(x, 0.0005, 0.05), rng, 0.6, 0.12)


@sound("fail", reverse=False, about="she burned or drowned: power down, the room starts over")
def fail(rng):
    n = n_of(1.4)
    t = times(n)
    x = 1.0 * thump(n, 60, 34, 0.35)
    x += 0.5 * swept_noise(rng, n, np.geomspace(3500, 180, n), 0.5) * decay(n, 0.45, 0.01)
    f = np.geomspace(330, 55, n)
    x += 0.22 * (sine(f, n) + 0.5 * sine(f * 1.5, n)) * decay(n, 0.5, 0.02)
    x += 0.3 * burst(rng, n, 200, 2500, 0.05)
    return reverb(fade(x, 0.001, 0.2), rng, 1.6, 0.25, 2500)


# The heroine's hands: controls and items.

@sound("button", about="an iron push button: press, click")
def button(rng):
    n = n_of(0.3)
    x = 0.9 * burst(rng, n, 2500, 9000, 0.003)
    x += 0.7 * modal(rng, n, 1350, [1, 2.05, 3.3, 4.7], [0.03, 0.02, 0.012, 0.008])
    x += 0.8 * thump(n, 210, 150, 0.022)
    place(x, 0.4 * modal(rng, n_of(0.08), 2100, [1, 2.4], [0.015, 0.01]) + 0.3 * burst(rng, n_of(0.08), 3000, 9000, 0.002), n_of(0.075))
    return reverb(fade(x), rng, 0.7, 0.12)


@sound("button_up", about="the button springs back")
def button_up(rng):
    n = n_of(0.16)
    x = 0.6 * burst(rng, n, 3000, 9000, 0.002) + 0.5 * modal(rng, n, 1800, [1, 2.3, 3.6], [0.02, 0.012, 0.008])
    x += 0.3 * thump(n, 260, 200, 0.012)
    return reverb(fade(x), rng, 0.6, 0.1)


@sound("lever", about="a heavy lever: ratchet clicks and a clunk")
def lever(rng):
    n = n_of(0.75)
    x = np.zeros(n)
    at = 0.02
    for k in range(5):
        tick = 0.35 * burst(rng, n_of(0.05), 2500, 8000, 0.002) + 0.3 * modal(rng, n_of(0.05), 2600 + 150 * k, [1, 2.2], [0.01, 0.006])
        place(x, tick, n_of(at))
        at += 0.05 * (1 - 0.12 * k)
    place(x, clank(rng, 0.6, 380, bright=0.8, body=1.0, ring=0.45), n_of(at + 0.02))
    return reverb(fade(x), rng, 0.9, 0.18)


@sound("valve", about="a part seated in its socket: a scrape and a heavy clunk")
def valve(rng):
    n = n_of(0.8)
    x = np.zeros(n)
    m = n_of(0.3)
    scrape = resonate(colored(rng, m, -0.5), [950, 1850, 2900], 18) * env_ar(m, 0.06, 0.12)
    x[:m] += 0.25 * scrape / (np.max(np.abs(scrape)) + 1e-9)
    place(x, clank(rng, 0.5, 300, bright=0.6, body=1.0, ring=0.5), n_of(0.26))
    return reverb(fade(x), rng, 0.9, 0.18)


@sound("pickup", about="a small iron thing taken in hand")
def pickup(rng):
    n = n_of(0.25)
    x = 0.4 * modal(rng, n, 2100, [1, 1.52, 2.73, 3.9], [0.07, 0.05, 0.03, 0.02])
    x += 0.35 * swept_noise(rng, n, np.geomspace(900, 2400, n), 0.6) * env_ar(n, 0.02, 0.05)
    x += 0.3 * burst(rng, n, 2000, 8000, 0.003)
    return fade(x, 0.001, 0.03)


@sound("drop", about="an iron thing put down on the floor")
def drop(rng):
    n = n_of(0.4)
    x = 0.7 * modal(rng, n, 720, [1, 2.1, 3.6, 5.2], [0.09, 0.06, 0.035, 0.02])
    x += 0.6 * thump(n, 140, 90, 0.03) + 0.5 * burst(rng, n, 800, 6000, 0.006)
    place(x, 0.35 * modal(rng, n_of(0.15), 760, [1, 2.1, 3.6], [0.05, 0.03, 0.02]), n_of(0.07))
    return reverb(fade(x), rng, 0.7, 0.14)


@sound("plate", about="a time plate under the boot: a heavy click and a pneumatic hiss")
def plate(rng):
    n = n_of(0.5)
    x = 0.8 * modal(rng, n, 560, [1, 2.5, 4.1], [0.06, 0.04, 0.02]) + 0.9 * thump(n, 130, 85, 0.04)
    x += 0.5 * burst(rng, n, 1000, 7000, 0.004)
    m = n_of(0.3)
    hiss = highpass(rng.standard_normal(m), 3000) * env_ar(m, 0.01, 0.08)
    place(x, 0.18 * hiss, n_of(0.04))
    return reverb(fade(x), rng, 0.8, 0.15)


# Mechanisms: doors, shutters, platforms, lifts.

@sound("door_move", loop=2.0, about="a heavy blade on a toothed rack: motor hum and teeth")
def door_move(rng):
    length, xf = 2.0, 0.25
    n = n_of(length + xf)
    t = times(n)
    x = np.zeros(n)
    f0 = 96.0
    vib = 0.6 * np.sin(2 * np.pi * (3 / length) * t)
    motor = sum((1.0 / k) * sine(f0 * k + vib * k, n) for k in range(1, 13))
    x += 0.32 * lowpass(motor, 900, 2) * lfo(n, [22.0], 0.12, length)
    tooth_step = 1.0 / 22.0
    for k in range(int((length + xf) / tooth_step) + 1):
        m = n_of(0.03)
        tooth = 0.6 * modal(rng, m, rng.uniform(1600, 1850), [1, 1.71, 2.93], [0.008, 0.006, 0.004]) + 0.35 * burst(rng, m, 2000, 7000, 0.0015)
        place(x, tooth, n_of(k * tooth_step + rng.uniform(-0.002, 0.002)), rng.uniform(0.5, 1.0) * 0.45)
    x += 0.35 * lowpass(colored(rng, n, -2.0), 180) * lfo(n, [0.5, 1.5], 0.3, length, rng)
    x = reverb(x, rng, 0.9, 0.18, 3000, loop=True)
    return seamless(x, xf)


@sound("door_stop", about="the blade hits its stop: a big iron clank")
def door_stop(rng):
    n = n_of(1.0)
    x = clank(rng, 1.0, 150, bright=1.0, body=1.2, ring=1.1)
    for at, f in ((0.04, 1900), (0.09, 2600), (0.16, 2200)):
        place(x, 0.12 * modal(rng, n_of(0.15), f, [1, 2.2, 3.4], [0.03, 0.02, 0.012]), n_of(at))
    return reverb(fade(x, 0.0005, 0.1), rng, 1.5, 0.3, 3000)


@sound("platform_move", loop=2.0, about="a platform on a chain: links over sprockets, an electric motor")
def platform_move(rng):
    length, xf = 2.0, 0.25
    n = n_of(length + xf)
    x = np.zeros(n)
    link = 1.0 / 34.0
    for k in range(int((length + xf) / link) + 1):
        m = n_of(0.02)
        tick = modal(rng, m, rng.uniform(2800, 4200), [1, 1.63, 2.41], [0.006, 0.004, 0.003]) + 0.4 * burst(rng, m, 3000, 9000, 0.001)
        accent = 1.6 if k % 6 == 0 else 1.0
        place(x, tick, n_of(k * link + rng.uniform(-0.003, 0.003)), rng.uniform(0.4, 0.9) * 0.22 * accent)
    motor = sine(130, n) * 0.5 + sine(260, n) * 0.25 + sine(390, n) * 0.15
    x += 0.25 * motor * lfo(n, [2.0], 0.1, length)
    x += 0.035 * sine(1040 + 6 * np.sin(2 * np.pi * (2 / length) * times(n)), n)
    x += 0.3 * lowpass(colored(rng, n, -2.0), 150) * lfo(n, [0.5], 0.25, length, rng)
    x = reverb(x, rng, 0.9, 0.16, 3000, loop=True)
    return seamless(x, xf)


@sound("platform_stop", about="a platform reaches its end: a softer clunk and the chain settling")
def platform_stop(rng):
    n = n_of(0.7)
    x = clank(rng, 0.7, 260, bright=0.6, body=0.9, ring=0.6)
    for at in (0.05, 0.085, 0.13):
        place(x, 0.15 * modal(rng, n_of(0.04), rng.uniform(2800, 3800), [1, 1.63], [0.008, 0.005]), n_of(at))
    return reverb(fade(x, 0.0005, 0.08), rng, 1.1, 0.22, 3000)


@sound("wood_creak", loop=1.6, about="planks and a beam under strain: a slow creak")
def wood_creak(rng):
    length, xf = 1.6, 0.2
    n = n_of(length + xf)
    rate = 45 * lfo(n, [0.6, 1.3], 0.5, length, rng)
    pos = np.cumsum(rate) / SR
    pulses = np.zeros(n)
    idx = np.nonzero(np.diff(np.floor(pos)) > 0)[0]
    pulses[idx] = rng.uniform(0.5, 1.0, len(idx))
    creak = resonate(pulses, [320, 610, 950, 1500, 2300], 9, [1.0, 0.8, 0.6, 0.4, 0.25])
    creak *= lfo(n, [0.4, 0.9], 0.6, length, rng).clip(0.1)
    x = creak / (np.max(np.abs(creak)) + 1e-9)
    x += 0.035 * lowpass(bandpass(colored(rng, n, -1.0), 300, 1500), 1200) * lfo(n, [1.0], 0.5, length)
    x += 0.05 * sine(78, n)
    x = reverb(x, rng, 0.8, 0.15, 2500, loop=True)
    return seamless(x, xf)


@sound("wood_thud", about="a heavy wooden ramp slams down")
def wood_thud(rng):
    n = n_of(0.8)
    x = 1.1 * thump(n, 88, 58, 0.09)
    x += 0.6 * modal(rng, n, 190, [1, 2.7, 4.6, 6.8], [0.12, 0.07, 0.04, 0.025])
    x += 0.6 * lowpass(burst(rng, n, 100, 3000, 0.025), 2200)
    x += 0.12 * bandpass(colored(rng, n, -1.0), 1000, 5000) * decay(n, 0.35, 0.02)
    m = n_of(0.3)
    place(x, 0.35 * thump(m, 80, 60, 0.05) + 0.2 * modal(rng, m, 205, [1, 2.7], [0.06, 0.035]), n_of(0.13))
    return reverb(fade(x, 0.0005, 0.1), rng, 1.3, 0.28, 2500)


@sound("rail_switch", about="the switch blade slides over and locks")
def rail_switch(rng):
    n = n_of(0.8)
    x = np.zeros(n)
    m = n_of(0.42)
    scrape = resonate(colored(rng, m, -0.5), [1200, 2300, 3700], 16) * env_ar(m, 0.08, 0.2)
    x[:m] += 0.35 * scrape / (np.max(np.abs(scrape)) + 1e-9)
    place(x, clank(rng, 0.5, 420, bright=0.8, body=0.8, ring=0.45), n_of(0.4))
    return reverb(fade(x), rng, 1.0, 0.2, 3000)


@sound("cart_roll", loop=2.0, reverse=False, about="iron wheels on rails: rumble, joints, a faint squeal")
def cart_roll(rng):
    length, xf = 2.0, 0.25
    n = n_of(length + xf)
    x = 0.6 * bandpass(colored(rng, n, -2.0), 60, 420) * lfo(n, [0.5, 1.5, 3.0], 0.3, length, rng)
    x += 0.12 * (sine(210, n) + 0.5 * sine(420, n)) * lfo(n, [1.0], 0.3, length)
    for k in range(3):
        for dt in (0.0, 0.11):
            place(x, 0.5 * clank(rng, 0.2, rng.uniform(500, 650), bright=0.5, body=0.6, ring=0.15), n_of(k * 1.0 + 0.2 + dt))
    x += 0.02 * sine(3100 + 40 * np.sin(2 * np.pi * (1 / length) * times(n)), n)
    x = reverb(x, rng, 0.9, 0.15, 3000, loop=True)
    return seamless(x, xf)


# Level 05: the crane and the collapse.

@sound("crane_break", about="the crane breaks loose and screeches down its rail")
def crane_break(rng):
    n = n_of(3.2)
    t = times(n)
    x = np.zeros(n)
    place(x, clank(rng, 1.2, 520, bright=1.2, body=1.0, ring=0.8), 0)
    snap = 0.8 * burst(rng, n_of(0.1), 1500, 9000, 0.01)
    place(x, snap, 0)
    screech_env = env_ar(n, 0.25, 0.9) * np.clip((2.95 - t) / 0.4, 0.0, 1.0)
    for f, a in ((1900, 0.12), (2650, 0.08), (3700, 0.04)):
        wob = f * (1 + 0.02 * np.sin(2 * np.pi * rng.uniform(4, 7) * t) + 0.01 * rng.standard_normal(n).cumsum() / np.sqrt(n))
        x += a * sine(wob, n) * screech_env
    x += 0.35 * swept_noise(rng, n, np.geomspace(1600, 900, n), 0.4) * screech_env
    x += 0.5 * lowpass(colored(rng, n, -2.0), 200) * env_ar(n, 0.2, 1.2)
    for at in poisson_times(rng, 8.0, 2.6, 0.2):
        place(x, 0.12 * modal(rng, n_of(0.05), rng.uniform(2500, 4000), [1, 1.6], [0.01, 0.006]), n_of(at))
    return reverb(fade(x, 0.0005, 0.3), rng, 1.8, 0.3, 2800)


@sound("crane_brake", about="the crane's brake: a squeal and a clunk")
def crane_brake(rng):
    n = n_of(1.2)
    t = times(n)
    env = env_ar(n, 0.04, 0.35)
    f = 2400 * (1 + 0.01 * np.sin(2 * np.pi * 6 * t))
    x = 0.25 * (sine(f, n) + 0.4 * sine(f * 2.02, n) + 0.2 * sine(f * 0.5, n)) * env
    x += 0.2 * bandpass(rng.standard_normal(n), 1500, 6000) * env
    place(x, clank(rng, 0.6, 330, bright=0.7, body=1.0, ring=0.5), n_of(0.45))
    return reverb(fade(x, 0.002, 0.1), rng, 1.4, 0.25, 3000)


@sound("quake", about="a push of the collapse: a deep blast, rumble and falling stones")
def quake(rng):
    n = n_of(3.0)
    t = times(n)
    x = 1.2 * thump(n, 62, 30, 0.5)
    x += 0.7 * lowpass(burst(rng, n, 60, 3000, 0.06), 1500)
    rumble = lowpass(colored(rng, n, -2.0), 120) * env_ar(n, 0.06, 0.9)
    rumble *= 1 + 0.5 * np.sin(2 * np.pi * 6.5 * t + 3 * np.sin(2 * np.pi * 0.7 * t))
    x += 0.8 * rumble / (np.max(np.abs(rumble)) + 1e-9)
    for at in poisson_times(rng, 11.0, 2.4, 0.12):
        m = n_of(0.12)
        stone = burst(rng, m, 250, 3000, rng.uniform(0.008, 0.025)) + 0.5 * modal(rng, m, rng.uniform(180, 700), [1, 2.3, 3.7], [0.05, 0.03, 0.02])
        place(x, stone, n_of(at), 0.4 * np.exp(-at / 1.0) * rng.uniform(0.4, 1.0))
    x += 0.08 * highpass(colored(rng, n, -1.0), 2000) * decay(n, 1.4, 0.1)
    return reverb(fade(x, 0.0005, 0.3), rng, 2.6, 0.32, 2000)


# Light.

@sound("lamp_break", about="a lamp in its wire cage hits the floor: clank, glass, shards")
def lamp_break(rng):
    n = n_of(1.6)
    x = 0.55 * modal(rng, n, 640, [1, 2.2, 3.6, 5.1], [0.12, 0.08, 0.05, 0.03])
    x += 0.9 * highpass(burst(rng, n, 2000, 14000, 0.004), 2000)
    x += 0.35 * burst(rng, n, 900, 4000, 0.012)
    for _ in range(46):
        at = min(rng.exponential(0.2), 1.2)
        m = n_of(0.12)
        partials = sorted(rng.uniform(3000, 9500, 3))
        shard = modal(rng, m, partials[0], [1, partials[1] / partials[0], partials[2] / partials[0]],
                      [rng.uniform(0.015, 0.08), rng.uniform(0.01, 0.05), rng.uniform(0.008, 0.03)], [1, 0.6, 0.4])
        place(x, shard, n_of(at), 0.3 * rng.uniform(0.3, 1.0) * np.exp(-at / 0.45))
    return reverb(fade(x, 0.0003, 0.15), rng, 1.2, 0.22, 5000)


@sound("spark", about="a torn cable sparks: crackle and a short buzz")
def spark(rng):
    n = n_of(0.5)
    x = np.zeros(n)
    for at in sorted(rng.uniform(0.0, 0.3, rng.integers(10, 17))):
        m = n_of(0.02)
        click = highpass(rng.standard_normal(m), 2500) * decay(m, 0.0015, 0.0) + 0.3 * modal(rng, m, rng.uniform(4000, 7000), [1, 1.4], [0.003, 0.002])
        place(x, click, n_of(at), rng.uniform(0.3, 1.0))
    m = n_of(0.12)
    buzz = sum((1.0 / k) * sine(100 * k, m) for k in range(1, 20))
    place(x, 0.25 * bandpass(buzz, 200, 3500) * decay(m, 0.05, 0.004), 0)
    x += 0.12 * highpass(rng.standard_normal(n), 4000) * decay(n, 0.12, 0.002)
    return reverb(fade(x, 0.0005, 0.05), rng, 0.5, 0.06, 4000)


# Water.

@sound("water_flow", loop=3.0, about="water running in and out: rush, bubbles, a low swirl")
def water_flow(rng):
    length, xf = 3.0, 0.3
    n = n_of(length + xf)
    gurgle = lfo(n, [0.33, 1.0, 1.67, 4.0], 0.55, length, rng).clip(0.15)
    x = 0.22 * lowpass(bandpass(colored(rng, n, -1.0), 200, 1600), 1100) * gurgle
    for at in poisson_times(rng, 38.0, length + xf):
        m = n_of(rng.uniform(0.02, 0.07))
        f0 = rng.uniform(280, 1100)
        f = f0 * (1 + 1.6 * times(m) / (m / SR))
        bub = sine(f, m) * decay(m, m / SR / 3, 0.002)
        place(x, bub, n_of(at), rng.uniform(0.08, 0.3))
    x += 0.35 * lowpass(colored(rng, n, -2.0), 260) * lfo(n, [0.67], 0.3, length)
    x = reverb(x, rng, 1.0, 0.15, 3500, loop=True)
    return seamless(x, xf)


# Fire.

@sound("fire_loop", loop=3.0, about="a wood zone burning: roar, crackles, hiss")
def fire_loop(rng):
    length, xf = 3.0, 0.3
    n = n_of(length + xf)
    x = 0.55 * lowpass(colored(rng, n, -2.0), 520) * lfo(n, [0.67, 1.33, 2.33], 0.45, length, rng)
    for at in poisson_times(rng, 15.0, length + xf):
        m = n_of(0.012)
        lo = rng.uniform(1200, 3500)
        pop = bandpass(rng.standard_normal(m), lo, lo * 2.2) * decay(m, rng.uniform(0.001, 0.004), 0.0)
        place(x, pop, n_of(at), min(rng.pareto(2.5) * 0.3 + 0.1, 1.0))
    x += 0.07 * highpass(colored(rng, n, -1.0), 2500) * lfo(n, [1.0, 2.0], 0.4, length, rng)
    x = reverb(x, rng, 0.8, 0.12, 4000, loop=True)
    return seamless(x, xf)


@sound("ignite", about="fire catches: a whoosh, a low whump, first crackles")
def ignite(rng):
    n = n_of(1.0)
    t = times(n)
    centers = np.where(t < 0.25, 300 * (1500 / 300) ** (t / 0.25), 1500 * np.exp(-(t - 0.25) * 1.2))
    x = 0.7 * swept_noise(rng, n, centers, 0.7, -1.0) * env_ar(n, 0.06, 0.25)
    x += 0.8 * thump(n, 60, 85, 0.12) * np.clip(t / 0.02, 0, 1)
    for at in poisson_times(rng, 14.0, 0.85, 0.15):
        m = n_of(0.01)
        place(x, bandpass(rng.standard_normal(m), 1500, 5000) * decay(m, 0.002, 0.0), n_of(at), rng.uniform(0.2, 0.6))
    return reverb(fade(x, 0.002, 0.15), rng, 1.0, 0.18, 3500)


@sound("douse", about="water on fire: steam hiss and sizzle")
def douse(rng):
    n = n_of(1.3)
    x = 0.45 * highpass(colored(rng, n, -0.5), 2500) * env_ar(n, 0.025, 0.4)
    x += 0.25 * bandpass(rng.standard_normal(n), 800, 2500) * decay(n, 0.15, 0.01)
    for at in poisson_times(rng, 90.0, 1.0):
        m = n_of(0.006)
        place(x, highpass(rng.standard_normal(m), 5000) * decay(m, 0.001, 0.0), n_of(at), 0.25 * np.exp(-at / 0.35) * rng.uniform(0.3, 1.0))
    return reverb(fade(x, 0.002, 0.2), rng, 1.0, 0.15, 5000)


@sound("rain_loop", loop=3.0, about="the sprinkler's rain: hiss, drops, drops on iron")
def rain_loop(rng):
    length, xf = 3.0, 0.3
    n = n_of(length + xf)
    x = 0.3 * bandpass(colored(rng, n, -1.0), 1000, 9000) * lfo(n, [0.67, 1.33], 0.15, length, rng)
    drops = np.zeros(n)
    for at in poisson_times(rng, 420.0, length + xf):
        drops[min(n_of(at), n - 1)] += rng.lognormal(-1.0, 0.6)
    x += 0.5 * highpass(lowpass(drops, 9000), 1800)
    for at in poisson_times(rng, 12.0, length + xf):
        m = n_of(0.05)
        place(x, modal(rng, m, rng.uniform(1500, 4500), [1, 1.5, 2.2], [0.02, 0.012, 0.008]), n_of(at), rng.uniform(0.05, 0.18))
    x += 0.08 * lowpass(colored(rng, n, -1.0), 600)
    x = reverb(x, rng, 0.9, 0.12, 5000, loop=True)
    return seamless(x, xf)


@sound("alarm", about="the fire alarm: an electric bell rings")
def alarm(rng):
    n = n_of(2.2)
    t = times(n)
    x = np.zeros(n)
    strike = 1.0 / 18.0
    ring_n = n_of(0.8)
    for k in range(int(1.4 / strike)):
        bell = modal(rng, ring_n, 780, [1, 2.0, 2.76, 3.5, 5.4], [0.5, 0.35, 0.25, 0.18, 0.09], [1, 0.5, 0.6, 0.3, 0.2], jitter=0.0)
        bell += 0.3 * burst(rng, ring_n, 2000, 8000, 0.001)
        place(x, bell, n_of(k * strike), 0.25)
    return reverb(fade(x, 0.001, 0.3), rng, 1.4, 0.25, 4000)


# The hall and the menus.

@sound("ambience_factory", loop=12.0, about="the night shop: mains hum, air, far clanks, a drip, steam")
def ambience_factory(rng):
    length, xf = 12.0, 1.0
    n = n_of(length + xf)
    x = np.zeros(n)
    hum = 0.5 * sine(50, n) + 0.32 * sine(100, n) + 0.18 * sine(150, n) + 0.08 * sine(200, n)
    hum += 0.25 * sine(601 / 12.0, n) + 0.12 * sine(1199 / 12.0, n)
    x += 0.12 * hum
    x += 0.28 * lowpass(colored(rng, n, -1.0), 900) * lfo(n, [1 / 12, 2 / 12, 3 / 12], 0.3, length, rng)
    far = np.zeros(n)
    for at, f in ((2.1, 180), (6.3, 120), (9.4, 260)):
        place(far, lowpass(clank(rng, 1.2, f, bright=0.5, body=0.8, ring=0.9), 1500), n_of(at), 0.5)
    for at in (4.0, 10.8):
        m = n_of(0.03)
        place(far, 0.15 * sine(np.geomspace(1100, 1800, m), m) * decay(m, 0.012, 0.001), n_of(at))
    x += reverb(far, rng, 2.8, 0.9, 1800)[:n] * 0.45
    m = n_of(1.4)
    place(x, 0.05 * highpass(colored(rng, m, -1.0), 2000) * env_ar(m, 0.3, 0.4), n_of(7.5))
    x = reverb(x, rng, 1.8, 0.2, 2000, loop=True)
    return seamless(x, xf)


@sound("ui_move", reverse=False, about="menu: focus moves to another button")
def ui_move(rng):
    n = n_of(0.08)
    x = 0.6 * modal(rng, n, 2600, [1, 2.4], [0.012, 0.008]) + 0.2 * burst(rng, n, 3000, 9000, 0.0015)
    return fade(x, 0.0003, 0.02)


@sound("ui_click", reverse=False, about="menu: a button pressed, like a relay")
def ui_click(rng):
    n = n_of(0.2)
    x = 0.7 * burst(rng, n, 2000, 9000, 0.0025) + 0.6 * modal(rng, n, 1500, [1, 2.2, 3.7], [0.03, 0.018, 0.01])
    x += 0.5 * thump(n, 230, 170, 0.02)
    place(x, 0.35 * burst(rng, n_of(0.05), 2500, 9000, 0.002) + 0.25 * modal(rng, n_of(0.05), 1900, [1, 2.2], [0.012, 0.008]), n_of(0.035))
    return reverb(fade(x, 0.0003, 0.03), rng, 0.5, 0.08)


@sound("level_done", reverse=False, about="the exit: a latch, a pneumatic hiss, two soft chimes")
def level_done(rng):
    n = n_of(2.0)
    x = clank(rng, 0.8, 210, bright=0.5, body=1.0, ring=0.4)
    x = np.pad(x, (0, n - len(x)))
    m = n_of(0.9)
    place(x, 0.16 * highpass(colored(rng, m, -0.5), 2000) * env_ar(m, 0.05, 0.25), n_of(0.1))
    for at, f in ((0.28, 659.3), (0.5, 987.8)):
        k = n_of(1.4)
        chime = modal(rng, k, f, [1, 2.0, 3.0, 4.2], [0.9, 0.5, 0.3, 0.15], [1, 0.3, 0.12, 0.06], jitter=0.0)
        place(x, chime, n_of(at), 0.22)
    return reverb(fade(x, 0.0005, 0.3), rng, 1.6, 0.25, 4000)


# --- output ------------------------------------------------------------------

def render(name: str) -> np.ndarray:
    spec = SOUNDS[name]
    seed = sum((i + 1) * ord(c) for i, c in enumerate(name)) % (2 ** 31)
    x = np.asarray(spec["fn"](np.random.default_rng(seed)), dtype=float)
    x -= np.mean(x) if spec["loop"] else 0.0
    if not spec["loop"]:
        x = trim_tail(x)
        x = fade(x, 0.0, 0.01)
    x = to_peak(x)
    if not np.all(np.isfinite(x)):
        raise ValueError(f"{name}: not finite")
    return x


def write(name: str, x: np.ndarray) -> list[Path]:
    OUT.mkdir(parents=True, exist_ok=True)
    paths = [OUT / f"{name}.ogg"]
    sf.write(paths[0], x.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    if SOUNDS[name]["reverse"]:
        paths.append(OUT / f"{name}_rev.ogg")
        sf.write(paths[1], x[::-1].astype(np.float32), SR, format="OGG", subtype="VORBIS")
    return paths


def sheet(rendered: dict[str, np.ndarray], path: Path) -> None:
    """Spectrograms of every sound in one picture, to look at what cannot be heard."""
    from PIL import Image, ImageDraw

    cell_w, cell_h, label = 420, 150, 16
    cols = 3
    rows = (len(rendered) + cols - 1) // cols
    img = Image.new("RGB", (cols * cell_w, rows * (cell_h + label)), (12, 12, 16))
    draw = ImageDraw.Draw(img)
    for i, (name, x) in enumerate(rendered.items()):
        f, _, s = signal.spectrogram(x, SR, nperseg=1024, noverlap=768)
        db = 10 * np.log10(s + 1e-12)
        db = np.clip((db - (db.max() - 70)) / 70, 0, 1)
        keep = f <= 12000
        db = db[keep][::-1]
        tile = Image.fromarray((db * 255).astype(np.uint8)).resize((cell_w - 8, cell_h - 30))
        wave = Image.new("L", (cell_w - 8, 26))
        wd = ImageDraw.Draw(wave)
        env = np.abs(x)
        chunks = np.array_split(env, cell_w - 8)
        for j, c in enumerate(chunks):
            h = int(min(1.0, (c.max() if len(c) else 0)) * 12)
            wd.line([(j, 13 - h), (j, 13 + h)], fill=200)
        cx, cy = (i % cols) * cell_w + 4, (i // cols) * (cell_h + label)
        draw.text((cx, cy + 2), f"{name}  {len(x) / SR:.2f}s{'  loop' if SOUNDS[name]['loop'] else ''}", fill=(230, 220, 160))
        img.paste(Image.merge("RGB", (tile, tile.point(lambda v: int(v * 0.8)), tile.point(lambda v: int(v * 0.5)))), (cx, cy + label))
        img.paste(Image.merge("RGB", (wave, wave, wave)), (cx, cy + label + cell_h - 30))
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("names", nargs="*", help="only these sounds (default: all)")
    parser.add_argument("--sheet", type=Path, help="also draw spectrograms into this PNG")
    parser.add_argument("--list", action="store_true", help="print the sounds and stop")
    args = parser.parse_args(argv)
    if args.list:
        for name, spec in SOUNDS.items():
            print(f"{name:20s} {'loop ' + str(spec['loop']) + ' s' if spec['loop'] else 'one-shot':12s} {'+rev' if spec['reverse'] else '    '}  {spec['about']}")
        return 0
    names = args.names or list(SOUNDS)
    unknown = [n for n in names if n not in SOUNDS]
    if unknown:
        print("unknown sounds: " + ", ".join(unknown), file=sys.stderr)
        return 1
    rendered = {}
    total = 0
    for name in names:
        x = render(name)
        rendered[name] = x
        for p in write(name, x):
            total += p.stat().st_size
        print(f"{name:20s} {len(x) / SR:5.2f} s")
    print(f"{len(names)} sounds, {total / 1024:.0f} KB of OGG in {OUT.relative_to(ROOT)}")
    if args.sheet:
        sheet(rendered, args.sheet)
        print(f"sheet: {args.sheet}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
