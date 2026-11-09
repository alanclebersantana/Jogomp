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
    # alfa em degrau: as bordas meio transparentes (borrão da hélice, franja do recorte) não viram
    # manchas no contorno vermelho — o traço fica fino e limpo em volta do desenho
    a = im.getchannel('A').point(lambda v: 255 if v >= 110 else 0)
    w = Image.new('RGBA', im.size, (255, 255, 255, 0))
    w.putalpha(a)
    out = os.path.join(S, n + '_sil.png')
    if os.path.exists(out) and os.path.getmtime(out) >= os.path.getmtime(p):
        continue
    w.save(out, optimize=True)
    print('sil', n)
