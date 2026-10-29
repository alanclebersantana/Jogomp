#!/usr/bin/env python3
"""Folhas de sprites do Episódio 2 a partir das artes do Gemini (tools/art_src/*.jpg, fundo branco):
vigia noturno, cão de guarda, Vargas a pé e a Isis jogável.
Cada folha: quadros numa linha, células do mesmo tamanho, pés no fundo da célula e o corpo centralizado.
Uso: python3 tools/make_ep2_art.py"""
import json, os, subprocess, sys, tempfile
import numpy as np
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'tools', 'art_src')
OUT = os.path.join(ROOT, 'assets', 'sprites')


def cut(name, dil=3):
    tmp = tempfile.mkdtemp()
    subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'cut_sheet.py'), os.path.join(SRC, name + '.jpg'),
                    os.path.join(tmp, 'f'), '236', str(dil)], check=True, capture_output=True)
    fr = []
    k = 0
    while os.path.exists(os.path.join(tmp, 'f_%d.png' % k)):
        fr.append(Image.open(os.path.join(tmp, 'f_%d.png' % k)).convert('RGBA'))
        k += 1
    return fr


def split_v(im):
    """separa duas poses empilhadas (linha vazia no meio)"""
    a = np.asarray(im)[..., 3]
    rows = a.max(axis=1)
    mid = len(rows) // 2
    # o vão vazio mais comprido entre as duas poses
    best = (0, mid)
    run = 0
    for yy in range(int(len(rows) * .2), int(len(rows) * .8)):
        if rows[yy] < 10:
            run += 1
            if run > best[0]:
                best = (run, yy - run // 2)
        else:
            run = 0
    y = best[1]
    top = _main_part(im.crop((0, 0, im.width, y)))
    bot = _main_part(im.crop((0, y, im.width, im.height)))
    return top.crop(top.getbbox()), bot.crop(bot.getbbox())


def _main_part(im):
    """só a maior mancha (tira pedacinhos da pose de baixo/de cima que sobraram no corte)"""
    from scipy import ndimage as nd
    a = np.asarray(im).copy()
    m = a[..., 3] > 20
    lab, n = nd.label(m)
    if n <= 1:
        return im
    sizes = nd.sum(m, lab, range(1, n + 1))
    keep = lab == (int(np.argmax(sizes)) + 1)
    a[~keep] = 0
    return Image.fromarray(a)


def build(name, frames, scale, cw, ch, center='body'):
    S = Image.new('RGBA', (cw * len(frames), ch), (0, 0, 0, 0))
    for i, im in enumerate(frames):
        im = im.crop(im.getbbox())
        im = im.resize((max(1, int(im.width * scale)), max(1, int(im.height * scale))), Image.LANCZOS)
        a = np.asarray(im)[..., 3]
        # centro: média das colunas do tronco (metade de cima sem os braços esticados)
        ys, xs = np.nonzero(a[: max(1, im.height * 2 // 3)] > 128)
        cx = float(np.median(xs)) if len(xs) else im.width / 2
        x = cw / 2 - cx
        y = ch - im.height - 2
        if im.width > cw or im.height > ch - 2:
            k = min(cw / im.width, (ch - 2) / im.height)
            im = im.resize((int(im.width * k), int(im.height * k)), Image.LANCZOS)
            cx *= k
            x = cw / 2 - cx
            y = ch - im.height - 2
        S.alpha_composite(im, (i * cw + int(round(max(0, min(cw - im.width, x)))), int(max(0, y))))
    S.save(os.path.join(OUT, name + '.png'))
    print(name, len(frames), 'quadros', cw, 'x', ch)
    return {'n': len(frames), 'cw': cw, 'ch': ch}


meta = {}
v = cut('vigia')
meta['vigia'] = build('vigia', v, .5, 220, 200)
d = cut('cao')
meta['cao'] = build('cao', d, .42, 200, 150)
g = cut('vargas_pe')
meta['vargas_pe'] = build('vargas_pe', g, .5, 200, 200)
i = cut('isis')
# a 10ª pose saiu grudada: agachada escondida (em cima) + pendurada (embaixo)
top, bot = split_v(i[9])
frames = i[:9] + [top, bot] + i[10:]
# ordem final: 0-3 corrida, 4 parada, 5 pulo, 6 caindo, 7 ajoelhada (shh), 8 escada, 9 agachada (shh),
#              10 pendurada, 11-12 engatinhando
meta['isis2'] = build('isis2', frames, .42, 150, 150)
p = os.path.join(ROOT, 'assets', 'data', 'art_meta.json')
m = json.load(open(p)) if os.path.exists(p) else {}
m.update(meta)
json.dump(m, open(p, 'w'), indent=1)
