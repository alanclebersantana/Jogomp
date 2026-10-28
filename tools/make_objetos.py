"""Obstáculos, objetos e decoração do aeroporto (132 px por metro, ponto de apoio no meio da base).
Gera também objetos.json com o tamanho de cada imagem em metros."""
import json, math, os
from arte import Tela, folha, cor, escurecer, clarear, SPR, TINTA

A = 132
META = {}
LATAM, LATAM2 = "#E8114B", "#1B0088"


def nova(nome, w_m, h_m, px_m=A, margem=10):
    t = Tela(int(w_m * px_m) + margem * 2, int(h_m * px_m) + margem * 2)
    t.m = margem; t.pxm = px_m; t.nome = nome
    t.W = int(w_m * px_m); t.Hh = int(h_m * px_m)
    t.base = t.h - margem
    return t


def fim(t, nome=None, quadros=1):
    nome = nome or t.nome
    t.salvar(nome + ".png")
    META[nome] = {"w": t.w / t.pxm / quadros, "h": t.h / t.pxm, "pxm": t.pxm, "base": (t.h - t.base) / t.pxm, "quadros": quadros}


def fim_folha(qs, nome):
    folha(qs, nome + ".png")
    t = qs[0]
    META[nome] = {"w": t.w / t.pxm, "h": t.h / t.pxm, "pxm": t.pxm, "base": (t.h - t.base) / t.pxm, "quadros": len(qs)}


def mala():
    # branca: o jogo pinta com a cor da fase (modulate)
    t = nova("mala", 0.9, 0.95); m, b = t.m, t.base
    w, h = t.W, int(0.75 * A)
    t.rret(m + w / 2 - 22, b - h - 22, 44, 30, 9); t.pintar(None, lw=8)
    t.rret(m, b - h, w, h, 16); t.pintar("#f4f4f4")
    t.sombra_em(lambda: t.rret(m, b - h, w, h, 16), lambda: t.c.rectangle(m, b - h * 0.35, w, h), "#c8ccd2")
    t.rret(m, b - h, w, h, 16); t.pintar(None)
    for x in (m + w * 0.3, m + w * 0.7):
        t.linha([(x, b - h + 6), (x, b - 6)], 9, "#26282c")
        t.rret(x - 8, b - h * 0.55, 16, 14, 3); t.pintar("#c9a26a", lw=3)
    t.rret(m + w * 0.78, b - h * 0.85, 16, 24, 3); t.pintar("#fcc352", lw=3)  # etiqueta
    t.brilho(m + 22, b - h + 16, 12, 5, 0.7)
    fim(t)


def fita():
    t = nova("fita", 1.85, 1.0); m, b = t.m, t.base
    for x in (m + 10, m + t.W - 10):
        t.elipse(x, b - 5, 22, 7); t.pintar("#6f7a84")
        t.rret(x - 6, b - 0.95 * A, 12, 0.95 * A - 4, 5); t.pintar("#c7ced5")
        t.elipse(x, b - 0.95 * A, 11, 8); t.pintar("#9aa4ad")
    t.rret(m + 14, b - 0.95 * A + 6, t.W - 28, 16, 3); t.pintar(LATAM2)
    t.linha([(m + 20, b - 0.95 * A + 14), (m + t.W - 20, b - 0.95 * A + 14)], 2, "#ffffff", 0.6)
    fim(t)


def balcao():
    t = nova("balcao", 3.6, 2.4); m, b = t.m, t.base
    W, h = 3.2 * A, 1.2 * A
    x0 = m + 0.2 * A
    # atendente atrás
    from make_pessoas import humano
    at = humano(dict(coxa=(0, 0), joelho=(0, 0), braco=(1.2, 0.4), cotovelo=(-1.6, -0.5)), camisa=LATAM2, calca=LATAM2, pele="#e8b48c",
                cabelo="#7a4320", estilo="longo", lenco=LATAM, boca="sorriso")
    t.c.set_source_surface(at.s, x0 + W * 0.25 - 110, b - h - 150); t.c.paint()
    # monitor e balança
    t.rret(x0 + W * 0.62, b - h - 70, 70, 52, 6); t.pintar("#2b2f35"); t.rret(x0 + W * 0.62 + 6, b - h - 64, 58, 40, 3); t.pintar("#5fb7e8", lw=2)
    t.rret(x0 + W * 0.62 + 30, b - h - 18, 10, 18, 2); t.pintar("#2b2f35")
    # tampo e frente
    t.rret(x0 - 8, b - h - 12, W + 16, 18, 6); t.pintar("#0d4a2b")
    f = lambda: t.rret(x0, b - h, W, h, 10)
    f(); t.pintar("#eef1f4", contorno=False)
    t.sombra_em(f, lambda: t.c.rectangle(x0, b - h * 0.3, W, h), "#c9d0d7"); f(); t.pintar(None)
    t.rret(x0 + W * 0.12, b - h * 0.78, W * 0.76, h * 0.34, 8); t.pintar(LATAM2, lw=4)
    t.caber_texto("CHECK-IN", x0 + W / 2, b - h * 0.61, W * 0.66, h * 0.24)
    t.rret(x0, b - 10, W, 10, 3); t.pintar("#7c8791", lw=3)
    fim(t)


