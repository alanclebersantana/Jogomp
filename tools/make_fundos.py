"""Fundos repetíveis na horizontal (66 px por metro). O jogo emenda lado a lado com paralaxe."""
import json, math, os, random
from arte import Tela, cor, escurecer, clarear, BG, TINTA

P = 66
W = 1386  # 21 m
META = {}
LATAM, LATAM2 = "#E8114B", "#1B0088"


def emenda(f):
    """Desenha f(dx) três vezes para a imagem emendar nas bordas."""
    for dx in (-W, 0, W): f(dx)


def salvar(t, nome, chao_px=None):
    t.salvar(nome + ".png", BG)
    META[nome] = {"w": t.w / P, "h": t.h / P, "pxm": P, "chao": (chao_px / P) if chao_px is not None else None}


def predios(t, base, n, hmin, hmax, tons, janelas=True, semente=1, traco=3.0):
    r = random.Random(semente)
    xs = []
    x = 0
    while x < W:
        w = r.randint(50, 120); h = r.randint(hmin, hmax); xs.append((x, w, h, r.choice(tons), r.random())); x += w + r.randint(-10, 14)
    for (x, w, h, c, k) in xs:
        def d(dx, x=x, w=w, h=h, c=c, k=k):
            t.rret(x + dx, base - h, w, h + 20, 4); t.pintar(c, lw=traco)
            if janelas:
                rr = random.Random(int(x * 7 + h))
                for yy in range(int(base - h + 10), int(base - 6), 14):
                    for xx in range(int(x + 8), int(x + w - 8), 12):
                        if rr.random() < 0.55:
                            t.c.rectangle(xx + dx, yy, 6, 7); t.c.set_source_rgba(*cor("#ffe3a0" if rr.random() < 0.3 else escurecer(c, 0.18))); t.c.fill()
            if k < 0.12:
                t.linha([(x + dx + w / 2, base - h), (x + dx + w / 2, base - h - 40)], 3, "#d9dde0")
                t.elipse(x + dx + w / 2, base - h - 42, 4, 4); t.pintar("#ff3030", lw=1.5)
        emenda(d)


def ceu_sp():
    t = Tela(W, 900)
    t.c.rectangle(0, 0, W, 900); t.gradiente(0, 0, 0, 900, [(0, "#8597a8"), (0.6, "#b9c5cf"), (1, "#cfd8df")])
    r = random.Random(4)
    for i in range(9):
        cx, cy = r.randint(0, W), r.randint(60, 380)
        def nuvem(dx, cx=cx, cy=cy):
            for k in range(5):
                t.elipse(cx + dx + k * 46 - 90, cy + (k % 2) * 10, 70, 30); t.c.set_source_rgba(1, 1, 1, 0.22); t.c.fill()
        emenda(nuvem)
    predios(t, 760, 0, 180, 420, ["#aab5c0", "#b4bec8", "#a3aeb9"], janelas=False, semente=2, traco=2)
    # Ponte Estaiada ao longe
    def ponte(dx):
        x = 900 + dx
        t.poli([(x - 40, 760), (x, 380), (x + 40, 760), (x + 20, 760), (x, 470), (x - 20, 760)]); t.pintar("#e8ecef", lw=2.5)
        for k in range(-7, 8):
            if k: t.linha([(x, 400 + abs(k) * 4), (x + k * 26, 640)], 1.6, "#f4f6f8")
        t.rret(x - 230, 636, 460, 14, 3); t.pintar("#dfe4e8", lw=2)
    emenda(ponte)
    predios(t, 800, 0, 120, 330, ["#8e9aa6", "#97a3ae", "#86929e"], semente=5)
    # MASP
    def masp(dx):
        x = 330 + dx
        for px in (x, x + 230): t.rret(px, 620, 20, 190, 3); t.pintar("#b0262c", lw=3)
        t.rret(x - 10, 600, 260, 90, 6); t.pintar("#c0262d", lw=3.5)
        for k in range(7): t.linha([(x + 10 + k * 34, 616), (x + 10 + k * 34, 676)], 3, "#8f1b20")
    emenda(masp)
    predios(t, 860, 0, 90, 260, ["#6f7b87", "#7a8692", "#66727e"], semente=9, traco=3.5)
    t.c.rectangle(0, 850, W, 50); t.c.set_source_rgba(*cor("#5a6470")); t.c.fill()
    salvar(t, "ceu_sp", 880)


