"""Pessoas do aeroporto, no mesmo traço do mascote (escala: 132 px por metro).
  guarda.png       6 quadros correndo para a direita (ele persegue o mascote)
  passageiroN.png  4 quadros andando para a esquerda + 1 caído (N = 0, 1, 2)
  comissaria.png   2 quadros acenando no portão
  atendente.png    meio corpo atrás do balcão
"""
import math
from arte import Tela, folha, cor, escurecer, clarear, TINTA

A = 132


def cabeca(t, cx, cy, pele, cabelo, estilo="curto", bone=None, bigode=False, olhar=1, bravo=False, boca="o"):
    c = t.c
    # orelha
    t.elipse(cx - 18 * olhar, cy + 4, 8, 10); t.pintar(pele, lw=4)
    if estilo == "longo":
        t.curva([(cx - 30, cy - 10), (cx - 6, cy - 34), (cx + 26, cy - 22), (cx + 20 * olhar * 0 + 4, cy + 10), (cx - 34 * olhar, cy + 48), (cx - 40 * olhar, cy + 10)])
        t.pintar(cabelo)
    t.elipse(cx, cy, 30, 31); t.pintar(pele)
    t.sombra_em(lambda: t.elipse(cx, cy, 30, 31), lambda: t.elipse(cx - 14 * olhar, cy + 14, 22, 20), escurecer(pele, 0.12))
    t.elipse(cx, cy, 30, 31); t.pintar(None)
    # nariz
    t.elipse(cx + 27 * olhar, cy + 5, 7, 6); t.pintar(pele, lw=4)
    # olho
    ox = cx + 13 * olhar
    t.elipse(ox, cy - 3, 6, 7.5); t.pintar("#ffffff", lw=3)
    t.elipse(ox + 2 * olhar, cy - 2, 3, 4); t.pintar("#1f1a17", contorno=False)
    if bravo:
        t.linha([(ox - 9 * olhar, cy - 15), (ox + 8 * olhar, cy - 9)], 5, "#1f1a17")
    else:
        t.linha([(ox - 7 * olhar, cy - 14), (ox + 7 * olhar, cy - 14)], 4, escurecer(cabelo, 0.2))
    # boca
    if boca == "o":
        t.elipse(cx + 18 * olhar, cy + 17, 4.5, 4); t.pintar("#7a2a22", lw=3)
    elif boca == "sorriso":
        c.arc(cx + 15 * olhar, cy + 12, 8, 0.3, 2.6); c.set_source_rgba(*cor(TINTA)); c.set_line_width(3.5); c.stroke()
    if bigode:
        t.curva([(cx + 10 * olhar, cy + 11), (cx + 26 * olhar, cy + 9), (cx + 30 * olhar, cy + 15), (cx + 12 * olhar, cy + 16)]); t.pintar(cabelo, lw=3)
    # cabelo
    if estilo in ("curto", "longo"):
        t.curva([(cx - 30, cy - 2), (cx - 26, cy - 26), (cx, cy - 36), (cx + 24, cy - 28), (cx + 30 * olhar, cy - 12), (cx + 8 * olhar, cy - 18), (cx - 12 * olhar, cy - 12), (cx - 22 * olhar, cy + 4)])
        t.pintar(cabelo)
    elif estilo == "careca":
        t.curva([(cx - 30 * olhar, cy + 4), (cx - 28 * olhar, cy - 14), (cx - 18 * olhar, cy - 6), (cx - 20 * olhar, cy + 10)]); t.pintar(cabelo, lw=3)
        t.brilho(cx - 4, cy - 20, 10, 5, 0.5)
    if bone:
        t.curva([(cx - 31, cy - 6), (cx - 26, cy - 30), (cx, cy - 38), (cx + 26, cy - 28), (cx + 30, cy - 8)], True); t.pintar(bone)
        t.c.save(); t.c.translate(cx + 22 * olhar, cy - 9); t.c.scale(olhar, 1); t.rret(-2, -5, 34, 9, 4); t.c.restore(); t.pintar(escurecer(bone, 0.2))
        t.rret(cx - 8, cy - 32, 14, 10, 3); t.pintar("#f6c84a", lw=3)


