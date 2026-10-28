"""Mascote da Milhas Plus: capacete branco, visor preto com olhos de LED, fones, moletom verde,
mochila marrom. Gera:
  mascote_corpo.png   folha de poses de lado (sem a cabeça)  + mascote_corpo.json (onde vai a cabeça)
  mascote_cabeca.png  folha de expressões (cabeça de lado, 3/4)
  mascote_costas.png  folha de poses de costas (para o trem)
  mascote_rola.png    bola rolando (o jogo gira)
"""
import json, math, os
from arte import Tela, folha, cor, escurecer, clarear, SPR, TINTA

W = H = 256
HIP = (124, 198)
BRANCO, BRANCO_S = "#f7f6f2", "#cfd4da"
VERDE, VERDE_S, VERDE_E = "#1d7a45", "#13592f", "#0f4726"
MARROM, MARROM_S = "#8f5226", "#6a3a19"
PRETO = "#17181b"
LED = "#ffc85a"


def rot(p, c, a):
    x, y = p[0] - c[0], p[1] - c[1]
    return (c[0] + x * math.cos(a) - y * math.sin(a), c[1] + x * math.sin(a) + y * math.cos(a))


def perna(t, quadril, ang_coxa, dobra, cor_b=BRANCO, cor_sap=PRETO, atras=False):
    c1 = 25; c2 = 24
    joelho = (quadril[0] + math.sin(ang_coxa) * c1, quadril[1] + math.cos(ang_coxa) * c1)
    a2 = ang_coxa - dobra
    pe = (joelho[0] + math.sin(a2) * c2, joelho[1] + math.cos(a2) * c2)
    b = escurecer(cor_b, 0.12) if atras else cor_b
    t.traco([quadril, joelho, pe], 21, b)
    # sapato
    c = t.c; c.save(); c.translate(*pe); c.rotate(-a2 * 0.5)
    t.rret(-12, -4, 34, 15, 7); t.pintar(cor_sap)
    t.rret(-12, 7, 34, 5, 2.5); t.pintar("#ffffff" if not atras else "#d9dbe0", lw=3)
    c.restore()
    return pe


def braco(t, ombro, ang, cotovelo=0.0, atras=False, joinha=False):
    c1 = 22; c2 = 20
    m1 = (ombro[0] + math.sin(ang) * c1, ombro[1] + math.cos(ang) * c1)
    a2 = ang + cotovelo
    mao = (m1[0] + math.sin(a2) * c2, m1[1] + math.cos(a2) * c2)
    v = VERDE_S if atras else VERDE
    t.traco([ombro, m1, mao], 19, v)
    # punho branco
    pu = (m1[0] + math.sin(a2) * (c2 - 4), m1[1] + math.cos(a2) * (c2 - 4))
    t.traco([pu, mao], 19, BRANCO_S if atras else BRANCO, lw=4)
    luva = (mao[0] + math.sin(a2) * 9, mao[1] + math.cos(a2) * 9)
    t.elipse(luva[0], luva[1], 12, 12); t.pintar(PRETO)
    if joinha:
        t.rret(luva[0] - 4, luva[1] - 24, 9, 18, 4.5); t.pintar(PRETO)
    else:
        t.elipse(luva[0] + 8 * math.cos(a2), luva[1] - 6 * math.sin(a2) - 4, 5, 5); t.pintar(PRETO, lw=3)
    t.brilho(luva[0] - 3, luva[1] - 4, 4, 2.5, 0.35)


def asas(t, abertura=1.0, bater=0.0):
    c = t.c
    for lado, a, esc in [(-1, -0.15 + bater, 0.82), (1, 0.05 - bater, 1.0)]:
        c.save(); c.translate(84, 150); c.rotate(a); c.scale(esc * abertura, esc)
        t.curva([(0, -6), (-30, -40), (-98, -58), (-108, -44), (-60, -14), (-4, 10)], True)
        t.pintar(BRANCO if lado > 0 else BRANCO_S)
        t.curva([(-86, -54), (-108, -46), (-104, -38), (-82, -40)], True); t.pintar("#f6c84a", lw=3.5)
        t.linha([(-20, -14), (-80, -40)], 3, "#b9c0c8")
        c.restore()


