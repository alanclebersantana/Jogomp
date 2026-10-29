#!/usr/bin/env python3
"""Conversão de arte do jogo para o estilo 3D (referência Pixar) via Gemini.

  px.py plan                 -> gera tools/px/jobs.json (todas as peças do jogo agrupadas em grades)
  px.py build <job>          -> tools/px/in/<job>.jpg  (grade enviada ao Gemini, fundo magenta)
  px.py cut <job> <img>      -> devolve cada peça convertida ao seu lugar original
  px.py list                 -> lista os trabalhos e o estado

Tipos de peça:
  frame : quadro de uma folha (arquivo, x, y, w, h)  -> escala única por grade, pés alinhados
  piece : peça de atlas/arquivo pequeno               -> encaixada no retângulo/caixa original
  paint : peça de art_src/paint                      -> grava o PNG (o pack_paint refaz o atlas)
  opaque: imagem inteira opaca (fundo, quadrinho, cena) -> só redimensiona
"""
import re
import json, os, sys, glob
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PX = os.path.join(ROOT, 'tools', 'px')
SPR = os.path.join(ROOT, 'assets', 'sprites')
MAG = (255, 0, 255)


def P(*a):
    return os.path.join(ROOT, *a)


# ---------------------------------------------------------------- plano
SHEETS = {  # folha: largura do quadro
    'bagre': 280, 'cao': 200, 'cavalo': 240, 'en_boar': 210, 'en_crow2': 170, 'en_frog2': 130,
    'esquilo': 130, 'filha': 150, 'gaviao': 132, 'horse_free': 260, 'isis2': 150, 'isis_run': 150,
    'javali': 210, 'morcego_rei': 300, 'pai': 170, 'pai2': 170, 'ride_dis': 340, 'ride_gallop': 260,
    'ride_jump': 260, 'sapo_rei': 320, 'sled_tome': 260, 'urso': 280, 'vargas_pe': 200, 'vigia': 220,
    'vigia_walk': 220,
}
SMALL = ['p_arvore_neve', 'p_biplano', 'p_biplano_voo', 'p_bola_neve', 'p_boneco', 'p_capacete',
         'p_galho_neve', 'p_gorro', 'p_pedra_neve', 'p_pinheiro', 'p_tora_neve', 'pai_climb',
         'pai_rope_a', 'pai_rope_b', 'pai_vine_a', 'pai_vine_b', 'tronco', 'galho', 'extra']


