#!/usr/bin/env python3
"""Chefes do Ep. 2 com arte própria (Gemini, fundo branco):
tools/art_src/sapo_rei.jpg (2x2: tonto, nadando encolhido, nadando esticado, sugando) -> assets/sprites/sapo_rei.png (4 x 320x180)
tools/art_src/morcego_rei.jpg (5 quadros: asas em cima, meio, embaixo, mergulho, tonto) -> assets/sprites/morcego_rei.png (5 x 300x240)
Cada quadro: escala comum (a maior largura cabe no quadro), centralizado pela caixa."""
import os, subprocess, sys, tempfile
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def cut(src, dil='6'):
    tmp = tempfile.mkdtemp()
    out = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'cut_sheet.py'), src, os.path.join(tmp, 'f'), '236', dil],
                         check=True, capture_output=True, text=True).stdout
    rows = []
    for l in out.strip().splitlines():
        k, x, y, w, h = map(int, l.split())
        rows.append((x, y, w, h, k))
    ims = []
    for x, y, w, h, k in rows:
        im = Image.open(os.path.join(tmp, 'f_%d.png' % k)).convert('RGBA')
        if w * h > 20000:
            ims.append((y + h / 2, x, im.crop(im.getbbox())))
    return ims

import numpy as np
def crown(im):
    a = np.asarray(im).astype(int)
    m = (a[..., 0] > 170) & (a[..., 1] > 130) & (a[..., 2] < 110) & (a[..., 3] > 200)
    ys, xs = np.nonzero(m)
    return (xs.mean(), ys.mean()) if len(xs) > 30 else None

def sheet(ims, CW, CH, name, pad=8, anchor=None):
    k = min(min((CW - pad) / im.width, (CH - pad) / im.height) for im in ims)
    if anchor:
        k *= .78
    sh = Image.new('RGBA', (CW * len(ims), CH), (0, 0, 0, 0))
    for i, im in enumerate(ims):
        c = crown(im) if anchor else None
        if c:
            c = (c[0] * k, c[1] * k)
        im = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)
        ox, oy = (CW - im.width) // 2, (CH - im.height) // 2
        if c and i < len(ims) - 1:
            # o corpo (pela coroa) fica no mesmo lugar em todos os quadros: só as asas se mexem
            ox, oy = int(anchor[0] * CW - c[0]), int(anchor[1] * CH - c[1])
        cell = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
        cell.paste(im, (ox, oy), im)
        sh.alpha_composite(cell, (i * CW, 0))
    sh.save(os.path.join(ROOT, 'assets', 'sprites', name))
    print(name, len(ims), round(k, 3))

src = os.path.join(ROOT, 'tools', 'art_src', 'sapo_rei.jpg')
if os.path.exists(src):
    ims = cut(src)
    ims.sort(key=lambda t: (int(t[0] // 300), t[1]))   # linhas, depois colunas
    sheet([t[2] for t in ims], 320, 180, 'sapo_rei.png')
src = os.path.join(ROOT, 'tools', 'art_src', 'morcego_rei.jpg')
if os.path.exists(src):
    ims = cut(src, '3')
    ims.sort(key=lambda t: t[1])
    sheet([t[2] for t in ims], 300, 340, 'morcego_rei.png', anchor=(.55, .41))
