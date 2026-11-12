#!/usr/bin/env python3
"""Ciclos de andar de 8 quadros desenhados pelo Gemini (tools/art_src/<fonte>, fundo branco, 2 fileiras de 4)
-> assets/sprites/<nome>_walk.png: tira de quadros CW x CH na mesma escala, linha do chão e posição da
cabeça da arte parada que já existe no jogo (o personagem não "pula" ao trocar de pose).
Uso: python3 tools/make_walks.py [nome ...]"""
import json, os, subprocess, sys, tempfile
import numpy as np
from PIL import Image
from scipy import ndimage as nd
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# nome: (fonte, CW, CH, linha do chão, altura do corpo, x da cabeça, ordem dos quadros, versão "de cenário")
JOBS = {
    'seg': ('seg_walk.png', 260, 230, 224, 214, 122, [4, 5, 6, 7, 8, 9, 10, 11], False),
    'fax': ('fax_walk.png', 320, 240, 236, 210, 100, None, False),
    'pax_exec': ('pax_exec_walk.png', 240, 260, 256, 240, 130, None, True),
    'pax_cel': ('pax_cel_walk.png', 240, 260, 256, 240, 130, None, True),
    'pax_comissaria': ('pax_comissaria_walk.png', 240, 260, 256, 240, 130, None, True),
    'pax_piloto': ('pax_piloto_walk.png', 240, 260, 256, 240, 130, None, True),
    'pax_mae': ('pax_mae_walk.png', 340, 260, 256, 240, 220, None, True),
}

# faixa (em x, relativa à cabeça) onde procurar o pé da frente: o faxineiro empurra a enceradeira
# bem na frente dos pés, que tem de ficar de fora da conta
FOOT_LIM = {'fax': (-110, 47)}

def apagado(q):
    """passageiros "de cenário": as mesmas cores, mais apagadas (igual ao make_arte.passageiros)"""
    from PIL import ImageEnhance
    rgb = q.convert("RGB")
    rgb = ImageEnhance.Color(rgb).enhance(.74)
    rgb = ImageEnhance.Contrast(rgb).enhance(.9)
    rgb = Image.blend(rgb, Image.new("RGB", rgb.size, (226, 218, 205)), .07)
    d = rgb.convert("RGBA")
    d.putalpha(q.getchannel("A"))
    return d

def furos(p):
    a = np.asarray(p).copy()
    wh = (a[..., :3].min(axis=2) >= 228) & (a[..., 3] > 0)
    lab, n = nd.label(wh)
    for i, sl in enumerate(nd.find_objects(lab)):
        if (lab[sl] == i + 1).sum() > 40 and sl[0].start > p.height * .25:
            m = nd.binary_dilation(lab == i + 1, iterations=1) & (a[..., :3].min(axis=2) >= 200)
            a[m, 3] = 0
    return Image.fromarray(a, 'RGBA')

def pieces(src):
    tmp = tempfile.mkdtemp()
    out = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'cut_sheet.py'), src, os.path.join(tmp, 'f'), '236', '4'],
                         check=True, capture_output=True, text=True).stdout
    ps = []
    for l in out.strip().splitlines():
        k = int(l.split()[0])
        im = Image.open(os.path.join(tmp, 'f_%d.png' % k)).convert('RGBA')
        ps.append(furos(im.crop(im.getbbox())))
    med = np.median([p.height for p in ps])
    return [p for p in ps if p.height > med * .6]   # tira pedacinhos soltos

def faixas(mask, axis, minlen):
    """intervalos com desenho ao longo de um eixo (separados por faixas brancas)"""
    on = mask.any(axis=axis)
    out, st = [], None
    for i, v in enumerate(list(on) + [False]):
        if v and st is None:
            st = i
        elif not v and st is not None:
            if i - st >= minlen:
                out.append((st, i))
            st = None
    return out

def pieces_grid(src):
    """folhas apertadas (figuras quase encostando): corta pelas faixas brancas — fileiras e depois colunas"""
    tmp = tempfile.mkdtemp()
    im = Image.open(src).convert('RGB')
    a = np.asarray(im).astype(int)
    ink = a.min(axis=2) < 200
    ps = []
    for y0, y1 in faixas(ink, 1, 60):
        band = ink[y0:y1]
        for x0, x1 in faixas(band, 0, 25):
            f = os.path.join(tmp, 'c.png')
            im.crop((max(0, x0 - 6), max(0, y0 - 6), min(im.width, x1 + 6), min(im.height, y1 + 6))).save(f)
            # a figura (maior pedaço) desse recorte, sem fundo
            out = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'cut_sheet.py'), f, os.path.join(tmp, 'p'), '236', '4'],
                                 check=True, capture_output=True, text=True).stdout.strip().splitlines()
            best = None
            for l in out:
                k, _, _, w, h = map(int, l.split())
                if best is None or w * h > best[1]:
                    best = (k, w * h)
            if best:
                q = Image.open(os.path.join(tmp, 'p_%d.png' % best[0])).convert('RGBA')
                ps.append(furos(q.crop(q.getbbox())))
    med = np.median([p.height for p in ps])
    return [p for p in ps if p.height > med * .6]

