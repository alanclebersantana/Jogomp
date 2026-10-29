#!/usr/bin/env python3
"""Quadros intermediários (x4) para as animações do jogo, no mesmo traço da arte original.

Para cada ciclo de animação listado em JOBS, gera 3 quadros entre cada par de quadros vizinhos
(fluxo óptico nos dois sentidos + mistura sem fantasma), e grava:
  assets/sprites/x4/<chave>.png   (quadros em grade, no máximo 4096 px de largura)
  assets/data/x4.json             (chave -> tamanho do quadro, colunas, escala, âncora)

O jogo (scripts/spr.gd) usa essas folhas automaticamente quando existem; sem elas, cai na
animação original. Uso:  python3 tools/x4.py           (refaz tudo)
                         python3 tools/x4.py tome/walk  (só as chaves que contêm o texto)
Precisa de: pip install opencv-python-headless pillow numpy
"""
import json, os, sys
import numpy as np
import cv2
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, 'assets', 'sprites')
OUT = os.path.join(SPR, 'x4')
META = os.path.join(ROOT, 'assets', 'data', 'x4.json')
K = 4            # quadros por quadro original
MAXW = 4096      # largura máxima da folha (celulares antigos não aceitam textura maior)

# (tipo, nome, parâmetros)
#  sheet: folha com quadros lado a lado: (arquivo relativo a assets/sprites, largura do quadro, sequência, cíclico, escala de armazenamento)
#  A:     peças do atlas desenhadas por Spr.A (âncora própria): lista de nomes
#  PC:    peças pintadas desenhadas centradas com largura fixa (WorldExtras._pc): nomes, largura
#  P:     peças pintadas desenhadas pela base com largura fixa (Spr.P): nomes, largura
JOBS = [
    # Tomé
    ('sheet', 'tome/walk', 256, list(range(8)), True, .5),
    ('sheet', 'tome/run', 256, list(range(8)), True, .5),
    ('sheet', 'tome/shiver', 256, [0, 1, 2], True, .5),
    ('sheet', 'tome/lantern', 256, [0, 1], True, .5),
    ('sheet', 'tome/jump', 256, [0, 1, 2], False, .5),
    ('sheet', 'tome/fall', 256, [0, 1], False, .5),
    ('sheet', 'tome/land', 256, [0, 1, 2], False, .5),
    ('sheet', 'pai', 170, [1, 2, 3, 2], True, .75),
    ('sheet', 'pai2', 170, [0, 1], True, .75),
    ('sheet', 'pai2', 170, [4, 7], True, .75),
    ('A', 'pai_crawl', ['pai_crawl1', 'pai_crawl2', 'pai_crawl3', 'pai_crawl2']),
    ('A', 'pai_push', ['pai_push1', 'pai_push2', 'pai_push3']),
    # Isis
    ('sheet', 'isis_run', 150, list(range(8)), True, .8),
    ('sheet', 'isis2', 150, [0, 1, 2, 3], True, .8),
    ('sheet', 'isis2', 150, [11, 12], True, .8),
    # Pipoca, cão do Vargas, gente da vila
    ('A', 'dog', ['dog0', 'dog1', 'dog2', 'dog3']),
    ('sheet', 'cao', 200, [0, 1, 2, 3], True, 1.0),
    ('sheet', 'vargas_pe', 200, [0, 1, 2, 3], True, .9),
    ('sheet', 'vigia_walk', 220, list(range(8)), True, .85),
    ('sheet', 'vigia', 220, [0, 1, 2, 3], True, .85),
    # cavalo
    ('sheet', 'cavalo', 240, list(range(6)), True, .85),
    ('sheet', 'ride_gallop', 260, list(range(8)), True, .8),
    # inimigos
    ('sheet', 'en_boar', 210, list(range(6)), True, .7),
    ('sheet', 'javali', 210, [0, 1, 2, 3], True, 1.0),
    ('sheet', 'javali', 210, [5, 3], True, 1.0),
    ('sheet', 'esquilo', 130, [0, 1, 2, 3], True, .9),
    ('sheet', 'en_crow2', 170, [0, 1, 2, 3], True, 1.0),
    ('sheet', 'en_frog2', 130, [0, 1], True, 1.0),
    ('A', 'crow', ['crow0', 'crow1', 'crow2']),
    ('A', 'en_owl', ['en_owl1', 'en_owl2']),
    ('PC', 'bat', ['bat0', 'bat1', 'bat2', 'bat1'], 50),
    ('PC', 'spider', ['spider0', 'spider1', 'spider2'], 42),
    ('PC', 'fly', ['fly0', 'fly1'], 40),
    # bichos do cenário
    ('P', 'goose', ['goose0', 'goose1', 'goose2', 'goose1'], 24),
    ('P', 'tuc_f', ['tuc_f0', 'tuc_f1', 'tuc_f2', 'tuc_f1'], 42),
    # chefes
    ('sheet', 'gaviao', 132, [0, 1, 2], True, 1.0),
    ('sheet', 'bagre', 280, [0, 1, 2, 3], True, 1.0),
    ('sheet', 'urso', 280, [0, 1], True, 1.0),
    ('sheet', 'morcego_rei', 300, [0, 1, 2, 1], True, 1.0),
    ('sheet', 'sapo_rei', 320, [1, 2], True, 1.0),
]


