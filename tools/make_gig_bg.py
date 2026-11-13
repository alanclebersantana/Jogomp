"""Gera assets/bg/gig_dia/tarde/noite.jpg a partir de tools/art_src/gig_dia.png (o saguão do Galeão).
dia: a pintura, com nitidez; tarde: céu alaranjado e luz quente; noite: lá fora escuro com estrelas e
luzes, e o saguão por dentro ACESO (luz quente das luminárias), como um aeroporto de verdade à noite."""
import random
from PIL import Image, ImageFilter, ImageDraw
import numpy as np
W, H = 1792, 592
src = Image.open('tools/art_src/gig_dia.png').convert('RGB').resize((W, H), Image.LANCZOS)
src = src.filter(ImageFilter.UnsharpMask(radius=2.2, percent=120, threshold=2))
a = np.asarray(src).astype(np.float32) / 255.0
r, g, b = a[..., 0], a[..., 1], a[..., 2]
yy = np.repeat(np.arange(H)[:, None], W, 1) / H
mx = a.max(2); mn = a.min(2); sat = (mx - mn) / (mx + 1e-4)

def blur(m, rad):
    return np.asarray(Image.fromarray((np.clip(m, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(rad))).astype(np.float32) / 255

# céu: azul bem claro nas vidraças
sky = ((b - r) > 0.12) & (b > 0.88) & (g > 0.80) & (yy > 0.12) & (yy < 0.62)
m = np.asarray(Image.fromarray((sky * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(1.5))).astype(np.float32)[..., None] / 255
# vidro (o que fica lá fora): colunas da imagem que têm céu, do topo do céu até o rodapé da vidraça,
# tirando o que é do saguão na frente do vidro (bandeiras e plantas bem verdes, painéis escuros)
colsky = sky[int(H * .13):int(H * .62)].mean(0)
colk = blur(np.repeat((colsky > .07).astype(np.float32)[None, :], 4, 0), 3)[0]
band = np.clip((yy - .13) / .03, 0, 1) * np.clip((.775 - yy) / .02, 0, 1)
verde = ((g > r * 1.25) & (g > b * 1.25) & (sat > .45)).astype(np.float32)
escuro = (mx < .22).astype(np.float32)
frente = blur(np.maximum(verde, escuro), 2.5)
glass = (band * colk[None, :] * (1 - np.clip(frente * 1.6, 0, 1)))
glass = np.maximum(blur(glass, 2), m[..., 0])[..., None]

def grad(stops):
    out = np.zeros((H, W, 3), np.float32)
    ys = np.arange(H) / H
    for i in range(3):
        out[:, :, i] = np.interp(ys, [s[0] for s in stops], [s[1][i] / 255 for s in stops])[:, None]
    return out

def save(arr, name):
    Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8)).save('assets/bg/gig_%s.jpg' % name, quality=92)

lum = a.mean(2, keepdims=True)
save(a, 'dia')
# ---------- tarde
sk = grad([(0.10, (255, 150, 90)), (0.35, (255, 120, 110)), (0.50, (255, 190, 120)), (0.62, (255, 215, 150))])
dentro = a * np.array([1.06, 0.9, 0.74]) + np.array([0.05, 0.02, 0.0])
dentro = dentro * (0.78 + 0.22 * lum) + (1 - lum) * np.array([0.04, 0.0, 0.07])
fora = (a * np.array([1.0, .62, .48])) * .8 + np.array([.16, .05, .03])      # paisagem em contraluz alaranjada
t = dentro * (1 - glass) + fora * glass
t = t * (1 - m) + sk * m
sun = Image.new('L', (W, H), 0); ImageDraw.Draw(sun).ellipse((1180 - 40, 300 - 40, 1180 + 40, 300 + 40), fill=255)
sun = np.asarray(sun.filter(ImageFilter.GaussianBlur(6))).astype(np.float32)[..., None] / 255 * m
glow = Image.new('L', (W, H), 0); ImageDraw.Draw(glow).ellipse((1180 - 260, 300 - 160, 1180 + 260, 300 + 160), fill=150)
glow = np.asarray(glow.filter(ImageFilter.GaussianBlur(80))).astype(np.float32)[..., None] / 255
t = t + sun * np.array([1.0, .9, .6]) + glow * np.array([.22, .1, .02])
# o jogo ainda soma o tom de fim de tarde por cima: aqui a pintura fica mais suave (menos vermelho)
tl = t.mean(2, keepdims=True)
t = tl + (t - tl) * .62
t = t * .9 + np.array([.07, .06, .06])
save(t, 'tarde')
# ---------- noite
sk = grad([(0.10, (8, 12, 38)), (0.45, (20, 28, 76)), (0.62, (64, 50, 112))])
rnd = random.Random(7)
st = np.zeros((H, W), np.float32)
for _ in range(420):
    x, y = rnd.randrange(W), rnd.randrange(int(H * .12), int(H * .50))
    st[y, x] = rnd.uniform(.4, 1)
st = np.asarray(Image.fromarray((st * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(.6))).astype(np.float32) / 255 * 1.6
sk = sk + st[..., None]
hb = np.exp(-((yy - 0.56) / 0.05) ** 2)[..., None]
sk = sk + hb * np.array([.35, .22, .12])
# por dentro: aceso, luz quente das luminárias (mais forte perto do teto e do piso encerado)
dentro = a * np.array([.80, .70, .58]) + np.array([.03, .02, .04])
dentro = dentro * (0.82 + 0.18 * lum)
# lá fora: silhuetas azul-escuras (morros, aviões, palmeiras)
fora = a * np.array([.13, .17, .32]) + np.array([.01, .015, .05])
n = dentro * (1 - glass) + fora * glass
n = n * (1 - m) + sk * m
# reflexo do saguão no vidro (um véu quente bem leve) e o Cristo iluminado
n = n + glass * np.array([.035, .025, .01])
cx, cy = int(W * .858), int(H * .48)
h = Image.new('L', (W, H), 0); ImageDraw.Draw(h).ellipse((cx - 46, cy - 60, cx + 46, cy + 40), fill=130)
h = np.asarray(h.filter(ImageFilter.GaussianBlur(26))).astype(np.float32)[..., None] / 255
n = n + h * glass * np.array([.6, .65, .95])
# poças de luz das luminárias no teto
pool = np.zeros((H, W), np.float32)
for lx in range(60, W, 150):
    pool[int(H * .035), lx] = 1
pool = blur(np.asarray(Image.fromarray((pool * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9))).astype(np.float32) / 255, 26)[..., None] * 14
n = n + np.clip(pool, 0, 1) * (1 - glass) * np.array([.22, .17, .08])
save(n, 'noite')
Image.fromarray((glass[..., 0] * 255).astype(np.uint8)).resize((896, 296)).save('/tmp/gig/glass.png')
print('ok')

# ---------- piso do Galeão: o calçadão de ondas pretas e brancas (pedra portuguesa) na faixa de cima
def piso():
    base = Image.open('assets/sprites/chao_vila.png').convert('RGBA')
    Wp, Hp = base.size
    S = 4
    top = 15                                   # altura da faixa de cima (onde se pisa), como no piso de Guarulhos
    arr = np.zeros((top * S, Wp * S, 3), np.float32)
    ys, xs = np.mgrid[0:top * S, 0:Wp * S].astype(np.float32) / S
    # perspectiva: as ondas de trás (em cima) ficam mais apertadas
    v = (ys / top) ** 1.5
    ph = v * 2.6 * np.pi * 2 / 2.0 + 1.25 * np.sin(xs * 2 * np.pi / (Wp / 5.0))
    k = np.sin(ph)
    preto = np.clip(k * 6, -1, 1) * .5 + .5
    pedra = (np.sin(xs * 2.1) * np.sin(ys * 2.7) * .5 + .5) * .06     # granulado das pedrinhas
    claro = np.array([.93, .91, .85]); escuro = np.array([.13, .13, .15])
    arr = claro * (1 - preto[..., None]) + escuro * preto[..., None] + pedra[..., None] - .03
    arr *= (0.86 + 0.14 * (ys / top))[..., None]                      # um pouco mais escuro no fundo
    t = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8)).resize((Wp, top), Image.LANCZOS)
    out = base.copy()
    # frente do piso: pedra clara e quente no lugar do cinza
    f = np.asarray(base.convert('RGB')).astype(np.float32) / 255
    f = f * np.array([1.06, 1.0, .9]) + np.array([.05, .04, .02])
    out = Image.fromarray((np.clip(f, 0, 1) * 255).astype(np.uint8)).convert('RGBA')
    out.putalpha(base.getchannel('A'))
    out.paste(t, (0, 0))
    d = ImageDraw.Draw(out)
    d.rectangle((0, top, Wp, top + 2), fill=(24, 22, 26, 255))        # quina (traço de tinta)
    d.rectangle((0, top + 3, Wp, top + 4), fill=(250, 244, 226, 255)) # filete claro
    # barrado de ondinhas na frente do piso
    for x in range(Wp):
        yw = top + 16 + 3.0 * np.sin(x * 2 * np.pi / (Wp / 10.0))
        d.rectangle((x, yw, x, yw + 3), fill=(40, 38, 44, 255))
    out.save('assets/sprites/chao_gig.png')
piso()
print('piso ok')