def membro(t, a, ang, dobra, c1, c2, larg, h, ponta=None, ponta_cor=None, ponta_tipo="mao"):
    j = (a[0] + math.sin(ang) * c1, a[1] + math.cos(ang) * c1)
    a2 = ang - dobra
    p = (j[0] + math.sin(a2) * c2, j[1] + math.cos(a2) * c2)
    t.traco([a, j, p], larg, h)
    if ponta_tipo == "mao":
        t.elipse(p[0], p[1] + 2, 9, 9); t.pintar(ponta_cor)
    elif ponta_tipo == "sapato":
        t.c.save(); t.c.translate(*p); t.c.rotate(-a2 * 0.4)
        t.rret(-12 if ponta > 0 else -26, -6, 38, 14, 7); t.pintar(ponta_cor)
        t.c.restore()
    return p


def humano(pose, camisa, calca, pele, cabelo, estilo="curto", olhar=1, bone=None, colete=None, bigode=False, bravo=False,
           mala=None, sapato="#2a2420", saia=False, lenco=None, boca="o", W=220, H=260):
    espelhar = olhar < 0
    olhar = 1
    t = Tela(W, H); c = t.c
    cx = W / 2
    bob = pose.get("bob", 0)
    quadril = (cx, 150 + bob)
    lean = pose.get("inclina", 0) * olhar
    # mala de rodinha (atrás de quem anda)
    if mala:
        mx = cx - 62 * olhar
        t.linha([(cx - 20 * olhar, 138 + bob), (mx + 6 * olhar, 168)], 5, "#3a3d42")
        t.rret(mx - 22, 168, 44, 64, 9); t.pintar(mala)
        t.sombra_em(lambda: t.rret(mx - 22, 168, 44, 64, 9), lambda: c.rectangle(mx - 22, 210, 44, 30), escurecer(mala, 0.18))
        t.rret(mx - 22, 168, 44, 64, 9); t.pintar(None)
        for dx in (-10, 10): t.linha([(mx + dx, 172), (mx + dx, 228)], 3, escurecer(mala, 0.3))
        t.elipse(mx - 12, 238, 7, 7); t.pintar("#222222", lw=3); t.elipse(mx + 12, 238, 7, 7); t.pintar("#222222", lw=3)
    # perna e braço de trás
    membro(t, (quadril[0] - 6 * olhar, quadril[1]), pose["coxa"][1] * olhar, pose["joelho"][1] * olhar, 46, 46, 24, escurecer(calca, 0.15), olhar, sapato, "sapato")
    c.save(); t.girar(quadril[0], quadril[1], lean)
    membro(t, (cx - 4 * olhar, 96 + bob), pose["braco"][1] * olhar, pose["cotovelo"][1] * olhar, 30, 28, 17, escurecer(camisa, 0.15), None, escurecer(pele, 0.1))
    # tronco
    tr = lambda: t.rret(cx - 26, 84 + bob, 52, 72, 16)
    tr(); t.pintar(camisa, contorno=False)
    t.sombra_em(tr, lambda: c.rectangle(cx - 30, 138 + bob, 60, 30), escurecer(camisa, 0.16))
    t.sombra_em(tr, lambda: c.rectangle(cx - 30 if olhar > 0 else cx + 16, 84 + bob, 14, 80), escurecer(camisa, 0.12))
    tr(); t.pintar(None)
    if saia:
        t.poli([(cx - 26, 140 + bob), (cx + 26, 140 + bob), (cx + 32, 178 + bob), (cx - 32, 178 + bob)]); t.pintar(calca)
    if colete:
        t.rret(cx - 27, 92 + bob, 54, 50, 10); t.pintar(colete)
        for yy in (110, 126): t.linha([(cx - 24, yy + bob), (cx + 24, yy + bob)], 5, "#d9dde0")
        t.texto("SEGURANÇA", cx + 2, 100 + bob, 8.5, "#1f1a17")
    if lenco:
        t.poli([(cx - 12, 84 + bob), (cx + 14, 84 + bob), (cx + 2, 104 + bob)]); t.pintar(lenco, lw=3)
    c.restore()
    # perna da frente
    membro(t, (quadril[0] + 6 * olhar, quadril[1]), pose["coxa"][0] * olhar, pose["joelho"][0] * olhar, 46, 46, 24, calca, olhar, sapato, "sapato")
    # cabeça
    c.save(); t.girar(quadril[0], quadril[1], lean)
    cabeca(t, cx + 4 * olhar, 50 + bob, pele, cabelo, estilo, bone, bigode, olhar, bravo, boca)
    # braço da frente
    membro(t, (cx + 4 * olhar, 96 + bob), pose["braco"][0] * olhar, pose["cotovelo"][0] * olhar, 30, 28, 17, camisa, None, pele)
    c.restore()
    if espelhar:
        e = Tela(W, H); e.c.translate(W, 0); e.c.scale(-1, 1); e.c.set_source_surface(t.s, 0, 0); e.c.paint()
        return e
    return t


