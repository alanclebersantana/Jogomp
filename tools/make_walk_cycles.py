#!/usr/bin/env python3
"""Ciclos de andar completos (Gemini, fundo branco) para personagens de folha antiga:
assets/sprites/<nome>_walk.png com os mesmos quadros (cw x ch), mesma escala, mesma linha do chão e o mesmo
centro dos quadros de andar antigos (0-3) — o jogo usa automaticamente (Spr.sheet_cycle)."""
import os, subprocess, sys, tempfile
import numpy as np
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JOBS = [
    # nome, folha antiga, cw, ch, fonte, ordem dos recortes (linha, coluna) a usar
    ('vigia', 220, 200, 'vigia_walk.jpg', [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4), (1, 0), (1, 1), (1, 2)]),
    ('cao', 200, 150, 'cao_run.jpg', None),
]

def pieces(src):
    tmp = tempfile.mkdtemp()
    out = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'cut_sheet.py'), src, os.path.join(tmp, 'f'), '236', '4'],
                         check=True, capture_output=True, text=True).stdout
    ps = []
    for l in out.strip().splitlines():
        k, x, y, w, h = map(int, l.split())
        im = Image.open(os.path.join(tmp, 'f_%d.png' % k)).convert('RGBA')
        ps.append((y + h / 2, x, w, im.crop(im.getbbox())))
    # linhas
    ps.sort(key=lambda t: t[0])
    rows = []
    for p in ps:
        if rows and abs(p[0] - rows[-1][0][0]) < 150:
            rows[-1].append(p)
        else:
            rows.append([p])
    return [sorted(r, key=lambda t: t[1]) for r in rows]

for name, cw, ch, srcn, order in JOBS:
    src = os.path.join(ROOT, 'tools', 'art_src', srcn)
    if not os.path.exists(src):
        continue
    rows = pieces(src)
    medw = np.median([p[2] for r in rows for p in r])
    # tira recortes grudados (duas figuras juntas)
    rows = [[p for p in r if p[2] < medw * 1.45] for r in rows]
    if order:
        fr = [rows[a][b][3] for a, b in order]
    else:
        fr = [p[3] for r in rows for p in r]
    old = Image.open(os.path.join(ROOT, 'assets', 'sprites', name + '.png')).convert('RGBA')
    hs, cxs, bots = [], [], []
    for i in range(4):
        c = np.asarray(old.crop((i * cw, 0, i * cw + cw, ch)))[..., 3].astype(float)
        ys, xs = np.nonzero(c > 60)
        hs.append(ys.max() - ys.min()); bots.append(ys.max())
        cxs.append((c.sum(axis=0) * np.arange(cw)).sum() / c.sum())
    H, BOT, CX = np.mean(hs), int(np.max(bots)), np.mean(cxs)
    K = H / np.mean([im.height for im in fr])
    sh = Image.new('RGBA', (cw * len(fr), ch), (0, 0, 0, 0))
    for i, im in enumerate(fr):
        im = im.resize((max(1, int(im.width * K)), max(1, int(im.height * K))), Image.LANCZOS)
        a = np.asarray(im)[..., 3].astype(float)
        cx = (a.sum(axis=0) * np.arange(im.width)).sum() / a.sum()
        cell = Image.new('RGBA', (cw, ch), (0, 0, 0, 0))
        cell.paste(im, (int(round(CX - cx)), BOT + 1 - im.height), im)
        sh.alpha_composite(cell, (i * cw, 0))
    sh.save(os.path.join(ROOT, 'assets', 'sprites', name + '_walk.png'))
    print(name, len(fr), round(K, 3))