def carrinho():
    t = nova("carrinho", 1.9, 1.5); m, b = t.m, t.base
    W = 1.8 * A
    x0 = m
    for x in (x0 + 24, x0 + W - 24):
        t.elipse(x, b - 14, 14, 14); t.pintar("#26282c"); t.elipse(x, b - 14, 5, 5); t.pintar("#9aa1a9", lw=2)
    t.rret(x0 + 4, b - 40, W - 8, 12, 4); t.pintar("#9aa3ab")
    t.traco([(x0 + 10, b - 40), (x0 + 4, b - 1.45 * A), (x0 + 30, b - 1.45 * A)], 8, "#9aa3ab")
    cores = ["#d9453b", "#3a8fd8", "#2e9e6a", "#8e44ad"]
    y = b - 40
    for i, (wf, hf) in enumerate([(0.88, 0.32), (0.7, 0.28), (0.55, 0.24)]):
        w, hh = W * wf, hf * A; x = x0 + 26 + i * 8
        t.rret(x, y - hh, w, hh, 10); t.pintar(cores[i])
        t.sombra_em(lambda: t.rret(x, y - hh, w, hh, 10), lambda: t.c.rectangle(x, y - hh * 0.4, w, hh), escurecer(cores[i], 0.2))
        t.rret(x, y - hh, w, hh, 10); t.pintar(None)
        t.linha([(x + w * 0.5, y - hh + 4), (x + w * 0.5, y - 4)], 5, escurecer(cores[i], 0.35))
        y -= hh
    fim(t)


def raiox():
    t = nova("raiox", 3.7, 2.05); m, b = t.m, t.base
    W, h = 3.6 * A, 1.05 * A
    x0 = m + 6
    # túnel
    tx, tw, th = x0 + W * 0.22, W * 0.56, 0.95 * A
    t.rret(tx, b - h - th, tw, th + 14, 16); t.pintar("#aeb7bf")
    t.rret(tx + 14, b - h - th + 18, tw - 28, th - 10, 10); t.pintar("#2b3036")
    for i in range(7): t.rret(tx + 18 + i * (tw - 36) / 7, b - h - th + 20, (tw - 36) / 7 - 3, th * 0.55, 2); t.pintar("#3e454d", lw=2)
    t.rret(tx + tw * 0.35, b - h - th - 24, tw * 0.3, 30, 6); t.pintar("#c0392b"); t.texto("RAIO-X", tx + tw / 2, b - h - th - 9, 19, "#ffffff")
    # base
    f = lambda: t.rret(x0, b - h, W, h, 10)
    f(); t.pintar("#cfd6dc", contorno=False)
    t.sombra_em(f, lambda: t.c.rectangle(x0, b - h * 0.45, W, h), "#aab4bd"); f(); t.pintar(None)
    t.rret(x0 - 4, b - h - 8, W + 8, 16, 6); t.pintar("#2b2f33")
    for i in range(14): t.elipse(x0 + 14 + i * (W - 28) / 13, b - h, 5, 5); t.pintar("#5d656e", lw=2)
    t.rret(x0 + W * 0.08, b - h * 0.6, 60, 30, 5); t.pintar("#2b2f35"); t.elipse(x0 + W * 0.08 + 46, b - h * 0.6 + 15, 6, 6); t.pintar("#3fe07a", lw=2)
    fim(t)


