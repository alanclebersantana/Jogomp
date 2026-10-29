#!/usr/bin/env python3
"""Acrescenta à fase 1 (uma vez só, sobre a versão sem estes trechos):
 - armadilhas novas: espinhos (manhã e mina), tronco-pêndulo e colmeia (tarde), teia (tarde e noite),
   areia movediça (pântano);
 - a corredeira de jangada entre o pântano e a neve;
 - o período do Céu depois do urso: subida com rajadas de vento, ponte de cordas que se solta,
   pista com o biplano antes do precipício, voo sobre o vale e pouso perto da mina;
 - o bosque dos cogumelos gigantes no começo da noite;
 - a fuga da bola de pedra gigante no túnel da mina.
Abre o espaço com tools/shift_level.py (da direita para a esquerda) e depois põe o conteúdo."""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import shift_level as SL

P = 'assets/data/level1.json'
L = json.load(open(P))
assert 'raft' not in L, 'os trechos novos já estão na fase'

# ---------- 1) abre espaço (posições da fase antiga) ----------
XB, DB = 51760, 2300     # bola de pedra (túnel da mina)
XM, DM = 45885, 2400     # bosque dos cogumelos (começo da noite)
XC, DC = 45520, 11300    # período do Céu (depois da fogueira grande 4)
XR, DR = 25080, 7200     # corredeira (depois da fogueira grande 3)
for X, D, mode in [(XB, DB, 'widen'), (XM, DM, 'widen'), (XC, DC, 'widen'), (XR, DR, 'split')]:
    SL.shift(L, X, D, mode)
    SL.shift_tests(X, D, ['tests/route.gd', 'tests/trap_test.gd'])

def F(x):
    """posição antiga -> posição nova"""
    return x + (DR if x >= XR else 0) + (DC if x >= XC else 0) + (DM if x >= XM else 0) + (DB if x >= XB else 0)

# início de cada trecho novo (o espaço aberto fica logo antes da posição nova do X)
R0, C0, M0, B0 = F(XR) - DR, F(XC) - DC, F(XM) - DM, F(XB) - DB
print('corredeira', R0, 'céu', C0, 'cogumelos', M0, 'bola', B0)
S = L['solids']
T = L['traps']
H = L['hints']
CO = L['coins']
CH = L['checks']

def solid_at(x, y, t=('ground',)):
    for s in S:
        if s['t'] in t and s['x'] <= x < s['x'] + s['w'] and s['y'] == y:
            return s
    raise SystemExit('sem chão em %d,%d' % (x, y))

def ground(x0, x1, y, **kw):
    s = {'t': 'ground', 'x': x0, 'y': y, 'w': x1 - x0, 'h': max(140, 1150 - y)}
    s.update(kw)
    S.append(s)
    return s

def cut(s, x0, x1):
    """tira o trecho [x0, x1) de um bloco de chão (pode virar dois)"""
    a, b = s['x'], s['x'] + s['w']
    S.remove(s)
    if a < x0:
        l = dict(s); l['w'] = x0 - a; S.append(l)
    if x1 < b:
        r = dict(s); r['x'] = x1; r['w'] = b - x1; S.append(r)

def coins_line(x0, x1, y, step=40):
    x = x0
    while x <= x1:
        CO.append([x, y]); x += step

def coins_arc(cx, y, n=5, w=120, hgt=50):
    for i in range(n):
        t = i / (n - 1)
        CO.append([round(cx - w / 2 + w * t), round(y - hgt * (1 - (2 * t - 1) ** 2))])

