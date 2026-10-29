"""Desenhos feitos em código no mesmo traço das folhas do Gemini (contorno escuro grosso, cor chapada,
uma sombra e um brilho): passageiros, carrinho de bagagem, malas, laser do raio-X, porta de vidro,
ventilador, placa de chão molhado, asas, e as texturas de parede.
Desenha 4x maior e reduz no fim (antisserrilhado)."""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter

OL = (38, 36, 44, 255)          # contorno
S = 4


def rgba(c, a=255):
    if isinstance(c, str):
        c = c.lstrip("#")
        return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), a)
    return c


def mist(c, k, alvo=(0, 0, 0)):
    c = rgba(c)
    return (int(c[0] + (alvo[0] - c[0]) * k), int(c[1] + (alvo[1] - c[1]) * k), int(c[2] + (alvo[2] - c[2]) * k), c[3])


def esc(c, k=.28):
    return mist(c, k)


def cla(c, k=.35):
    return mist(c, k, (255, 255, 255))


class Tela:
    def __init__(s, w, h):
        s.w, s.h = w, h
        s.im = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
        s.d = ImageDraw.Draw(s.im)

    def _p(s, pts):
        return [(x * S, y * S) for x, y in pts]

    def _b(s, b):
        return [b[0] * S, b[1] * S, b[2] * S, b[3] * S]

    def ret(s, b, cor, r=4, ol=OL, lw=2.6):
        s.d.rounded_rectangle(s._b(b), r * S, fill=rgba(cor), outline=ol, width=int(lw * S) if ol else 0)

    def elip(s, b, cor, ol=OL, lw=2.6):
        s.d.ellipse(s._b(b), fill=rgba(cor), outline=ol, width=int(lw * S) if ol else 0)

    def poli(s, pts, cor, ol=OL, lw=2.6):
        s.d.polygon(s._p(pts), fill=rgba(cor) if cor else None, outline=ol, width=int(lw * S) if ol else 0)

    def lin(s, pts, cor=OL, lw=2.6):
        s.d.line(s._p(pts), fill=rgba(cor), width=int(lw * S), joint="curve")
        for x, y in (pts[0], pts[-1]):
            r = lw * S / 2
            s.d.ellipse([x * S - r, y * S - r, x * S + r, y * S + r], fill=rgba(cor))

    def membro(s, a, b, larg, cor):
        """braço/perna: traço grosso com contorno"""
        s.lin([a, b], OL, larg + 5.2)
        s.lin([a, b], cor, larg)

    def pronto(s):
        return s.im.resize((s.w, s.h), Image.LANCZOS)


def sombra_suave(im, k=0.0):
    return im


# ---------------------------------------------------------------- passageiros
PELE = ["#f1c7a0", "#c98d5f", "#8a5a3c", "#e8b48a"]