def ciclo(n, corre=True):
    P = []
    for i in range(n):
        f = i / n * 2 * math.pi; s = math.sin(f)
        amp = 0.8 if corre else 0.45
        P.append(dict(coxa=(amp * s, -amp * s), joelho=(max(0, -math.cos(f)) * (1.2 if corre else 0.5), max(0, math.cos(f)) * (1.2 if corre else 0.5)),
                      braco=(-0.9 * s if corre else -0.4 * s, 0.9 * s if corre else 0.4 * s), cotovelo=(-1.0 if corre else -0.2, -1.0 if corre else -0.2),
                      bob=(-abs(math.cos(f)) * 7 + 4) if corre else -abs(math.cos(f)) * 3, inclina=0.12 if corre else 0.0))
    return P


def caido(var):
    """Sentado no chão, tonto, com estrelinhas."""
    v = {k: x for k, x in var.items() if k != "mala"}
    t = humano(dict(coxa=(1.45, 1.35), joelho=(0.1, 0.0), braco=(-0.6, 0.5), cotovelo=(0.3, 0.3), bob=70), **v, boca="o")
    for (x, y) in [(80, 76), (110, 64), (140, 76)]:
        pts = []
        for j in range(10):
            a = -math.pi / 2 + j * math.pi / 5; r = 9 if j % 2 == 0 else 4
            pts.append((x + math.cos(a) * r, y + math.sin(a) * r))
        t.poli(pts); t.pintar("#ffd447", lw=2.5)
    return t


if __name__ == "__main__":
    guarda = dict(camisa="#24395e", calca="#1d2b47", pele="#b9845a", cabelo="#2a1a10", bone="#1d2b47", colete="#d8ef3a", bigode=True, bravo=True, olhar=1, sapato="#111111")
    gq = []
    for p in ciclo(6):
        p["braco"] = (1.9 + 0.15 * math.sin(len(gq) * 1.7), p["braco"][1]); p["cotovelo"] = (-0.3, -1.0)
        gq.append(humano(p, **guarda, W=240, H=270))
    folha(gq, "guarda.png")
    VAR = [
        dict(camisa="#e2483d", calca="#2c3e50", pele="#8d5a3b", cabelo="#1b1410", estilo="curto", olhar=-1, mala="#3a8fd8"),
        dict(camisa="#3a8fd8", calca="#34495e", pele="#f1c7a0", cabelo="#e0b04a", estilo="longo", olhar=-1, mala="#e86aa6", saia=True),
        dict(camisa="#f2b630", calca="#5d4037", pele="#d9a273", cabelo="#5b5b5b", estilo="careca", bigode=True, olhar=-1, mala="#2e9e6a"),
    ]
    for i, v in enumerate(VAR):
        qs = [humano(p, **v) for p in ciclo(4, corre=False)]
        qs.append(caido(v))
        folha(qs, "passageiro%d.png" % i)
    com = dict(camisa="#1B0088", calca="#1B0088", pele="#8d5a3b", cabelo="#151010", estilo="longo", olhar=1, saia=True, lenco="#E8114B", boca="sorriso")
    folha([humano(dict(coxa=(0.05, -0.05), joelho=(0, 0), braco=(a, 0.3), cotovelo=(-0.5, -0.3)), **com) for a in (2.3, 2.75)], "comissaria.png")
    humano(dict(coxa=(0, 0), joelho=(0, 0), braco=(-0.6, 0.4), cotovelo=(-1.2, -0.5)), camisa="#1B0088", calca="#1B0088", pele="#e8b48c", cabelo="#7a4320", estilo="longo", olhar=1, lenco="#E8114B", boca="sorriso").salvar("atendente.png")
    print("ok")
