#!/usr/bin/env python3
"""Inimigos animados (Gemini, tools/art_src/inimigos.jpg, fundo branco): javali andando (6),
sapo (respira, infla, pisca, agacha, pulo) e corvo batendo asas (4)."""
import os, subprocess, sys, tempfile
import numpy as np
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
tmp = tempfile.mkdtemp()
subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'cut_sheet.py'), os.path.join(ROOT, 'tools', 'art_src', 'inimigos.jpg'),
                os.path.join(tmp, 'f'), '236', '3'], check=True, capture_output=True)
fr = []
k = 0
while os.path.exists(os.path.join(tmp, 'f_%d.png' % k)):
    im = Image.open(os.path.join(tmp, 'f_%d.png' % k)).convert('RGBA')
    fr.append(im.crop(im.getbbox()))
    k += 1
assert len(fr) == 15, len(fr)
def sheet(name, frames, cw, ch, sc, bottom=None):
    S = Image.new('RGBA', (cw * len(frames), ch), (0, 0, 0, 0))
    for i, im in enumerate(frames):
        im = im.resize((max(1, int(im.width * sc)), max(1, int(im.height * sc))), Image.LANCZOS)
        a = np.asarray(im)[..., 3].astype(float)
        cx = (a.sum(axis=0) * np.arange(im.width)).sum() / a.sum()
        x = int(round(cw / 2 - cx))
        y = (bottom - im.height) if bottom is not None else int((ch - im.height) / 2)
        S.alpha_composite(im, (i * cw + x, y)) if x >= 0 else S.alpha_composite(im.crop((-x, 0, im.width, im.height)), (i * cw, y))
    S.save(os.path.join(ROOT, 'assets', 'sprites', name + '.png'))
boar_h = np.mean([f.height for f in fr[0:6]])
sheet('en_boar', fr[0:6], 210, 140, 121.0 / boar_h, bottom=136)
sheet('en_frog2', fr[6:11], 130, 70, 50.0 / np.mean([f.height for f in fr[6:9]]), bottom=68)
sheet('en_crow2', fr[11:15], 170, 130, 150.0 / fr[12].width)
print('ok')