def passageiro(var, quadro):
    """passageiro de perfil andando para a direita puxando uma mala de rodinhas. 150 x 190 (75 x 95 no mundo)"""
    t = Tela(150, 190)
    v = [
        dict(casaco="#3f6fb5", calca="#2e3550", cabelo="#5a3a22", pele=PELE[0], mala="#c8463d", tipo="curto"),
        dict(casaco="#d9a33a", calca="#4b3b36", cabelo="#1d1a1c", pele=PELE[2], mala="#2f8f8a", tipo="coque"),
        dict(casaco="#7b5aa6", calca="#3a3a44", cabelo="#b8752f", pele=PELE[3], mala="#e0e0e0", tipo="bone"),
    ][var]
    fase = [-1, 1][quadro]
    chao = 186
    # mala de rodinhas atrás (à esquerda)
    mx0, my0 = 8, 118
    t.lin([(46, 104), (30, 122)], "#9aa0a8", 3.2)
    t.ret((mx0, my0, mx0 + 40, my0 + 58), v["mala"], r=6)
    t.ret((mx0 + 4, my0 + 6, mx0 + 12, my0 + 52), esc(v["mala"], .18), r=3, ol=None)
    t.lin([(mx0 + 6, my0 + 22), (mx0 + 34, my0 + 22)], esc(v["mala"], .35), 2)
    t.elip((mx0 + 4, my0 + 54, mx0 + 14, my0 + 64), "#2b2b30")
    t.elip((mx0 + 26, my0 + 54, mx0 + 36, my0 + 64), "#2b2b30")
    # pernas
    q = 70
    t.membro((q, 128), (q - 12 * fase, chao - 8), 13, esc(v["calca"], .15))
    t.membro((q + 8, 128), (q + 8 + 12 * fase, chao - 8), 13, v["calca"])
    for px in (q - 12 * fase, q + 8 + 12 * fase):
        t.ret((px - 9, chao - 13, px + 14, chao - 2), "#2a2526", r=5)
    # braço de trás (puxando a mala)
    t.membro((64, 86), (48, 104), 11, esc(v["casaco"], .2))
    t.elip((42, 99, 54, 111), v["pele"])
    # tronco
    t.ret((52, 70, 98, 134), v["casaco"], r=16)
    t.ret((54, 74, 64, 130), esc(v["casaco"], .16), r=6, ol=None)
    t.lin([(88, 82), (88, 126)], cla(v["casaco"], .25), 2.4)
    t.ret((70, 70, 84, 80), "#f4f1ea", r=4, lw=1.8)       # gola
    # braço da frente balançando
    t.membro((82, 86), (96 + 6 * fase, 116), 11, v["casaco"])
    t.elip((90 + 6 * fase, 110, 103 + 6 * fase, 123), v["pele"])
    # cabeça grande
    cx, cy, r = 80, 44, 31
    t.elip((cx - r, cy - r, cx + r, cy + r + 4), v["pele"])
    t.elip((cx + r - 6, cy - 2, cx + r + 6, cy + 12), esc(v["pele"], .08), lw=2)   # nariz
    t.elip((cx - 16, cy + 2, cx - 4, cy + 16), esc(v["pele"], .1), lw=2)          # orelha
    t.elip((cx + 13, cy - 4, cx + 20, cy + 6), "#24202a", ol=None)                # olho
    t.elip((cx + 15, cy - 3, cx + 17, cy), "#ffffff", ol=None)
    t.lin([(cx + 10, cy - 12), (cx + 22, cy - 13)], esc(v["cabelo"], .1), 2.4)   # sobrancelha
    t.lin([(cx + 14, cy + 20), (cx + 22, cy + 18)], "#7a3b33", 2)                 # boca
    if v["tipo"] == "curto":
        t.poli([(cx - r - 2, cy + 4), (cx - r + 2, cy - 18), (cx - 8, cy - r - 6), (cx + 18, cy - r - 2),
                (cx + r + 2, cy - 14), (cx + 12, cy - 16), (cx - 10, cy - 8), (cx - 14, cy + 6)], v["cabelo"])
    elif v["tipo"] == "coque":
        t.elip((cx - r - 12, cy - r - 10, cx - r + 18, cy - r + 18), v["cabelo"])
        t.poli([(cx - r - 2, cy + 12), (cx - r, cy - 18), (cx - 4, cy - r - 6), (cx + 22, cy - r),
                (cx + r + 2, cy - 12), (cx + 8, cy - 14), (cx - 14, cy - 2), (cx - 18, cy + 14)], v["cabelo"])
    else:
        t.poli([(cx - r - 2, cy - 2), (cx - r + 4, cy - 24), (cx + 6, cy - r - 8), (cx + r, cy - 18), (cx + r + 2, cy - 8)],
               "#2f6b3a")
        t.poli([(cx + r - 10, cy - 12), (cx + r + 20, cy - 8), (cx + r + 18, cy - 2), (cx + r - 8, cy - 4)], esc("#2f6b3a", .2))
        t.poli([(cx - r - 2, cy - 2), (cx - r + 6, cy + 10), (cx - 12, cy + 2)], v["cabelo"], lw=2)
    # brilho no rosto
    t.elip((cx - 4, cy - 20, cx + 10, cy - 12), cla(v["pele"], .4), ol=None)
    return t.pronto()


