#!/usr/bin/env python3
"""Abre espaço na fase: tudo que está em x >= X anda D pixels para a direita.
Uso: python3 tools/shift_level.py X D [widen|split]
 - widen: blocos que atravessam X ficam mais largos (o chão continua)
 - split: blocos que atravessam X são cortados em dois (abre um vão)
Também ajusta as posições x escritas nos testes (tests/*.gd)."""
import json, re, sys

P = 'assets/data/level1.json'

def sx(v, X, D):
    return v + D if v >= X else v

def shift(L, X, D, mode='widen'):
    f = lambda v: sx(v, X, D)
    L['spanX'] += D
    L['spawn']['x'] = f(L['spawn']['x'])
    L['lanternOutX'] = f(L['lanternOutX'])
    for k in ['sections', 'darkZones', 'lily', 'mud', 'climb', 'bushes', 'items', 'clues', 'specials',
              'drawings', 'springs', 'crates', 'water', 'mirrors', 'crystals', 'ghost', 'secrets',
              'chalk', 'tocas', 'plates', 'caves', 'swamp']:
        for e in L.get(k, []):
            if 'w' in e and e['x'] < X < e['x'] + e['w'] and k in ('caves', 'swamp', 'darkZones'):
                e['w'] += D
            else:
                e['x'] = f(e['x'])
    new = []
    for s in L['solids']:
        w = s.get('w', 0)
        if s['x'] < X < s['x'] + w:
            if mode == 'widen' or s['t'] not in ('ground', 'dirt', 'cliff'):
                s['w'] += D
            else:
                b = dict(s); b['x'] = X + D; b['w'] = s['x'] + w - X
                s['w'] = X - s['x']
                new.append(b)
        else:
            if 'ladder' in s and s['x'] >= X: s['ladder'][0] += D
            s['x'] = f(s['x'])
    L['solids'] += new
    for v in L.get('vines', []):
        v['x'] = f(v['x'])
        if 'aim' in v: v['aim'][0] = f(v['aim'][0])
    for e in L.get('enemies', []):
        moved = e['x'] >= X
        e['x'] = f(e['x'])
        if moved: e['r'] = [e['r'][0] + D, e['r'][1] + D]
    for k in ['coins', 'clocks', 'checks']:
        for c in L.get(k, []):
            c[0] = f(c[0])
    L['door']['x'] = f(L['door']['x'])
    v = L['villain']
    for k in ['trig', 'x0', 'gateX']: v[k] = f(v[k])
    for h in L.get('hints', []):
        if h['b'] >= X:
            h['a'] = f(h['a']) if h['a'] >= X else X + D
            h['b'] += D
    L['pits'] = [[f(a), f(b)] for a, b in L.get('pits', [])]
    L['shafts'] = [[f(a), f(b), y] for a, b, y in L.get('shafts', [])]
    b = L['boss']
    moved = b['x0'] >= X
    for k in ['x0', 'x1', 'trig', 'spawn']: b[k] = f(b[k])
    b['item'][0] = f(b['item'][0])
    for k in ['gold', 'dog', 'table']:
        if k in L: L[k]['x'] = f(L[k]['x'])
    bo = L.get('boat')
    if bo:
        bo['x'] = f(bo['x']); bo['post'][0] = f(bo['post'][0])
    for l in L.get('locks', []):
        moved = l['x'] >= X
        l['x'] = f(l['x'])
        if 'ring' in l: l['ring'][0] = f(l['ring'][0])
        if 'topX' in l: l['topX'] = f(l['topX'])
    for e in L.get('entrances', []):
        e['x'] = f(e['x'])
        e['to'][0] = f(e['to'][0])
    for t in L.get('traps', []):
        moved = t['x'] >= X
        t['x'] = f(t['x'])
        for k in ['trig', 'end', 'frame', 'back']:
            if k in t and moved: t[k] += D
        if 'niche' in t and moved: t['niche'] = [t['niche'][0] + D, t['niche'][1] + D]
        if 'post' in t and moved: t['post'][0] += D
        if isinstance(t.get('to'), list) and moved: t['to'][0] += D
    # trechos novos (natureza, reis, cavalo)
    for k in ['bogs', 'vents', 'currents', 'gear', 'holes', 'decor', 'ride']:
        for e in L.get(k, []):
            e['x'] = f(e['x'])
    for b in L.get('bars', []):
        if b['x0'] >= X: b['x0'] += D; b['x1'] += D
    for k in ['hawk', 'fish', 'bear']:
        if k in L and L[k]['x0'] >= X:
            for kk in ['x0', 'x1', 'trig']: L[k][kk] += D
    if 'horse' in L:
        h = L['horse']
        for kk in ['x', 'ride0', 'ride1']: h[kk] = f(h[kk])
    for k in ['cattails']:
        if k in L: L[k] = [f(x) for x in L[k]]
    if 'tunnel' in L: L['tunnel'] = [f(x) for x in L['tunnel']]
    # corredeira, biplano, precipícios e vaga-lumes
    for k in ['chasms', 'fireflies']:
        L[k] = [[f(a), f(b) if a >= X else (b + D if b >= X else b), y] for a, b, y in L.get(k, [])]
    ra = L.get('raft')
    if ra:
        for kk in ['x', 'x0', 'x1']: ra[kk] = f(ra[kk])
        ra['falls'] = [f(x) for x in ra.get('falls', [])]
        for o in ra.get('obs', []): o['x'] = f(o['x'])
    pl = L.get('plane')
    if pl:
        for kk in ['x', 'edge', 'x1', 'r0', 'vend']:
            if kk in pl: pl[kk] = f(pl[kk])
        for o in pl.get('obs', []): o['x'] = f(o['x'])
    return L

# só mexe em números que são posições x nos testes (não em contagens de quadros nem em alturas)
POS = re.compile(r'((?:walk_to|jump_to|crawl|put|dodge_roll)\(\s*|px\(\)\s*[<>]=?\s*|\.x\s*[<>]=?\s*|\.x\s*\+\s*[\w\[\]\.]+\s*[<>]=?\s*|\.x\s*=\s*|Vector2\(|tx: float = |float = |else |\bx < |w / 2 - |x \+ 15 < )(\d{3,5})(?!\d)')

def shift_tests(X, D, files):
    for fn in files:
        s = open(fn).read()
        s2 = POS.sub(lambda m: m.group(1) + str(sx(int(m.group(2)), X, D)), s)
        open(fn, 'w').write(s2)

if __name__ == '__main__':
    X, D = int(sys.argv[1]), int(sys.argv[2])
    mode = sys.argv[3] if len(sys.argv) > 3 else 'widen'
    L = json.load(open(P))
    shift(L, X, D, mode)
    open(P, 'w').write(json.dumps(L, ensure_ascii=False, indent=1))
    shift_tests(X, D, ['tests/route.gd', 'tests/trap_test.gd'])
