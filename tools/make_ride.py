#!/usr/bin/env python3
"""Monta as folhas da cavalgada com quadros do mesmo tamanho, alinhados pelo chão (cascos)
e pelo meio do corpo do cavalo: assets/sprites/ride_gallop.png (8), horse_free.png (4), ride_jump.png (4)."""
import os, numpy as np
from PIL import Image
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = os.path.join(R, 'art_src', 'ride')
CW, CH, BASE, MIDX = 260, 250, 244, 130

def torso_cx(im):
    a = np.asarray(im)[..., 3] > 40
    h = a.shape[0]
    band = a[int(h * .45):int(h * .7)]
    xs = np.where(band.any(axis=0))[0]
    cols = band.sum(axis=0)
    return float((cols * np.arange(len(cols))).sum() / max(1, cols.sum()))

def holes(im):
    # buracos brancos grandes presos entre as patas e o arame viram transparentes
    from scipy import ndimage as nd
    a = np.asarray(im).copy()
    w = (a[..., :3].min(axis=2) >= 238) & (a[..., 3] > 0)
    lab, n = nd.label(w)
    for i in range(1, n + 1):
        m = lab == i
        if m.sum() > 250:
            a[m, 3] = 0
    return Image.fromarray(a, 'RGBA')

def cell(im, sc=1.0):
    im = holes(im)
    im = im.crop(im.getbbox())
    if sc != 1.0:
        im = im.resize((round(im.width * sc), round(im.height * sc)), Image.LANCZOS)
    c = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
    cx = torso_cx(im)
    c.alpha_composite(im, (int(round(MIDX - cx)), BASE - im.height))
    return c

def strip(cells, name):
    out = Image.new('RGBA', (CW * len(cells), CH), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        out.alpha_composite(c, (i * CW, 0))
    out.save(os.path.join(R, 'assets', 'sprites', name))
    print(name, out.size)

raw = Image.open(os.path.join(A, 'ride_gallop_raw.png')).convert('RGBA')
fw = raw.width / 8
gal = [cell(raw.crop((round(i * fw), 0, round((i + 1) * fw), raw.height))) for i in range(8)]
strip(gal, 'ride_gallop.png')
gw = np.mean([Image.open(os.path.join(A, 'ride_gallop_raw.png')).crop((round(i * fw), 0, round((i + 1) * fw), raw.height)).getbbox()[2] for i in range(1)])
free = [Image.open(os.path.join(A, 'h_%d.png' % k)).convert('RGBA') for k in range(4)]
sc = 236.0 / free[3].crop(free[3].getbbox()).width
strip([cell(f, sc) for f in free], 'horse_free.png')
jp = os.path.join(A, 'jump_0.png')
if os.path.exists(jp):
    js = [Image.open(os.path.join(A, 'jump_%d.png' % k)).convert('RGBA') for k in range(4)]
    sc2 = 236.0 / js[1].crop(js[1].getbbox()).width
    strip([cell(j, sc2) for j in js], 'ride_jump.png')