# ---------- 2) armadilhas novas nos trechos antigos ----------
T.append({'k': 'spikes', 'x': 2560, 'y': 500, 'w': 80, 'per': 150, 'ph': 30})
H.append({'a': 2470, 'b': 2650, 't': 'Espinhos! Espere eles descerem e passe rápido.'})
T.append({'k': 'web', 'x': 7340, 'y': -150, 'w': 76, 'h': 130})
H.append({'a': 7220, 'b': 7460, 't': 'Teia de aranha! Corte com a picareta (GOLPE) antes de passar.', 'yl': 60})
T.append({'k': 'swing', 'x': 10010, 'y': 300, 'len': 176, 'amp': .95, 'per': 170, 'ph': 0})
H.append({'a': 9860, 'b': 10150, 't': 'Tronco balançando! Passe por baixo quando ele estiver lá no alto.'})
T.append({'k': 'hive', 'x': 11640, 'y': 420})
H.append({'a': 11480, 'b': 11780, 't': 'Colmeia! Passe por baixo sem pular. Se as abelhas vierem, fuja para longe ou para a água.'})
T.append({'k': 'sand', 'x': 19700, 'y': 500, 'w': 180})
H.append({'a': 19640, 'b': 19900, 't': 'Areia movediça! Parado você afunda: atravesse pulando.'})
coins_arc(19790, 420, 5, 140, 40)
# espinhos no fundo do poço da mina
T.append({'k': 'spikes', 'x': F(46150), 'y': 900, 'w': 96, 'per': 150, 'ph': 70})
H.append({'a': F(46080), 'b': F(46260), 't': 'Espinhos no poço! Espere descerem.', 'yg': 700})

# ---------- 3) corredeira ----------
# margem esquerda sem neve (a neve começa depois do rio)
for s in S:
    if s['t'] == 'ground' and s['x'] + s['w'] == R0 and s.get('snow'):
        s.pop('snow')
RX1 = R0 + DR
falls = [R0 + 2520, R0 + 5120]
obs = []
for i, k in enumerate(['rock', 'log', 'branch', 'rock', None, 'log', 'branch', 'rock', 'log', 'branch', None, 'rock', 'log', 'branch', 'rock']):
    x = R0 + 620 + i * 450
    if k is None:
        continue
    if any(abs(x - f) < 160 for f in falls):
        x += 200
    obs.append({'k': k, 'x': x})
L['raft'] = {'x': R0 + 80, 'x0': R0, 'x1': RX1, 'y': 530, 'spd': 5.4, 'falls': falls, 'obs': obs}
def wy(x):
    return 530 + 40 * sum(1 for f in falls if x >= f)
for o in obs:
    if o['k'] in ('rock', 'log'):
        coins_arc(o['x'] + 30, wy(o['x']) - 80, 5, 110, 40)
for f in falls:
    coins_arc(f + 40, wy(f) - 110, 5, 120, 40)
# a fogueira grande do fim do pântano passa para depois do rio (a corredeira é o fim do pântano)
for c in CH:
    if len(c) > 3 and c[2] == 'rest' and c[3] == 3:
        CH.remove(c)
        break
CH.append([R0 - 70, 500])
CH.append([RX1 + 100, 500, 'rest', 3])
H.append({'a': R0 - 140, 'b': R0 + 60, 't': 'Uma jangada! ✦ USAR para subir e descer a corredeira.', 'raft': 1})
L['sections'].append({'x': R0 - 60, 'song': 'chuva', 'rain': .6, 'dark': .22, 'tint': 'rgba(40,70,90,.16)', 'map': 'rio'})

# ---------- 4) período do Céu ----------
# o chão da neve que foi esticado vai só até o começo da subida; a clareira do pouso é nova
g0 = solid_at(C0 + 10, 500)
cut(g0, C0 + 380, C0 + DC - 20)
steps = [(380, 640, 430), (640, 900, 360), (1030, 1400, 330), (1400, 1650, 260), (1650, 2000, 190), (2120, 2500, 190),
         (3500, 4700, 190)]
for a, b, y in steps:
    ground(C0 + a, C0 + b, y, snow=1)
ground(C0 + 10500, C0 + DC - 20, 500)
L['chasms'] = L.get('chasms', []) + [[C0 + 900, C0 + 1030, 480], [C0 + 2000, C0 + 2120, 340],
                                      [C0 + 2500, C0 + 3500, 330], [C0 + 4700, C0 + 10500, 600]]