def bandeja():
    t = nova("bandeja", 0.8, 0.5); m, b = t.m, t.base
    W, h = 0.7 * A, 0.35 * A
    x0 = m + 6
    t.rret(x0, b - h, W, h, 6); t.pintar("#8b949c")
    t.rret(x0 + 8, b - h - 14, 30, 16, 6); t.pintar("#7a4b2a")   # sapato
    t.rret(x0 + 46, b - h - 8, 22, 10, 3); t.pintar("#1f2328")   # celular
    t.elipse(x0 + 78, b - h - 6, 7, 7); t.pintar("#f6c84a", lw=2.5)  # chaves
    fim(t)


def banco():
    t = nova("banco", 2.3, 1.15); m, b = t.m, t.base
    W, h = 2.2 * A, 0.6 * A
    x0 = m + 6
    for sx in (x0 + 16, x0 + W - 16):
        t.rret(sx - 6, b - h, 12, h, 3); t.pintar("#8a9199")
    t.rret(x0, b - 12, W, 8, 3); t.pintar("#8a9199", lw=3)
    for i in range(3):
        x = x0 + i * W / 3 + 4
        t.rret(x, b - h - 6, W / 3 - 8, 20, 8); t.pintar("#2e4a66")
        t.rret(x + 6, b - h - 0.5 * A, W / 3 - 20, 0.5 * A, 12); t.pintar("#3a5a7a")
        t.brilho(x + 20, b - h - 0.45 * A + 8, 12, 4, 0.35)
    fim(t)


def detector():
    t = nova("detector", 1.4, 2.4); m, b = t.m, t.base
    W, h = 1.3 * A, 2.3 * A
    x0 = m + 6
    for x in (x0, x0 + W - 26):
        t.rret(x, b - h + 30, 26, h - 30, 8); t.pintar("#d5dbe0")
        t.sombra_em(lambda: t.rret(x, b - h + 30, 26, h - 30, 8), lambda: t.c.rectangle(x + 16, b - h, 20, h), "#b1bac2")
        t.rret(x, b - h + 30, 26, h - 30, 8); t.pintar(None)
    t.rret(x0 - 4, b - h, W + 8, 42, 10); t.pintar("#d5dbe0")
    t.rret(x0 + W / 2 - 30, b - h + 10, 60, 20, 5); t.pintar("#2b2f35")
    fim(t)
    # luzinhas (verde / vermelha) em quadros separados
    qs = []
    for c_ in ("#3fe07a", "#ff3040"):
        q = nova("detector_luz", 0.3, 0.2, margem=4); q.elipse(q.w / 2, q.h / 2, 10, 10); q.pintar(c_, lw=3); q.brilho(q.w / 2 - 3, q.h / 2 - 3, 3, 2, 0.8); qs.append(q)
    fim_folha(qs, "detector_luz")


def placa(texto, w_m, nome):
    t = nova(nome, w_m, 1.05, margem=8); m, b = t.m, t.base
    W, h = t.W, t.Hh
    t.rret(m, b - h, W, h, 14); t.pintar("#fcc352", lw=5)
    t.rret(m + 8, b - h + 8, W - 16, h - 16, 9); t.pintar(LATAM2, lw=3)
    t.caber_texto(texto, m + W / 2, b - h / 2, W - 34, h * 0.42)
    for x in (m + W * 0.2, m + W * 0.8):
        t.elipse(x, b - h + 4, 6, 6); t.pintar("#8a9199", lw=2.5)
    fim(t)


def mola():
    qs = []
    for comp in (0, 1):
        t = nova("mola", 1.5, 0.95); m, b = t.m, t.base
        W = 1.4 * A; x0 = m + 6
        alt = 0.55 * A if comp == 0 else 0.3 * A
        t.rret(x0, b - 16, W, 16, 5); t.pintar("#3d4246")
        for i in range(4):
            y = b - 16 - (i + 0.5) * (alt - 20) / 4
            t.elipse(x0 + W / 2, y, W * 0.3, 7); t.pintar(None, lw=7, tinta="#7f8c8d")
        t.rret(x0 + 6, b - 16 - alt, W - 12, 26, 9); t.pintar("#f2c230")
        for i in range(5): t.poli([(x0 + 20 + i * 34, b - 16 - alt + 2), (x0 + 36 + i * 34, b - 16 - alt + 2), (x0 + 22 + i * 34, b - alt + 6), (x0 + 6 + i * 34, b - alt + 6)]); t.pintar(TINTA, contorno=False)
        t.texto("↑", x0 + W / 2, b - 16 - alt - 20, 30, "#f2c230", contorno=TINTA, lw=5)
        qs.append(t)
    fim_folha(qs, "mola")


