"""はかり野の効果音と BGM を手続きで合成する。

使い方:
    python3 -I tools/audio/gen_audio.py assets/audio

numpy と ffmpeg（libvorbis）が必要。出力は Ogg Vorbis。
乱数の種を固定しているので、何度実行しても同じ音になる。
音の方針: 北欧の夕暮れ。低い持続音、風、竪琴（カープラス・ストロング法の撥弦）、鐘、枠太鼓、角笛。
"""

import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
RNG = np.random.default_rng(20261016)


# ---------- 基本の部品 ----------

def secs(d):
    return np.arange(int(SR * d)) / SR


def noise(d):
    return RNG.uniform(-1.0, 1.0, int(SR * d))


def band(x, lo=None, hi=None, soft=0.15):
    """FFT のマスクで帯域を通す。lo/hi は Hz。端はなだらかにする。"""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    mask = np.ones_like(f)
    if lo is not None:
        mask *= 1.0 / (1.0 + (lo / np.maximum(f, 1e-3)) ** (2.0 / soft * 0.2))
    if hi is not None:
        mask *= 1.0 / (1.0 + (f / hi) ** (2.0 / soft * 0.2))
    return np.fft.irfft(spec * mask, len(x))


def decay(d, rate):
    return np.exp(-secs(d) * rate)


def attack_release(d, a, r):
    t = secs(d)
    env = np.minimum(1.0, t / max(a, 1e-4))
    tail = np.clip((d - t) / max(r, 1e-4), 0.0, 1.0)
    return env * tail


def pluck(freq, d, damp=0.996, bright=0.6):
    """カープラス・ストロング法の撥弦（竪琴・リュートの代わり）。周期ごとにまとめて計算する。"""
    n = int(SR * d)
    period = max(2, int(SR / freq))
    burst = band(RNG.uniform(-1, 1, period * 8), hi=SR * 0.5 * bright)[:period]
    out = np.zeros(n + period)
    out[:period] = burst
    prev_last = 0.0
    for start in range(period, n + period, period):
        block = out[start - period:start]
        shifted = np.concatenate(([prev_last], block[:-1]))
        prev_last = block[-1]
        new = damp * 0.5 * (block + shifted)
        end = min(start + period, len(out))
        out[start:end] = new[:end - start]
    return out[:n] * attack_release(d, 0.002, 0.3)


def bell(freq, d, rate=1.6):
    """鐘。非整数倍の倍音を、高いものほど早く減衰させる。"""
    t = secs(d)
    ratios = [0.5, 1.0, 1.19, 1.56, 2.0, 2.74, 3.76, 5.4]
    amps = [0.5, 1.0, 0.45, 0.35, 0.3, 0.22, 0.12, 0.08]
    x = np.zeros_like(t)
    for r, a in zip(ratios, amps):
        x += a * np.sin(2 * np.pi * freq * r * t + RNG.uniform(0, 6.28)) * np.exp(-t * rate * (0.6 + r * 0.5))
    return x * attack_release(d, 0.003, 0.2)


def sweep(f0, f1, d):
    t = secs(d)
    f = f0 * (f1 / f0) ** (t / d)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def saw(freq, d):
    t = secs(d)
    x = np.zeros_like(t)
    for k in range(1, 18):
        x += np.sin(2 * np.pi * freq * k * t) / k
    return x * 0.6


def drum(d=0.5, f0=120.0, f1=55.0, body=1.0):
    """枠太鼓。音程の落ちる正弦と、短い革の雑音。"""
    x = sweep(f0, f1, d) * decay(d, 9.0) * body
    x += band(noise(d), 200, 2500) * decay(d, 40.0) * 0.35
    return x


def place(track, clip, at, gain=1.0):
    i = int(at * SR)
    if i >= len(track):
        return
    j = min(len(track), i + len(clip))
    track[i:j] += clip[:j - i] * gain


def normalize(x, peak):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def fold_loop(x, loop_len):
    """loop_len 秒より後ろの余韻を頭に重ねて、継ぎ目のない輪にする。"""
    n = int(loop_len * SR)
    head = x[:n].copy()
    tail = x[n:]
    head[:len(tail)] += tail
    return head


