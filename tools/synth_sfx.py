"""Procedural weapon / impact / UI sound effects -> assets/sfx/*.wav (44.1 kHz mono 16-bit).
Toy-shooter flavour: punchy, short, slightly plasticky. Run: python tools/synth_sfx.py"""
import numpy as np, wave, os
from scipy import signal

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sfx')
rng = np.random.default_rng(7)

def t(dur): return np.arange(int(SR * dur)) / SR
def noise(dur): return rng.standard_normal(int(SR * dur))
def env(dur, a=0.001, d=0.1, s=0.0, r=0.05, hold=0.0):
    n = int(SR * dur)
    parts = [np.linspace(0, 1, max(int(SR*a), 1)), np.ones(int(SR*hold)),
             np.linspace(1, s, max(int(SR*d), 1)), np.linspace(s, 0, max(int(SR*r), 1))]
    e = np.concatenate(parts)
    if len(e) >= n: return e[:n]
    return np.concatenate([e, np.zeros(n - len(e))])
def lp(x, f, o=2): b, a = signal.butter(o, min(f, SR*0.49) / (SR/2), 'low'); return signal.lfilter(b, a, x)
def hp(x, f, o=2): b, a = signal.butter(o, max(f, 20) / (SR/2), 'high'); return signal.lfilter(b, a, x)
def bp(x, lo, hi, o=2): b, a = signal.butter(o, [lo/(SR/2), min(hi, SR*0.49)/(SR/2)], 'band'); return signal.lfilter(b, a, x)
def sine(dur, f0, f1=None, phase=0.0):
    tt = t(dur); f = np.linspace(f0, f1 if f1 else f0, len(tt))
    return np.sin(2*np.pi*np.cumsum(f)/SR + phase)
def fit(*parts):
    n = max(len(p) for p in parts); out = np.zeros(n)
    for p in parts: out[:len(p)] += p
    return out
def norm(x, peak=0.9):
    m = np.max(np.abs(x)) or 1.0; return x / m * peak
def soft(x, drive=1.5): return np.tanh(x * drive) / np.tanh(drive)
def save(name, x):
    x = np.clip(x, -1, 1)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())
    print(' ', name, '%.2fs' % (len(x)/SR))

def gunshot(dur=0.28, body_f=180, crack_hp=1500, crack_len=0.03, thump=1.0, tail=0.6):
    crack = hp(noise(crack_len), crack_hp) * env(crack_len, 0.0005, crack_len*0.8, 0, 0.005)
    body = lp(noise(dur), 900) * env(dur, 0.001, dur*0.5, 0.15, dur*0.4) * 0.8
    th = sine(0.12, body_f, body_f*0.4) * env(0.12, 0.001, 0.08, 0, 0.03) * thump
    tl = bp(noise(dur*1.5), 200, 2500) * env(dur*1.5, 0.005, dur, 0.1, dur*0.4) * 0.35 * tail
    return norm(soft(fit(crack*1.4, body, th, tl), 2.0))