def cavalete():
    t = nova("cavalete", 0.7, 0.9); m, b = t.m, t.base
    W, h = t.W, t.Hh
    t.poli([(m + W * 0.15, b), (m + W * 0.5, b - h), (m + W * 0.85, b)]); t.pintar("#f6c331")
    t.poli([(m + W * 0.5, b - h * 0.78), (m + W * 0.3, b - h * 0.4), (m + W * 0.7, b - h * 0.4)]); t.pintar("#f6c331", lw=3)
    t.texto("!", m + W / 2, b - h * 0.52, 26, TINTA)
    t.caber_texto("PISO MOLHADO", m + W / 2, b - h * 0.22, W * 0.55, 13, TINTA)
    fim(t)


def milha():
    qs = []
    for i in range(8):
        t = nova("milha", 0.8, 0.8, margem=6); m = t.m
        cx, cy = t.w / 2, t.h / 2
        esc = abs(math.cos(i / 8 * math.pi))
        r = 46
        rx = max(6, r * esc)
        t.elipse(cx + (1 - esc) * 4, cy, rx + 2, r); t.pintar(escurecer(LATAM, 0.3), lw=5)
        t.elipse(cx, cy, rx, r); t.pintar(LATAM, lw=5)
        if esc > 0.35:
            t.elipse(cx, cy, rx * 0.74, r * 0.74); t.pintar(None, lw=4, tinta="#ffffff")
            t.c.save(); t.c.translate(cx, cy); t.c.scale(esc, 1); t.texto("M", 0, 2, 44, "#ffffff", contorno=LATAM2, lw=4); t.c.restore()
        t.brilho(cx - rx * 0.4, cy - r * 0.5, rx * 0.25, 7, 0.65)
        qs.append(t)
    fim_folha(qs, "milha")


def mala_dourada():
    t = nova("mala_dourada", 1.0, 0.9); m, b = t.m, t.base
    W, h = 0.7 * A, 0.5 * A; x0 = m + (t.W - W) / 2
    for k in range(8):
        a = k * math.pi / 4
        t.linha([(x0 + W / 2 + math.cos(a) * 58, b - h / 2 - 10 + math.sin(a) * 50), (x0 + W / 2 + math.cos(a) * 74, b - h / 2 - 10 + math.sin(a) * 64)], 5, "#fff1a8")
    t.rret(x0 + W / 2 - 16, b - h - 18, 32, 24, 7); t.pintar(None, lw=8, tinta="#b8860b")
    t.rret(x0, b - h, W, h, 12); t.gradiente(x0, b - h, x0, b, [(0, "#ffe27a"), (0.5, "#ffc22e"), (1, "#d9930c")], contorno=True)
    t.linha([(x0 + W / 2, b - h + 6), (x0 + W / 2, b - 6)], 6, "#b8860b")
    t.brilho(x0 + 18, b - h + 12, 12, 5, 0.85)
    fim(t)


def taxi():
    t = nova("taxi", 4.3, 1.75); m, b = t.m, t.base
    W = 4.2 * A; x0 = m
    corpo = lambda: t.curva([(x0 + 10, b - 40), (x0 + 20, b - 0.95 * A), (x0 + W * 0.25, b - 1.0 * A), (x0 + W * 0.34, b - 1.5 * A), (x0 + W * 0.68, b - 1.5 * A),
                             (x0 + W * 0.8, b - 1.02 * A), (x0 + W - 10, b - 0.92 * A), (x0 + W - 4, b - 40)])
    corpo(); t.pintar("#f6f6f4", contorno=False)
    t.sombra_em(corpo, lambda: t.c.rectangle(x0, b - 0.62 * A, W, A), "#d3d7dc"); corpo(); t.pintar(None)
    t.poli([(x0 + W * 0.36, b - 1.42 * A), (x0 + W * 0.5, b - 1.42 * A), (x0 + W * 0.5, b - 1.06 * A), (x0 + W * 0.29, b - 1.06 * A)]); t.pintar("#34495e", lw=4)
    t.poli([(x0 + W * 0.53, b - 1.42 * A), (x0 + W * 0.66, b - 1.42 * A), (x0 + W * 0.75, b - 1.06 * A), (x0 + W * 0.53, b - 1.06 * A)]); t.pintar("#34495e", lw=4)
    t.rret(x0 + W * 0.44, b - 1.72 * A, W * 0.14, 0.24 * A, 6); t.pintar("#f2c230"); t.caber_texto("TÁXI", x0 + W * 0.51, b - 1.6 * A, W * 0.11, 20, TINTA)
    t.rret(x0 + W - 30, b - 0.86 * A, 22, 16, 5); t.pintar("#fff2b0", lw=3)
    t.linha([(x0 + 20, b - 0.6 * A), (x0 + W - 12, b - 0.6 * A)], 8, "#1f6fbf")  # faixa
    for x in (x0 + W * 0.2, x0 + W * 0.8):
        t.elipse(x, b - 34, 38, 38); t.pintar("#202226"); t.elipse(x, b - 34, 16, 16); t.pintar("#b9c0c8", lw=3)
    fim(t)