def note(name):
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    base = names[name[0]]
    acc = 1 if "#" in name else (-1 if "b" in name[1:-1] else 0)
    octave = int(name[-1])
    return 440.0 * 2 ** ((base + acc + (octave - 4) * 12) / 12.0)


def write_ogg(path, x, quality=4):
    x = np.clip(x, -1.0, 1.0)
    pcm = (x * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        tmp_path = tmp.name
    with wave.open(tmp_path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp_path, "-c:a", "libvorbis", "-q:a", str(quality), path], check=True)
    os.remove(tmp_path)


# ---------- 効果音 ----------

def sfx_pen():
    """ペン先が羊皮紙をこする音（ループ用、0.8 秒）。"""
    d = 0.8
    grains = np.zeros(int(SR * d))
    for k in range(40):
        g = band(noise(0.03), 2500, 7000) * attack_release(0.03, 0.005, 0.02)
        place(grains, g, RNG.uniform(0, d - 0.03), RNG.uniform(0.3, 1.0))
    bed = band(noise(d), 1800, 5000) * 0.25
    x = grains + bed
    # 継ぎ目をなめらかに
    fade = int(0.02 * SR)
    x[:fade] *= np.linspace(0, 1, fade)
    x[-fade:] *= np.linspace(1, 0, fade)
    return normalize(x, 0.5)


def sfx_seal():
    d = 0.6
    x = sweep(160, 70, d) * decay(d, 14.0)
    x += band(noise(d), 100, 900) * decay(d, 18.0) * 0.6
    return normalize(x, 0.9)


def sfx_merge():
    d = 4.0
    x = np.zeros(int(SR * d))
    swell = band(noise(1.2), 800, 6000) * np.linspace(0, 1, int(SR * 1.2)) ** 2 * 0.25
    place(x, swell, 0.0)
    for i, n in enumerate(["D4", "A4", "D5", "F5"]):
        place(x, bell(note(n), 2.8, 1.1), 1.1 + i * 0.12, 0.8 - i * 0.12)
    place(x, sweep(110, 40, 1.5) * decay(1.5, 2.5), 1.1, 0.7)
    return normalize(x, 0.9)


def sfx_land():
    d = 1.4
    x = sweep(95, 32, d) * decay(d, 3.5)
    x += band(noise(d), 40, 400) * decay(d, 6.0) * 0.7
    place(x, band(noise(0.4), 300, 3000) * decay(0.4, 20.0), 0.0, 0.6)
    debris = np.zeros(int(SR * d))
    for k in range(18):
        place(debris, band(noise(0.04), 600, 4000) * decay(0.04, 60.0), RNG.uniform(0.05, 0.7), RNG.uniform(0.1, 0.4))
    return normalize(x + debris, 0.95)


def whoosh(d=0.18, lo=500, hi=4000):
    return band(noise(d), lo, hi) * np.sin(np.linspace(0, np.pi, int(SR * d))) ** 2


def sfx_hit_blade():
    d = 0.4
    x = np.zeros(int(SR * d))
    place(x, whoosh(0.14, 1200, 6000), 0.0, 0.7)
    place(x, bell(1800, 0.25, 12.0), 0.12, 0.35)
    place(x, band(noise(0.08), 400, 3000) * decay(0.08, 50.0), 0.12, 0.8)
    return normalize(x, 0.85)


def sfx_hit_heavy():
    d = 0.8
    x = np.zeros(int(SR * d))
    place(x, whoosh(0.22, 200, 1500), 0.0, 0.8)
    place(x, sweep(120, 38, 0.6) * decay(0.6, 7.0), 0.2, 1.0)
    place(x, band(noise(0.3), 60, 1200) * decay(0.3, 16.0), 0.2, 0.9)
    return normalize(x, 0.95)


def sfx_hit_light():
    d = 0.25
    x = np.zeros(int(SR * d))
    place(x, whoosh(0.08, 1500, 7000), 0.0, 0.5)
    place(x, band(noise(0.05), 800, 5000) * decay(0.05, 70.0), 0.07, 0.8)
    place(x, sweep(400, 180, 0.08) * decay(0.08, 40.0), 0.07, 0.4)
    return normalize(x, 0.7)