os.makedirs(OUT, exist_ok=True)
print('writing to', os.path.abspath(OUT))
save('rifle_shot', gunshot(0.22, 220, 2000, 0.02, 0.8, 0.5))
save('shotgun_shot', gunshot(0.45, 110, 900, 0.05, 1.6, 1.0))
save('sniper_shot', fit(gunshot(0.6, 90, 2500, 0.03, 1.4, 1.4), sine(0.5, 1200, 300) * env(0.5, 0.001, 0.4, 0, 0.1) * 0.15))
save('gatling_shot', gunshot(0.12, 260, 2500, 0.012, 0.5, 0.3))
# gatling spin-up: rising motor whine loop-ish
d = 0.45; sp = sine(d, 60, 240) + 0.5*sine(d, 120, 480); save('gatling_spin', norm(lp(sp, 1200) * env(d, 0.05, 0.1, 0.8, 0.1), 0.5))
# rocket launch: whoosh + thump
d = 0.7; wh = bp(noise(d), 300, 3000) * env(d, 0.02, 0.5, 0.2, 0.15)
save('bazooka_launch', norm(soft(fit(wh, sine(0.2, 140, 50)*env(0.2, 0.001, 0.15, 0, 0.05)*1.2), 1.8)))
d = 0.3; save('grenade_launch', norm(fit(lp(noise(d), 600)*env(d, 0.002, 0.2, 0, 0.08), sine(0.15, 300, 90)*env(0.15, 0.001, 0.1, 0, 0.04)*0.8)))
# explosion: deep boom + crackle + long tail
d = 1.6; boom = lp(noise(d), 160) * env(d, 0.003, 0.5, 0.25, 1.0) * 1.5
crk = bp(noise(d), 800, 6000) * env(d, 0.001, 0.15, 0.05, 0.6) * 0.6
sub = sine(0.5, 70, 30) * env(0.5, 0.002, 0.35, 0, 0.13)
save('explosion', norm(soft(fit(boom, crk, sub), 2.5)))
d = 0.18; save('grenade_bounce', norm(fit(sine(d, 420, 260)*env(d, 0.001, 0.12, 0, 0.05), lp(noise(0.06), 3000)*env(0.06, 0.001, 0.04, 0, 0.02)*0.5), 0.6))
d = 0.25; save('melee_swing', norm(bp(noise(d), 400, 4000) * env(d, 0.06, 0.12, 0, 0.07) * (1 + 0.5*sine(d, 8)), 0.55))
d = 0.16; save('melee_hit', norm(soft(fit(sine(d, 240, 120)*env(d, 0.001, 0.1, 0, 0.05), lp(noise(0.08), 1800)*env(0.08, 0.001, 0.05, 0, 0.03)), 1.8)))
d = 0.07; save('hit_marker', norm(fit(sine(d, 1800)*env(d, 0.001, 0.04, 0, 0.02), sine(d, 2700)*env(d, 0.001, 0.03, 0, 0.02)*0.5), 0.45))
d = 0.09; save('headshot', norm(fit(sine(d, 2600)*env(d, 0.001, 0.05, 0, 0.03), sine(d, 3900)*env(d, 0.001, 0.04, 0, 0.03)*0.6), 0.5))
d = 0.45; save('kill', norm(fit(sine(0.12, 660)*env(0.12, 0.002, 0.08, 0, 0.03), np.concatenate([np.zeros(int(SR*0.1)), sine(0.3, 990)*env(0.3, 0.002, 0.2, 0, 0.08)])), 0.55))
d = 0.6; save('death', norm(soft(fit(lp(noise(d), 700)*env(d, 0.002, 0.4, 0.1, 0.15), sine(0.4, 220, 60)*env(0.4, 0.001, 0.3, 0, 0.1)), 1.6), 0.8))
# reload: two plastic clicks + slide
c1 = lp(noise(0.03), 4000)*env(0.03, 0.001, 0.02, 0, 0.008); c2 = np.concatenate([np.zeros(int(SR*0.35)), lp(noise(0.035), 3500)*env(0.035, 0.001, 0.02, 0, 0.01)])
sl = np.concatenate([np.zeros(int(SR*0.12)), bp(noise(0.15), 600, 2500)*env(0.15, 0.02, 0.1, 0, 0.03)*0.5])
save('reload', norm(fit(c1, c2, sl), 0.6))
d = 0.05; save('empty_click', norm(lp(noise(d), 3000)*env(d, 0.001, 0.03, 0, 0.015), 0.4))
d = 0.35; save('vial_pickup', norm(fit(sine(0.15, 880)*env(0.15, 0.002, 0.1, 0, 0.04), np.concatenate([np.zeros(int(SR*0.09)), sine(0.25, 1320)*env(0.25, 0.002, 0.15, 0, 0.08)])), 0.5))
d = 0.5; save('respawn', norm(fit(sine(d, 300, 900)*env(d, 0.01, 0.3, 0.2, 0.15), bp(noise(d), 1000, 5000)*env(d, 0.05, 0.3, 0, 0.1)*0.3), 0.5))
d = 0.6; save('overheat', norm(fit(bp(noise(d), 2000, 8000)*env(d, 0.01, 0.4, 0.1, 0.15)*0.6, sine(d, 900, 500)*env(d, 0.01, 0.4, 0, 0.15)*0.3), 0.5))
d = 0.2; save('swap', norm(fit(lp(noise(0.03), 3500)*env(0.03, 0.001, 0.02, 0, 0.01), np.concatenate([np.zeros(int(SR*0.08)), lp(noise(0.04), 2500)*env(0.04, 0.001, 0.025, 0, 0.01)*0.8])), 0.5))
d = 0.12; save('hurt', norm(soft(fit(sine(d, 320, 200)*env(d, 0.001, 0.08, 0, 0.03), lp(noise(0.05), 1500)*env(0.05, 0.001, 0.03, 0, 0.02)*0.6), 1.5), 0.6))
d = 0.14; save('footstep', norm(lp(noise(d), 900)*env(d, 0.002, 0.08, 0, 0.05), 0.35))
d = 0.6; save('ui_click', norm(sine(0.05, 1200)*env(0.05, 0.001, 0.03, 0, 0.015), 0.4))
# rocket flight loop (2 s, loopable-ish)
d = 2.0; save('rocket_loop', norm(bp(noise(d), 200, 1800) * (0.7 + 0.3*np.sin(2*np.pi*11*t(d))), 0.45))
# ---- v0.8 animations + effects -------------------------------------------------------
def at(x, offset):          # delay a layer by `offset` seconds
    return np.concatenate([np.zeros(int(SR*offset)), x])

