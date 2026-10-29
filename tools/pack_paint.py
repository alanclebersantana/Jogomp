#!/usr/bin/env python3
"""Junta as artes pintadas (art_src/paint/*.png) num atlas: assets/sprites/paint1.png (+paint2...)
e assets/data/paint.json  {nome: [x, y, w, h, ax, ay, pagina]}  (âncora = centro da base).
Cada peça é reduzida para o tamanho máximo da sua família (o celular desenha em ~2x)."""
import glob, json, os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'art_src', 'paint')
MAXS = [
    ('grass', 96), ('fl_', 80), ('cat_', 200), ('mush', 110), ('mossrock', 140), ('peb', 64),
    ('wb', 150), ('rock', 190), ('slab', 220), ('plate', 150), ('burrow', 260),
    ('crate', 128), ('log', 260), ('ladder', 150), ('rope', 150), ('vine', 150), ('gate', 260),
    ('stake', 150), ('lever', 128), ('seesaw_plank', 300), ('seesaw_rock', 120),
    ('tuc', 128), ('goose', 72), ('rab', 96), ('bfly', 48), ('frog', 72), ('owl', 96), ('bird', 64),
    ('spider', 120), ('logend', 110), ('hive', 130), ('bee', 40), ('web', 200), ('sign', 120), ('apple', 48), ('icicle', 90), ('alga', 170), ('boat', 300), ('raft', 320), ('moinho_pas', 900), ('moinho', 620), ('casa', 520), ('it_', 72), ('relic_', 64), ('clb_', 220), ('cl_', 64), ('bolt', 160), ('crankpost', 220), ('crankarm', 220), ('snowpile', 300), ('sledp', 260), ('windsock', 200), ('icecube', 200), ('stormcloud', 360), ('birdp', 120), ('hawkp', 200), ('fenda', 400), ('signup', 200), ('signdown', 200), ('flagred', 160), ('galhoneve2', 360), ('galhorio', 380), ('plant', 240), ('logroll', 220), ('stoneball', 200), ('plank', 160), ('snapbranch', 300), ('spiketop', 360), ('spikebase', 360), ('net', 220), ('cage', 220), ('hatch', 220), ('bearden', 900), ('riacho', 420), ('saltador', 260), ('pier', 300), ('dockpost', 200), ('sluicepost', 220), ('bat', 110), ('fly', 72), ('leech', 96), ('piranha', 110),
]
PAGE = 2048
PAD = 2

def maxs(n):
    for k, v in MAXS:
        if n.startswith(k):
            return v
    return 160

items = []
for f in sorted(glob.glob(os.path.join(SRC, '*.png'))):
    n = os.path.splitext(os.path.basename(f))[0]
    im = Image.open(f).convert('RGBA')
    bb = im.getbbox()
    if bb:
        im = im.crop(bb)
    m = maxs(n)
    k = min(1.0, m / max(im.size))
    if k < 1:
        im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
    items.append((n, im))

items.sort(key=lambda t: -t[1].height)
pages = [Image.new('RGBA', (PAGE, PAGE), (0, 0, 0, 0))]
out = {}
x = y = rowh = 0
for n, im in items:
    if x + im.width + PAD > PAGE:
        x = 0
        y += rowh + PAD
        rowh = 0
    if y + im.height + PAD > PAGE:
        pages.append(Image.new('RGBA', (PAGE, PAGE), (0, 0, 0, 0)))
        x = y = rowh = 0
    pages[-1].paste(im, (x, y))
    out[n] = [x, y, im.width, im.height, im.width // 2, im.height, len(pages) - 1]
    x += im.width + PAD
    rowh = max(rowh, im.height)

for i, p in enumerate(pages):
    # corta a sobra de baixo da última página
    if i == len(pages) - 1:
        h = 0
        for n, r in out.items():
            if r[6] == i:
                h = max(h, r[1] + r[3])
        hh = 1
        while hh < h:
            hh *= 2
        p = p.crop((0, 0, PAGE, hh))
    p.save(os.path.join(ROOT, 'assets', 'sprites', 'paint%d.png' % (i + 1)))
json.dump(out, open(os.path.join(ROOT, 'assets', 'data', 'paint.json'), 'w'), indent=0)
print(len(out), 'peças em', len(pages), 'página(s)')

import subprocess, sys
subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'make_sil.py')])
