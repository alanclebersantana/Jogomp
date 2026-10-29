#!/usr/bin/env python3
"""Monta as folhas de sprites a partir das artes geradas no Gemini (tools/art_src/*.jpg, fundo branco).
Uso: python3 tools/make_gemini_art.py   (gera assets/sprites/cavalo.png, bagre.png, esquilo.png e
assets/data/art_meta.json com âncoras usadas pelo jogo)."""
import json, os, subprocess, sys, tempfile
import numpy as np
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'tools', 'art_src')
OUT = os.path.join(ROOT, 'assets', 'sprites')
meta = {}

def cut(name, dil=12):
    tmp = tempfile.mkdtemp()
    subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'cut_sheet.py'), os.path.join(SRC, name + '.jpg'),
                    os.path.join(tmp, 'f'), '236', str(dil)], check=True, capture_output=True)
    fr = []
    k = 0
    while os.path.exists(os.path.join(tmp, 'f_%d.png' % k)):
        fr.append(Image.open(os.path.join(tmp, 'f_%d.png' % k)).convert('RGBA'))
        k += 1
    return fr

def sheet(frames, cw, ch, place):
    """place(i, im) -> (x, y) canto do quadro dentro da célula"""
    S = Image.new('RGBA', (cw * len(frames), ch), (0, 0, 0, 0))
    for i, im in enumerate(frames):
        x, y = place(i, im)
        cell = Image.new('RGBA', (cw, ch), (0, 0, 0, 0))
        cell.alpha_composite(im, (int(round(x)), int(round(y))))
        S.alpha_composite(cell, (i * cw, 0))
    return S

# ---------- cavalo: galope (4), pulo, parado ----------
h = cut('cavalo')
# galope novo em 6 quadros (galope.jpg, 2 colunas x 3 linhas, na ordem de leitura) + pulo e parado do cavalo.jpg
gl = cut('galope')
sc = .5
def rs(im, k):
    return im.resize((int(im.width * k), int(im.height * k)), Image.LANCZOS)
# o galope novo foi desenhado maior: iguala a altura média ao cavalo antigo
hk = np.mean([h[i].width for i in [1, 0, 4, 3]]) / np.mean([im.width for im in gl])
frames = [rs(im, sc * hk) for im in gl] + [rs(h[i], sc * 1.12) for i in [5, 6]]
CW, CH = 240, 170
SX, BOT = 112, 166
seats = []
def saddle(im):
    a = np.asarray(im).astype(int)
    red = (a[..., 3] > 200) & (a[..., 0] > 140) & (a[..., 1] < 90) & (a[..., 2] < 80) & (a[..., 0] - a[..., 1] > 70)
    ys, xs = np.nonzero(red)
    return float(np.median(xs)), float(np.percentile(ys, 5))
def place_h(i, im):
    sx, sy = saddle(im)
    x = SX - sx
    y = BOT - im.height
    seats.append([SX, round(y + sy - 6, 1)])
    return x, y
S = sheet(frames, CW, CH, place_h)
S.save(os.path.join(OUT, 'cavalo.png'))
meta['cavalo'] = {'w': CW, 'h': CH, 'n': len(frames), 'ax': SX, 'ay': BOT, 'seat': seats}

# ---------- Bagre-Rei: nado (4), boca aberta, tonto, derrotado ----------
b = cut('bagre', 6)
order = [0, 1, 2, 3, 4, 5, 7]
sc = .6
from scipy import ndimage as nd
def no_blue(im):
    # as escamas azuis do desenho saem (o jogo desenha os pontos fracos por cima, no lugar certo)
    a = np.asarray(im).copy()
    r, g, bb, al = [a[..., k].astype(int) for k in range(4)]
    m = (al > 0) & (bb > r + 25) & (bb > 120)
    m = nd.binary_dilation(m, iterations=3) & (al > 200)
    if m.any():
        idx = nd.distance_transform_edt(m, return_distances=False, return_indices=True)
        for k in range(3):
            ch = a[..., k]
            ch[m] = ch[idx[0][m], idx[1][m]]
    return Image.fromarray(a, 'RGBA')
frames = [(b[i]).resize((int(b[i].width * sc), int(b[i].height * sc)), Image.LANCZOS) for i in order]
CW, CH = 280, 160
S = sheet(frames, CW, CH, lambda i, im: ((CW - im.width) / 2, (CH - im.height) / 2))
S.save(os.path.join(OUT, 'bagre.png'))
meta['bagre'] = {'w': CW, 'h': CH, 'n': len(frames)}

