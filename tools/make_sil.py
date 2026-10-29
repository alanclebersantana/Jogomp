#!/usr/bin/env python3
"""Silhuetas brancas (mesmo alfa) das folhas usadas no contorno de luz e no contorno vermelho dos inimigos.
Gera <nome>_sil.png ao lado de cada folha (o jogo usa se existir, em vez de calcular no celular)."""
import os, sys
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = os.path.join(ROOT, 'assets', 'sprites')
# todas as folhas (inclusive subpastas, como tome/): qualquer uma pode sair em silhueta (clarão do golpe,
# contorno vermelho, contorno de luz) — calcular no celular trava o jogo
names = []
for dp, dn, fs in os.walk(S):
    for f in fs:
        if f.endswith('.png') and not f.endswith('_sil.png'):
            names.append(os.path.relpath(os.path.join(dp, f), S)[:-4])
for n in names:
    p = os.path.join(S, n + '.png')
    if not os.path.exists(p):
        continue
    im = Image.open(p).convert('RGBA')
    a = im.getchannel('A')
    w = Image.new('RGBA', im.size, (255, 255, 255, 0))
    w.putalpha(a)
    out = os.path.join(S, n + '_sil.png')
    if os.path.exists(out) and os.path.getmtime(out) >= os.path.getmtime(p):
        continue
    w.save(out, optimize=True)
    print('sil', n)