def carrinho():
    """carrinho de bagagem desgovernado, de perfil (220 x 170 -> 110 x 85 no mundo)"""
    t = Tela(220, 170)
    met = "#a7b0ba"
    # malas empilhadas
    t.ret((40, 52, 132, 108), "#2f8f8a", r=8)
    t.ret((48, 58, 60, 102), esc("#2f8f8a", .18), r=4, ol=None)
    t.lin([(86, 52), (86, 108)], esc("#2f8f8a", .35), 3)
    t.ret((74, 44, 98, 52), "#3a3a40", r=3, lw=2)
    t.ret((60, 6, 150, 54), "#c8463d", r=8)
    t.lin([(64, 30), (146, 30)], esc("#c8463d", .3), 3)
    t.ret((96, 0, 118, 8), "#3a3a40", r=3, lw=2)
    t.ret((132, 66, 176, 108), "#e2b23a", r=7)
    t.ret((140, 72, 150, 104), cla("#e2b23a", .25), r=3, ol=None)
    t.ret((120, 74, 142, 92), "#f5f2e8", r=2, lw=1.6)          # etiqueta
    # estrutura
    t.ret((22, 108, 196, 122), met, r=4)
    t.lin([(186, 116), (204, 20)], OL, 9)
    t.lin([(186, 116), (204, 20)], met, 4.5)
    t.ret((192, 10, 216, 24), "#d33a2f", r=5)                   # pegador vermelho
    t.lin([(30, 122), (24, 140)], OL, 7)
    t.lin([(30, 122), (24, 140)], met, 3)
    for cx in (44, 168):
        t.elip((cx - 22, 124, cx + 22, 168), "#2a2a2e")
        t.elip((cx - 9, 137, cx + 9, 155), "#8e959e", lw=2)
    t.lin([(28, 111), (190, 111)], cla(met, .45), 2)
    return t.pronto()


def mala(cor, alca=True):
    """mala solta (cai da esteira de bagagens): 96 x 76 -> 48 x 38"""
    t = Tela(96, 76)
    t.ret((30, 2, 66, 14), "#3a3a40", r=4, lw=2.2)
    t.ret((4, 10, 92, 72), cor, r=10)
    t.ret((10, 16, 24, 66), esc(cor, .16), r=5, ol=None)
    t.lin([(48, 12), (48, 70)], esc(cor, .32), 3)
    t.ret((60, 26, 84, 44), "#f5f2e8", r=2, lw=1.6)
    t.lin([(64, 32), (80, 32)], "#9a3a32", 1.6)
    t.lin([(64, 38), (76, 38)], "#5a5a62", 1.4)
    t.elip((12, 16, 22, 22), cla(cor, .5), ol=None)
    return t.pronto()


def laser():
    """emissor do raio-X (em cima) e receptor (embaixo): 96 x 56 -> 48 x 28"""
    def caixa(inv):
        t = Tela(96, 56)
        t.ret((4, 4, 92, 46), "#5a6270", r=8)
        for i in range(6):
            x = 10 + i * 14
            t.poli([(x, 8), (x + 7, 8), (x + 1, 20), (x - 6, 20)], "#f2c230", ol=None)
        t.ret((10, 24, 86, 40), "#3c424c", r=5, lw=2)
        t.elip((36, 34, 60, 54), "#e8302a")
        t.elip((42, 38, 50, 44), "#ffb3a8", ol=None)
        im = t.pronto()
        return im.transpose(Image.FLIP_TOP_BOTTOM) if inv else im
    return caixa(False), caixa(True)


def porta_vidro():
    """uma folha da porta automática (vidro com caixilho): 44 x 240 -> 22 x 120"""
    t = Tela(44, 240)
    t.ret((2, 2, 42, 238), "#b9c2cc", r=3)
    t.ret((7, 8, 37, 232), (170, 214, 236, 150), r=2, lw=2)
    t.poli([(9, 70), (35, 30), (35, 52), (9, 92)], (255, 255, 255, 120), ol=None)
    t.poli([(9, 120), (35, 80), (35, 88), (9, 128)], (255, 255, 255, 90), ol=None)
    t.ret((16, 112, 28, 136), "#8b939d", r=3, lw=1.8)
    return t.pronto()


def sensor_porta():
    """caixa do motor da porta com a luz (verde/vermelha): 96 x 40 -> 48 x 20"""
    res = []
    for cor in ("#36c26a", "#e8302a"):
        t = Tela(96, 40)
        t.ret((2, 4, 94, 38), "#8d96a2", r=6)
        t.ret((8, 10, 70, 32), "#6f7885", r=4, lw=2)
        t.elip((74, 12, 90, 28), cor)
        t.elip((78, 15, 83, 20), (255, 255, 255, 170), ol=None)
        res.append(t.pronto())
    return res