def sfx_bow():
    d = 0.6
    x = np.zeros(int(SR * d))
    place(x, pluck(98.0, 0.5, 0.99, 0.9), 0.0, 0.8)
    place(x, whoosh(0.25, 1500, 7000), 0.05, 0.5)
    return normalize(x, 0.8)


def sfx_shatter():
    d = 0.9
    x = np.zeros(int(SR * d))
    place(x, band(noise(0.06), 1500, 9000) * decay(0.06, 60.0), 0.0, 1.0)
    for k in range(22):
        f = RNG.uniform(2200, 6500)
        ping = np.sin(2 * np.pi * f * secs(0.25)) * decay(0.25, RNG.uniform(18, 40))
        place(x, ping, RNG.uniform(0.0, 0.35), RNG.uniform(0.08, 0.3))
    place(x, sweep(300, 120, 0.2) * decay(0.2, 25.0), 0.0, 0.4)
    return normalize(x, 0.8)


def sfx_frost_spawn():
    d = 1.0
    x = band(noise(d), 3000, 10000) * attack_release(d, 0.5, 0.45) * 0.6
    place(x, bell(2637, 0.8, 4.0), 0.35, 0.15)
    return normalize(x, 0.45)


def sfx_seed_hit():
    d = 0.6
    x = np.zeros(int(SR * d))
    for k in range(10):
        place(x, band(noise(0.02), 1000, 7000) * decay(0.02, 80.0), RNG.uniform(0.0, 0.2), RNG.uniform(0.3, 0.9))
    place(x, sweep(140, 60, 0.4) * decay(0.4, 12.0), 0.0, 0.6)
    return normalize(x, 0.7)


def sfx_repair():
    d = 0.9
    x = np.zeros(int(SR * d))
    place(x, bell(note("A5"), 0.8, 4.0), 0.0, 0.5)
    place(x, bell(note("E6"), 0.6, 5.0), 0.06, 0.3)
    return normalize(x, 0.45)


def sfx_horn():
    """波の始まりの角笛。完全五度の重なり、ゆっくり立ち上がる。"""
    d = 2.6
    t = secs(d)
    vib = 1.0 + 0.004 * np.sin(2 * np.pi * 5.0 * t)
    x = np.zeros_like(t)
    for f, a in [(note("D2"), 1.0), (note("A2"), 0.7), (note("D3"), 0.35)]:
        ph = 2 * np.pi * np.cumsum(f * vib) / SR
        for k in range(1, 12):
            x += a * np.sin(ph * k) / (k ** 1.3)
    x = band(x, 40, 1400) * attack_release(d, 0.6, 0.9)
    return normalize(x, 0.8)


def sfx_tick():
    d = 0.12
    x = np.sin(2 * np.pi * 1200 * secs(d)) * decay(d, 60.0)
    x += band(noise(d), 2000, 6000) * decay(d, 120.0) * 0.3
    return normalize(x, 0.5)


def sfx_ui():
    return normalize(pluck(note("A4"), 0.7, 0.995, 0.7), 0.6)


def sfx_wave_clear():
    d = 2.4
    x = np.zeros(int(SR * d))
    for i, n in enumerate(["D4", "F4", "A4", "C5", "D5"]):
        place(x, pluck(note(n), 1.6, 0.997, 0.7), i * 0.11, 0.8)
    place(x, bell(note("D5"), 1.8, 1.5), 0.55, 0.4)
    return normalize(x, 0.8)


def sfx_gameover():
    d = 5.0
    x = np.zeros(int(SR * d))
    for i, n in enumerate(["A3", "F3", "D3"]):
        place(x, bell(note(n), 3.5, 0.9), i * 0.7, 0.7)
    drone = (np.sin(2 * np.pi * note("D2") * secs(d)) + 0.5 * np.sin(2 * np.pi * note("A1") * secs(d))) * attack_release(d, 1.0, 2.0)
    x += band(drone, 30, 600) * 0.5
    return normalize(x, 0.85)


def sfx_enemy_attack():
    d = 0.3
    x = band(noise(d), 2500, 9000) * attack_release(d, 0.01, 0.25) * 0.6
    place(x, sweep(900, 400, 0.1) * decay(0.1, 30.0), 0.0, 0.3)
    return normalize(x, 0.45)


# ---------- 音楽 ----------

PENTA = ["D3", "F3", "G3", "A3", "C4", "D4", "F4", "G4", "A4", "C5"]


