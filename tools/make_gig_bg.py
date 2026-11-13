"""Gera assets/bg/gig_dia/tarde/noite.jpg a partir de tools/art_src/gig_dia.png."""
import random
from PIL import Image, ImageFilter, ImageDraw, ImageChops
import numpy as np
W, H = 1792, 592
src = Image.open('tools/art_src/gig_dia.png').convert('RGB').resize((W, H), Image.LANCZOS)
a = np.asarray(src).astype(np.float32) / 255.0
r, g, b = a[..., 0], a[..., 1], a[..., 2]
yy = np.repeat(np.arange(H)[:, None], W, 1) / H
# céu: azul claro nas vidraças (faixa do meio)
sky = ((b - r) > 0.12) & (b > 0.88) & (g > 0.80) & (yy > 0.12) & (yy < 0.62)
m = Image.fromarray((sky * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(1.5))
m = np.asarray(m).astype(np.float32)[..., None] / 255.0
# vidro (tudo atrás das vidraças, para tingir a paisagem): faixa 0.12-0.80 e não-piso
win = np.zeros((H, W), np.float32)
win[int(H*.14):int(H*.78)] = 1
win = np.asarray(Image.fromarray((win*255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(20))).astype(np.float32)[..., None]/255

def grad(stops):
    out = np.zeros((H, W, 3), np.float32)
    ys = np.arange(H) / H
    for i in range(3):
        out[:, :, i] = np.interp(ys, [s[0] for s in stops], [s[1][i] / 255 for s in stops])[:, None]
    return out

def save(arr, name):
    Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8)).save('assets/bg/gig_%s.jpg' % name, quality=90)

save(a, 'dia')
# ---------- tarde: céu laranja-rosa, luz quente, sombras lilás
sk = grad([(0.10, (255, 150, 90)), (0.35, (255, 120, 110)), (0.50, (255, 190, 120)), (0.62, (255, 215, 150))])
warm = a * np.array([1.08, 0.88, 0.70]) + np.array([0.06, 0.02, 0.0])
lum = a.mean(2, keepdims=True)
warm = warm * (0.75 + 0.25 * lum) + (1 - lum) * np.array([0.04, 0.0, 0.08])
# paisagem atrás do vidro mais alaranjada
warm = warm * (1 - win * .25) + win * .25 * (warm * np.array([1.1, .8, .65]))
t = warm * (1 - m) + sk * m
# sol baixo no horizonte
sun = Image.new('L', (W, H), 0); d = ImageDraw.Draw(sun)
d.ellipse((1180 - 40, 300 - 40, 1180 + 40, 300 + 40), fill=255)
sun = np.asarray(sun.filter(ImageFilter.GaussianBlur(6))).astype(np.float32)[..., None] / 255 * m
glow = Image.new('L', (W, H), 0); ImageDraw.Draw(glow).ellipse((1180 - 260, 300 - 160, 1180 + 260, 300 + 160), fill=150)
glow = np.asarray(glow.filter(ImageFilter.GaussianBlur(80))).astype(np.float32)[..., None] / 255
t = t + sun * np.array([1.0, .9, .6]) + glow * np.array([.25, .12, .02])
save(t, 'tarde')
# ---------- noite: céu azul-marinho com estrelas, interior escurecido, luzes acesas
sk = grad([(0.10, (8, 12, 38)), (0.45, (22, 30, 78)), (0.62, (60, 50, 110))])
rnd = random.Random(7)
st = np.zeros((H, W), np.float32)
for _ in range(500):
    x, y = rnd.randrange(W), rnd.randrange(int(H*.12), int(H*.50))
    st[y, x] = rnd.uniform(.4, 1)
st = np.asarray(Image.fromarray((st*255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(.6))).astype(np.float32)/255*1.6
sk = sk + st[..., None]
dark = a * np.array([0.42, 0.45, 0.62])
# paisagem lá fora bem escura e azulada
dark = dark * (1 - win * .45) + win * .45 * (a * np.array([.18, .22, .40]))
n = dark * (1 - m) + sk * m
# brilho de cidade no horizonte (só onde é céu, perto da linha do horizonte)
hb = np.exp(-((yy - 0.56) / 0.05) ** 2)[..., None]
n = n + hb * m * np.array([.35, .22, .12])
# Cristo iluminado (lado direito, ~x 0.86) — halo
cx, cy = int(W*.858), int(H*.48)
h = Image.new('L', (W, H), 0); ImageDraw.Draw(h).ellipse((cx-60, cy-70, cx+60, cy+50), fill=120)
h = np.asarray(h.filter(ImageFilter.GaussianBlur(30))).astype(np.float32)[..., None]/255
n = n + h * np.array([.55, .6, .9])
# luminárias do teto e piso com reflexo quente
ceil = grad([(0.0, (70, 55, 30)), (0.15, (20, 15, 5)), (0.3, (0, 0, 0)), (0.85, (0, 0, 0)), (1.0, (40, 30, 15))])
n = n + ceil
save(n, 'noite')
print('ok')
