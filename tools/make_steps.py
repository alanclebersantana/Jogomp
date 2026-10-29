"""Sons de passo sintetizados (um por tipo de chão): grama, terra, neve, madeira, pedra, lama.
Rajadas curtas de ruído filtrado com envelope; cada tipo tem 2 variações (a e b)."""
import numpy as np, wave
from scipy.signal import butter, lfilter
SR = 22050
rng = np.random.default_rng(7)

def bp(x, lo, hi):
    b, a = butter(2, [lo / (SR / 2), hi / (SR / 2)], btype='band')
    return lfilter(b, a, x)

def env(n, att, dec):
    t = np.arange(n) / SR
    e = np.minimum(1, t / att) * np.exp(-t / dec)
    return e

def save(name, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * .8
    d = (x * 32767).astype(np.int16)
    with wave.open('assets/audio/%s.wav' % name, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(d.tobytes())

def make(kind, v):
    n = int(SR * .16)
    noise = rng.standard_normal(n)
    if kind == 'grass':
        x = bp(noise, 1800, 7000) * env(n, .004, .035)
        x += .5 * bp(rng.standard_normal(n), 3000, 9000) * env(n, .02, .03) * (np.arange(n) > SR * .015)
    elif kind == 'dirt':
        x = bp(noise, 150, 1400) * env(n, .002, .03)
    elif kind == 'snow':
        # rangido: grãos rápidos
        g = (rng.random(n) < .08) * rng.standard_normal(n)
        x = bp(g, 1500, 6000) * env(n, .01, .06) + .4 * bp(noise, 300, 1200) * env(n, .002, .02)
    elif kind == 'wood':
        t = np.arange(n) / SR
        f = 210 + v * 30
        x = (np.sin(2 * np.pi * f * t) + .5 * np.sin(2 * np.pi * f * 2.7 * t)) * env(n, .001, .04)
        x += .4 * bp(noise, 800, 3000) * env(n, .001, .012)
    elif kind == 'stone':
        x = bp(noise, 1200, 5000) * env(n, .0008, .018) + .5 * bp(noise, 200, 700) * env(n, .001, .02)
    elif kind == 'mud':
        t = np.arange(n) / SR
        x = bp(noise, 200, 900) * env(n, .006, .05) * (1 + .6 * np.sin(2 * np.pi * 30 * t))
    return x

for k in ['grass', 'dirt', 'snow', 'wood', 'stone', 'mud']:
    for i, v in enumerate('ab'):
        save('step_%s_%s' % (k, v), make(k, i))
print('ok')