def clicks(times, dur=0.03, lo=800, hi=4000, decay=0.02):
    parts = []
    for i, when in enumerate(times):
        c = bp(noise(dur), lo, hi) * env(dur, 0.001, decay, 0, 0.008) * (0.9 ** i)
        parts.append(at(c, when))
    return fit(*parts)

# reload flourish: the spent magazine hits the floor and bounces once
save('mag_drop', norm(fit(clicks([0.0, 0.085, 0.14], 0.035, 700, 3200),
    sine(0.09, 380, 220)*env(0.09, 0.001, 0.06, 0, 0.02)*0.35), 0.45))

# a toy bursting into parts: hollow plastic pop + snap
save('toy_break', norm(soft(fit(sine(0.11, 760, 170)*env(0.11, 0.001, 0.07, 0, 0.03),
    hp(noise(0.06), 1400)*env(0.06, 0.001, 0.04, 0, 0.02)*0.8,
    lp(noise(0.18), 500)*env(0.18, 0.001, 0.12, 0, 0.05)*0.5), 1.7), 0.85))
# the pieces bouncing on the floor afterwards
save('part_clatter', norm(clicks([0.0, 0.07, 0.13, 0.22, 0.34, 0.41, 0.55, 0.72], 0.03, 900, 5000), 0.5))
# respawn: the toy assembles itself
save('assemble', norm(fit(sine(0.55, 260, 1500)*env(0.55, 0.02, 0.35, 0.1, 0.15)*0.5,
    bp(noise(0.5), 1200, 7000)*env(0.5, 0.03, 0.3, 0.05, 0.15)*0.35,
    at(fit(sine(0.3, 1320)*env(0.3, 0.002, 0.2, 0, 0.1),
           sine(0.3, 1980)*env(0.3, 0.002, 0.18, 0, 0.1)*0.5), 0.34)), 0.6))

# gatling: overheat steam burst, and the barrels winding down
save('steam', norm(fit(hp(noise(0.75), 2600)*env(0.75, 0.006, 0.45, 0.08, 0.25),
    bp(noise(0.3), 400, 1400)*env(0.3, 0.004, 0.2, 0, 0.1)*0.4), 0.5))
d = 0.9; save('spin_down', norm(fit(sine(d, 210, 40)*env(d, 0.01, 0.6, 0.15, 0.25)*0.6,
    bp(noise(d), 300, 2600)*(np.linspace(1.0, 0.15, int(SR*d)))*env(d, 0.01, 0.6, 0.15, 0.25)*0.5), 0.45))

# grenade fuse tick and the bazooka backblast behind the shooter
save('fuse_tick', norm(bp(noise(0.022), 2500, 9000)*env(0.022, 0.001, 0.014, 0, 0.006), 0.35))
save('backblast', norm(soft(fit(lp(noise(0.38), 800)*env(0.38, 0.004, 0.24, 0.05, 0.12),
    sine(0.25, 120, 55)*env(0.25, 0.002, 0.16, 0, 0.08)*0.7), 1.4), 0.7))

# surface-aware impacts: what the bullet hit sounds like
save('impact_wood', norm(soft(fit(sine(0.09, 300, 150)*env(0.09, 0.001, 0.06, 0, 0.02),
    bp(noise(0.05), 700, 3000)*env(0.05, 0.001, 0.03, 0, 0.015)*0.8), 1.3), 0.5))
save('impact_fabric', norm(lp(noise(0.09), 700)*env(0.09, 0.002, 0.06, 0, 0.03), 0.35))
save('impact_metal', norm(fit(sine(0.28, 2400)*env(0.28, 0.001, 0.2, 0, 0.08)*0.5,
    sine(0.22, 3600)*env(0.22, 0.001, 0.15, 0, 0.06)*0.3,
    hp(noise(0.04), 3000)*env(0.04, 0.001, 0.025, 0, 0.01)), 0.45))
save('impact_paper', norm(bp(noise(0.07), 1800, 9000)*env(0.07, 0.001, 0.045, 0, 0.02), 0.4))
save('impact_plastic', norm(fit(sine(0.07, 900, 420)*env(0.07, 0.001, 0.045, 0, 0.02)*0.6,
    bp(noise(0.04), 1500, 6000)*env(0.04, 0.001, 0.025, 0, 0.012)), 0.45))

# low health: lub-dub
save('heartbeat', norm(soft(fit(sine(0.16, 66, 42)*env(0.16, 0.004, 0.1, 0, 0.05),
    at(sine(0.2, 58, 36)*env(0.2, 0.004, 0.13, 0, 0.06)*0.75, 0.19)), 1.5), 0.8))

print('done')
