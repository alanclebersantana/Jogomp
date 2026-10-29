#!/usr/bin/env python3
"""Recorta poses de uma folha com fundo branco: remove o branco ligado à borda (mantém brancos internos),
separa as poses por componentes conectados e salva PNGs com alfa, ordenadas por linha/coluna."""
import sys, numpy as np
from PIL import Image
from scipy import ndimage as nd
src, outp = sys.argv[1], sys.argv[2]
thr = int(sys.argv[3]) if len(sys.argv) > 3 else 236
dil = int(sys.argv[4]) if len(sys.argv) > 4 else 12
im = Image.open(src).convert('RGB')
a = np.asarray(im).astype(np.int16)
white = (a.min(axis=2) >= thr)
# fundo = branco conectado à borda
lab, n = nd.label(white)
border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
bg = np.isin(lab, list(border))
fg = ~bg
fg = nd.binary_opening(fg, iterations=1)
# alfa suave na borda: pixels quase brancos perto do fundo ficam semitransparentes
dist = nd.distance_transform_edt(fg)
alpha = np.clip(dist / 1.5, 0, 1)
# junta partes próximas da mesma pose
grp, m = nd.label(nd.binary_dilation(fg, iterations=dil))
objs = nd.find_objects(grp)
boxes = []
for i, sl in enumerate(objs):
    area = (grp[sl] == i + 1).sum()
    if area < 3000:
        continue
    boxes.append((sl[0].start, sl[1].start, sl[0].stop, sl[1].stop, i + 1))
# ordena por linha (centro y em faixas) e depois x
boxes.sort(key=lambda b: (b[0] + b[2]) / 2)
rows = []
for b in boxes:
    cy = (b[0] + b[2]) / 2
    if rows and abs(cy - rows[-1][0]) < 120:
        rows[-1][1].append(b)
    else:
        rows.append([cy, [b]])
boxes = [b for r in rows for b in sorted(r[1], key=lambda b: b[1])]
rgba = np.dstack([a.astype(np.uint8), (alpha * 255 * fg).astype(np.uint8)])
for k, (y0, x0, y1, x1, gi) in enumerate(boxes):
    mask = (grp[y0:y1, x0:x1] == gi)
    piece = rgba[y0:y1, x0:x1].copy()
    piece[..., 3] = piece[..., 3] * mask
    Image.fromarray(piece, 'RGBA').save(f'{outp}_{k}.png')
    print(k, x0, y0, x1 - x0, y1 - y0)
