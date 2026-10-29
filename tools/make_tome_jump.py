#!/usr/bin/env python3
"""Pulo do Tomé em quadros (Gemini: tools/art_src/tome_jump8.jpg, fundo branco) ->
assets/sprites/tome/jump.png (impulso, subindo, topo), fall.png (caindo), land.png (pouso, levantando).
Mesma escala da folha de andar (Tomé em pé ~214 px num quadro de 256), pés na base, centro de massa no meio."""
import os, subprocess, sys, tempfile, re
import numpy as np
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
tmp = tempfile.mkdtemp()
out = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'cut_sheet.py'), os.path.join(ROOT, 'tools', 'art_src', 'tome_jump8.jpg'),
                      os.path.join(tmp, 'f'), '236', '3'], check=True, capture_output=True, text=True).stdout
pos = []
for l in out.strip().splitlines():
    k, x, y, w, h = map(int, l.split())
    pos.append((x, k))
pos.sort()
fr = [Image.open(os.path.join(tmp, 'f_%d.png' % k)).convert('RGBA') for _, k in pos]
fr = [im.crop(im.getbbox()) for im in fr]
# 0 agachado, 1 saindo do chão, 2 subindo encolhido, 3 topo, 4 caindo, 5 pouso, 6 em pé
S = 256
K = 214.0 / fr[6].height       # o quadro em pé fica da altura do Tomé andando
def cell(im):
    im = im.resize((max(1, int(im.width * K)), max(1, int(im.height * K))), Image.LANCZOS)
    a = np.asarray(im)[..., 3].astype(float)
    cx = (a.sum(axis=0) * np.arange(im.width)).sum() / a.sum()
    o = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    o.alpha_composite(im, (int(round(S / 2 - cx)), S - 2 - im.height))
    return o
def save(name, idx):
    sh = Image.new('RGBA', (S * len(idx), S), (0, 0, 0, 0))
    for i, j in enumerate(idx):
        sh.alpha_composite(cell(fr[j]), (i * S, 0))
    sh.save(os.path.join(ROOT, 'assets', 'sprites', 'tome', name + '.png'))
save('jump', [1, 2, 3])
save('fall', [3, 4])
save('land', [5, 0, 6])
print('ok', len(fr))
