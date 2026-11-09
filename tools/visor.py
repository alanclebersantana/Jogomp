#!/usr/bin/env python3
"""Acha o visor preto do Milis em cada quadro das folhas (tome/*.png, pai.png, pai2.png) e grava
assets/data/visor.json: {folha: [[u, v, w, h] normalizados no quadro, ...]} — o jogo desenha as
expressões (olhos de LED) por cima do visor."""
import os, json
import numpy as np
from PIL import Image
from scipy import ndimage
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = os.path.join(ROOT, 'assets', 'sprites')
out = {}
def frames(path, fw, fh):
    im = np.array(Image.open(path).convert('RGBA')).astype(int)
    n = im.shape[1] // fw
    res = []
    for i in range(n):
        f = im[:fh, i * fw:(i + 1) * fw]
        lum = f[..., 0] * .3 + f[..., 1] * .59 + f[..., 2] * .11
        dark = (f[..., 3] > 200) & (lum < 40)
        # o visor fica na metade de cima do desenho
        ys = np.where(f[..., 3] > 100)[0]
        if len(ys) == 0:
            res.append(None); continue
        top, bot = ys.min(), ys.max()
        dark[int(top + (bot - top) * .5):, :] = False
        # tira os traços finos do contorno (que ligam o visor ao capacete) e fecha os olhos acesos
        er = max(2, fw // 64)
        dark = ndimage.binary_fill_holes(ndimage.binary_closing(dark, iterations=2))
        dark = ndimage.binary_erosion(dark, iterations=er)
        lab, k = ndimage.label(dark)
        if k == 0:
            res.append(None); continue
        sizes = ndimage.sum(dark, lab, range(1, k + 1))
        j = int(np.argmax(sizes)) + 1
        if sizes[j - 1] < fw * fh * .004:
            res.append(None); continue
        comp = ndimage.binary_dilation(lab == j, iterations=er)
        yy, xx = np.where(comp)
        bw, bh = (xx.max() - xx.min() + 1) / fw, (yy.max() - yy.min() + 1) / fh
        if bw > .32 or bh > .28:
            res.append(None); continue   # o braço levantado encostou no visor: sem expressão nesse quadro
        res.append([round(xx.min() / fw, 4), round(yy.min() / fh, 4), round((xx.max() - xx.min() + 1) / fw, 4), round((yy.max() - yy.min() + 1) / fh, 4)])
    return res
for f in sorted(os.listdir(os.path.join(S, 'tome'))):
    if f.endswith('.png') and not f.endswith('_sil.png'):
        p = os.path.join(S, 'tome', f)
        h = Image.open(p).height
        out['tome/' + f[:-4]] = frames(p, h, h)
for n in ['pai', 'pai2']:
    out[n] = frames(os.path.join(S, n + '.png'), 170, 160)
json.dump(out, open(os.path.join(ROOT, 'assets', 'data', 'visor.json'), 'w'))
for k, v in out.items():
    print(k, sum(1 for x in v if x), '/', len(v), v[0])
