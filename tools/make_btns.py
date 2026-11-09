#!/usr/bin/env python3
"""Botões novos de luta no estilo dos outros (círculo azul-marinho com aro dourado):
btn_chute (bota em chute, com rastro) e btn_defesa (escudo). Gera em assets/ui/."""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI = os.path.join(ROOT, 'assets', 'ui')
base = Image.open(os.path.join(UI, 'btn_golpe.png')).convert('RGBA')
S = base.width
a = np.array(base)
yy0, xx0 = np.mgrid[0:S, 0:S]
_inn = (xx0 - S / 2) ** 2 + (yy0 - S / 2) ** 2 < (S * .3) ** 2
_c = a[_inn][:, :3].astype(int)
_m = (_c.max(1) - _c.min(1) > 20) & (_c[:, 2] > _c[:, 0])
navy = tuple(int(v) for v in np.median(_c[_m], axis=0))
# limpa o miolo (tira o bastão)
blank = base.copy()
d = ImageDraw.Draw(blank)
d.ellipse((S * .17, S * .17, S * .83, S * .83), fill=navy + (255,))
# bota do botão de pulo (só o branco/cinza do desenho, sem a seta)
jump = Image.open(os.path.join(UI, 'btn_jump.png')).convert('RGBA')
j = np.array(jump).astype(int)
lum = j[..., :3].mean(axis=2)
sat = j[..., :3].max(axis=2) - j[..., :3].min(axis=2)
m = (lum > 150) & (sat < 60) & (j[..., 3] > 200)
yy, xx = np.mgrid[0:S, 0:S]
inner = (xx - S / 2) ** 2 + (yy - S / 2) ** 2 < (S * .34) ** 2
m &= inner
# fica só com a bota (a seta fica no canto de cima à direita)
m &= ~((xx > S * .58) & (yy < S * .5))
m &= yy < S * .7
boot = np.zeros_like(j)
boot[m] = j[m]
# contorno escuro da bota
mk = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(7))
bimg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
bimg.paste(Image.new('RGBA', (S, S), (20, 24, 40, 255)), (0, 0), mk)
bimg.alpha_composite(Image.fromarray(boot.astype(np.uint8)))
bbox = bimg.getbbox()
bimg = bimg.crop(bbox)
# chute: bota deitada apontando para a direita, com rastro e estrela de impacto
k = blank.copy()
bt = bimg.rotate(-62, expand=True, resample=Image.BICUBIC)
bt.thumbnail((int(S * .5), int(S * .5)))
dk = ImageDraw.Draw(k)
for i, yy0 in enumerate((.38, .5, .62)):
    dk.line((S * .2, S * yy0, S * .42, S * yy0), fill=(255, 255, 255, 150 - i * 25), width=int(S * .035))
cx, cy = int(S * .63), int(S * .5)
pts = []
import math
for i in range(16):
    r = S * (.13 if i % 2 == 0 else .06)
    an = i * math.pi / 8
    pts.append((S * .73 + math.cos(an) * r, S * .4 + math.sin(an) * r))
dk.polygon(pts, fill=(255, 150, 40, 255))
k.alpha_composite(bt, (cx - bt.width // 2, cy - bt.height // 2))
k.save(os.path.join(UI, 'btn_chute.png'))
# defesa: escudo branco com faixa laranja e o aro escuro
dfs = blank.copy()
dd = ImageDraw.Draw(dfs)
def shield(sc, fill):
    w, h = S * .36 * sc, S * .44 * sc
    x0, y0 = S / 2 - w / 2, S / 2 - h / 2 - S * .01
    p = [(x0, y0 + h * .12), (S / 2, y0), (x0 + w, y0 + h * .12), (x0 + w, y0 + h * .5),
         (S / 2 + w * .25, y0 + h * .85), (S / 2, y0 + h), (S / 2 - w * .25, y0 + h * .85), (x0, y0 + h * .5)]
    dd.polygon(p, fill=fill)
shield(1.1, (20, 24, 40, 255))
shield(1.0, (245, 247, 252, 255))
shield(.62, (255, 150, 40, 255))
shield(.4, (245, 247, 252, 255))
dfs.save(os.path.join(UI, 'btn_defesa.png'))
prev = Image.new('RGBA', (S * 2 + 20, S), (90, 110, 140, 255))
prev.alpha_composite(k)
prev.alpha_composite(dfs, (S + 20, 0))
prev.save('/tmp/btns_novos.png')