def tronco(t, bob):
    c = t.c
    y0 = 126 + bob
    # mochila (atrás)
    t.rret(60, y0 + 4, 40, 70, 12); t.pintar(MARROM)
    t.sombra_em(lambda: t.rret(60, y0 + 4, 40, 70, 12), lambda: t.c.rectangle(60, y0 + 46, 40, 40), MARROM_S)
    t.rret(60, y0 + 4, 40, 70, 12); t.pintar(None)
    t.rret(56, y0 + 8, 30, 26, 9); t.pintar(MARROM_S, lw=4)
    t.rret(62, y0 + 44, 24, 20, 6); t.pintar(escurecer(MARROM, 0.1), lw=3.5)
    # capuz atrás do pescoço
    t.elipse(110, y0 + 4, 32, 13); t.pintar(VERDE_S)
    # corpo do moletom
    pts = [(96, y0 + 6), (128, y0 + 1), (152, y0 + 8), (164, y0 + 40), (163, y0 + 76), (126, y0 + 82), (90, y0 + 78), (86, y0 + 40)]
    forma = lambda: t.curva(pts)
    forma(); t.pintar(VERDE, contorno=False)
    t.sombra_em(forma, lambda: (t.c.rectangle(80, y0 + 62, 100, 30)), VERDE_S)
    t.sombra_em(forma, lambda: t.elipse(84, y0 + 40, 14, 50), VERDE_S)
    forma(); t.pintar(None)
    # barra
    t.sombra_em(forma, lambda: t.c.rectangle(80, y0 + 68, 100, 20), VERDE_E)
    t.linha([(92, y0 + 69), (160, y0 + 67)], 3, TINTA)
    # bolso canguru
    t.curva([(124, y0 + 50), (156, y0 + 48), (158, y0 + 64), (122, y0 + 66)], True); t.pintar(VERDE_S, lw=3.5)
    # logo Milhas Plus no peito
    for i, (dx, dy) in enumerate([(0, 0), (9, 0), (0, 9), (9, 9)]):
        t.rret(124 + dx, y0 + 22 + dy, 8, 8, 1.5); t.pintar("#f6c84a", lw=1.6)
    t.texto("MILHAS", 151, y0 + 26, 8, "#ffffff")
    t.texto("PLUS", 149, y0 + 36, 10, "#ffffff")
    # cordões
    for dx in (0, 9):
        t.linha([(128 + dx, y0 + 6), (126 + dx, y0 + 20)], 3, "#ffffff")
    # alça da mochila
    t.traco([(106, y0 + 4), (112, y0 + 40), (108, y0 + 76)], 9, MARROM, lw=3.5)
    t.rret(104, y0 + 34, 14, 9, 2); t.pintar("#c9a26a", lw=2.5)


def pose_corpo(p):
    """p: dict com coxa/joelho/bracos/bob/inclina/asas/joinha."""
    t = Tela(W, H); c = t.c
    bob = p.get("bob", 0); lean = p.get("inclina", 0.0)
    hip = (HIP[0], HIP[1] + bob)
    # perna de trás
    c.save(); t.girar(hip[0], hip[1], lean * 0.3)
    perna(t, (hip[0] - 6, hip[1]), p["coxa"][1], p["joelho"][1], atras=True)
    c.restore()
    c.save(); t.girar(hip[0], hip[1], lean)
    braco(t, (112, 140 + bob), p["braco"][1], p.get("cotovelo", (0, 0))[1], atras=True)
    if p.get("asas"): asas(t, 1.0, p.get("bater", 0.0))
    tronco(t, bob)
    c.restore()
    perna(t, (hip[0] + 8, hip[1]), p["coxa"][0], p["joelho"][0])
    c.save(); t.girar(hip[0], hip[1], lean)
    braco(t, (130, 140 + bob), p["braco"][0], p.get("cotovelo", (0, 0))[0], joinha=p.get("joinha", False))
    c.restore()
    pesc = rot((124, 128 + bob), hip, lean)
    return t, pesc