# folhas bagunçadas (fileiras tortas, um desenho solto no meio): recorte à mão, (x0, y0, x1, y1)
BOXES = {
    'pax_mae': [(18, 10, 247, 335), (338, 10, 531, 335), (531, 10, 760, 335),
                (20, 365, 255, 690), (285, 365, 500, 690), (505, 365, 740, 690),
                (70, 705, 305, 1015), (470, 705, 705, 1015)],
}

def pieces_boxes(src, boxes):
    tmp = tempfile.mkdtemp()
    im = Image.open(src).convert('RGB')
    ps = []
    for b in boxes:
        f = os.path.join(tmp, 'c.png')
        im.crop(b).save(f)
        out = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'cut_sheet.py'), f, os.path.join(tmp, 'p'), '236', '4'],
                             check=True, capture_output=True, text=True).stdout.strip().splitlines()
        best = max(out, key=lambda l: int(l.split()[3]) * int(l.split()[4]))
        q = Image.open(os.path.join(tmp, 'p_%s.png' % best.split()[0])).convert('RGBA')
        ps.append(furos(q.crop(q.getbbox())))
    return ps

def make(name):
    src, CW, CH, BASE, HGT, HX, order, bg = JOBS[name]
    srcp = os.path.join(ROOT, 'tools', 'art_src', src)
    ps = pieces_boxes(srcp, BOXES[name]) if name in BOXES else pieces_grid(srcp)
    if order:
        ps = [ps[i] for i in order]
    sc = HGT / float(np.median([p.height for p in ps]))
    sheet = Image.new('RGBA', (CW * len(ps), CH), (0, 0, 0, 0))
    for i, p in enumerate(ps):
        p = p.resize((round(p.width * sc), round(p.height * sc)), Image.LANCZOS)
        a = np.asarray(p)[..., 3] > 100
        ys, xs = np.where(a)
        hx = xs[ys < ys.min() + p.height * .14].mean()
        c = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
        c.paste(p, (int(round(HX - hx)), BASE - (ys.max() + 1)), p)
        sheet.alpha_composite(c, (i * CW, 0))
    # ordem dos quadros pelo PÉ DA FRENTE: no passo, o pé da frente pisa lá na frente e vai ficando
    # para trás (o corpo passa por cima dele) até o outro pé assumir a frente. Ordenando do mais à
    # frente para o mais atrás, cada volta da tira é um passo, e o comprimento do passo (quanto o pé
    # plantado recua) diz quanto o corpo anda por volta: o pé fica parado no chão, sem patinar.
    cells = [sheet.crop((i * CW, 0, (i + 1) * CW, CH)) for i in range(len(ps))]
    lim = FOOT_LIM.get(name)
    fr = []
    for c in cells:
        a = np.asarray(c)[..., 3] > 100
        band = a[BASE - int(HGT * .07):BASE + 1]
        if lim:
            x0 = max(0, int(HX + lim[0]))
            band = band[:, x0:int(HX + lim[1])]
            off = x0
        else:
            off = 0
        xs = np.where(band.any(axis=0))[0]
        fr.append((xs.max() + off - HX) if len(xs) else 0)
    order = sorted(range(len(cells)), key=lambda i: -fr[i])
    step = float(fr[order[0]] - fr[order[-1]])
    sheet = Image.new('RGBA', (CW * len(cells), CH), (0, 0, 0, 0))
    for k, i in enumerate(order):
        sheet.alpha_composite(cells[i], (k * CW, 0))
    meta_path = os.path.join(ROOT, 'assets', 'data', 'walks.json')
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {}
    # passo em px do quadro e a altura de referência (o jogo converte pela escala com que desenha)
    meta[name + '_walk'] = {'n': len(cells), 'cw': CW, 'ch': CH, 'base': BASE, 'hx': HX, 'step': round(max(step, HGT * .3), 1), 'hgt': HGT}
    json.dump(meta, open(meta_path, 'w'), indent=1, sort_keys=True)
    if bg:
        sheet = apagado(sheet)
    sheet.save(os.path.join(ROOT, 'assets', 'sprites', name + '_walk.png'))
    print(name + '_walk.png', len(ps), 'quadros')

for n in (sys.argv[1:] or JOBS):
    if os.path.exists(os.path.join(ROOT, 'tools', 'art_src', JOBS[n][0])):
        make(n)
