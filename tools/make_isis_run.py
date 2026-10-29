#!/usr/bin/env python3
"""Corrida da Isis em 8 quadros (Gemini: tools/art_src/isis_run8.jpg, 2 linhas de 4, fundo branco) ->
assets/sprites/isis_run.png (8 quadros 150x150, mesma escala e mesma base da isis2.png)."""
import os, subprocess, sys, tempfile
import numpy as np
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
tmp = tempfile.mkdtemp()
out = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'cut_sheet.py'), os.path.join(ROOT, 'tools', 'art_src', 'isis_run8.jpg'),
                      os.path.join(tmp, 'f'), '236', '4'], check=True, capture_output=True, text=True).stdout
pos = []
for l in out.strip().splitlines():
    k, x, y, w, h = map(int, l.split())
    pos.append((y // 300, x, k))
pos.sort()
fr = [Image.open(os.path.join(tmp, 'f_%d.png' % k)).convert('RGBA') for _, _, k in pos]
fr = [im.crop(im.getbbox()) for im in fr]
ref = Image.open(os.path.join(ROOT, 'assets', 'sprites', 'isis2.png')).convert('RGBA')
# altura e centro dos quadros de corrida antigos (0-3)
hs, cxs, bots = [], [], []
for i in range(4):
    c = ref.crop((i * 150, 0, i * 150 + 150, 150))
    a = np.asarray(c)[..., 3] > 60
    ys, xs = np.nonzero(a)
    hs.append(ys.max() - ys.min()); bots.append(ys.max())
    w = np.asarray(c)[..., 3].astype(float)
    cxs.append((w.sum(axis=0) * np.arange(150)).sum() / w.sum())
H = float(np.mean(hs)); BOT = int(np.max(bots)); CX = float(np.mean(cxs))
mh = np.mean([im.height for im in fr])
K = H / mh
S = 150
sheet = Image.new('RGBA', (S * len(fr), S), (0, 0, 0, 0))
for i, im in enumerate(fr):
    im = im.resize((max(1, int(im.width * K)), max(1, int(im.height * K))), Image.LANCZOS)
    w = np.asarray(im)[..., 3].astype(float)
    cx = (w.sum(axis=0) * np.arange(im.width)).sum() / w.sum()
    c = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    c.alpha_composite(im, (int(round(CX - cx)), BOT + 1 - im.height))
    sheet.alpha_composite(c, (i * S, 0))
sheet.save(os.path.join(ROOT, 'assets', 'sprites', 'isis_run.png'))
print('ok', len(fr), round(K, 3))