# ---------------------------------------------------------------- quadros intermediários
def _gray(a):
    rgb = a[..., :3].astype(np.float32); al = a[..., 3:4].astype(np.float32) / 255
    return cv2.cvtColor((rgb * al + 128 * (1 - al)).astype(np.uint8), cv2.COLOR_RGB2GRAY)


_DIS = None
def _flow(g0, g1):
    global _DIS
    if _DIS is None:
        _DIS = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
        _DIS.setFinestScale(0)
    return _DIS.calc(g0, g1, None)


def _farne(g0, g1):
    return cv2.calcOpticalFlowFarneback(g0, g1, None, .5, 6, 31, 5, 7, 1.5, 0)


def _err(f01, f10, alpha):
    # consistência ida e volta: quanto menor, mais confiável o fluxo
    back = _warp(f01, f10)
    e = np.linalg.norm(back + f10, axis=2)
    m = alpha > 128
    return float(e[m].mean()) if m.any() else 0.0


def best_flow(a, b):
    """testa dois métodos de fluxo óptico e fica com o mais consistente (asas e saltos grandes pedem o segundo)"""
    g0, g1 = _gray(a), _gray(b)
    best = None
    for fn in (_flow, _farne):
        f01, f10 = fn(g0, g1), fn(g1, g0)
        e = _err(f01, f10, b[..., 3]) + _err(f10, f01, a[..., 3])
        if best is None or e < best[0]:
            best = (e, f01, f10)
    return best[1], best[2], best[0] / 2


def _warp(img, fl):
    h, w = fl.shape[:2]
    gx, gy = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
    return cv2.remap(img, gx + fl[..., 0], gy + fl[..., 1], cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)


def tween(a0, a1, t, f01=None, f10=None):
    if f01 is None:
        g0, g1 = _gray(a0), _gray(a1)
        f01, f10 = _flow(g0, g1), _flow(g1, g0)
    p0 = a0.astype(np.float32); p0[..., :3] *= p0[..., 3:4] / 255
    p1 = a1.astype(np.float32); p1[..., :3] *= p1[..., 3:4] / 255
    w0 = _warp(p0, f10 * t)
    w1 = _warp(p1, f01 * (1 - t))
    a0w = w0[..., 3:4] / 255; a1w = w1[..., 3:4] / 255
    # bordas esticadas pelo deslocamento ficam meio transparentes: endurece cada lado antes de misturar
    h0 = np.clip((a0w - .55) / .25, 0, 1); h1 = np.clip((a1w - .55) / .25, 0, 1)
    wa = (1 - t) * h0; wb = t * h1
    # no meio exato (t = .5) a silhueta precisa de um dono: sem isso, onde o fluxo erra aparecem
    # as duas formas juntas (asa dupla, cabeça dupla)
    ta = .47 if abs(t - .5) < 1e-6 else t
    sa = (1 - ta) * h0; sb = ta * h1
    den = np.maximum(wa + wb, 1e-4)
    c0 = w0[..., :3] / np.maximum(a0w, 1e-3); c1 = w1[..., :3] / np.maximum(a1w, 1e-3)
    rgb = (c0 * wa + c1 * wb) / den
    # alfa sem fantasma: cada pedaço fica inteiro ou some (vence o quadro mais próximo);
    # onde os dois quadros concordam, mantém a borda suave original
    al = (sa + sb)[..., 0]
    agree = np.minimum(h0, h1)[..., 0]
    soft = (a0w * (1 - t) + a1w * t)[..., 0]
    al = np.where((al >= .5) | (agree > .5), np.maximum(soft, (al >= .5) * 1.0), 0) * 255
    o = np.concatenate([rgb, al[..., None]], -1)
    return np.clip(o, 0, 255).astype(np.uint8)


ERRS = []


def expand(frames, cyclic=True):
    out = []
    n = len(frames)
    for i in range(n if cyclic else n - 1):
        a, b = frames[i], frames[(i + 1) % n]
        out.append(a)
        if np.array_equal(a, b):
            out += [a] * (K - 1)
            continue
        f01, f10, err = best_flow(a, b)
        ERRS.append(err)
        for j in range(1, K):
            out.append(tween(a, b, j / K, f01, f10))
    if not cyclic:
        out.append(frames[-1])
    return out


# ---------------------------------------------------------------- leitura das peças
def _load(p):
    return np.array(Image.open(p).convert('RGBA'))


def _atlas():
    at = json.load(open(os.path.join(ROOT, 'assets', 'data', 'atlas.json')))
    out = {}
    for a, d in at.items():
        for n, r in d.items():
            out[n] = (os.path.join(SPR, a + '.png'), r)
    return out