def janela_aeroporto(t, x, y, w, h, aviao=True, semente=0):
    t.rret(x, y, w, h, 6); t.gradiente(x, y, x, y + h, [(0, "#93a3b1"), (0.58, "#c3cdd5"), (0.6, "#6b737b"), (1, "#545b62")], contorno=True, lw=5)
    if aviao:
        ax = x + w * 0.2; ay = y + h * 0.6
        t.curva([(ax, ay), (ax + w * 0.06, ay - 22), (ax + w * 0.6, ay - 24), (ax + w * 0.66, ay - 10), (ax + w * 0.6, ay + 2)]); t.pintar("#f2f2f2", lw=3)
        t.poli([(ax + 4, ay - 18), (ax - 12, ay - 70), (ax + 22, ay - 70), (ax + 40, ay - 20)]); t.pintar(LATAM2, lw=3)
        t.linha([(ax + 30, ay - 8), (ax + w * 0.58, ay - 10)], 4, LATAM)
    r = random.Random(semente)
    for _ in range(40):
        gx, gy = x + r.random() * w, y + r.random() * h
        t.linha([(gx, gy), (gx - 2, gy + 10)], 1.4, "#ffffff", 0.35)
    t.linha([(x + w / 2, y), (x + w / 2, y + h)], 6, "#3b4752")


def parede(nome, cor_parede, faixa, texto_faixa, janelas=True, extra=None, alto=8.4):
    H = int(alto * P)
    t = Tela(W, H)
    t.c.rectangle(0, 0, W, H); t.gradiente(0, 0, 0, H, [(0, clarear(cor_parede, 0.15)), (1, cor_parede)])
    # teto com luzes
    t.c.rectangle(0, 0, W, 34); t.c.set_source_rgba(*cor("#f3f5f7")); t.c.fill()
    for x in range(40, W, 170):
        t.rret(x, 30, 120, 10, 4); t.pintar("#fffbe0", lw=2)
    t.linha([(0, 44), (W, 44)], 4, "#9aa6b1")
    # faixa de sinalização
    t.rret(0, 70, W, 48, 0); t.pintar(faixa, contorno=False)
    for x in range(160, W, 700):
        t.texto(texto_faixa, x + 180, 94, 26, "#ffffff" if faixa != "#fcc352" else TINTA)
    if janelas:
        for i, x in enumerate(range(40, W, 462)):
            janela_aeroporto(t, x, 150, 380, H - 230, aviao=(i % 2 == 0), semente=i)
    # colunas
    for x in range(0, W, 462):
        t.rret(x - 18, 118, 36, H - 118, 4); t.pintar("#cfd6dc", lw=3.5)
    if extra: extra(t, H)
    t.c.rectangle(0, H - 26, W, 26); t.c.set_source_rgba(*cor("#9aa4ad")); t.c.fill()
    t.linha([(0, H - 26), (W, H - 26)], 3, TINTA)
    salvar(t, nome, H)


def anuncio(t, x, y):
    t.rret(x, y, 300, 170, 10); t.pintar("#0d4a2b", lw=4)
    for i, (dx, dy) in enumerate([(0, 0), (22, 0), (0, 22), (22, 22)]):
        t.rret(x + 24 + dx, y + 30 + dy, 18, 18, 3); t.pintar("#f6c84a", lw=2)
    t.texto("MILHAS PLUS", x + 180, y + 52, 28, "#ffffff")
    t.texto("Junte milhas.", x + 150, y + 105, 24, "#fcc352")
    t.texto("Voe mais.", x + 150, y + 138, 24, "#fcc352")