def porta():
    t = nova("porta", 3.4, 3.9); m, b = t.m, t.base
    W, h = 3.2 * A, 3.8 * A; x0 = m + 12
    for x in (x0, x0 + W - 34):
        t.rret(x, b - h + 60, 34, h - 60, 6); t.pintar("#5f6870")
    t.rret(x0 - 10, b - h, W + 20, 70, 10); t.pintar("#0d4a2b")
    t.caber_texto("ENTRADA · EMBARQUE", x0 + W / 2, b - h + 35, W * 0.8, 34, "#fcc352")
    for x in (x0 + 34, x0 + W / 2 + 40):
        t.rret(x - 30, b - h + 70, W / 2 - 40, h - 74, 6)
        t.c.set_source_rgba(0.72, 0.88, 0.95, 0.35); t.c.fill_preserve(); t.c.set_source_rgba(*cor(TINTA)); t.c.set_line_width(4); t.c.stroke()
        t.linha([(x - 10, b - h + 110), (x + 30, b - h + 190)], 6, "#ffffff", 0.45)
    fim(t)


def painel(ultima):
    nome = "painel_ultima" if ultima else "painel"
    t = nova(nome, 4.4, 2.3); m, b = t.m, t.base
    W, h = t.W, t.Hh
    t.rret(m, b - h, W, h, 14); t.pintar("#1a1f25")
    t.rret(m + 12, b - h + 12, W - 24, 52, 6); t.pintar("#0d4a2b", lw=3)
    t.texto("PARTIDAS · DEPARTURES", m + W / 2, b - h + 38, 30, "#fcc352", fonte="DejaVu Sans Mono")
    lin = [("PLUS 218", "MARINGÁ", "ÚLTIMA CHAMADA" if ultima else "EMBARQUE"), ("PLUS 104", "BRASÍLIA", "NO HORÁRIO"), ("PLUS 330", "SALVADOR", "NO HORÁRIO"), ("PLUS 512", "RIO SDU", "ATRASADO")]
    for i, (a, d, s) in enumerate(lin):
        y = b - h + 100 + i * 46
        t.texto(a, m + 24, y, 25, "#e8e8e8", centro=False, fonte="DejaVu Sans Mono")
        t.texto(d, m + 190, y, 25, "#e8e8e8", centro=False, fonte="DejaVu Sans Mono")
        t.texto(s, m + 350, y, 25, ("#ff3b4d" if ultima else "#3fe07a") if i == 0 else "#9fb3c8", centro=False, fonte="DejaVu Sans Mono")
    fim(t)


def pastel():
    t = nova("pastel", 4.4, 3.0); m, b = t.m, t.base
    W = 4.2 * A; x0 = m + 12
    for x in (x0 + 14, x0 + W - 28):
        t.rret(x, b - 2.6 * A, 14, 2.6 * A, 4); t.pintar("#4a4f55")
    t.rret(x0 - 6, b - 2.95 * A, W + 12, 0.5 * A, 10); t.pintar("#f6c331")
    t.caber_texto("PASTEL & CALDO DE CANA", x0 + W / 2, b - 2.7 * A, W * 0.86, 40, "#7a1f0f")
    for i in range(7):
        t.poli([(x0 + i * W / 7, b - 2.45 * A), (x0 + (i + 1) * W / 7, b - 2.45 * A), (x0 + (i + 0.5) * W / 7, b - 2.2 * A)]); t.pintar("#e74c3c" if i % 2 else "#ffffff", lw=3)
    f = lambda: t.rret(x0, b - 1.1 * A, W, 1.1 * A, 10)
    f(); t.pintar("#c84b2f")
    t.rret(x0 - 6, b - 1.18 * A, W + 12, 18, 6); t.pintar("#f5ede0")
    for i in range(5):  # pastéis no balcão
        x = x0 + 40 + i * 100
        t.c.save(); t.c.translate(x, b - 1.25 * A); t.c.rotate(-0.15); t.curva([(-34, 8), (0, -16), (34, 8)], True); t.pintar("#e9b35a"); t.c.restore()
    t.rret(x0 + W - 110, b - 1.75 * A, 60, 70, 8); t.pintar("#9b6b3d")  # moenda
    t.elipse(x0 + W - 80, b - 1.78 * A, 30, 12); t.pintar("#4a4f55")
    fim(t)


