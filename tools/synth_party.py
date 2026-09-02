"""Party sounds for the Lalu's Birthday room -> assets/sfx/party/*.wav (44.1 kHz mono 16-bit).
Pops, squeaks, cheers, a spring boing, coins, fireworks, a horn, a fanfare and a chiptune loop
of the (public-domain) "Happy Birthday" melody. Run: python tools/synth_party.py"""
import numpy as np, wave, os
from scipy import signal

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sfx', 'party')
rng = np.random.default_rng(11)

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
def square(dur, f, duty=0.5):
    ph = (np.cumsum(np.full(int(SR*dur), f)) / SR) % 1.0
    return np.where(ph < duty, 1.0, -1.0)
def tri(dur, f):
    ph = (np.cumsum(np.full(int(SR*dur), f)) / SR) % 1.0
    return 4*np.abs(ph - 0.5) - 1
def saw(dur, f):
    ph = (np.cumsum(np.full(int(SR*dur), f)) / SR) % 1.0
    return 2*ph - 1
def fit(*parts):
    n = max(len(p) for p in parts); out = np.zeros(n)
    for p in parts: out[:len(p)] += p
    return out
def at(x, offset):
    return np.concatenate([np.zeros(int(SR*offset)), x])
def norm(x, peak=0.9):
    m = np.max(np.abs(x)) or 1.0; return x / m * peak
def soft(x, drive=1.5): return np.tanh(x * drive) / np.tanh(drive)
def save(name, x):
    x = np.clip(x, -1, 1)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())
    print(' ', name, '%.2fs' % (len(x)/SR))

os.makedirs(OUT, exist_ok=True)
print('writing to', os.path.abspath(OUT))

# balloon pop: sharp noise crack + a little rubber thump
d = 0.22
save('balloon_pop', norm(soft(fit(hp(noise(0.03), 1200)*env(0.03, 0.0003, 0.02, 0, 0.01)*1.6,
                                  lp(noise(d), 700)*env(d, 0.001, 0.08, 0.05, 0.1)*0.7,
                                  sine(0.08, 160, 70)*env(0.08, 0.001, 0.05, 0, 0.03)*0.6), 2.0)))
# toy squeak: two-harmonic chirp with vibrato
d = 0.2; tt = t(d); vib = 1 + 0.03*np.sin(2*np.pi*40*tt)
f = np.linspace(950, 1500, len(tt)) * vib
sq = np.sin(2*np.pi*np.cumsum(f)/SR) + 0.35*np.sin(2*np.pi*np.cumsum(2*f)/SR)
save('squeak', norm(sq*env(d, 0.01, 0.12, 0.3, 0.05), 0.55))
# crowd cheer "yay": many detuned voices through vowel-ish band passes
d = 1.1; out = np.zeros(int(SR*d))
for v in range(10):
    f0 = rng.uniform(190, 380); tt = t(d)
    f = f0 * (1 + 0.04*np.sin(2*np.pi*rng.uniform(4.5, 6.5)*tt + rng.uniform(0, 6))) * np.linspace(0.92, 1.05, len(tt))
    voice = 2*((np.cumsum(f)/SR) % 1.0) - 1
    voice = bp(voice, 550, 900) + 0.6*bp(voice, 1100, 1700) + 0.25*bp(voice, 2300, 3200)
    e = env(d, rng.uniform(0.03, 0.12), 0.5, 0.35, 0.35, hold=rng.uniform(0.1, 0.3))
    out += voice * e * rng.uniform(0.6, 1.0)
out += bp(noise(d), 1500, 5000)*env(d, 0.05, 0.6, 0.2, 0.3)*0.15
save('cheer', norm(soft(out, 1.4), 0.8))
# pinata thwack
d = 0.14
save('pinata_hit', norm(soft(fit(lp(noise(d), 1400)*env(d, 0.001, 0.08, 0, 0.04), sine(0.1, 200, 80)*env(0.1, 0.001, 0.07, 0, 0.03)*0.9), 1.8)))
# pinata burst: crack + paper rustle + candy rain of little clicks
d = 1.2; crack = hp(noise(0.05), 900)*env(0.05, 0.0005, 0.03, 0, 0.02)*1.5
rustle = bp(noise(d), 1200, 6000)*env(d, 0.01, 0.5, 0.15, 0.4)*0.5
clicks = np.zeros(int(SR*d))
for i in range(26):
    o = int(SR*rng.uniform(0.15, 1.0)); c = lp(noise(0.02), 4000)*env(0.02, 0.0005, 0.012, 0, 0.005)*rng.uniform(0.3, 0.8)
    clicks[o:o+len(c)] += c[:max(0, len(clicks)-o)]
