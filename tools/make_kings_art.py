#!/usr/bin/env python3
"""Gera as artes do Gavião-Rei e do Bagre-Rei recolorindo o corvo e o peixe-lanterna do atlas antigo."""
import json, colorsys
from PIL import Image
j = json.load(open('assets/data/atlas.json'))
A = Image.open('assets/sprites/atlas1.png').convert('RGBA')

def crop(n):
    r = j['atlas1'][n]
    return A.crop((r[0], r[1], r[0] + r[2], r[1] + r[3]))

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def recolor(im, fn):
    px = im.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = px[x, y]
            if a == 0: continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            px[x, y] = fn(r, g, b, a, h, s, v)
    return im

def hawk(r, g, b, a, h, s, v):
    # bico/garras amarelos ficam; o corpo escuro vira marrom com o peito claro
    if s > .45 and .08 < h < .2:
        return (r, g, b, a)
    if v < .13:
        return (38, 22, 12, a)
    t = min(1.0, (v - .13) / .4)
    c = lerp((92, 52, 26), (196, 140, 82), t)
    return c + (a,)

def catfish(r, g, b, a, h, s, v):
    # lanterna amarela continua (vira o bigode que brilha); corpo azul vira lodo esverdeado
    if s > .4 and .1 < h < .2 and v > .6:
        return (r, g, b, a)
    if v < .12:
        return (24, 22, 12, a)
    if .45 < h < .6 and v > .7 and s > .3:
        return (190, 240, 210, a)    # olho
    t = min(1.0, (v - .12) / .5)
    c = lerp((58, 60, 30), (150, 140, 84), t)
    return c + (a,)

fr = [recolor(crop('crow%d' % i).copy(), hawk) for i in range(3)]
W, H = 132, 124
out = Image.new('RGBA', (W * 3, H))
for i, f in enumerate(fr):
    out.paste(f, (i * W, H - f.size[1]))
out.save('assets/sprites/gaviao.png')
fr = [recolor(crop('angler%d' % i).copy(), catfish) for i in range(4)]
W, H = 122, 76
out = Image.new('RGBA', (W * 4, H))
for i, f in enumerate(fr):
    out.paste(f, (i * W, H - f.size[1]))
out.save('assets/sprites/bagre.png')
print('ok')