T.append({'k': 'gust', 'x': C0 + 1110, 'y': 130, 'w': 280, 'h': 200, 'per': 260, 'on': 110, 'ph': 0})
T.append({'k': 'gust', 'x': C0 + 1700, 'y': -10, 'w': 290, 'h': 200, 'per': 240, 'on': 110, 'ph': 90})
T.append({'k': 'gust', 'x': C0 + 2200, 'y': -10, 'w': 290, 'h': 200, 'per': 280, 'on': 120, 'ph': 170})
T.append({'k': 'bridge', 'x': C0 + 2500, 'y': 190, 'w': 1000, 'gaps': [9, 10, 19], 'spd': 5.2, 'delay': 26})
for a, b, y in steps[:-1]:
    coins_line(C0 + a + 40, C0 + b - 40, y - 40, 60)
coins_line(C0 + 2560, C0 + 3440, 140, 80)
CH.append([C0 + 2300, 190])
CH.append([C0 + 3620, 190])
L['plane'] = {'x': C0 + 4300, 'y': 190, 'r0': C0 + 3560, 'edge': C0 + 4700, 'x1': C0 + 11000, 'vend': C0 + 10500, 'land': 500,
              'spd': 6.2, 'top': -260, 'low': 430, 'obs': []}
po = L['plane']['obs']
seq = [('flock', 5300, 100), ('cloud', 5700, -110), ('flock', 6100, 300), ('hawk', 6500, -200), ('cloud', 6900, 240),
       ('flock', 7300, -60), ('flock', 7300, 330), ('hawk', 7800, -160), ('cloud', 8200, -10), ('cloud', 8200, 330),
       ('flock', 8700, 150), ('hawk', 9100, -220), ('flock', 9500, -110), ('cloud', 9500, 280), ('flock', 9900, 200)]
for k, x, y in seq:
    o = {'k': k, 'x': C0 + x, 'y': y}
    if k == 'cloud':
        o.update({'w': 250, 'h': 120})
    if k == 'flock':
        o['n'] = 5
    po.append(o)
# lápis no céu, nas faixas livres
for x0, y in [(5000, 200), (5480, 60), (5880, 140), (6300, 60), (6700, 0), (7040, 130), (7560, 140), (8000, 160),
              (8420, 130), (8900, 0), (9300, 60), (9700, 100), (10100, 300)]:
    coins_line(C0 + x0, C0 + x0 + 160, y, 40)
CH.append([C0 + 11120, 500, 'rest', 5])
H.append({'a': C0 + 200, 'b': C0 + 700, 't': 'Subida da montanha! Nas rajadas de vento, segure ↓ para se abaixar e aguentar.', 'yl': 520})
H.append({'a': C0 + 2300, 'b': C0 + 2560, 't': 'Ponte velha... quando pisar, ela vai se soltar. Corra (toque duas vezes →)!', 'yl': 200})
H.append({'a': C0 + 3900, 'b': C0 + 4500, 't': 'Um biplano! ✦ USAR para decolar.', 'plane': 1, 'yl': 200})
L['sections'].append({'x': C0 + 300, 'song': 'tema', 'bg': 'neve', 'snow': .5, 'tint': 'rgba(170,200,255,.08)', 'map': 'ceu'})
L['decor'] = L.get('decor', []) + [{'k': 'pine', 'x': C0 + 500, 'y': 430, 's': 1.0}, {'k': 'pine', 'x': C0 + 1200, 'y': 330, 's': 1.1},
                                   {'k': 'snowtree', 'x': C0 + 1820, 'y': 190, 's': .9}, {'k': 'pine', 'x': C0 + 3700, 'y': 190, 's': .9},
                                   {'k': 'pine', 'x': C0 + 10560, 'y': 500, 's': 1.1}]

# ---------- 5) bosque dos cogumelos gigantes ----------
gm = solid_at(M0 + 10, 500)
cut(gm, M0 + 560, M0 + 1560)
L['pits'].append([M0 + 560, M0 + 1560])
L['pits'].sort()
giants = [(300, 500, 400, 130, '#6a5acd'), (700, 700, 230, 150, '#3a8ad0'), (930, 700, 330, 130, '#8a4ac0'),
          (1250, 700, 150, 140, '#2a9a8a'), (1450, 700, 300, 140, '#6a5acd'), (2050, 500, 140, 150, '#3a8ad0')]