def freeshop():
    t = nova("freeshop", 8.2, 3.0); m, b = t.m, t.base
    W = 8 * A; x0 = m + 12
    cores = ["#e84a5f", "#ffd166", "#06d6a0", "#118ab2", "#f78c6b", "#9b5de5"]
    for i in range(3):
        sx = x0 + i * W / 3 + 10
        t.rret(sx, b - 2.3 * A, W / 3 - 20, 2.3 * A, 10); t.pintar("#3b2d4a")
        for r in range(3):
            y = b - 0.4 * A - r * 0.68 * A
            t.rret(sx + 8, y, W / 3 - 36, 12, 3); t.pintar("#8b6a4f", lw=3)
            for k in range(6):
                hh = 34 + (k * 7 + r * 13 + i * 5) % 22
                t.rret(sx + 16 + k * 52, y - hh, 40, hh, 5); t.pintar(cores[(i + r + k) % 6], lw=3.5)
    t.rret(x0 + W * 0.3, b - 2.92 * A, W * 0.4, 0.5 * A, 10); t.pintar("#3b2d4a")
    t.caber_texto("LOJA · CAFÉ · LIVRARIA", x0 + W / 2, b - 2.67 * A, W * 0.36, 40, "#ffd166")
    fim(t)


def portao():
    t = nova("portao", 2.8, 3.6); m, b = t.m, t.base
    x0 = m + 10
    t.rret(x0 + 40, b - 3.3 * A, 18, 3.3 * A, 4); t.pintar("#3d464e")
    t.rret(x0, b - 3.55 * A, 2.6 * A, 0.55 * A, 10); t.pintar("#0d4a2b")
    t.texto("218", x0 + 0.5 * A, b - 3.27 * A, 46, "#fcc352")
    t.caber_texto("PLUS 218 · MARINGÁ", x0 + 1.65 * A, b - 3.27 * A, 1.6 * A, 30, "#ffffff")
    t.rret(x0 + 0.9 * A, b - 1.1 * A, 1.4 * A, 1.1 * A, 10); t.pintar("#cdd3d8")
    t.rret(x0 + 0.9 * A, b - 1.18 * A, 1.4 * A, 18, 6); t.pintar(LATAM2)
    fim(t)