def poses():
    P = []
    for i in range(8):  # corrida
        f = i / 8 * 2 * math.pi
        s = math.sin(f)
        P.append(dict(nome="corre%d" % i, coxa=(0.85 * s, -0.85 * s),
                      joelho=(max(0, -math.cos(f)) * 1.3 + 0.15, max(0, math.cos(f)) * 1.3 + 0.15),
                      braco=(-1.0 * s - 0.2, 1.0 * s - 0.2), cotovelo=(-0.9, -0.9), bob=-abs(math.cos(f)) * 6 + 3, inclina=0.12))
    P.append(dict(nome="sobe", coxa=(0.9, -0.5), joelho=(1.4, 0.4), braco=(-2.6, -2.2), cotovelo=(-0.3, -0.3), bob=-2, inclina=0.05))
    P.append(dict(nome="cai", coxa=(0.4, -0.3), joelho=(0.6, 0.5), braco=(-1.9, 2.0), cotovelo=(0.4, 0.2), bob=0, inclina=-0.05))
    for k in range(2):
        P.append(dict(nome="plana%d" % k, coxa=(0.5, -0.2), joelho=(0.9, 0.6), braco=(-1.55, -1.45), cotovelo=(0, 0), bob=0, inclina=0.08,
                      asas=True, bater=0.08 if k == 0 else -0.06))
    P.append(dict(nome="dash", coxa=(1.1, -1.0), joelho=(0.4, 1.2), braco=(1.3, 1.0), cotovelo=(-0.5, -0.5), bob=4, inclina=0.32))
    P.append(dict(nome="tropeca", coxa=(-0.4, 0.5), joelho=(0.3, 0.6), braco=(-2.7, 2.6), cotovelo=(0.5, 0.5), bob=-4, inclina=-0.28))
    P.append(dict(nome="vitoria", coxa=(0.1, -0.1), joelho=(0.1, 0.1), braco=(-2.9, 0.3), cotovelo=(-0.6, -0.4), bob=0, inclina=0.0, joinha=True))
    P.append(dict(nome="parado", coxa=(0.08, -0.08), joelho=(0.05, 0.05), braco=(0.25, -0.2), cotovelo=(-0.4, -0.4), bob=0, inclina=0.0))
    return P


# --------------------------------------------------------------------------- cabeça
def mascara_olhos(tipo, x, y, ox, oy, esc):
    """Retorna True se o pontinho (x,y) acende para a expressão, olho centrado em (ox,oy)."""
    dx, dy = (x - ox) / esc, (y - oy) / esc
    d = math.hypot(dx, dy)
    if tipo == "feliz": return abs(math.hypot(dx, dy - 9) - 12) < 3.6 and dy < 5
    if tipo == "x": return abs(abs(dx) - abs(dy)) < 3.2 and abs(dx) < 10
    if tipo == "susto": return abs(d - 11) < 3.0
    if tipo == "foco": return abs(dx) < 12 and abs(dy) < 3.6
    if tipo == "pisca": return abs(dx) < 11 and abs(dy) < 2.2
    return d < 10.5   # aberto