for x, base, cap, w, c in giants:
    T.append({'k': 'giant', 'x': M0 + x, 'y': base, 'cap': cap, 'w': w, 'c': c})
T.append({'k': 'bounce', 'x': M0 + 470, 'y': 500, 'to': [M0 + 700, 230], 'c': 'azul'})
T.append({'k': 'bounce', 'x': M0 + 960, 'y': 330, 'to': [M0 + 1250, 150], 'c': 'azul'})
T.append({'k': 'bounce', 'x': M0 + 1800, 'y': 500, 'to': [M0 + 2050, 140]})
T.append({'k': 'web', 'x': M0 + 2240, 'y': 380, 'w': 76, 'h': 120})
coins_line(M0 + 650, M0 + 750, 190, 50)
coins_line(M0 + 1200, M0 + 1300, 110, 50)
coins_line(M0 + 2000, M0 + 2100, 100, 50)
L['fireflies'] = L.get('fireflies', []) + [[M0 - 100, M0 + DM, 120]]
H.append({'a': M0 + 150, 'b': M0 + 520, 't': 'Cogumelos gigantes! Pule nos chapéus; os cogumelos saltadores te lançam lá para cima.'})
H.append({'a': M0 + 2100, 'b': M0 + 2280, 't': 'Outra teia! Corte com a picareta (GOLPE).'})
CH.append([M0 + 60, 500])

# ---------- 6) bola de pedra no túnel ----------
gb = solid_at(B0 + 10, 500)
cut(gb, B0 + 700, B0 + 800)
L['pits'].append([B0 + 700, B0 + 800])
L['pits'].sort()
gb2 = solid_at(B0 + 1760, 500)
cut(gb2, B0 + 1750, B0 + 1820)
ground(B0 + 1750, B0 + 1820, 526)
S.append({'t': 'bob', 'bob': 'crate', 'id': 'bo1', 'x': B0 + 430, 'y': 460, 'w': 44, 'h': 40})
S.append({'t': 'bob', 'bob': 'cart', 'id': 'bo2', 'x': B0 + 1060, 'y': 456, 'w': 66, 'h': 44})
S.append({'t': 'bob', 'bob': 'crate2', 'id': 'bo3', 'x': B0 + 1380, 'y': 444, 'w': 46, 'h': 56})
S.append({'t': 'bob', 'bob': 'barricade', 'id': 'bo4', 'x': B0 + 2000, 'y': 380, 'w': 26, 'h': 120})
T.append({'k': 'boulder', 'x': B0 + 40, 'y': 500, 'r': 56, 'trig': B0 + 230, 'vmax': 6.0, 'end': B0 + 2170,
          'smash': ['bo1', 'bo2', 'bo3', 'bo4'], 'back': B0 + 30, 'niche': [B0 + 1750, B0 + 1820]})
coins_arc(B0 + 450, 400, 4, 70, 20)
coins_arc(B0 + 750, 410, 5, 110, 30)
coins_arc(B0 + 1090, 400, 4, 80, 20)
coins_arc(B0 + 1400, 390, 4, 80, 20)
CH.append([B0 + 20, 500])
H.append({'a': B0 - 60, 'b': B0 + 220, 't': 'Silêncio... o teto deste túnel parece bem frágil.'})
H.append({'a': B0 + 1600, 'b': B0 + 1790, 't': 'O buraco no chão! Entre nele e segure ↓!'})
# o morcego do túnel atrapalharia a fuga
L['enemies'] = [e for e in L['enemies'] if not (e['k'] == 'bat' and B0 - 200 < e['x'] < B0 + DB + 200)]

CH.sort(key=lambda c: c[0])
L['sections'].sort(key=lambda s: s['x'])
open(P, 'w').write(json.dumps(L, ensure_ascii=False, indent=1))
print('ok', L['spanX'], len(CO), 'lápis')