def aviao():
    px = 66
    t = nova("aviao", 22, 8, px_m=px); m, b = t.m, t.base
    W, H = t.W, t.Hh
    fx0, fx1 = m + 40, m + W - 60
    fy = b - 2.2 * px  # base da fuselagem
    fh = 3.4 * px
    # asa de trás e motor
    t.poli([(fx0 + W * 0.38, fy - fh * 0.35), (fx0 + W * 0.62, fy - fh * 0.35), (fx0 + W * 0.42, fy + 1.4 * px), (fx0 + W * 0.3, fy + 1.4 * px)]); t.pintar("#c9cfd5")
    # fuselagem (nariz à direita)
    f = lambda: t.curva([(fx0, fy - fh * 0.2), (fx0 + W * 0.1, fy - fh * 0.98), (fx1 - 1.6 * px, fy - fh), (fx1, fy - fh * 0.55), (fx1 - 0.6 * px, fy - fh * 0.05), (fx0 + W * 0.2, fy)])
    f(); t.pintar("#f7f7f7", contorno=False)
    t.sombra_em(f, lambda: t.c.rectangle(0, fy - fh * 0.3, t.w, fh), "#d5dade")
    t.sombra_em(f, lambda: t.c.rectangle(0, fy - fh * 0.52, t.w, 0.35 * px), LATAM2)
    t.sombra_em(f, lambda: t.c.rectangle(0, fy - fh * 0.6, t.w, 0.12 * px), LATAM)
    f(); t.pintar(None, lw=6)
    # cauda
    t.poli([(fx0 + 0.4 * px, fy - fh * 0.9), (fx0 - 0.2 * px, fy - fh - 3.6 * px), (fx0 + 1.6 * px, fy - fh - 3.6 * px), (fx0 + 3.6 * px, fy - fh * 0.95)]); t.pintar(LATAM2, lw=6)
    # janelas
    for i in range(22):
        x = fx0 + 4 * px + i * 0.62 * px
        if x > fx1 - 3 * px: break
        t.rret(x, fy - fh * 0.78, 0.28 * px, 0.4 * px, 8); t.pintar("#2c3e50", lw=3)
    t.poli([(fx1 - 1.9 * px, fy - fh * 0.82), (fx1 - 0.9 * px, fy - fh * 0.82), (fx1 - 0.55 * px, fy - fh * 0.62), (fx1 - 1.8 * px, fy - fh * 0.62)]); t.pintar("#2c3e50", lw=4)
    # porta aberta (onde o mascote entra)
    t.rret(fx0 + 3.0 * px, fy - fh * 0.95, 1.0 * px, 2.0 * px, 10); t.pintar("#26313a", lw=5)
    # asa da frente, motor, trem de pouso
    t.elipse(fx0 + W * 0.45, fy + 0.6 * px, 1.8 * px, 0.75 * px); t.pintar("#dfe3e6", lw=5)
    t.elipse(fx0 + W * 0.45 + 1.6 * px, fy + 0.6 * px, 0.35 * px, 0.55 * px); t.pintar("#2b2f35", lw=4)
    for x in (fx0 + W * 0.3, fx1 - 2.5 * px):
        t.linha([(x, fy), (x, b - 0.5 * px)], 10, "#6f7a84"); t.elipse(x, b - 0.45 * px, 0.45 * px, 0.45 * px); t.pintar("#202226")
    fim(t)


# --------------------------------------------------------------- vistos de frente (trecho de trás)
def barreira_frente():
    t = nova("barreira_f", 1.6, 0.9); m, b = t.m, t.base
    W, h = 1.5 * A, 0.8 * A; x0 = m + 6
    for x in (x0 + 10, x0 + W - 30): t.rret(x, b - h, 20, h, 5); t.pintar("#5d656e")
    t.rret(x0, b - h, W, h * 0.55, 8); t.pintar("#f39c12")
    t.c.save(); t.rret(x0, b - h, W, h * 0.55, 8); t.c.clip()
    for i in range(-2, 9): t.poli([(x0 + i * 28, b - h), (x0 + i * 28 + 14, b - h), (x0 + i * 28 + 14 + 30, b - h * 0.45), (x0 + i * 28 + 30, b - h * 0.45)]); t.pintar(TINTA, contorno=False)
    t.c.restore(); t.rret(x0, b - h, W, h * 0.55, 8); t.pintar(None)
    fim(t)


def trem_frente(nome, vindo):
    t = nova(nome, 1.7, 2.6); m, b = t.m, t.base
    W, h = 1.6 * A, 2.5 * A; x0 = m + 6
    f = lambda: t.rret(x0, b - h, W, h, 30)
    f(); t.pintar("#f3f5f6", contorno=False)
    t.sombra_em(f, lambda: t.c.rectangle(x0, b - h * 0.25, W, h), "#cfd5db"); f(); t.pintar(None)
    t.rret(x0 + 16, b - h + 24, W - 32, h * 0.38, 18); t.pintar("#1b2733" if vindo else "#2c3e50")
    t.linha([(x0 + 34, b - h + 40), (x0 + 60, b - h + 90)], 7, "#ffffff", 0.3)
    t.rret(x0, b - h * 0.42, W, 18, 4); t.pintar(LATAM2, lw=3)
    if vindo:
        for x in (x0 + 34, x0 + W - 34):
            t.elipse(x, b - h * 0.24, 17, 17); t.pintar("#fff6c0")
            t.elipse(x, b - h * 0.24, 30, 30); t.c.set_source_rgba(1, 0.96, 0.7, 0.35); t.c.fill()
    else:
        for x in (x0 + 34, x0 + W - 34): t.rret(x - 14, b - h * 0.28, 28, 16, 4); t.pintar("#c0392b")
        t.rret(x0 + W / 2 - 34, b - h * 0.3, 68, 60, 8); t.pintar("#9aa3ab")
    t.rret(x0 + 20, b - 20, W - 40, 20, 4); t.pintar("#3d4246")
    fim(t)


