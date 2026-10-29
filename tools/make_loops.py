"""Loops sintetizados: tambores de perigo (camada extra da música), fogueira estalando e riacho."""
import numpy as np, wave
from scipy.signal import butter, lfilter
SR = 22050
rng = np.random.default_rng(11)
def bp(x, lo, hi):
    b, a = butter(2, [lo / (SR / 2), hi / (SR / 2)], btype='band'); return lfilter(b, a, x)
def lp(x, hi):
    b, a = butter(2, hi / (SR / 2)); return lfilter(b, a, x)
def save(name, x, peak=.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    with wave.open('assets/audio/%s.wav' % name, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes((x * 32767).astype(np.int16).tobytes())
# tambores: 2 compassos a 104 bpm (taiko grave + caixa de mão)
bpm = 104; beat = 60 / bpm; n = int(SR * beat * 8)
t = np.arange(n) / SR
x = np.zeros(n)
def hit(at, f, dec, amp, noise=0.0):
    i = int(at * SR); m = min(n - i, int(SR * .6)); tt = np.arange(m) / SR
    s = np.sin(2 * np.pi * (f * (1 + 1.5 * np.exp(-tt * 30))) * tt) * np.exp(-tt / dec) * amp
    if noise:
        s += bp(rng.standard_normal(m), 900, 4000) * np.exp(-tt / .04) * noise
    x[i:i + m] += s
pat = [0, 1.5, 2, 3, 4, 5.5, 6, 6.5, 7, 7.5]
for b_ in pat:
    hit(b_ * beat, 62, .25, 1.0)
for b_ in [1, 3, 5, 7]:
    hit(b_ * beat, 180, .06, .35, noise=.5)
for b_ in np.arange(0, 8, .5):
    hit(b_ * beat + beat * .25, 400, .02, .08, noise=.15)
save('loop_tambores', x, .7)
# fogueira: chiado grave + estalos
n = SR * 6
x = lp(rng.standard_normal(n), 600) * .25
for k in range(140):
    i = rng.integers(0, n - 800); m = rng.integers(60, 400)
    x[i:i + m] += bp(rng.standard_normal(m), 1500, 7000) * np.exp(-np.arange(m) / (m * .3)) * rng.uniform(.4, 1.4)
x[:2000] *= np.linspace(0, 1, 2000); x[-2000:] *= np.linspace(1, 0, 2000)
x[:2000] += x[-2000:][::-1] * 0
save('loop_fogo', x, .6)
# riacho: ruído borbulhante modulado
n = SR * 6
t = np.arange(n) / SR
x = bp(rng.standard_normal(n), 300, 2500) * (.6 + .4 * np.sin(2 * np.pi * .7 * t) * np.sin(2 * np.pi * 1.9 * t))
for k in range(220):
    i = rng.integers(0, n - 1200); m = rng.integers(200, 1100); tt = np.arange(m) / SR
    f = rng.uniform(500, 1400)
    x[i:i + m] += np.sin(2 * np.pi * f * (1 + 2 * tt) * tt) * np.exp(-tt / .015) * .5
x[:3000] *= np.linspace(0, 1, 3000); x[-3000:] *= np.linspace(1, 0, 3000)
save('loop_agua', x, .5)
print('ok')
