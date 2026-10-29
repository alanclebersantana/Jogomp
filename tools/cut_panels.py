#!/usr/bin/env python3
"""Corta uma folha 2x2 de quadrinhos (calhas brancas) em 4 quadros. Uso: cut_panels.py folha.jpg saida_prefixo"""
import sys
import numpy as np
from PIL import Image
src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert('RGB')
a = np.asarray(im).astype(int)
H, W = a.shape[:2]
white = a.min(axis=2) > 225
colw = white.mean(axis=0)
roww = white.mean(axis=1)
def gutter(prof, n):
    mid = n // 2
    best = None
    for c in range(int(n * .3), int(n * .7)):
        if prof[c] > .9:
            d = abs(c - mid)
            if best is None or d < best[0]:
                best = (d, c)
    if best is None:
        return mid, mid
    c = best[1]
    a0 = c
    while a0 > 0 and prof[a0 - 1] > .9:
        a0 -= 1
    b0 = c
    while b0 < n - 1 and prof[b0 + 1] > .9:
        b0 += 1
    return a0, b0
cx0, cx1 = gutter(colw, W)
cy0, cy1 = gutter(roww, H)
boxes = [(0, 0, cx0, cy0), (cx1 + 1, 0, W, cy0), (0, cy1 + 1, cx0, H), (cx1 + 1, cy1 + 1, W, H)]
for i, (x0, y0, x1, y1) in enumerate(boxes):
    p = a[y0:y1, x0:x1]
    nw = ~(p.min(axis=2) > 225)
    ys = np.nonzero(nw.any(axis=1))[0]
    xs = np.nonzero(nw.any(axis=0))[0]
    crop = im.crop((x0 + xs[0], y0 + ys[0], x0 + xs[-1] + 1, y0 + ys[-1] + 1))
    crop = crop.resize((512, int(512 * crop.height / crop.width)), Image.LANCZOS)
    crop.save('%s_%d.jpg' % (out, i), quality=88)
    print(i, crop.size)