def ventilador():
    """grade do ventilador no chão: 168 x 44 -> 84 x 22"""
    t = Tela(168, 44)
    t.ret((2, 6, 166, 42), "#596170", r=6)
    for i in range(9):
        x = 14 + i * 16.5
        t.ret((x, 12, x + 9, 36), "#2a2f38", r=3, lw=1.6)
    t.lin([(8, 9), (160, 9)], cla("#596170", .35), 2)
    return t.pronto()


def placa_molhado():
    """placa amarela de chão molhado: 64 x 96 -> 32 x 48"""
    t = Tela(64, 96)
    t.poli([(14, 92), (26, 6), (38, 6), (50, 92)], "#f2c230")
    t.poli([(20, 80), (29, 14), (35, 14), (44, 80)], cla("#f2c230", .2), ol=None)
    t.poli([(32, 30), (42, 52), (22, 52)], "#2a2a30", lw=1.4)
    t.elip((30, 56, 36, 62), "#2a2a30", ol=None)
    t.lin([(24, 70), (32, 64), (40, 72)], "#2a2a30", 2.2)
    t.ret((22, 2, 42, 10), "#d9a020", r=3, lw=2)
    return t.pronto()


def asas():
    """asas de avião (o poder de planar): 150 x 90 -> 75 x 45"""
    t = Tela(150, 90)
    for sx in (-1, 1):
        cx = 75
        pts = [(cx, 44), (cx + sx * 70, 18), (cx + sx * 72, 30), (cx + sx * 20, 64), (cx, 60)]
        t.poli(pts, "#d7dde4")
        t.poli([(cx + sx * 50, 22), (cx + sx * 70, 18), (cx + sx * 72, 30), (cx + sx * 56, 36)], "#1f7a43", lw=2)
        t.lin([(cx + sx * 12, 52), (cx + sx * 54, 30)], "#9aa4b0", 2.2)
    t.elip((60, 34, 90, 70), "#1f7a43")
    t.elip((66, 40, 78, 50), cla("#1f7a43", .5), ol=None)
    return t.pronto()


def seta(cor="#f2c230"):
    """seta pintada (indicações no chão/parede): 60 x 60"""
    t = Tela(60, 60)
    t.poli([(8, 22), (34, 22), (34, 8), (56, 30), (34, 52), (34, 38), (8, 38)], cor, lw=2.4)
    return t.pronto()


# ---------------------------------------------------------------- texturas de parede (emendáveis)
def _ruido(im, amp=10, seed=1):
    rnd = random.Random(seed)
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            n = rnd.randint(-amp, amp)
            px[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)), a)
    return im


def parede_terminal():
    im = Image.new("RGBA", (160, 160), rgba("#c9c2b4"))
    d = ImageDraw.Draw(im)
    for y in (0, 80):
        d.rectangle([0, y, 160, y + 3], fill=rgba("#a69e8f"))
        d.rectangle([0, y + 4, 160, y + 6], fill=rgba("#ddd7cb"))
    for (x, y) in ((0, 4), (80, 84)):
        d.rectangle([x, y, x + 2, y + 76], fill=rgba("#a69e8f"))
    for (x, y) in ((40, 30), (120, 110), (100, 40), (20, 120)):
        d.ellipse([x, y, x + 3, y + 3], fill=rgba("#b3ab9c"))
    return _ruido(im, 5, 2)


def parede_metal():
    im = Image.new("RGBA", (160, 160), rgba("#525a66"))
    d = ImageDraw.Draw(im)
    for y in (0, 80):
        d.rectangle([0, y, 160, y + 3], fill=rgba("#383e48"))
        d.rectangle([0, y + 4, 160, y + 5], fill=rgba("#6b7482"))
        for x in range(10, 160, 36):
            d.ellipse([x, y + 10, x + 6, y + 16], fill=rgba("#3a404a"))
            d.ellipse([x + 1, y + 10, x + 4, y + 13], fill=rgba("#7d8796"))
    for x in (0, 80):
        d.rectangle([x, 0, x + 2, 160], fill=rgba("#40464f"))
    return _ruido(im, 6, 3)