def bgm_ambient():
    """タイトルと記録帳。64 秒の輪。持続音・風・竪琴・ときどき鐘。"""
    loop = 64.0
    d = loop + 6.0
    t = secs(d)
    x = np.zeros_like(t)
    lfo = 0.75 + 0.25 * np.sin(2 * np.pi * t / 16.0)
    for f, a in [(note("D2"), 0.5), (note("D2") * 1.003, 0.4), (note("A2"), 0.3), (note("A2") * 0.997, 0.25), (note("D3"), 0.12)]:
        x += a * np.sin(2 * np.pi * f * t) * lfo
    x = band(x, 30, 900)
    wind = band(noise(d), 180, 1100) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 11.0 + 1.0)) ** 2 * 0.35
    x += wind
    at = 1.5
    while at < loop:
        n = RNG.choice(PENTA)
        figure = RNG.integers(1, 4)
        for k in range(figure):
            nn = PENTA[min(len(PENTA) - 1, PENTA.index(n) + k * RNG.integers(1, 3))]
            place(x, pluck(note(nn), 3.0, 0.998, 0.55), at + k * 0.28, 0.35)
        at += RNG.uniform(2.2, 4.2)
    for b in [8.0, 40.0]:
        place(x, bell(note("D4"), 5.0, 0.8), b, 0.18)
    return normalize(fold_loop(x, loop), 0.55)


def bgm_battle():
    """戦闘。100 BPM、48 秒の輪。枠太鼓・持続音・竪琴の反復・角笛。"""
    bpm = 100.0
    beat = 60.0 / bpm
    bars = 20
    loop = bars * 4 * beat
    d = loop + 4.0
    t = secs(d)
    x = np.zeros_like(t)
    trem = 0.8 + 0.2 * np.sin(2 * np.pi * t * (bpm / 60.0) / 2.0)
    for f, a in [(note("D2"), 0.45), (note("A2"), 0.25), (note("D2") * 1.004, 0.3)]:
        x += a * np.sin(2 * np.pi * f * t) * trem
    x = band(x, 30, 700)
    pattern = [1.0, 0.0, 0.55, 0.0, 0.9, 0.45, 0.6, 0.3]
    for bar in range(bars):
        for i, v in enumerate(pattern):
            if v > 0:
                place(x, drum(0.45, 115 if i % 4 == 0 else 150, 50, 1.0), bar * 4 * beat + i * beat / 2, v * 0.7)
    roots = [0, 0, -2, -2, -4, -4, -2, 0]
    ostinato = ["D3", "A3", "D4", "A3", "C4", "A3", "G3", "A3"]
    for bar in range(bars):
        shift = roots[bar % len(roots)]
        if bar < 2:
            continue
        for i, n in enumerate(ostinato):
            f = note(n) * 2 ** (shift / 12.0)
            place(x, pluck(f, 1.0, 0.994, 0.6), bar * 4 * beat + i * beat / 2, 0.28)
    for bar in range(0, bars, 8):
        place(x, sfx_horn(), bar * 4 * beat + 0.2, 0.25)
    return normalize(fold_loop(x, loop), 0.6)


SFX = {
    "pen": sfx_pen, "seal": sfx_seal, "merge": sfx_merge, "land": sfx_land,
    "hit_blade": sfx_hit_blade, "hit_heavy": sfx_hit_heavy, "hit_light": sfx_hit_light, "bow": sfx_bow,
    "shatter": sfx_shatter, "frost_spawn": sfx_frost_spawn, "seed_hit": sfx_seed_hit, "repair": sfx_repair,
    "horn": sfx_horn, "tick": sfx_tick, "ui": sfx_ui, "wave_clear": sfx_wave_clear, "gameover": sfx_gameover,
    "enemy_attack": sfx_enemy_attack,
}
MUSIC = {"bgm_ambient": bgm_ambient, "bgm_battle": bgm_battle}


def main(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    for name, make in SFX.items():
        write_ogg(os.path.join(out_dir, "sfx_%s.ogg" % name), make(), quality=5)
        print("sfx_%s" % name)
    for name, make in MUSIC.items():
        write_ogg(os.path.join(out_dir, "%s.ogg" % name), make(), quality=4)
        print(name)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "assets/audio")