def _paint():
    pj = json.load(open(os.path.join(ROOT, 'assets', 'data', 'paint.json')))
    return {n: (os.path.join(SPR, 'paint%d.png' % (int(r[6]) + 1)), r) for n, r in pj.items()}


_CACHE = {}
def _img(p):
    if p not in _CACHE:
        _CACHE[p] = _load(p)
    return _CACHE[p]


def _crop(p, r):
    x, y, w, h = [int(round(v)) for v in r[:4]]
    return _img(p)[y:y + h, x:x + w].copy()


def _resize(a, w, h):
    return np.array(Image.fromarray(a).resize((max(1, int(round(w))), max(1, int(round(h)))), Image.LANCZOS))


# ---------------------------------------------------------------- trabalhos
def job_sheet(name, fw, seq, cyc, q):
    im = _load(os.path.join(SPR, name + '.png'))
    ch = im.shape[0]
    frames = [im[:, i * fw:(i + 1) * fw] for i in seq]
    out = expand(frames, cyc)
    if q != 1.0:
        out = [_resize(f, fw * q, ch * q) for f in out]
    key = name + ':' + '-'.join(map(str, seq))
    return key, out, {'kind': 'sheet', 'q': q, 'cyc': cyc}


def job_A(name, names):
    at = _atlas()
    rs = [at[n] for n in names]
    # quadro comum alinhado pela âncora de cada peça
    x0 = min(-r[4] for _, r in rs); y0 = min(-r[5] for _, r in rs)
    x1 = max(r[2] - r[4] for _, r in rs); y1 = max(r[3] - r[5] for _, r in rs)
    W = int(np.ceil(x1 - x0)) + 2; H = int(np.ceil(y1 - y0)) + 2
    frames = []
    for p, r in rs:
        c = np.zeros((H, W, 4), np.uint8)
        pc = _crop(p, r)
        ox = int(round(-r[4] - x0)) + 1; oy = int(round(-r[5] - y0)) + 1
        c[oy:oy + pc.shape[0], ox:ox + pc.shape[1]] = pc
        frames.append(c)
    out = expand(frames, True)
    return 'A:' + name, out, {'kind': 'A', 'q': 1.0, 'cyc': True, 'ax': float(-x0 + 1), 'ay': float(-y0 + 1)}


def job_P(name, names, w, bottom):
    pa = _paint()
    rs = [pa[n] for n in names]
    # cada peça é desenhada com a mesma largura: normaliza para essa largura (em 2x) e alinha
    S = 4.0 if w <= 30 else 2.0
    if w == 0:
        w = 64.0
    pcs = [_resize(_crop(p, r), w * S, w * S * r[3] / r[2]) for p, r in rs]
    W = max(pc.shape[1] for pc in pcs) + 2; H = max(pc.shape[0] for pc in pcs) + 2
    frames = []
    for pc in pcs:
        c = np.zeros((H, W, 4), np.uint8)
        ox = (W - pc.shape[1]) // 2
        oy = (H - pc.shape[0]) - 1 if bottom else (H - pc.shape[0]) // 2
        c[oy:oy + pc.shape[0], ox:ox + pc.shape[1]] = pc
        frames.append(c)
    out = expand(frames, True)
    return ('P:' if bottom else 'PC:') + name, out, {'kind': 'P' if bottom else 'PC', 'q': 1.0, 'cyc': True, 'w': float(w), 'px': S}


def save(key, frames, meta, allm):
    fh, fw = frames[0].shape[:2]
    cols = max(1, min(len(frames), MAXW // fw))
    rows = -(-len(frames) // cols)
    sheet = np.zeros((rows * fh, cols * fw, 4), np.uint8)
    for i, f in enumerate(frames):
        r, c = divmod(i, cols)
        sheet[r * fh:(r + 1) * fh, c * fw:(c + 1) * fw] = f
    fn = key.replace('/', '_').replace(':', '__') + '.png'
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(sheet).save(os.path.join(OUT, fn), optimize=True)
    meta.update({'file': 'x4/' + fn, 'n': len(frames), 'cw': fw, 'ch': fh, 'cols': cols})
    allm[key] = meta
    print('%-28s %3d quadros  %dx%d  folha %dx%d  erro %s' % (key, len(frames), fw, fh, sheet.shape[1], sheet.shape[0], ' '.join('%.1f' % e for e in ERRS)))
    ERRS.clear()


def main():
    only = sys.argv[1:]
    allm = json.load(open(META)) if os.path.exists(META) and only else {}
    for j in JOBS:
        kind = j[0]
        if kind == 'sheet':
            if not os.path.exists(os.path.join(SPR, j[1] + '.png')):
                continue
            key, fr, meta = job_sheet(*j[1:])
        elif kind == 'A':
            key, fr, meta = job_A(*j[1:])
        else:
            key, fr, meta = job_P(j[1], j[2], j[3], kind == 'P')
        if only and not any(o in key for o in only):
            continue
        save(key, fr, meta, allm)
    json.dump(allm, open(META, 'w'), indent=1, sort_keys=True)


if __name__ == '__main__':
    main()
