#!/usr/bin/env python3
"""Generate every asset of Ringfall procedurally: stage textures (PNG) and
audio (WAV). No third-party or ripped content; everything is synthesized here
and the output is deterministic for a given seed.

Usage: python3 tools/gen_assets.py
"""
import math
import os
import struct
import wave
import zlib

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX_DIR = os.path.join(ROOT, "assets", "textures")
AUD_DIR = os.path.join(ROOT, "assets", "audio")
SR = 44100

# ------------------------------------------------------------------ PNG writer

def write_png(path, arr):
    assert arr.dtype == np.uint8
    h, w, c = arr.shape
    color_type = 6 if c == 4 else 2
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        raw += arr[y].tobytes()
    comp = zlib.compress(bytes(raw), 6)

    def chunk(tag, data):
        out = struct.pack(">I", len(data)) + tag + data
        out += struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        return out

    ihdr = struct.pack(">IIBBBBB", w, h, 8, color_type, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", comp) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)
    return os.path.getsize(path)


def fx(x):
    """numpy linspace of x in [0, 1) with width n."""
    return np.linspace(0.0, 1.0, x, endpoint=False)


# ------------------------------------------------------------------- textures

def sky(name, top, bottom, stars=False, sun=None, clouds=0.4, seed=3):
    w, h = 1920, 1080
    t = fx(h)[:, None]
    arr = np.zeros((h, w, 4), dtype=np.uint8)
    for c in range(3):
        col = top[c] * (1 - t) + bottom[c] * t
        arr[:, :, c] = np.clip(np.repeat(col, w, axis=1), 0, 255)
    rng = np.random.default_rng(seed)
    if stars:
        n = 420
        xs = rng.integers(0, w, n)
        ys = rng.integers(0, h * 2 // 3, n)
        b = rng.uniform(0.35, 1.0, n)
        tw = 1 + (rng.random(n) < 0.25).astype(int)
        for x, y, bb, tt in zip(xs, ys, b, tw):
            arr[y - tt:y + 1, x - tt:x + 1, :3] = np.maximum(
                arr[y - tt:y + 1, x - tt:x + 1, :3],
                (np.array([235, 240, 255]) * bb).astype(np.uint8))
    if sun is not None:
        sx, sy, sr, scol = sun
        yy, xx = np.mgrid[0:h, 0:w]
        d = np.sqrt((xx - sx) ** 2 + (yy - sy) ** 2)
        glow = np.clip(1.0 - d / (sr * 4.0), 0, 1) ** 2
        disk = np.clip(sr - d, 0, 1).clip(0, 1)
        for c in range(3):
            arr[:, :, c] = np.clip(arr[:, :, c] + glow * scol[c] * 90 + disk * scol[c] * 255, 0, 255)
    # soft cloud bands
    band = (np.sin(fx(w) * 9 + seed) * 0.5 + 0.5) * (np.sin(fx(h) * 3.0)[:, None] * 0.5 + 0.5)
    haze = (band ** 2 * clouds * 60).astype(np.uint8)
    arr[:, :, :3] = np.clip(arr[:, :, :3] + haze[:, :, None], 0, 255)
    arr[:, :, 3] = 255
    write_png(os.path.join(TEX_DIR, name), arr)


def _silhouette_layer(name, w, h, ridges, col, seed, spiky=0.0, towers=False):
    """Ridge silhouette with alpha; several stacked mountain/roof lines."""
    arr = np.zeros((h, w, 4), dtype=np.uint8)
    rng = np.random.default_rng(seed)
    x = np.arange(w)
    base = np.zeros(w)
    for amp, freq, ph in ridges:
        base += amp * (np.sin(x * freq + ph) * 0.6 + np.sin(x * freq * 2.3 + ph * 2.7) * 0.4)
    base += rng.standard_normal(w).cumsum() * 0.02
    base = base - base.min()
    scale = h * 0.55 / max(base.max(), 1.0)
    line = (h - 1 - base * scale).astype(int)
    if spiky > 0:
        jitter = (rng.random(w) < 0.02).astype(int) * int(60 * spiky)
        line = line - jitter
    if towers:
        for i in range(5):
            tx = int(w * (0.12 + 0.19 * i))
            th = int(h * (0.16 + 0.10 * rng.random()))
            tw = int(46 + 30 * rng.random())
            line[tx:tx + tw] = np.minimum(line[tx:tx + tw], h - th)
            # battlements
            for k in range(0, tw, 26):
                line[tx + k:tx + k + 13] = np.minimum(line[tx + k:tx + k + 13], h - th - 18)
    mask = np.zeros((h, w), dtype=bool)
    for xxi in range(w):
        mask[line[xxi]:, xxi] = True
    arr[mask, 0] = col[0]
    arr[mask, 1] = col[1]
    arr[mask, 2] = col[2]
    arr[:, :, 3] = mask * 255
    # subtle vertical fade into darkness at the very bottom
    fade = np.clip((np.arange(h) / h - 0.85) * 8, 0, 1)[:, None, None]
    arr[:, :, :3] = (arr[:, :, :3] * (1 - fade)).astype(np.uint8)
    write_png(os.path.join(TEX_DIR, name), arr)


def light_radial():
    n = 256
    yy, xx = np.mgrid[0:n, 0:n]
    d = np.sqrt((xx - n / 2) ** 2 + (yy - n / 2) ** 2) / (n / 2)
    a = np.clip(1.0 - d, 0, 1) ** 2
    arr = np.zeros((n, n, 4), dtype=np.uint8)
    arr[:, :, 0] = 255
    arr[:, :, 1] = 255
    arr[:, :, 2] = 255
    arr[:, :, 3] = (a * 255).astype(np.uint8)
    write_png(os.path.join(TEX_DIR, "light_radial.png"), arr)


def gen_textures():
    os.makedirs(TEX_DIR, exist_ok=True)
    # Stage 1: Sunspire Keep - bright day, gold citadel.
    sky("stage1_sky.png", (96, 156, 214), (244, 208, 150),
        stars=False, sun=(1440, 190, 46, (1.0, 0.9, 0.7)), clouds=0.5, seed=5)
    _silhouette_layer("stage1_far.png", 1920, 1080,
                      [(86, 0.003, 0.6), (44, 0.009, 2.2), (20, 0.022, 4.1)],
                      (88, 108, 148), seed=11, spiky=1.0, towers=True)
    _silhouette_layer("stage1_mid.png", 1920, 1080,
                      [(64, 0.005, 1.4), (30, 0.014, 0.3)],
                      (54, 66, 96), seed=12, spiky=1.4, towers=True)
    # Stage 2: Frostbridge Crossing - starry night, blue ice.
    sky("stage2_sky.png", (10, 18, 44), (46, 74, 118),
        stars=True, sun=(1560, 150, 30, (0.75, 0.85, 1.0)), clouds=0.25, seed=7)
    _silhouette_layer("stage2_far.png", 1920, 1080,
                      [(100, 0.0025, 2.0), (52, 0.007, 0.8), (22, 0.018, 3.3)],
                      (30, 44, 78), seed=21, spiky=0.8, towers=True)
    _silhouette_layer("stage2_mid.png", 1920, 1080,
                      [(76, 0.004, 4.0), (34, 0.011, 1.9)],
                      (18, 28, 52), seed=22, spiky=0.5, towers=True)
    # Stage 3: Ember Hollow - dusk caldera, magma glow.
    sky("stage3_sky.png", (52, 16, 38), (214, 84, 46),
        stars=False, sun=(960, 690, 70, (1.0, 0.55, 0.3)), clouds=0.6, seed=9)
    _silhouette_layer("stage3_far.png", 1920, 1080,
                      [(110, 0.002, 1.0), (56, 0.006, 2.6), (24, 0.016, 5.0)],
                      (66, 26, 40), seed=31, spiky=0.6, towers=False)
    _silhouette_layer("stage3_mid.png", 1920, 1080,
                      [(84, 0.003, 3.2), (38, 0.009, 0.9)],
                      (40, 16, 26), seed=32, spiky=0.4, towers=False)
    light_radial()
    print("textures done")


# ---------------------------------------------------------------------- audio

def wav_write(path, sig, sr=SR):
    sig = np.clip(sig, -1, 1)
    data = (sig * 32767).astype(np.int16)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(sr)
        f.writeframes(data.tobytes())
    return os.path.getsize(path)


def env(n, a, d, s_level=0.0, r=None):
    """attack/decay/sustain envelope of n samples (a, d, r in seconds)."""
    t = np.arange(n) / SR
    e = np.ones(n)
    an = max(int(a * SR), 1)
    e[:an] = np.linspace(0, 1, an)
    dn = int(d * SR)
    e[an:an + dn] = np.linspace(1, s_level, dn)
    e[an + dn:] = s_level
    if r is not None:
        rn = min(int(r * SR), n)
        e[-rn:] *= np.linspace(1, 0, rn)
    return e


def saw_h(ph, k=7):
    out = np.zeros_like(ph)
    for i in range(1, k + 1):
        out += np.sin(ph * i) / i
    return out * (2.0 / math.pi)


def square_h(ph, k=6):
    out = np.zeros_like(ph)
    for i in range(1, k + 1, 2):
        out += np.sin(ph * i) / i
    return out * (4.0 / math.pi)


def place(buf, start, sig):
    n = len(sig)
    end = min(len(buf), start + n)
    if end > start:
        buf[start:end] += sig[:end - start]


def track(name, bpm, prog, seed, lead_wave=saw_h, arp=True, mood=0.0, bars_per_chord=1):
    """Loopable battle track: pad + bass + arp + drums over a chord loop."""
    rng = np.random.default_rng(seed)
    beat = 60.0 / bpm
    bar = beat * 4
    chord_len = bar * bars_per_chord
    loop_len = chord_len * len(prog)
    reps = 3
    total = int((loop_len * reps + 2.0) * SR)
    buf = np.zeros(total)
    freqs_root = {"A": 55.0, "B": 61.74, "C": 65.41, "D": 73.42, "E": 82.41, "F": 87.31, "G": 98.0}
    minor = [0, 3, 7, 12]
    major = [0, 4, 7, 12]
    for rep in range(reps):
        base = int(rep * loop_len * SR)
        for ci, (root, kind) in enumerate(prog):
            t0 = base + int(ci * chord_len * SR)
            rootf = freqs_root[root]
            intervals = minor if kind == "m" else major
            # pad: 3-voice, detuned
            n = int(chord_len * SR)
            t = np.arange(n) / SR
            pad = np.zeros(n)
            for iv in intervals[:3]:
                f = rootf * 2 ** (iv / 12.0) * 2
                for det in (0.997, 1.003):
                    pad += lead_wave(2 * math.pi * f * det * t, 5)
            pad *= env(n, 0.6, chord_len * 0.5, 0.55, 0.4) * 0.055
            place(buf, t0, pad)
            # bass: 8ths on root
            step = int(beat * 0.5 * SR)
            for i in range(int(chord_len * SR) // step):
                bn = int(beat * 0.45 * SR)
                tb = np.arange(bn) / SR
                f = rootf
                bass = np.sin(2 * math.pi * f * tb) + 0.4 * np.sin(2 * math.pi * f * 2 * tb)
                bass *= env(bn, 0.004, bn * 0.6 / SR, 0.0, 0.06) * 0.16
                place(buf, t0 + i * step, bass)
            if arp:
                # 16th arpeggio walking the chord
                astep = int(beat * 0.25 * SR)
                notes = [rootf * 2 ** (iv / 12.0 + 2) for iv in intervals] + \
                        [rootf * 2 ** (iv / 12.0 + 3) for iv in intervals]
                order = [0, 2, 1, 3, 2, 0, 3, 1]
                for i in range(int(chord_len * SR) // astep):
                    an = int(beat * 0.22 * SR)
                    ta = np.arange(an) / SR
                    if rng.random() < 0.12:  # tasteful rests
                        continue
                    f = notes[order[i % len(order)]]
                    arp_sig = lead_wave(2 * math.pi * f * ta, 6)
                    arp_sig *= env(an, 0.003, an * 0.7 / SR, 0.0, 0.05) * 0.055
                    place(buf, t0 + i * astep, arp_sig)
            # drums: kick on 1&3, hat 8ths, snare 2&4 (noise burst)
            for b in range(int(bars_per_chord * 4)):
                bb = t0 + int(b * beat * SR)
                kn = int(0.13 * SR)
                tk = np.arange(kn) / SR
                kick = np.sin(2 * math.pi * (110 * np.exp(-tk * 22)) * tk)
                kick *= np.exp(-tk * 26) * 0.6
                place(buf, bb, kick)
                if b % 2 == 1:
                    sn = int(0.09 * SR)
                    noise = rng.standard_normal(sn) * np.exp(-np.arange(sn) / SR * 40) * 0.18
                    place(buf, bb, noise)
                hn = int(0.03 * SR)
                hat = rng.standard_normal(hn) * np.exp(-np.arange(hn) / SR * 160) * 0.06
                for h8 in range(2):
                    place(buf, bb + int(h8 * beat * 0.5 * SR), hat)
    # normalize
    buf = buf / max(1.0, np.abs(buf).max()) * 0.85
    # fade the tail for a clean loop point
    tail = int(1.2 * SR)
    buf[:tail] *= np.linspace(0, 1, tail)
    buf[-tail:] *= np.linspace(1, 0, tail)
    wav_write(os.path.join(AUD_DIR, name), buf)
    print("audio:", name, "%.1fs" % (len(buf) / SR))


def sfx(name, fn):
    sig = fn()
    wav_write(os.path.join(AUD_DIR, name), sig)
    print("audio:", name, "%.2fs" % (len(sig) / SR))


def gen_audio():
    os.makedirs(AUD_DIR, exist_ok=True)
    track("music_menu.wav", 92, [("A", "m"), ("F", "M"), ("C", "M"), ("G", "M")], 41,
          arp=True, bars_per_chord=2)
    track("music_stage1.wav", 128, [("A", "m"), ("F", "M"), ("C", "M"), ("G", "M")], 42)
    track("music_stage2.wav", 118, [("D", "m"), ("B", "M"), ("F", "M"), ("A", "m")], 43,
          bars_per_chord=2)
    track("music_stage3.wav", 138, [("E", "m"), ("C", "M"), ("D", "m"), ("B", "M")], 44)

    def hit_light():
        n = int(0.16 * SR)
        t = np.arange(n) / SR
        rng = np.random.default_rng(1)
        thud = np.sin(2 * math.pi * 160 * np.exp(-t * 8) * t) * np.exp(-t * 30)
        noise = rng.standard_normal(n) * np.exp(-t * 55) * 0.7
        return thud * 0.8 + noise * 0.6

    def hit_heavy():
        n = int(0.34 * SR)
        t = np.arange(n) / SR
        rng = np.random.default_rng(2)
        thud = np.sin(2 * math.pi * 90 * np.exp(-t * 5) * t) * np.exp(-t * 14)
        crack = rng.standard_normal(n) * np.exp(-t * 34) * 0.9
        boom = np.sin(2 * math.pi * 48 * t) * np.exp(-t * 9) * 0.7
        return thud * 0.9 + crack * 0.7 + boom

    def whiff():
        n = int(0.22 * SR)
        t = np.arange(n) / SR
        noise = np.random.default_rng(3).standard_normal(n)
        # crude band sweep: modulate with sine
        mod = np.sin(2 * math.pi * (400 + 1400 * t / 0.22) * t)
        return noise * mod * np.exp(-t * 12) * 0.35

    def ko_blast():
        n = int(1.0 * SR)
        t = np.arange(n) / SR
        rng = np.random.default_rng(4)
        boom = np.sin(2 * math.pi * (70 * np.exp(-t * 3) + 30) * t) * np.exp(-t * 4) * 1.1
        crack = rng.standard_normal(n) * np.exp(-t * 18) * 0.8
        sweep = np.sin(2 * math.pi * (900 * np.exp(-t * 4) + 60) * t) * np.exp(-t * 6) * 0.5
        return boom + crack * 0.6 + sweep

    def jump():
        n = int(0.18 * SR)
        t = np.arange(n) / SR
        f = 300 + 500 * t / 0.18
        return np.sin(2 * math.pi * f * t) * np.exp(-t * 14) * 0.5

    def dash():
        n = int(0.2 * SR)
        t = np.arange(n) / SR
        noise = np.random.default_rng(6).standard_normal(n)
        return noise * np.sin(2 * math.pi * 200 * t) * np.exp(-t * 16) * 0.5

    def dodge():
        n = int(0.25 * SR)
        t = np.arange(n) / SR
        noise = np.random.default_rng(7).standard_normal(n)
        return noise * np.sin(2 * math.pi * (600 + 300 * t) * t) * np.exp(-t * 11) * 0.45

    def pickup():
        n = int(0.22 * SR)
        t = np.arange(n) / SR
        a = np.sin(2 * math.pi * 660 * t) * np.exp(-t * 20) * 0.4
        b = np.sin(2 * math.pi * 990 * (t - 0.09)) * np.exp(-np.maximum(t - 0.09, 0) * 20) * 0.4
        b[t < 0.09] = 0
        return a + b

    def throw():
        n = int(0.18 * SR)
        t = np.arange(n) / SR
        noise = np.random.default_rng(9).standard_normal(n)
        return noise * np.exp(-t * 22) * np.sin(2 * math.pi * 90 * t) * 0.7

    def shoot():
        n = int(0.24 * SR)
        t = np.arange(n) / SR
        pluck = np.sin(2 * math.pi * 220 * t) * np.exp(-t * 18) * 0.5
        noise = np.random.default_rng(10).standard_normal(n) * np.exp(-t * 60) * 0.5
        return pluck + noise * 0.5

    def ui_click():
        n = int(0.07 * SR)
        t = np.arange(n) / SR
        return np.sin(2 * math.pi * 1200 * t) * np.exp(-t * 60) * 0.5

    def ui_go():
        notes = [523.25, 659.25, 784.0, 1046.5]
        total = int(0.9 * SR)
        buf = np.zeros(total)
        for i, f in enumerate(notes):
            n = int(0.5 * SR)
            t = np.arange(n) / SR
            sig = (np.sin(2 * math.pi * f * t) + 0.5 * np.sin(2 * math.pi * f * 2 * t))
            sig *= np.exp(-t * 5) * 0.3
            place(buf, int(i * 0.11 * SR), sig)
        return buf

    def countdown():
        n = int(0.16 * SR)
        t = np.arange(n) / SR
        return np.sin(2 * math.pi * 880 * t) * np.exp(-t * 22) * 0.45

    def victory():
        notes = [523.25, 659.25, 784.0, 1046.5, 1318.5]
        total = int(1.6 * SR)
        buf = np.zeros(total)
        for i, f in enumerate(notes):
            n = int(0.6 * SR)
            t = np.arange(n) / SR
            sig = (square_h(2 * math.pi * f * t, 4) + np.sin(2 * math.pi * f * t)) * 0.5
            sig *= np.exp(-t * 4) * 0.25
            place(buf, int(i * 0.14 * SR), sig)
        return buf

    def spawn():
        n = int(0.5 * SR)
        t = np.arange(n) / SR
        f = 200 + 800 * t / 0.5
        return np.sin(2 * math.pi * f * t) * np.exp(-t * 6) * 0.25

    def taunt():
        n = int(0.35 * SR)
        t = np.arange(n) / SR
        f = 440 + 220 * np.sin(2 * math.pi * 5 * t)
        return np.sin(2 * math.pi * f * t) * np.exp(-t * 6) * 0.3

    sfx("hit_light.wav", hit_light)
    sfx("hit_heavy.wav", hit_heavy)
    sfx("whiff.wav", whiff)
    sfx("ko_blast.wav", ko_blast)
    sfx("jump.wav", jump)
    sfx("dash.wav", dash)
    sfx("dodge.wav", dodge)
    sfx("pickup.wav", pickup)
    sfx("throw.wav", throw)
    sfx("shoot.wav", shoot)
    sfx("ui_click.wav", ui_click)
    sfx("ui_go.wav", ui_go)
    sfx("countdown.wav", countdown)
    sfx("victory.wav", victory)
    sfx("spawn.wav", spawn)
    sfx("taunt.wav", taunt)


if __name__ == "__main__":
    gen_textures()
    gen_audio()
    print("all assets generated")