def subsolo():
    H = int(5.2 * P)
    t = Tela(W, H)
    t.c.rectangle(0, 0, W, H); t.gradiente(0, 0, 0, H, [(0, "#4f5861"), (1, "#3a4148")])
    for y in (30, 60): t.linha([(0, y), (W, y)], 10, "#69737d")
    for x in range(80, W, 230):
        t.rret(x, 6, 20, 40, 4); t.pintar("#ff9b2a", lw=2.5)
    # esteira circular de bagagens ao fundo
    def esteira(dx):
        x = 200 + dx
        t.rret(x, H - 130, 600, 70, 30); t.pintar("#2b2f33", lw=4)
        t.rret(x + 20, H - 120, 560, 20, 8); t.pintar("#5d656e", lw=3)
        for k, c in enumerate(["#c0392b", "#2980b9", "#27ae60", "#8e44ad", "#f39c12", "#2c3e50"]):
            t.rret(x + 40 + k * 90, H - 150, 60, 36, 8); t.pintar(c, lw=3.5)
    emenda(esteira)
    t.rret(40, 100, 260, 60, 6); t.pintar("#f2c230", lw=4); t.texto("ÁREA RESTRITA", 170, 130, 24, TINTA)
    t.rret(900, 100, 340, 60, 6); t.pintar("#f2c230", lw=4); t.texto("BAGAGENS · GRU", 1070, 130, 24, TINTA)
    salvar(t, "parede_subsolo", H)


def finger():
    H = int(3.3 * P)
    t = Tela(W, H)
    t.c.rectangle(0, 0, W, H); t.gradiente(0, 0, 0, H, [(0, "#d7dce0"), (1, "#bfc6cc")])
    for x in range(0, W, 22): t.linha([(x, 0), (x, H)], 2, "#b2bac1")
    for x in range(60, W, 231):
        t.rret(x, 50, 110, 70, 14); t.gradiente(x, 50, x, 120, [(0, "#9fb4c4"), (0.7, "#c3cdd5"), (0.72, "#666e76"), (1, "#5a6168")], contorno=True, lw=4)
    t.c.rectangle(0, 0, W, 14); t.c.set_source_rgba(*cor("#8a939b")); t.c.fill()
    salvar(t, "parede_finger", H)


def frente_trem():
    t = Tela(1400, 900)
    t.c.rectangle(0, 0, 1400, 900); t.gradiente(0, 0, 0, 900, [(0, "#8191a3"), (0.62, "#c1ccd5"), (1, "#d3dbe1")])
    global W
    W0 = W; W = 1400
    predios(t, 560, 0, 120, 300, ["#aab5c0", "#b4bec8"], janelas=False, semente=12, traco=2)
    x = 700
    t.poli([(x - 60, 560), (x, 150), (x + 60, 560), (x + 30, 560), (x, 260), (x - 30, 560)]); t.pintar("#eef1f3", lw=3)
    for k in range(-9, 10):
        if k: t.linha([(x, 180 + abs(k) * 4), (x + k * 40, 470)], 2, "#f4f6f8")
    t.rret(x - 420, 466, 840, 18, 4); t.pintar("#dfe4e8", lw=2.5)
    predios(t, 600, 0, 60, 200, ["#8e9aa6", "#97a3ae", "#86929e"], semente=14)
    t.c.rectangle(0, 596, 1400, 304); t.gradiente(0, 596, 0, 900, [(0, "#6d7a64"), (1, "#56634f")])
    W = W0
    t.salvar("frente_trem.png", BG); META["frente_trem"] = {"w": 1400 / P, "h": 900 / P, "pxm": P, "horizonte": 596}


if __name__ == "__main__":
    ceu_sp()
    parede("parede_checkin", "#e3e8ec", LATAM2, "TERMINAL 3 · CHECK-IN")
    def seg_extra(t, H):
        for x in range(240, W, 462):
            t.rret(x - 120, 160, 240, H - 260, 8); t.gradiente(x - 120, 160, x - 120, H - 100, [(0, "#eef3f6"), (1, "#d5dde3")], contorno=True, lw=4)
            t.texto("INSPEÇÃO", x, 230, 28, "#0d4a2b")
            t.texto("DE SEGURANÇA", x, 266, 22, "#0d4a2b")
    parede("parede_seguranca", "#dfe6eb", "#0d4a2b", "INSPEÇÃO DE SEGURANÇA", janelas=False, extra=seg_extra)
    def emb_extra(t, H):
        anuncio(t, 520, 190)
    parede("parede_embarque", "#ece8df", LATAM2, "EMBARQUE DOMÉSTICO · PORTÕES 201-230", extra=emb_extra)
    subsolo(); finger(); frente_trem()
    json.dump(META, open(os.path.join(BG, "fundos.json"), "w"), indent=1)
    print("ok")
