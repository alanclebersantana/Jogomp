#!/usr/bin/env python3
"""Ícone do app (Milis comemorando sobre o amarelo da Milhas Plus).
Gera assets/ui/icon_bg.png, assets/ui/icon_fg.png (ícone adaptativo do Android, 432x432) e icon.png."""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = Image.open(os.path.join(ROOT, 'art_src/gemini/milis_poses_a.jpg')).convert('RGB').crop((480, 0, 740, 400))
a = np.asarray(src).astype(np.float32)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
ver = g - np.maximum(r, b)
# fundo = verde forte ligado à borda (o moletom verde-escuro fica)
bgm = (ver > 55) & (g > 120)
lab, n = ndimage.label(bgm)
edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
bgm = np.isin(lab, list(edge))
fgm = ~ndimage.binary_dilation(bgm, iterations=1)
lab2, n2 = ndimage.label(fgm)
sz = ndimage.sum(fgm, lab2, range(1, n2 + 1))
fgm = lab2 == (np.argmax(sz) + 1)
fgm = ndimage.binary_fill_holes(fgm)
alpha = Image.fromarray((fgm * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(.8))
# borda sem reflexo verde
a[..., 1] = np.where(ver > 0, np.maximum(r, b) + np.clip(ver, 0, 8), g)
im = Image.fromarray(a.astype(np.uint8)).convert('RGBA')
im.putalpha(alpha)
im = im.crop(im.getbbox())
S = 432
# fundo amarelo com brilho no alto
yy, xx = np.mgrid[0:S, 0:S]
d = np.clip(np.sqrt((xx - S * .5) ** 2 + (yy - S * .3) ** 2) / (S * .8), 0, 1)[..., None]
rgb = (np.array([255, 216, 70]) * (1 - d) + np.array([242, 162, 12]) * d).astype(np.uint8)
bg = Image.fromarray(np.dstack([rgb, np.full((S, S), 255, np.uint8)]))
# raios suaves atrás dele
ray = Image.new('RGBA', (S, S), (0, 0, 0, 0))
dr = ImageDraw.Draw(ray)
import math
for k in range(12):
    a0 = k * 30
    p = [(S / 2, S * .42)]
    for aa in (a0 - 7, a0 + 7):
        p.append((S / 2 + math.cos(math.radians(aa)) * S, S * .42 + math.sin(math.radians(aa)) * S))
    dr.polygon(p, fill=(255, 245, 190, 46))
bg.alpha_composite(ray)
bg.save(os.path.join(ROOT, 'assets/ui/icon_bg.png'))
# frente: busto grande, cortado pela borda de baixo (zona segura do ícone redondo)
w = 305
h = int(im.height * w / im.width)
big = im.resize((w, h), Image.LANCZOS)
top = 72
fg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
sh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
sh.paste(Image.new('RGBA', big.size, (120, 64, 0, 255)), ((S - w) // 2 + 7, top + 8), big.getchannel('A').point(lambda v: int(v * .4)))
fg.alpha_composite(sh.filter(ImageFilter.GaussianBlur(7)))
fg.alpha_composite(big, ((S - w) // 2, top))
fg = fg.crop((0, 0, S, S))
fg.save(os.path.join(ROOT, 'assets/ui/icon_fg.png'))
full = bg.copy()
full.alpha_composite(fg)
mask = Image.new('L', (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, S - 1, S - 1), radius=96, fill=255)
out = Image.new('RGBA', (S, S), (0, 0, 0, 0))
out.paste(full, (0, 0), mask)
out.resize((256, 256), Image.LANCZOS).save(os.path.join(ROOT, 'icon.png'))
prev = Image.new('RGBA', (S * 2 + 20, S), (255, 255, 255, 255))
prev.alpha_composite(out)
cm = Image.new('L', (S, S), 0)
ImageDraw.Draw(cm).ellipse((0, 0, S - 1, S - 1), fill=255)
circ = Image.new('RGBA', (S, S), (0, 0, 0, 0))
circ.paste(full, (0, 0), cm)
prev.alpha_composite(circ, (S + 20, 0))
prev.save('/tmp/icon_prev.png')