def rampa_frente():
    t = nova("rampa_f", 1.7, 2.6); m, b = t.m, t.base
    W, h = 1.6 * A, 2.5 * A; x0 = m + 6
    t.poli([(x0 + 10, b), (x0 + W - 10, b), (x0 + W - 22, b - h), (x0 + 22, b - h)]); t.pintar("#f39c12")
    for i in range(9):
        y = b - (i + 0.5) * h / 9
        t.linha([(x0 + 18 + i * 1.3, y), (x0 + W - 18 - i * 1.3, y)], 5, escurecer("#f39c12", 0.3))
    fim(t)


def placa_pare():
    t = nova("placa_pare", 1.9, 3.1); m, b = t.m, t.base
    W, h = 1.8 * A, 3.0 * A; x0 = m + 6
    for x in (x0, x0 + W - 22): t.rret(x, b - h, 22, h, 5); t.pintar("#5d656e")
    t.rret(x0 - 4, b - h, W + 8, 24, 6); t.pintar("#5d656e")
    t.rret(x0 + 26, b - 2.6 * A, W - 52, 1.25 * A, 14); t.pintar("#c0392b", lw=5)
    t.rret(x0 + 34, b - 2.6 * A + 8, W - 68, 1.25 * A - 16, 10); t.pintar(None, lw=4, tinta="#ffffff")
    t.caber_texto("ABAIXE!", x0 + W / 2, b - 2.6 * A + 0.62 * A, W - 90, 46)
    fim(t)


def tiles():
    # piso do terminal (repetível)
    t = Tela(264, 56); t.pxm = A
    t.c.rectangle(0, 0, 264, 56); t.gradiente(0, 0, 0, 56, [(0, "#eef2f5"), (1, "#d6dde3")])
    for x in range(0, 264, 66): t.linha([(x, 0), (x - 10, 56)], 2, "#c3ccd4")
    t.linha([(0, 28), (264, 28)], 2, "#c9d1d8")
    t.salvar("piso.png"); META["piso"] = {"w": 2.0, "h": 56 / A, "pxm": A}
    t = Tela(264, 56); t.pxm = A
    t.c.rectangle(0, 0, 264, 56); t.c.set_source_rgba(*cor("#dcd8d0")); t.c.fill()
    for y0 in (8, 32):
        t.curva([(x, y0 + 7 * math.sin(x / 264 * 4 * math.pi)) for x in range(0, 265, 12)], False)
        t.c.set_source_rgba(*cor("#2f2f2f")); t.c.set_line_width(9); t.c.stroke()
    t.salvar("calcada.png"); META["calcada"] = {"w": 2.0, "h": 56 / A, "pxm": A}
    t = Tela(132, 40); t.pxm = A
    t.c.rectangle(0, 0, 132, 40); t.c.set_source_rgba(*cor("#2b2f33")); t.c.fill()
    for x in (20, 86):
        t.poli([(x, 8), (x + 22, 20), (x, 32), (x + 8, 20)]); t.pintar("#f5c242", contorno=False)
    t.linha([(0, 2), (132, 2)], 4, "#5d656e"); t.linha([(0, 38), (132, 38)], 4, "#5d656e")
    t.salvar("esteira.png"); META["esteira"] = {"w": 1.0, "h": 40 / A, "pxm": A}


if __name__ == "__main__":
    mala(); fita(); balcao(); carrinho(); raiox(); bandeja(); banco(); detector()
    for texto, w, nome in [("EMBARQUE", 1.6, "placa_embarque"), ("CHECK-IN 1-20", 1.8, "placa_checkin"), ("DESPACHO", 1.8, "placa_despacho"),
                           ("PISO MOLHADO", 1.8, "placa_molhado"), ("PORTÕES 201-230", 1.8, "placa_portoes"), ("CUIDADO", 1.0, "placa_cuidado")]:
        placa(texto, w, nome)
    mola(); cavalete(); milha(); mala_dourada(); taxi(); porta(); painel(False); painel(True); pastel(); freeshop(); portao(); aviao()
    barreira_frente(); trem_frente("trem_f", True); trem_frente("vagao_f", False); rampa_frente(); placa_pare(); tiles()
    json.dump(META, open(os.path.join(SPR, "objetos.json"), "w"), indent=1)
    print("ok", len(META))
