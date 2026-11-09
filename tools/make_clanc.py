#!/usr/bin/env python3
"""Sons do falso segurança: 'clanc' (golpe no escudo de acrílico/metal) e 'escudo_voa' (o escudo arrancado)."""
import numpy as np, wave, os
SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")

def salva(nome, x):
    x = x / max(1e-6, np.max(np.abs(x))) * .85
    with wave.open(os.path.join(OUT, nome + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())

rng = np.random.default_rng(3)
t = np.arange(int(SR * .45)) / SR
# parciais inarmônicos (placa batida) com decaimentos diferentes + estalo de ruído no começo
x = np.zeros_like(t)
for f, a, d in [(620, 1, 9), (1490, .7, 14), (2310, .5, 18), (3170, .35, 24), (905, .5, 11)]:
    x += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) * np.exp(-d * t)
clk = rng.normal(0, 1, len(t)) * np.exp(-90 * t) * .9
low = np.sin(2 * np.pi * 140 * t) * np.exp(-30 * t) * .8   # baque do corpo
salva("clanc", x + clk + low)
# escudo voando: ruído filtrado subindo (whoosh) + um clanc menor
t2 = np.arange(int(SR * .6)) / SR
n = rng.normal(0, 1, len(t2))
k = np.exp(-((t2 - .18) / .12) ** 2)
wh = np.convolve(n, np.ones(9) / 9, "same") * k
x2 = np.zeros_like(t2)
for f, a, d in [(700, 1, 10), (1650, .6, 16), (2500, .4, 22)]:
    x2 += a * np.sin(2 * np.pi * f * t2) * np.exp(-d * t2)
salva("escudo_voa", wh * 1.2 + x2 * .6)
print("ok")
