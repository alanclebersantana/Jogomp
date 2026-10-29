#!/usr/bin/env python3
"""Gera o fundo de neve (assets/bg/neve.jpg) a partir do bosque: folhas e grama viram neve,
troncos esfriam, o céu fica claro de inverno."""
import numpy as np
from PIL import Image, ImageFilter
im = Image.open('assets/bg/bosque.jpg').convert('RGB')
a = np.asarray(im).astype(np.float32) / 255.0
hsv = np.asarray(im.convert('HSV')).astype(np.float32) / 255.0
h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
lum = a[..., 0] * .3 + a[..., 1] * .59 + a[..., 2] * .11
H, W = lum.shape
yy = np.repeat(np.linspace(0, 1, H)[:, None], W, axis=1)
# cores frias de base (dessaturadas)
gray = np.stack([lum, lum, lum], -1)
cool = gray * .45 + a * .55
cool[..., 2] += .05
# folhagem/grama/morros (amarelo-verde) viram neve: claro = branco, escuro = azul acinzentado
fol = ((h > .10) & (h < .48) & (s > .18)).astype(np.float32)
# topo de cada mancha fica mais branco (neve acumulada por cima)
up = np.clip(lum - np.roll(lum, 6, axis=0), 0, 1)
L3 = lum[..., None]
dark = np.array([.20, .25, .38]); mid = np.array([.58, .66, .82]); snow = np.array([.95, .97, 1.0])
t1 = np.clip((L3 - .12) / .30, 0, 1)
t2 = np.clip((L3 - .42) / .28 + up[..., None] * 3, 0, 1)
leaf = dark * (1 - t1) + mid * t1
leaf = leaf * (1 - t2) + snow * t2
out = cool * (1 - fol[..., None]) + leaf * fol[..., None]
# céu (azul claro no alto): inverno pálido
sky = ((h > .5) & (h < .65) & (v > .7) & (yy < .5)).astype(np.float32)[..., None]
skyc = np.stack([.80 + .1 * yy, .86 + .08 * yy, .95 + 0 * yy], -1)
out = out * (1 - sky) + (skyc * .7 + out * .3) * sky
out = np.clip(out * 1.04, 0, 1)
img = Image.fromarray((out * 255).astype(np.uint8))
img = img.filter(ImageFilter.SMOOTH)
img.save('assets/bg/neve.jpg', quality=88)
img.resize((W // 2, H // 2)).save('/tmp/claude-0/-home-claude/fef9574a-d26b-53bc-80f6-dbbfa5c388ae/scratchpad/neve_small.jpg')
print('ok')
