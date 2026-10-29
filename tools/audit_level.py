#!/usr/bin/env python3
"""Confere o mapa: árvores/enfeites, fogueiras e troncos têm de estar pousados num chão de verdade
(nada flutuando sobre buracos). Sai com erro se achar algum."""
import json, sys, os
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = json.load(open(os.path.join(R, 'assets', 'data', 'level1.json')))
sol = [s for s in L['solids'] if s['t'] in ('ground', 'cliff', 'dirt', 'stone', 'plat', 'hill', 'log', 'snowbank') and not s.get('deco')]
def tops(x):
    return [s['y'] for s in sol if s['x'] - 2 <= x <= s['x'] + s['w'] + 2]
bad = []
for d in L['decor']:
    if d['k'] == 'tracks':
        continue
    if not any(abs(d['y'] - y) < 6 for y in tops(d['x'])):
        bad.append(('enfeite', d))
for c in L['checks']:
    if not any(abs(c[1] - y) < 6 for y in tops(c[0])):
        bad.append(('fogueira', c))
for b in bad:
    print('FLUTUANDO:', b)
print('auditoria: %d problema(s)' % len(bad))
sys.exit(1 if bad else 0)
