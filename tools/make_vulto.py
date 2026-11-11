#!/usr/bin/env python3
"""Vulto de capuz (ladrão das milhas): quadros desenhados pelo Gemini (tools/art_src/vulto_*.png, fundo
branco) -> assets/sprites/vulto.png, uma tira de quadros CW x CH com a mesma linha do chão (pé mais baixo)
e a cabeça no mesmo x (a cabeça fica firme e as pernas é que se mexem).
Quadros: 0-7 corrida com a mala | 8 susto | 9 caído sentado | 10-12 corre sem a mala"""
import os, subprocess, sys, tempfile
import numpy as np
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CW, CH, BASE, HX = 280, 360, 352, 150

def pieces(src):
    tmp = tempfile.mkdtemp()
    out = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'cut_sheet.py'), src, os.path.join(tmp, 'f'), '236', '4'],
                         check=True, capture_output=True, text=True).stdout
    ps = []
    for l in out.strip().splitlines():
        k = int(l.split()[0])
        im = Image.open(os.path.join(tmp, 'f_%d.png' % k)).convert('RGBA')
        ps.append(furos(im.crop(im.getbbox())))
    return ps

def furos(p):
    """brancos fechados (entre o braço e o corpo) viram transparentes; os olhos (no alto) ficam"""
    from scipy import ndimage as nd
    a = np.asarray(p).copy()
    wh = (a[..., :3].min(axis=2) >= 228) & (a[..., 3] > 0)
    lab, n = nd.label(wh)
    for i, sl in enumerate(nd.find_objects(lab)):
        area = (lab[sl] == i + 1).sum()
        if area > 90 and sl[0].start > p.height * .22:
            m = lab == i + 1
            m = nd.binary_dilation(m, iterations=1) & (a[..., :3].min(axis=2) >= 200)
            a[m, 3] = 0
    return Image.fromarray(a, 'RGBA')


def cell(p, sc):
    if sc != 1:
        p = p.resize((round(p.width * sc), round(p.height * sc)), Image.LANCZOS)
    a = np.asarray(p)[..., 3] > 100
    ys, xs = np.where(a)
    top = ys.min()
    head = xs[ys < top + p.height * .14]
    hx = head.mean()
    c = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
    c.paste(p, (int(round(HX - hx)), BASE - (ys.max() + 1)), p)
    return c

frames = []
run = pieces(os.path.join(ROOT, 'tools', 'art_src', 'vulto_run.png'))
ref_h = np.median([p.height for p in run])
sc = 330.0 / ref_h
frames += [cell(p, sc) for p in run[:8]]
ext = os.path.join(ROOT, 'tools', 'art_src', 'vulto_extra.png')
if os.path.exists(ext):
    ex = pieces(ext)
    # folha extra: 0-2 corrida (mesma escala), 3 susto, 4 caído (5 = a mala solta, fica de fora), 6-8 sem a mala
    sc2 = 330.0 / np.median([ex[i].height for i in (0, 1, 2)])
    frames += [cell(ex[i], sc2) for i in (3, 4, 6, 7, 8)]
sheet = Image.new('RGBA', (CW * len(frames), CH), (0, 0, 0, 0))
for i, f in enumerate(frames):
    sheet.alpha_composite(f, (i * CW, 0))
sheet.save(os.path.join(ROOT, 'assets', 'sprites', 'vulto.png'))
print('vulto.png', len(frames), 'quadros')