def chunks(lst, n):
    k = max(1, -(-len(lst) // -(-len(lst) // n)))  # divide em partes de tamanho parecido
    return [lst[i:i + k] for i in range(0, len(lst), k)]


def plan():
    jobs = []
    # personagem principal: folhas do Tomé (256x256)
    T = 'assets/sprites/tome/'
    tome = [('walk', 8), ('run', 8), ('jump', 3), ('fall', 2), ('land', 3), ('lantern', 2), ('look', 1),
            ('rain', 1), ('shiver', 3), ('tired', 1)]
    fr = [dict(kind='frame', file=T + n + '.png', rect=[i * 256, 0, 256, 256]) for n, c in tome for i in range(c)]
    for i, ch in enumerate([fr[0:8], fr[8:16], fr[16:24], fr[24:32]]):
        jobs.append(dict(id='tome%d' % i, cols=4, items=ch, what='o Tomé'))
    # demais folhas
    for s, fw in SHEETS.items():
        im = Image.open(os.path.join(SPR, s + '.png'))
        n = im.width // fw
        items = [dict(kind='frame', file='assets/sprites/%s.png' % s, rect=[i * fw, 0, fw, im.height]) for i in range(n)]
        for j, ch in enumerate(chunks(items, 10)):
            n2 = len(ch); fw2, fh2 = ch[0]['rect'][2], ch[0]['rect'][3]
            best = min(range(1, n2 + 1), key=lambda c: abs((c * fw2 * 1.12) / (-(-n2 // c) * fh2 * 1.12) - 1.6))
            jobs.append(dict(id='%s_%d' % (s, j), cols=best, items=ch, what=s))
    # peças já convertidas (trabalhos feitos) não entram de novo
    old = os.path.join(PX, 'jobs.json'); dn = os.path.join(PX, 'done.txt')
    done0 = set(open(dn).read().split()) if os.path.exists(dn) else set()
    prev0 = {j['id']: j for j in json.load(open(old))} if os.path.exists(old) else {}
    seen = {(it['file'], tuple(it['rect'])) for jid in done0 if jid in prev0 for it in prev0[jid]['items']}
    fresh = lambda it: (it['file'], tuple(it['rect'])) not in seen
    chars, rest = [], {'atlas': [], 'paint': [], 'small': []}
    def route(it, cat):
        if not fresh(it):
            return
        n = it.get('name', '')
        if CHAR_RX.match(n):
            chars.append(it)
        else:
            rest[cat].append(it)
    # atlas1/atlas2 (peças com retângulo fixo)
    at = json.load(open(P('assets', 'data', 'atlas.json')))
    for a, d in at.items():
        for k, v in d.items():
            x, y, w, h = v[:4]
            route(dict(kind='piece', file='assets/sprites/%s.png' % a, rect=[x, y, w, h], name=k), 'atlas')
    # peças pintadas
    for f in sorted(glob.glob(P('art_src', 'paint', '*.png'))):
        im = Image.open(f)
        route(dict(kind='paint', file=os.path.relpath(f, ROOT), rect=[0, 0, im.width, im.height],
                   name=os.path.basename(f)[:-4]), 'paint')
    # arquivos pequenos
    for s in SMALL:
        im = Image.open(os.path.join(SPR, s + '.png'))
        route(dict(kind='piece', file='assets/sprites/%s.png' % s, rect=[0, 0, im.width, im.height], name=s), 'small')
    # personagens e bichos primeiro (Tomé, Isis, inimigos), em grades próprias
    tome_p = [i for i in chars if i['name'].startswith('pai')]
    others = [i for i in chars if not i['name'].startswith('pai')]
    for j, ch in enumerate(chunks(sorted(tome_p, key=lambda t: t['rect'][3]), 10)):
        jobs.append(dict(id='ctome_%d' % j, cols=5, items=ch, what='tome'))
    for j, ch in enumerate(chunks(sorted(others, key=lambda t: t['rect'][3]), 12)):
        jobs.append(dict(id='cbicho_%d' % j, cols=4, items=ch, what='bichos'))
    rest['atlas'].sort(key=lambda t: t['rect'][3])
    for j, ch in enumerate(chunks(rest['atlas'], 12)):
        jobs.append(dict(id='ratlas_%02d' % j, cols=4, items=ch, what='objetos'))
    rest['paint'].sort(key=lambda t: t['rect'][3] / max(1, t['rect'][2]))
    for j, ch in enumerate(chunks(rest['paint'], 12)):
        jobs.append(dict(id='rpaint_%02d' % j, cols=4, items=ch, what='objetos'))
    for j, ch in enumerate(chunks(rest['small'], 10)):
        jobs.append(dict(id='rsmall_%d' % j, cols=5, items=ch, what='objetos'))
    # trabalhos de peças já feitos continuam valendo (o recorte depende do arranjo antigo)
    for jid in sorted(done0):
        if jid in prev0 and re.match(r'(atlas\d|paint|small)_', jid):
            jobs.append(prev0[jid])
    # botões e controles
    items = []
    for f in sorted(glob.glob(P('assets', 'ui', '*.png'))):
        if 'icon_bg' in f:
            continue
        im = Image.open(f)
        items.append(dict(kind='piece', file=os.path.relpath(f, ROOT), rect=[0, 0, im.width, im.height],
                          name=os.path.basename(f)[:-4]))
    for j, ch in enumerate(chunks(items, 12)):
        jobs.append(dict(id='ui_%d' % j, cols=4, items=ch, what='botões'))
    # fundos, chão, quadrinhos e cenas (opacos)
    for f in sorted(glob.glob(P('assets', 'bg', '*.jpg'))):
        im = Image.open(f)
        jobs.append(dict(id='bg_' + os.path.basename(f)[:-4], cols=1, opaque=True,
                         items=[dict(kind='opaque', file=os.path.relpath(f, ROOT), rect=[0, 0, im.width, im.height])]))
    for s in ['chao', 'chao_mina', 'chao_vila']:
        im = Image.open(os.path.join(SPR, s + '.png'))
        jobs.append(dict(id='g_' + s, cols=1, ground=True,
                         items=[dict(kind='piece', file='assets/sprites/%s.png' % s, rect=[0, 0, im.width, im.height], name=s)]))
    com = sorted(glob.glob(P('assets', 'comic', '*.jpg')))
    for j in range(0, len(com), 4):
        items = []
        for f in com[j:j + 4]:
            im = Image.open(f)
            items.append(dict(kind='opaque', file=os.path.relpath(f, ROOT), rect=[0, 0, im.width, im.height]))
        jobs.append(dict(id='comic_%d' % (j // 4), cols=2, opaque=True, items=items))
    for f in sorted(glob.glob(P('assets', 'ui', '*.jpg'))):
        im = Image.open(f)
        jobs.append(dict(id='cut_' + os.path.basename(f)[:-4], cols=1, opaque=True,
                         items=[dict(kind='opaque', file=os.path.relpath(f, ROOT), rect=[0, 0, im.width, im.height])]))
    os.makedirs(PX, exist_ok=True)
    # trabalhos já feitos mantêm o arranjo antigo (o recorte depende dele)
    old = os.path.join(PX, 'jobs.json'); dn = os.path.join(PX, 'done.txt')
    if os.path.exists(old) and os.path.exists(dn):
        done = set(open(dn).read().split()); prev = {j['id']: j for j in json.load(open(old))}
        jobs = [prev[j['id']] if j['id'] in done and j['id'] in prev else j for j in jobs]
    json.dump(jobs, open(os.path.join(PX, 'jobs.json'), 'w'), indent=0)
    print(len(jobs), 'trabalhos,', sum(len(j['items']) for j in jobs), 'peças')


def jobs():
    return {j['id']: j for j in json.load(open(os.path.join(PX, 'jobs.json')))}


def src_img(it):
    """peça original como RGBA (a partir do arquivo de origem preservado em tools/px/orig)."""
    f = it['file']
    o = os.path.join(PX, 'orig', f)
    if not os.path.exists(o):
        os.makedirs(os.path.dirname(o), exist_ok=True)
        Image.open(P(f)).save(o)
    im = Image.open(o).convert('RGBA')
    x, y, w, h = it['rect']
    return im.crop((x, y, x + w, y + h))


# ---------------------------------------------------------------- grade
def layout(job):
    its = job['items']
    cols = job['cols']
    rows = -(-len(its) // cols)
    if job.get('opaque') or job.get('ground'):
        cw = max(i['rect'][2] for i in its)
        ch = max(i['rect'][3] for i in its)
        pad = 0 if job.get('opaque') else 40
    elif all(i['kind'] == 'frame' for i in its):
        cw = max(i['rect'][2] for i in its)
        ch = max(i['rect'][3] for i in its)
        pad = max(16, int(0.12 * max(cw, ch)))
    else:
        cw = ch = 300
        pad = 40
    W = cols * cw + (cols + 1) * pad
    H = rows * ch + (rows + 1) * pad
    cells = []
    for k, it in enumerate(its):
        cx, cy = k % cols, k // cols
        cells.append([pad + cx * (cw + pad), pad + cy * (ch + pad), cw, ch])
    return W, H, cells


def build(jid):
    job = jobs()[jid]
    W, H, cells = layout(job)
    g = Image.new('RGB', (W, H), MAG)
    for it, (x, y, cw, ch) in zip(job['items'], cells):
        im = src_img(it)
        if job.get('opaque'):
            g.paste(im.convert('RGB'), (x, y))
        elif it['kind'] != 'frame':
            bb = im.getbbox()
            if bb:
                im = im.crop(bb)
            k = min(cw / im.width, ch / im.height)
            im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
            g.paste(im, (x + (cw - im.width) // 2, y + (ch - im.height) // 2), im)
        else:
            # quadro: posição relativa preservada (base no fundo da célula, centralizado)
            ox = x + (cw - im.width) // 2
            oy = y + (ch - im.height)
            g.paste(im, (ox, oy), im)
    os.makedirs(os.path.join(PX, 'in'), exist_ok=True)
    # tamanho de envio: lado maior até 1280
    k = min(1.0, 1280 / max(W, H))
    if k < 1:
        g = g.resize((round(W * k), round(H * k)), Image.LANCZOS)
    out = os.path.join(PX, 'in', jid + '.jpg')
    g.save(out, quality=88)
    print(out, g.size, len(job['items']), 'peças')


# ---------------------------------------------------------------- recorte
def key_alpha(rgb, glow=False):
    """alfa a partir do fundo magenta (cor estimada nos cantos)."""
    a = rgb.astype(np.float32)
    corners = np.concatenate([a[:6, :6].reshape(-1, 3), a[:6, -6:].reshape(-1, 3), a[-6:, :6].reshape(-1, 3), a[-6:, -6:].reshape(-1, 3)])
    bg = np.median(corners, axis=0)
    # "magentice": r e b altos, g baixo
    mag = (np.minimum(a[..., 0], a[..., 2]) - a[..., 1])
    d = np.sqrt(((a - bg) ** 2).sum(-1))
    bgish = (d < 90) | (mag > 110)
    # linhas de grade claras que o Gemini às vezes desenha entre as células
    light = (a.min(-1) > 175) & ((a.max(-1) - a.min(-1)) < 45)
    for ax in (0, 1):
        frac = light.mean(axis=1 - ax)
        idx = np.nonzero(frac > 0.55)[0]
        for i in idx:
            if ax == 0:
                bgish[max(0, i - 2):i + 3, :] |= light[max(0, i - 2):i + 3, :] | (a[max(0, i - 2):i + 3, :].min(-1) > 140)
            else:
                bgish[:, max(0, i - 2):i + 3] |= light[:, max(0, i - 2):i + 3] | (a[:, max(0, i - 2):i + 3].min(-1) > 140)
    lab, n = ndimage.label(bgish)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bgm = np.isin(lab, list(border))
    # buracos fechados (entre pernas, alça da lanterna) bem magenta também são fundo
    hole = (d < 70) & (mag > 150)
    hl, hn = ndimage.label(hole)
    if hn:
        hs = ndimage.sum(hole, hl, range(1, hn + 1))
        hk = np.zeros(hn + 1, bool); hk[1:] = hs > 12
        bgm |= ndimage.binary_dilation(hk[hl], iterations=1) & bgish
    fg = ~bgm
    lab2, n2 = ndimage.label(fg)
    if n2:
        sizes = ndimage.sum(fg, lab2, range(1, n2 + 1))
        keep = np.zeros(n2 + 1, bool)
        keep[1:] = sizes > 40
        fg = keep[lab2]
    alpha = fg.astype(np.float32)
    edge = fg & ~ndimage.binary_erosion(fg, iterations=2)
    soft = np.clip((140 - np.clip(mag, 0, 255)) / 140.0, 0, 1)
    alpha[edge] = np.minimum(alpha[edge], np.maximum(soft[edge], 0.25))
    alpha = ndimage.gaussian_filter(alpha, 0.5) * fg
    # linhas retas que atravessam a imagem inteira (grade desenhada) não são peças
    on = alpha > 0.3
    for ax in (0, 1):
        cov = on.mean(axis=ax)  # ax=0 -> cobertura por coluna
        idx = [i for i in np.nonzero(cov > 0.8)[0]
               if min(cov[max(0, i - 5)], cov[min(len(cov) - 1, i + 5)]) < 0.45]
        for i in idx:
            if ax == 0:
                alpha[:, max(0, i - 2):i + 3] = 0
            else:
                alpha[max(0, i - 2):i + 3, :] = 0
    # brilho/halo misturado com o magenta perto do fundo (lanterna, pelos): vira transparência
    near = ndimage.binary_dilation(~fg, iterations=7) & fg
    sp0 = np.clip(np.minimum(a[..., 0], a[..., 2]) - a[..., 1], 0, None)
    kill = near & (sp0 > 35)
    alpha[kill] *= np.clip(1 - (sp0[kill] - 35) / 90.0, 0, 1)
    halo = ndimage.binary_dilation(~fg, iterations=30) & fg & (sp0 > 45)
    alpha[halo] *= np.clip(1 - (sp0[halo] - 45) / 40.0, 0, 1)
    near = near | halo
    if glow:
        # brilho quente misturado ao magenta (lanterna acesa): vira brilho laranja translúcido
        bg_ = a[..., 2] - a[..., 1]
        gl = fg & (a[..., 0] > 190) & (bg_ > 15)
        alpha[gl] *= np.clip(1 - (bg_[gl] - 15) / 45.0, 0.0, 1.0)
        a[..., 2][gl] = np.minimum(a[..., 2][gl], a[..., 1][gl] * .8)
    out = a.copy()
    # tira o reflexo magenta das bordas
    spill = np.clip(np.minimum(out[..., 0], out[..., 2]) - out[..., 1], 0, None)
    m = edge | near | (spill > 30)
    out[..., 0][m] -= spill[m] * 0.5
    out[..., 2][m] -= spill[m] * 0.5
    out = np.clip(out, 0, 255)
    return np.dstack([out, alpha * 255]).astype(np.uint8)


def cut(jid, src):
    job = jobs()[jid]
    W, H, cells = layout(job)
    im = Image.open(src).convert('RGB')
    sx, sy = im.width / W, im.height / H
    targets = {}

    def tgt(f):
        if f not in targets:
            targets[f] = Image.open(P(f)).convert('RGBA') if not f.endswith('.jpg') else Image.open(P(f)).convert('RGB')
        return targets[f]

    if job.get('opaque'):
        for it, (x, y, cw, ch) in zip(job['items'], cells):
            c = im.crop((round(x * sx), round(y * sy), round((x + cw) * sx), round((y + ch) * sy)))
            w, h = it['rect'][2:]
            c = c.resize((w, h), Image.LANCZOS)
            t = tgt(it['file'])
            t.paste(c, tuple(it['rect'][:2]))
        for f, t in targets.items():
            t.convert('RGB').save(P(f), quality=90)
            print('ok', f)
        return

    rgba = key_alpha(np.array(im), glow=jid.startswith('vigia'))
    pieces = []
    for it, (x, y, cw, ch) in zip(job['items'], cells):
        # célula com uma margem (o Gemini às vezes passa um pouco)
        m = 0.02
        x0 = max(0, round((x - cw * m) * sx)); y0 = max(0, round((y - ch * m) * sy))
        x1 = min(im.width, round((x + cw * (1 + m)) * sx)); y1 = min(im.height, round((y + ch * (1 + m)) * sy))
        cell = rgba[y0:y1, x0:x1].copy()
        lb, nl = ndimage.label(cell[..., 3] > 24)
        for k2, sl in enumerate(ndimage.find_objects(lb), 1):
            hh, ww = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
            if min(hh, ww) <= 5 and max(hh, ww) > 8 * max(1, min(hh, ww)):
                cell[..., 3][lb == k2] = 0
        ys, xs = np.nonzero(cell[..., 3] > 24)
        if len(xs) == 0:
            pieces.append(None)
            continue
        pieces.append(Image.fromarray(cell[ys.min():ys.max() + 1, xs.min():xs.max() + 1]))
    # se o Gemini rearrumou a grade, usa as manchas na ordem de leitura (quando a contagem bate)
    blobs = find_blobs(rgba, len(job['items']))
    if blobs is not None:
        pieces = blobs
        if os.environ.get('PX_ORDER'):
            pieces = [blobs[int(i)] for i in os.environ['PX_ORDER'].split(',')]
    elif os.environ.get('PX_STRICT'):
        raise SystemExit('contagem de peças não bate: ' + jid)
    origs = [src_img(it) for it in job['items']]
    obbs = [o.getbbox() for o in origs]
    kinds = set(it['kind'] for it in job['items'])
    common = None
    if kinds == {'frame'}:
        rs = [(b[3] - b[1]) / p.height for b, p in zip(obbs, pieces) if b and p]
        common = float(np.median(rs)) if rs else 1.0
    for it, o, b, p in zip(job['items'], origs, obbs, pieces):
        if p is None or b is None:
            print('  vazio:', it.get('name', it['file']))
            continue
        bw, bh = b[2] - b[0], b[3] - b[1]
        if common:
            k = common
        else:
            k = min(bw / p.width, bh / p.height)
        q = p.resize((max(1, round(p.width * k)), max(1, round(p.height * k))), Image.LANCZOS)
        w, h = it['rect'][2:]
        cx = (b[0] + b[2]) / 2
        nx = round(cx - q.width / 2)
        ny = b[3] - q.height
        nx = min(max(nx, 0), max(0, w - q.width))
        ny = min(max(ny, 0), max(0, h - q.height))
        frame = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        frame.alpha_composite(q.crop((0, 0, min(q.width, w), min(q.height, h))), (nx, ny))
        if it['kind'] == 'paint':
            # peça pintada: arquivo próprio, mantém o tamanho em pixels do original (mais nitidez quando cabe)
            k2 = min(bw / p.width, bh / p.height) if not common else common
            q2 = p if p.width * 1.0 <= w and p.height <= h and k2 < 1 else q
            out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
            q2 = q2.resize((max(1, round(q2.width * min(1, w / q2.width, h / q2.height))),
                            max(1, round(q2.height * min(1, w / q2.width, h / q2.height)))), Image.LANCZOS)
            out.alpha_composite(q2, (round(cx - q2.width / 2) if q2.width < w else 0, max(0, b[3] - q2.height)))
            out.save(P(it['file']))
            continue
        t = tgt(it['file'])
        x, y = it['rect'][:2]
        t.paste((0, 0, 0, 0), (x, y, x + w, y + h))
        t.alpha_composite(frame, (x, y))
    if job.get('ground'):
        for f in list(targets):
            targets[f] = seamless(targets[f])
    for f, t in targets.items():
        t.save(P(f), optimize=True)
        print('ok', f)


def find_blobs(rgba, n):
    al = rgba[..., 3] > 24
    H, W = al.shape
    r = max(6, int(min(H, W) * .018))
    dl = ndimage.binary_dilation(al, iterations=r)
    lab, k = ndimage.label(dl)
    if k == 0:
        return None
    objs = ndimage.find_objects(lab)
    areas = ndimage.sum(al, lab, range(1, k + 1))
    big = [i for i in range(k) if areas[i] > 0.15 * max(areas)]
    if len(big) != n:
        print('  manchas: %d (esperado %d) -> usa a grade' % (len(big), n))
        return None
    info = []
    for i in big:
        sl = objs[i]
        info.append(((sl[0].start + sl[0].stop) / 2, (sl[1].start + sl[1].stop) / 2, sl, i + 1, sl[0].stop - sl[0].start))
    hmed = float(np.median([t[4] for t in info]))
    info.sort(key=lambda t: t[0])
    rows = []
    for t in info:
        if rows and abs(t[0] - rows[-1][0][0]) < hmed * .5:
            rows[-1].append(t)
        else:
            rows.append([t])
    out = []
    for row in rows:
        for cy, cx, sl, li, _ in sorted(row, key=lambda t: t[1]):
            piece = rgba[sl].copy()
            piece[..., 3][lab[sl] != li] = 0
            ys, xs = np.nonzero(piece[..., 3] > 24)
            out.append(Image.fromarray(piece[ys.min():ys.max() + 1, xs.min():xs.max() + 1]))
    return out


def seamless(im, frac=.22):
    """emenda horizontal: a borda direita se mistura com o começo (ladrilho sem costura)."""
    a = np.array(im.convert('RGBA')).astype(np.float32)
    w = a.shape[1]
    k = max(4, int(w * frac))
    out = a[:, :w - k].copy()
    t = np.linspace(0, 1, k)[None, :, None]
    out[:, :k] = a[:, :k] * t + a[:, w - k:] * (1 - t)
    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
    return img.resize((w, a.shape[0]), Image.LANCZOS)


CHAR_RX = re.compile(r'(pai|lia_|en_|spider|bat\d|bat_|piranha|owl|leech|frog_|fly\d|saltador|goose|rab_|tuc_|bird|bee|bfly)')
DESC = {
    'tome': 'o Tomé (o mesmo personagem que você já fez)', 'bagre': 'o bagre gigante (chefe do rio)',
    'cao': 'a Pipoca, cachorra vira-lata cinza-amarronzada com coleira de corda', 'cavalo': 'o cavalo',
    'en_boar': 'o javali (inimigo)', 'en_crow2': 'o corvo (inimigo)', 'en_frog2': 'o sapo (inimigo)',
    'esquilo': 'o esquilo', 'filha': 'a Isis, menina de 10 anos de trança ruiva longa, camiseta rosa e short jeans',
    'gaviao': 'o gavião (chefe)', 'horse_free': 'o cavalo solto', 'isis2': 'a Isis, menina de 10 anos de trança ruiva longa, camiseta rosa e short jeans',
    'isis_run': 'a Isis correndo (menina de 10 anos, trança ruiva longa, camiseta rosa, short jeans)', 'javali': 'o javali',
    'morcego_rei': 'o morcego rei (chefe)', 'pai': 'o Tomé (o mesmo personagem que você já fez)', 'pai2': 'o Tomé (o mesmo personagem que você já fez)',
    'ride_dis': 'o Tomé montado no cavalo', 'ride_gallop': 'o Tomé montado no cavalo galopando', 'ride_jump': 'o Tomé montado no cavalo pulando',
    'sapo_rei': 'o sapo rei (chefe)', 'sled_tome': 'o Tomé no trenó', 'urso': 'o urso (chefe)',
    'vargas_pe': 'o Vargas, minerador de bigode com capacete de lanterna e colete', 'vigia': 'o vigia da vila', 'vigia_walk': 'o vigia da vila andando',
}
TAIL = ' Fundo MAGENTA puro (#FF00FF) liso em toda a imagem, sem chão, sem sombra no chão, sem cenário, sem texto, sem números.'


def prompt(jid):
    j = jobs()[jid]
    n = len(j['items'])
    cols = j['cols']; rows = -(-n // cols)
    st = 'exatamente no mesmo estilo 3D Disney Pixar da imagem de referência (render 3D macio, materiais e texturas ricas, iluminação quente e cinematográfica)'
    if jid.startswith('bg_'):
        return ('Agora este cenário de fundo do jogo (panorama largo). Refaça a MESMA cena, com a mesma composição, os mesmos elementos nos mesmos lugares e o mesmo formato panorâmico largo, ' + st +
                '. Sem personagens, sem texto.')
    if jid.startswith('g_'):
        return ('Agora esta faixa de chão do jogo (vista de lado). Refaça ' + st + ': a camada de cima do mesmo tipo que está na imagem e, embaixo, terra com raízes e pedrinhas igual ao chão da referência. '
                'Mesmo formato, preenchendo a imagem inteira, e as laterais esquerda e direita devem emendar sem costura. Sem personagens, sem texto.')
    if jid.startswith('comic_'):
        return ('Agora estes %d quadrinhos do jogo, numa grade %dx%d. Refaça cada quadro ' % (n, cols, rows) + st +
                ', mantendo em cada um a mesma cena, os mesmos personagens, as mesmas poses e o mesmo enquadramento, na mesma posição da grade, sem bordas nem espaço entre os quadros. Sem texto.')
    if jid.startswith('cut_'):
        return ('Agora esta cena de história do jogo. Refaça a MESMA cena, com os mesmos personagens, poses, composição e formato, ' + st + '. Sem texto.')
    if jid.startswith('ctome'):
        return ('Agora esta grade com %d poses do Tomé (%d colunas x %d linhas) sobre fundo magenta. O Tomé é o MESMO senhor idoso HUMANO das imagens anteriores (não é gnomo): '
                'casaco VERMELHO-TIJOLO, gorro de lã verde com pompom branco, cachecol listrado verde e bege, barba branca, calça escura e botas marrons. '
                'Refaça CADA pose como render 3D ' % (n, cols, rows) + st + ', cada uma no mesmo lugar da grade, com exatamente a mesma pose (agachado, engatinhando, escalando, '
                'pendurado, arremessando etc.), o mesmo tamanho e virada para o mesmo lado. Não junte, não remova e não adicione poses.' + TAIL)
    if jid.startswith('cbicho'):
        return ('Agora esta grade com %d bichos e personagens do jogo (%d colunas x %d linhas) sobre fundo magenta. Refaça CADA um como render 3D ' % (n, cols, rows) + st +
                ', cada um no mesmo lugar da grade, com a mesma espécie, pose, tamanho, cores principais e virado para o mesmo lado. A menina é a Isis (10 anos, trança ruiva, camiseta rosa, short jeans). '
                'Não junte, não remova e não adicione nada.' + TAIL)
    base = jid.rsplit('_', 1)[0] if not jid.startswith('tome') else 'tome'
    if all(i['kind'] == 'frame' for i in j['items']):
        quem = DESC.get(base, base)
        return ('Agora faça o mesmo com esta folha de animação (%s): %d quadros numa grade %dx%d sobre fundo magenta. Refaça como render 3D ' % (quem, n, cols, rows) + st +
                '. Mantenha os mesmos %d quadros, na mesma ordem e posição na grade, com a mesma pose de cada quadro, o mesmo tamanho e virado para o mesmo lado.' % n + TAIL)
    return ('Agora esta grade com %d objetos/peças do jogo (%d colunas x %d linhas) sobre fundo magenta. Refaça CADA objeto como render 3D ' % (n, cols, rows) + st +
            ', cada um no mesmo lugar da grade, com o mesmo formato, proporção, cores principais e orientação. Não junte, não remova e não adicione objetos.' + TAIL)


def ls():
    done = set(open(os.path.join(PX, 'done.txt')).read().split()) if os.path.exists(os.path.join(PX, 'done.txt')) else set()
    for j in json.load(open(os.path.join(PX, 'jobs.json'))):
        print(('x ' if j['id'] in done else '. ') + j['id'], len(j['items']))


if __name__ == '__main__':
    c = sys.argv[1]
    if c == 'plan':
        plan()
    elif c == 'build':
        for j in sys.argv[2:]:
            build(j)
    elif c == 'cut':
        cut(sys.argv[2], sys.argv[3])
    elif c == 'list':
        ls()
    elif c == 'prompt':
        print(prompt(sys.argv[2]))
    elif c == 'done':
        open(os.path.join(PX, 'done.txt'), 'a').write(sys.argv[2] + '\n')