def parede_aderente():
    """parede onde o Milis corre: borracha verde (cor da Milhas Plus) com setas amarelas para cima"""
    im = Image.new("RGBA", (80, 160), rgba("#1f6b3d"))
    d = ImageDraw.Draw(im)
    for y in range(0, 160, 10):
        for x in range(5 + (y // 10 % 2) * 5, 80, 10):
            d.ellipse([x - 2, y + 3, x + 2, y + 7], fill=rgba("#185632"))
    for y0 in (14, 94):
        pts = [(40, y0), (66, y0 + 26), (54, y0 + 26), (40, y0 + 12), (26, y0 + 26), (14, y0 + 26)]
        d.polygon(pts, fill=rgba("#f2c230"))
        d.line(pts + [pts[0]], fill=rgba("#2a2a20"), width=2)
    d.rectangle([0, 0, 5, 160], fill=rgba("#2a8a52"))
    d.rectangle([75, 0, 80, 160], fill=rgba("#16502e"))
    return _ruido(im, 5, 4)


def parede_concreto():
    im = Image.new("RGBA", (160, 160), rgba("#6c6e72"))
    d = ImageDraw.Draw(im)
    for y in (0, 80):
        d.rectangle([0, y, 160, y + 2], fill=rgba("#55575b"))
    for x in (40, 120):
        d.rectangle([x, 0, x + 2, 80], fill=rgba("#55575b"))
    for x in (0, 80):
        d.rectangle([x, 80, x + 2, 160], fill=rgba("#55575b"))
    return _ruido(im, 9, 5)


def enchimentos(OUT, IDX):
    for n, f in (("parede_terminal", parede_terminal), ("parede_metal", parede_metal),
                 ("parede_aderente", parede_aderente), ("parede_concreto", parede_concreto)):
        im = f()
        im.save(os.path.join(OUT, n + ".png"))
        IDX[n] = {"file": n + ".png", "w": im.width, "h": im.height, "n": 1, "ax": 0, "ay": 0, "fps": 1}


def _salva(OUT, IDX, nome, ims, ax=None, ay=None, fps=6):
    ims = ims if isinstance(ims, list) else [ims]
    W = max(i.width for i in ims)
    H = max(i.height for i in ims)
    tira = Image.new("RGBA", (W * len(ims), H), (0, 0, 0, 0))
    for n, i in enumerate(ims):
        tira.alpha_composite(i, (n * W + (W - i.width) // 2, H - i.height))
    tira.save(os.path.join(OUT, nome + ".png"))
    IDX[nome] = {"file": nome + ".png", "w": W, "h": H, "n": len(ims),
                 "ax": W / 2 if ax is None else ax, "ay": H if ay is None else ay, "fps": fps}


def todos(OUT, IDX):
    for v in range(3):
        _salva(OUT, IDX, "passageiro%d" % v, [passageiro(v, 0), passageiro(v, 1)], 80, 186, fps=5)
    _salva(OUT, IDX, "carrinho", carrinho(), 110, 168)
    _salva(OUT, IDX, "malas", [mala("#c8463d"), mala("#2f8f8a"), mala("#e2b23a"), mala("#5b6bb0")], 48, 38)
    e, r = laser()
    _salva(OUT, IDX, "laser_emissor", e, 48, 0)
    _salva(OUT, IDX, "laser_receptor", r, 48, 56)
    _salva(OUT, IDX, "porta_vidro", porta_vidro(), 0, 0)
    _salva(OUT, IDX, "porta_sensor", sensor_porta(), 48, 40)
    _salva(OUT, IDX, "ventilador", ventilador(), 84, 44)
    _salva(OUT, IDX, "placa_molhado", placa_molhado(), 32, 96)
    _salva(OUT, IDX, "asas", asas(), 75, 45)
    _salva(OUT, IDX, "seta", seta(), 30, 30)


if __name__ == "__main__":
    os.makedirs("/tmp/claude-0/des", exist_ok=True)
    idx = {}
    todos("/tmp/claude-0/des", idx)
    enchimentos("/tmp/claude-0/des", idx)