# ---------- Urso-Pardo-Rei: andando (2), em pé, patada, tonto, derrotado (todos olhando para a direita) ----------
u = cut('urso', 4)
from PIL import ImageOps
order = [(0, False), (1, True), (2, False), (3, True), (4, False), (5, True)]
sc = .55
frames = []
for i, fl in order:
    im = ImageOps.mirror(u[i]) if fl else u[i]
    frames.append(im.resize((int(im.width * sc), int(im.height * sc)), Image.LANCZOS))
CW, CH = 280, 230
S = sheet(frames, CW, CH, lambda i, im: ((CW - im.width) / 2, CH - 2 - im.height))
S.save(os.path.join(OUT, 'urso.png'))
meta['urso'] = {'w': CW, 'h': CH, 'n': len(frames)}

json.dump(meta, open(os.path.join(ROOT, 'assets', 'data', 'art_meta.json'), 'w'), indent=1)
print(json.dumps(meta))

# ---------- fundo da neve: emenda as bordas para repetir sem costura ----------
bg = np.asarray(Image.open(os.path.join(SRC, 'neve.jpg')).convert('RGB')).astype(np.float32)
Bw = 80
W = bg.shape[1]
out = bg[:, :W - Bw].copy()
for x in range(Bw):
    t = x / (Bw - 1)
    out[:, x] = bg[:, W - Bw + x] * (1 - t) + bg[:, x] * t
Image.fromarray(out.clip(0, 255).astype(np.uint8)).resize((1792, 592), Image.LANCZOS).save(
    os.path.join(ROOT, 'assets', 'bg', 'neve.jpg'), quality=88)

# ---------- esquilo: corrida (4), bote, nocauteado ----------
e = cut('esquilo', 8)
sc = .3
frames = [im.resize((int(im.width * sc), int(im.height * sc)), Image.LANCZOS) for im in e]
CW, CH = 130, 110
S = sheet(frames, CW, CH, lambda i, im: ((CW - im.width) / 2, CH - 2 - im.height))
S.save(os.path.join(OUT, 'esquilo.png'))
meta['esquilo'] = {'w': CW, 'h': CH, 'n': len(frames)}

# ---------- objetos da neve: um PNG por objeto ----------
names = ['pinheiro', 'arvore_neve', 'tora_neve', 'pedra_neve', 'galho_neve', 'boneco', 'gorro', 'capacete', 'bola_neve']
pr = cut('neve_props', 8)
meta['props'] = {}
for n, im in zip(names, pr):
    k = 220.0 / max(im.width, im.height)
    im2 = im.resize((int(im.width * k), int(im.height * k)), Image.LANCZOS) if k < 1 else im
    im2.save(os.path.join(OUT, 'p_' + n + '.png'))
    meta['props'][n] = [im2.width, im2.height]

json.dump(meta, open(os.path.join(ROOT, 'assets', 'data', 'art_meta.json'), 'w'), indent=1)
print(json.dumps(meta))

# ---------- biplano: parado (vazio) e voando com o Tomé; a folha vem com o nariz para a esquerda ----------
from PIL import ImageOps
from scipy import ndimage as nd
bp = cut('biplano', 8)
for i, (n, keep) in enumerate([('biplano', None), ('biplano_voo', (360, 480, 60, 220))]):
    a = np.asarray(bp[i]).astype(np.float32)
    w = (a[..., :3].min(axis=2) >= 236) & (a[..., 3] > 0)
    lab, _ = nd.label(w)
    kill = np.zeros(w.shape, bool)
    for j, sl in enumerate(nd.find_objects(lab)):
        x0, y0 = sl[1].start, sl[0].start
        # vãos brancos entre as asas e as rodas viram transparentes (a barba do Tomé fica)
        if (lab[sl] == j + 1).sum() > 120 and not (keep and keep[0] < x0 < keep[1] and keep[2] < y0 < keep[3]):
            kill |= lab == j + 1
    kill = nd.binary_dilation(kill, iterations=1)
    a[..., 3] *= np.clip(nd.distance_transform_edt(~kill) / 1.5, 0, 1)
    im = ImageOps.mirror(Image.fromarray(a.clip(0, 255).astype(np.uint8)))
    im = im.resize((360, int(im.height * 360 / im.width)), Image.LANCZOS)
    im.save(os.path.join(OUT, 'p_' + n + '.png'))
    meta['props'][n] = [im.width, im.height]
json.dump(meta, open(os.path.join(ROOT, 'assets', 'data', 'art_meta.json'), 'w'), indent=1)