def cabeca(tipo="aberto", costas=False):
    t = Tela(170, 160); c = t.c
    cx, cy, rx, ry = 85, 76, 64, 58
    if costas:
        for sx in (-1, 1):
            t.elipse(cx + sx * 62, cy + 8, 14, 24); t.pintar(BRANCO)
            t.elipse(cx + sx * 64, cy + 8, 7, 14); t.pintar(PRETO, lw=3)
    forma = lambda: t.elipse(cx, cy, rx, ry)
    forma(); t.pintar(BRANCO, contorno=False)
    def sombra():
        c.rectangle(0, 0, 170, 160); t.elipse(cx + 8 if not costas else cx, cy - 8, rx - 2, ry - 4)
        c.set_fill_rule(1)
    c.save(); forma(); c.clip(); sombra(); c.set_source_rgba(*cor(BRANCO_S)); c.fill(); c.restore(); c.set_fill_rule(0)
    forma(); t.pintar(None, lw=5.5)
    t.brilho(cx - 22, cy - 38, 16, 8, 0.85, -0.4)
    if costas:
        # arco dos fones por cima
        t.curva([(cx - 62, cy - 8), (cx - 40, cy - 58), (cx, cy - 66), (cx + 40, cy - 58), (cx + 62, cy - 8)], False)
        c.set_source_rgba(*cor(PRETO)); c.set_line_width(9); c.stroke()
        return t
    # visor
    vx, vy, vrx, vry = cx + 11, cy + 4, 46, 39
    visor = lambda: t.elipse(vx, vy, vrx, vry)
    visor(); t.gradiente(vx, vy - vry, vx, vy + vry, [(0, "#30343b"), (0.45, "#141519"), (1, "#0b0b0d")], contorno=True, lw=4.5)
    # olhos de LED
    for (ox, oy, esc) in [(vx - 15, vy + 2, 1.0), (vx + 19, vy + 2, 0.86)]:
        for gy in range(int(oy - 16), int(oy + 17), 4):
            for gx in range(int(ox - 16), int(ox + 17), 4):
                if mascara_olhos(tipo, gx, gy, ox, oy, esc):
                    g = __import__("cairo").RadialGradient(gx, gy, 0, gx, gy, 5)
                    g.add_color_stop_rgba(0, 1, 0.62, 0.15, 0.55); g.add_color_stop_rgba(1, 1, 0.5, 0.1, 0)
                    c.set_source(g); c.arc(gx, gy, 5, 0, 6.3); c.fill()
                    c.set_source_rgba(*cor(LED)); c.arc(gx, gy, 1.7, 0, 6.3); c.fill()
    # reflexo do visor
    c.save(); visor(); c.clip()
    t.curva([(vx - 36, vy - 10), (vx - 22, vy - 32), (vx + 6, vy - 37)], False); c.set_source_rgba(1, 1, 1, 0.33); c.set_line_width(5); c.stroke()
    c.restore()
    # fone do lado visível + arco
    t.curva([(cx - 40, cy - 22), (cx - 40, cy - 62), (cx + 10, cy - 70), (cx + 40, cy - 56)], False)
    c.set_source_rgba(*cor(TINTA)); c.set_line_width(12); c.stroke()
    t.curva([(cx - 40, cy - 22), (cx - 40, cy - 62), (cx + 10, cy - 70), (cx + 40, cy - 56)], False)
    c.set_source_rgba(*cor("#2b2e33")); c.set_line_width(6); c.stroke()
    t.elipse(cx - 40, cy + 2, 22, 27); t.pintar(BRANCO)
    t.elipse(cx - 40, cy + 2, 15, 19); t.pintar(PRETO, lw=3)
    t.elipse(cx - 40, cy + 2, 7, 10); t.pintar("#9aa1a9", lw=2.5)
    t.brilho(cx - 46, cy - 14, 5, 3, 0.8)
    return t


