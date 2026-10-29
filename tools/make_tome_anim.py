#!/usr/bin/env python3
"""Folhas novas do Tomé (geradas no Gemini, tools/art_src/tome_mov.jpg, fundo branco) ->
assets/sprites/tome/run.png (8), jump.png, fall.png, land.png — quadros quadrados de 256 px,
pés na base, centralizados pelo centro de massa do desenho (sem tremer entre quadros)."""
import os, subprocess, sys, tempfile
import numpy as np
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
tmp = tempfile.mkdtemp()
subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'cut_sheet.py'), os.path.join(ROOT, 'tools', 'art_src', 'tome_mov.jpg'),
                os.path.join(tmp, 'f'), '236', '8'], check=True, capture_output=True)
fr = []
k = 0
while os.path.exists(os.path.join(tmp, 'f_%d.png' % k)):
    fr.append(Image.open(os.path.join(tmp, 'f_%d.png' % k)).convert('RGBA'))
    k += 1
S = 256
C = .945            # escala comum (corrida ~64 px de altura na tela, como o Tomé parado)
def cell(im):
    im = im.crop(im.getbbox())
    im = im.resize((int(im.width * C), int(im.height * C)), Image.LANCZOS)
    a = np.asarray(im)[..., 3].astype(float)
    cx = (a.sum(axis=0) * np.arange(im.width)).sum() / a.sum()
    out = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    out.alpha_composite(im, (int(round(S / 2 - cx)), S - 2 - im.height))
    return out
def save(name, idx):
    sh = Image.new('RGBA', (S * len(idx), S), (0, 0, 0, 0))
    for i, j in enumerate(idx):
        sh.alpha_composite(cell(fr[j]), (i * S, 0))
    os.makedirs(os.path.join(ROOT, 'assets', 'sprites', 'tome'), exist_ok=True)
    sh.save(os.path.join(ROOT, 'assets', 'sprites', 'tome', name + '.png'))
# corrida refeita (tome_run2.jpg): pernas alternando; cada quadro com a mesma altura
tmp2 = tempfile.mkdtemp()
subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'cut_sheet.py'), os.path.join(ROOT, 'tools', 'art_src', 'tome_run3.jpg'),
                os.path.join(tmp2, 'f'), '236', '3'], check=True, capture_output=True)
run = []
k = 0
while os.path.exists(os.path.join(tmp2, 'f_%d.png' % k)):
    im = Image.open(os.path.join(tmp2, 'f_%d.png' % k)).convert('RGBA')
    im = im.crop(im.getbbox())
    kk = 210.0 / C / im.height
    run.append(im.resize((int(im.width * kk), int(im.height * kk)), Image.LANCZOS))
    k += 1
sh = Image.new('RGBA', (S * len(run), S), (0, 0, 0, 0))
for i, im in enumerate(run):
    sh.alpha_composite(cell(im), (i * S, 0))
sh.save(os.path.join(ROOT, 'assets', 'sprites', 'tome', 'run.png'))
save('jump', [13])
save('fall', [14])
save('land', [15])
print('ok', len(fr))

# poses de reação (tome_poses.jpg): olhar para cima, cobrir a cabeça na chuva, tremer de frio,
# erguer a lanterna e cansado
tmp3 = tempfile.mkdtemp()
subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'cut_sheet.py'), os.path.join(ROOT, 'tools', 'art_src', 'tome_poses.jpg'),
                os.path.join(tmp3, 'f'), '236', '3'], check=True, capture_output=True)
ps = []
k = 0
while os.path.exists(os.path.join(tmp3, 'f_%d.png' % k)):
    ps.append(Image.open(os.path.join(tmp3, 'f_%d.png' % k)).convert('RGBA'))
    k += 1
def save_list(name, idx, hgt):
    sh = Image.new('RGBA', (S * len(idx), S), (0, 0, 0, 0))
    for i, j in enumerate(idx):
        im = ps[j].crop(ps[j].getbbox())
        kk = hgt / C / im.height
        im = im.resize((int(im.width * kk), int(im.height * kk)), Image.LANCZOS)
        sh.alpha_composite(cell(im), (i * S, 0))
    sh.save(os.path.join(ROOT, 'assets', 'sprites', 'tome', name + '.png'))
save_list('look', [0], 218)
save_list('rain', [1], 214)
save_list('shiver', [2, 3, 4], 214)
save_list('lantern', [6, 7], 236)
save_list('tired', [8], 200)
print('poses ok', len(ps))

# caminhada calma (tome_walk.jpg): 8 quadros, mesma altura
tmp4 = tempfile.mkdtemp()
subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'cut_sheet.py'), os.path.join(ROOT, 'tools', 'art_src', 'tome_walk.jpg'),
                os.path.join(tmp4, 'f'), '236', '3'], check=True, capture_output=True)
wk = []
k = 0
while os.path.exists(os.path.join(tmp4, 'f_%d.png' % k)):
    im = Image.open(os.path.join(tmp4, 'f_%d.png' % k)).convert('RGBA')
    im = im.crop(im.getbbox())
    kk = 216.0 / C / im.height
    wk.append(im.resize((int(im.width * kk), int(im.height * kk)), Image.LANCZOS))
    k += 1
sh = Image.new('RGBA', (S * len(wk), S), (0, 0, 0, 0))
for i, im in enumerate(wk):
    sh.alpha_composite(cell(im), (i * S, 0))
sh.save(os.path.join(ROOT, 'assets', 'sprites', 'tome', 'walk.png'))
print('walk ok', len(wk))