save('pinata_burst', norm(soft(fit(crack, rustle, clicks, sine(0.15, 150, 60)*env(0.15, 0.001, 0.1, 0, 0.04)*0.8), 1.8)))
# gift open: lid pop + rising sparkle arpeggio
pop = lp(noise(0.04), 2500)*env(0.04, 0.0005, 0.025, 0, 0.01)
arp = fit(*[at(sine(0.25, f)*env(0.25, 0.002, 0.15, 0, 0.08)*0.5, 0.06 + i*0.07) for i, f in enumerate([1047, 1319, 1568, 2093])])
save('gift_open', norm(fit(pop, arp), 0.6))
# spring boing
d = 0.7; tt = t(d)
f = 330 * (1 + 0.35*np.exp(-tt*6)*np.sin(2*np.pi*14*tt))
bo = np.sin(2*np.pi*np.cumsum(f)/SR) + 0.3*np.sin(2*np.pi*np.cumsum(2*f)/SR)
save('boing', norm(soft(bo*env(d, 0.005, 0.5, 0.1, 0.15), 1.4), 0.6))
# coin ding (two quick notes)
save('coin', norm(fit(sine(0.08, 1975)*env(0.08, 0.001, 0.06, 0, 0.02), at(sine(0.3, 2637)*env(0.3, 0.001, 0.2, 0, 0.1), 0.07)), 0.5))
# firework: rising whistle, then a boom with crackle
d = 0.8; tt = t(d)
wh = sine(d, 500, 1900)*env(d, 0.02, 0.6, 0.3, 0.15)*0.6 + bp(noise(d), 1500, 6000)*env(d, 0.02, 0.6, 0.3, 0.15)*0.35
save('firework_launch', norm(wh, 0.5))
d = 1.4; boom = lp(noise(d), 260)*env(d, 0.002, 0.4, 0.2, 0.7)*1.4
gate = (rng.random(int(SR*d)) < 0.08).astype(float); crk = bp(noise(d), 2000, 9000)*env(d, 0.01, 0.3, 0.2, 0.8)*gate*2.0
save('firework_burst', norm(soft(fit(boom, crk, sine(0.4, 90, 40)*env(0.4, 0.002, 0.3, 0, 0.1)), 2.2)))
# candle blown out: a breath puff
d = 0.35
save('candle_out', norm(bp(noise(d), 700, 3500)*env(d, 0.04, 0.2, 0.1, 0.1), 0.5))
# confetti cannon: thump + paper burst
d = 0.5
save('confetti_pop', norm(soft(fit(lp(noise(0.08), 500)*env(0.08, 0.001, 0.05, 0, 0.03)*1.5, sine(0.12, 120, 50)*env(0.12, 0.001, 0.08, 0, 0.04),
                                    bp(noise(d), 1500, 7000)*env(d, 0.005, 0.3, 0.1, 0.2)*0.5), 1.8)))
# party horn: buzzy reed with vibrato
d = 0.7; tt = t(d); f = 440*(1 + 0.02*np.sin(2*np.pi*6*tt))*np.linspace(0.97, 1.0, len(tt))
horn = 2*((np.cumsum(f)/SR) % 1.0) - 1
save('party_horn', norm(soft(lp(horn, 2500)*env(d, 0.03, 0.4, 0.5, 0.15), 2.0), 0.7))
# fanfare: C E G C, squares + a triangle an octave down
notes = [523.25, 659.25, 783.99, 1046.5]
fan = fit(*[at((square(0.5 if i < 3 else 0.9, f)*0.5 + tri(0.5 if i < 3 else 0.9, f/2)*0.4)*env(0.5 if i < 3 else 0.9, 0.005, 0.3 if i < 3 else 0.6, 0.4, 0.15), i*0.16) for i, f in enumerate(notes)])
save('fanfare', norm(soft(lp(fan, 5000), 1.3), 0.7))

# ---- Happy Birthday chiptune loop (public-domain melody), 3/4 at 132 BPM ----------------
N = {'C4': 261.63, 'D4': 293.66, 'E4': 329.63, 'F4': 349.23, 'G4': 392.0, 'A4': 440.0, 'B4': 493.88,
     'C5': 523.25, 'D5': 587.33, 'E5': 659.25, 'F5': 698.46, 'G5': 783.99, 'C3': 130.81, 'G3': 196.0, 'F3': 174.61}
BEAT = 60.0 / 132.0
melody = [('G4', .75), ('G4', .25), ('A4', 1), ('G4', 1), ('C5', 1), ('B4', 2),
          ('G4', .75), ('G4', .25), ('A4', 1), ('G4', 1), ('D5', 1), ('C5', 2),
          ('G4', .75), ('G4', .25), ('G5', 1), ('E5', 1), ('C5', 1), ('B4', 1), ('A4', 2),
          ('F5', .75), ('F5', .25), ('E5', 1), ('C5', 1), ('D5', 1), ('C5', 2), ('R', 2)]
bass = ['C3']*4 + ['G3']*2 + ['C3'] + ['G3']*3 + ['C3']*2 + ['C3']*4 + ['F3']*3 + ['F3'] + ['C3']*2 + ['G3'] + ['C3']*4
total_beats = sum(b for _, b in melody)
song = np.zeros(int(SR * total_beats * BEAT) + 100)
pos = 0.0
for name, beats in melody:
    dur = beats * BEAT
    if name != 'R':
        f = N[name]
        tt = t(dur); vib = 1 + 0.006*np.sin(2*np.pi*5.5*tt)*np.clip(tt*4, 0, 1)
        ph = (np.cumsum(f*vib)/SR) % 1.0
        lead = np.where(ph < 0.5, 1.0, -1.0)*0.28 + np.where(((np.cumsum(f*2*vib)/SR) % 1.0) < 0.25, 1.0, -1.0)*0.08
        lead = lead*env(dur, 0.004, dur*0.5, 0.6, min(0.08, dur*0.3))
        o = int(pos*SR); song[o:o+len(lead)] += lead[:len(song)-o]
    pos += dur
for i, name in enumerate(bass[:int(total_beats)]):
    dur = BEAT
    b = tri(dur, N[name])*0.35*env(dur, 0.003, dur*0.6, 0.3, 0.05)
    o = int(i*BEAT*SR); song[o:o+len(b)] += b[:len(song)-o]
    # hat on every beat, softer off-beats
    h = hp(noise(0.05), 6000)*env(0.05, 0.0005, 0.03, 0, 0.01)*(0.12 if i % 3 == 0 else 0.06)
    song[o:o+len(h)] += h[:len(song)-o]
song = song[:int(SR*total_beats*BEAT)]
save('party_theme', norm(lp(song, 9000), 0.55))
print('done, theme %.1f s' % (total_beats*BEAT))