def costas(fase, pulo=False):
    """Mascote de costas (o jogador vê a mochila). Pés no fundo do quadro."""
    t = Tela(W, H); c = t.c
    s = math.sin(fase)
    bob = -abs(math.cos(fase)) * 6 + 3 if not pulo else -6
    # pernas
    for lado in (-1, 1):
        lev = (s * lado) if not pulo else 0.7
        y_pe = 246 - max(0, lev) * 22 + bob * 0.3
        x = 128 + lado * 20
        t.traco([(x, 196 + bob), (x, y_pe - 8)], 22, BRANCO)
        t.rret(x - 15, y_pe - 12, 30, 16, 7); t.pintar(PRETO)
        t.rret(x - 13, y_pe - 1, 26, 5, 2); t.pintar("#ffffff", lw=2.5)
    # braços
    for lado in (-1, 1):
        a = (-s * lado) * 0.7 if not pulo else -2.4
        ombro = (128 + lado * 40, 142 + bob)
        mao = (ombro[0] + lado * 10 + math.sin(a) * 2, ombro[1] + 40 * math.cos(a) - (0 if not pulo else 0))
        if pulo: mao = (ombro[0] + lado * 26, ombro[1] - 36)
        else: mao = (ombro[0] + lado * 8, ombro[1] + 34 + 10 * math.sin(a))
        t.traco([ombro, mao], 19, VERDE)
        t.elipse(mao[0], mao[1] + (6 if not pulo else -6), 12, 12); t.pintar(PRETO)
    # corpo
    y0 = 124 + bob
    forma = lambda: t.curva([(92, y0 + 8), (128, y0), (164, y0 + 8), (172, y0 + 44), (166, y0 + 80), (128, y0 + 86), (90, y0 + 80), (84, y0 + 44)])
    forma(); t.pintar(VERDE, contorno=False)
    t.sombra_em(forma, lambda: c.rectangle(70, y0 + 66, 120, 30), VERDE_S); forma(); t.pintar(None)
    # capuz
    t.curva([(104, y0 + 2), (128, y0 - 4), (152, y0 + 2), (146, y0 + 22), (110, y0 + 22)]); t.pintar(VERDE_S, lw=4)
    # mochila grande
    t.rret(100, y0 + 18, 56, 62, 14); t.pintar(MARROM)
    t.sombra_em(lambda: t.rret(100, y0 + 18, 56, 62, 14), lambda: c.rectangle(100, y0 + 60, 56, 30), MARROM_S)
    t.rret(100, y0 + 18, 56, 62, 14); t.pintar(None)
    t.rret(104, y0 + 16, 48, 24, 10); t.pintar(MARROM_S, lw=4)
    t.rret(122, y0 + 34, 12, 8, 2); t.pintar("#c9a26a", lw=2.5)
    t.rret(110, y0 + 52, 36, 20, 6); t.pintar(escurecer(MARROM, 0.1), lw=3.5)
    for lado in (-1, 1):
        t.linha([(128 + lado * 24, y0 + 6), (128 + lado * 26, y0 + 22)], 7, MARROM_S)
    # cabeça de costas
    cab = cabeca(costas=True)
    c.set_source_surface(cab.s, 128 - 85, y0 - 122); c.paint()
    return t


def bola():
    t = Tela(W, H); c = t.c
    cx, cy = 128, 140
    t.elipse(cx - 30, cy + 6, 26, 40); t.pintar(MARROM)  # mochila
    t.elipse(cx, cy + 12, 58, 50); t.pintar(VERDE)
    t.sombra_em(lambda: t.elipse(cx, cy + 12, 58, 50), lambda: c.rectangle(cx - 60, cy + 30, 120, 40), VERDE_S)
    t.elipse(cx, cy + 12, 58, 50); t.pintar(None)
    t.elipse(cx + 36, cy + 40, 18, 12); t.pintar(PRETO)  # sapatos encolhidos
    t.elipse(cx - 8, cy + 50, 18, 12); t.pintar(PRETO)
    cab = cabeca("foco")
    c.save(); c.translate(cx + 14, cy - 34); c.scale(0.8, 0.8); c.set_source_surface(cab.s, -85, -80); c.paint(); c.restore()
    t.elipse(cx + 40, cy + 2, 12, 12); t.pintar(PRETO)
    return t


if __name__ == "__main__":
    quadros, pesc = [], []
    nomes = []
    for p in poses():
        t, n = pose_corpo(p); quadros.append(t); pesc.append([round(n[0], 1), round(n[1], 1)]); nomes.append(p["nome"])
    folha(quadros, "mascote_corpo.png")
    exprs = ["aberto", "feliz", "x", "susto", "foco", "pisca"]
    folha([cabeca(e) for e in exprs], "mascote_cabeca.png")
    folha([costas(i / 4 * 2 * math.pi) for i in range(4)] + [costas(0, True)], "mascote_costas.png")
    bola().salvar("mascote_rola.png")
    meta = {"quadro": [W, H], "pe": [124, 248], "poses": nomes, "pescoco": pesc,
            "cabeca": {"quadro": [170, 160], "ancora": [80, 130], "expressoes": exprs}, "costas": ["corre0", "corre1", "corre2", "corre3", "pulo"]}
    json.dump(meta, open(os.path.join(SPR, "mascote.json"), "w"), indent=1)
    print("ok", len(quadros), "poses")
