#!/usr/bin/env python3
"""Monta a arte do "Cadê as milhas?!" a partir das folhas geradas no Gemini (art_src/gemini/*.jpg, fundo verde).

Gera, no lugar da arte do Encontre-a (mesmos nomes, tamanhos e âncoras, para o motor nem perceber):
  - o Milis: assets/sprites/tome/*.png (quadros 256x256), pai.png / pai2.png (170x160), pai_climb, pai_rope_*,
    pai_vine_* e as poses do atlas (abaixado, engatinhando, empurrando, golpe com o bastão...)
  - a Bag: assets/sprites/novos/pipoca.png
  - inimigos: cambista (en_boar, boar_wind, boar_ko), robô falsificado (en_frog2, frog_ko, frog_tongue),
    mala-monstro (bat*), Motoboy Turbo (javali.png, boss_charge.png)
  - objetos, ícones, pisos e fundos
As poses que ficam dentro dos atlas antigos vão para um atlas novo (assets/sprites/milhas.png +
assets/data/milhas.json), que o Spr carrega por cima dos nomes antigos.

Rodar:  python3 tools/make_arte.py   (depois: python3 tools/make_sil.py e godot --import)
"""
import json, os, sys
from PIL import Image, ImageOps
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recortar import abrir_sem_verde, componentes, quadros

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
G = os.path.join(ROOT, "art_src", "gemini")
SPR = os.path.join(ROOT, "assets", "sprites")
BG = os.path.join(ROOT, "assets", "bg")
UI = os.path.join(ROOT, "assets", "ui")
ATL = json.load(open(os.path.join(ROOT, "assets", "data", "atlas.json")))
PNT = json.load(open(os.path.join(ROOT, "assets", "data", "paint.json")))

_cache = {}


def comps(nome, dil=6, amin=2500):
    if nome not in _cache:
        _cache[nome] = componentes(abrir_sem_verde(os.path.join(G, nome + ".jpg")), dil=dil, area_min=amin)
    return _cache[nome]


def espelha(q):
    return ImageOps.mirror(q)


def corta_topo(q, px):
    return q.crop((0, px, q.width, q.height))


def cel(q, W, H, k, fx, fy, chao=True):
    """um quadro WxH com o desenho q na escala k, pés (base) em (fx, fy) ou centrado em (fx, fy)"""
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    q2 = q.resize((max(1, round(q.width * k)), max(1, round(q.height * k))), Image.LANCZOS)
    if q2.width > W or q2.height > H:
        kk = min(W / q2.width, H / q2.height)
        q2 = q2.resize((max(1, int(q2.width * kk)), max(1, int(q2.height * kk))), Image.LANCZOS)
    x = int(round(fx - q2.width / 2))
    y = int(round(fy - q2.height)) if chao else int(round(fy - q2.height / 2))
    x = max(0, min(W - q2.width, x))
    y = max(0, min(H - q2.height, y))
    out.alpha_composite(q2, (x, y))
    return out


def folha(qs, W, H, k, fx, fy, chao=True):
    out = Image.new("RGBA", (W * len(qs), H), (0, 0, 0, 0))
    for i, q in enumerate(qs):
        out.alpha_composite(cel(q, W, H, k, fx, fy, chao), (i * W, 0))
    return out


def caber(q, w, h, ax, ay, marg=1):
    """encaixa q num retângulo w x h (mantém a proporção): base na âncora se ela estiver embaixo"""
    k = min((w - 2 * marg) / q.width, (h - 2 * marg) / q.height)
    chao = ay >= h * .7
    return cel(q, w, h, k, ax, ay if chao else ay, chao)


def salva(im, *caminho):
    p = os.path.join(*caminho)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    im.save(p)


# ------------------------------------------------------------------ atlas novo (substitui nomes antigos)
NOVO = {}      # nome -> imagem (já no tamanho do retângulo) e âncora


def troca(nome, q, w=None, h=None, ax=None, ay=None):
    """troca a peça 'nome' de atlas1/atlas2/paint (ou cria uma nova com w,h,ax,ay)"""
    r = None
    if nome.startswith("p_"):
        r = PNT.get(nome[2:])
    else:
        r = ATL["atlas1"].get(nome) or ATL["atlas2"].get(nome) or PNT.get(nome)
    if r is not None:
        w, h, ax, ay = r[2], r[3], r[4], r[5]
    NOVO[nome] = (caber(q, int(w), int(h), ax, ay), float(ax), float(ay))


def grava_atlas():
    # empacotamento em prateleiras
    itens = sorted(NOVO.items(), key=lambda kv: -kv[1][0].height)
    W = 2048
    x = y = alt = 0
    pos = {}
    for n, (im, ax, ay) in itens:
        if x + im.width + 2 > W:
            x = 0
            y += alt + 2
            alt = 0
        pos[n] = (x, y)
        x += im.width + 2
        alt = max(alt, im.height)
    H = y + alt + 2
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    js = {}
    for n, (im, ax, ay) in itens:
        px, py = pos[n]
        out.alpha_composite(im, (px, py))
        js[n] = [px, py, im.width, im.height, ax, ay]
    out.save(os.path.join(SPR, "milhas.png"))
    json.dump(js, open(os.path.join(ROOT, "assets", "data", "milhas.json"), "w"), indent=0)
    print("atlas milhas.png", out.size, len(js), "peças")


# ======================================================================
#  MILIS
# ======================================================================
def milis():
    corre = comps("milis_corre")
    A = comps("milis_poses_a")
    B = comps("milis_poses_b")
    C = comps("milis_poses_c")
    # a última "peça" da folha B junta 5 poses pequenas lado a lado: separa pelas colunas
    b6 = quadros(B[6], n=5)
    golpe, defesa, plana1, plana2, mergulho = b6
    PE = 330.0                                   # altura do Milis em pé nas folhas do Gemini
    k = 205.0 / PE                               # quadros de 256: o Tomé tinha ~210 px
    T = os.path.join(SPR, "tome")
    sheets = {
        "walk": corre[0:6], "run": corre[6:12],
        "jump": [A[1], A[2], A[3]], "fall": [A[4], A[4]], "land": [A[9], A[9], A[0]],
        "lantern": [A[0], C[7]], "shiver": [A[0], A[0], A[0]], "look": [A[8]], "lookback": [espelha(A[0])],
        "rain": [A[5]], "tired": [A[11]], "push": [B[3]], "ice": [A[0]], "hurt": [A[6]], "cheer": [A[7]],
        "idle": [A[0], C[7]],
    }
    for n, qs in sheets.items():
        salva(folha(qs, 256, 256, k, 128, 254), T, n + ".png")
    # folhas antigas 170x160 (âncora 85,156): parado, andando, pulo, planando, mergulho, machucado
    k2 = 137.0 / PE
    pai = [A[0], corre[0], corre[2], corre[4], A[1], A[2], A[3], A[4], A[5]]
    pai2 = [plana1, plana2, plana1, plana2, mergulho, mergulho, A[6], mergulho, A[6]]
    salva(folha(pai, 170, 160, k2, 85, 156), SPR, "pai.png")
    salva(folha(pai2, 170, 160, k2, 85, 156), SPR, "pai2.png")
    # peças soltas (mesmo tamanho das antigas)
    soltas = {"pai_climb": C[0], "pai_rope_a": C[4], "pai_rope_b": C[4], "pai_vine_a": C[5],
              "pai_vine_b": corta_topo(C[2], 40)}
    for n, q in soltas.items():
        old = Image.open(os.path.join(SPR, n + ".png"))
        w, h = old.size
        salva(caber(q, w, h, w / 2, h), SPR, n + ".png")
    # poses do atlas
    P = {"pai_crouch": A[9], "pai_crawl1": B[0], "pai_crawl2": B[1], "pai_crawl3": B[0], "pai_crawl4": B[2],
         "pai_slide": B[2], "pai_push1": B[3], "pai_push2": B[4], "pai_push3": B[3], "pai_throw": B[5],
         "pai_throw1": B[5], "pai_throw2": golpe, "pai_run1": corre[6], "pai_run2": corre[9],
         "pai_swim1": plana1, "pai_swim2": plana2, "pai_vine1": C[5], "pai_vine2": corta_topo(C[3], 40),
         "pai_lad1": C[0], "pai_lad2": C[1], "pai_lookup": A[8], "pai_rope1": C[4], "pai_rope2": C[4],
         "pai_gear": A[0], "pai_harpoon": golpe, "pai_beam": defesa, "pai_blow": A[7]}
    for n, q in P.items():
        troca(n, q)
    # retratos (botões e falas)
    retrato = A[7].crop((0, 0, A[7].width, int(A[7].height * .55)))
    for n in ["btn_tome"]:
        im = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        im.alpha_composite(cel(retrato, 256, 256, 230 / max(retrato.size), 128, 128, False))
        salva(im, UI, n + ".png")
    return {"golpe": golpe, "defesa": defesa, "acena": C[8], "sentado": C[6], "parado": A[0], "festa": A[7]}


# ======================================================================
#  BAG
# ======================================================================
def bag():
    b = comps("bag")
    # quadros: 0-5 rolando, 6-7 parada, 8-9 buzinando, 10-11 aberta, 12 carregando, 13 presa
    qs = b[0:6] + [b[6], b[7], b[8], b[9], b[10], b[10], b[6], b[11]]
    s = 256
    k = 205.0 / 316.0
    salva(folha(qs, s, s, k, 128, 254), SPR, "novos", "pipoca.png")
    for i, n in enumerate(["dog0", "dog1", "dog2", "dog3"]):
        troca(n, b[i])
    troca("dog_dead", b[11])
    rt = b[7].crop((0, int(b[7].height * .2), b[7].width, int(b[7].height * .85)))
    salva(cel(rt, 256, 256, 230 / max(rt.size), 128, 128, False), UI, "btn_dog.png")
    for n, q in [("dog_dig", b[10]), ("dog_joy", b[8]), ("dog_sniff", b[7])]:
        old = Image.open(os.path.join(SPR, n + ".png"))
        salva(caber(q, old.width, old.height, old.width / 2, old.height), SPR, n + ".png")
    return b


# ======================================================================
#  INIMIGOS E CHEFE
# ======================================================================
def inimigos():
    c = comps("cambista")
    k = 132.0 / 296.0
    salva(folha(c[0:6], 210, 140, k, 105, 136), SPR, "en_boar.png")
    salva(caber(c[6], 172, 124, 86, 122), SPR, "boar_wind.png")
    salva(caber(c[9], 137, 119, 68, 117), SPR, "boar_ko.png")
    r = comps("robo_falso")
    # sapo: 0-1 parado, 2 agachado, 3 no ar, 4 pousando (quadros 130x70, pés em 65,68)
    k = 66.0 / 330.0
    salva(folha([r[5], r[6], r[0], r[2], r[3]], 130, 70, k, 65, 68), SPR, "en_frog2.png")
    salva(caber(r[10], 100, 50, 50, 48), SPR, "frog_ko.png")
    salva(caber(r[1], 132, 58, 66, 56), SPR, "frog_tongue.png")
    for n, q in [("en_frog", r[5]), ("en_frog_jump", r[2]), ("en_frog_dead", r[10])]:
        troca(n, q)
    m = comps("mala_monstro")
    for n, q in [("p_bat0", m[2]), ("p_bat1", m[3]), ("p_bat2", m[4]), ("p_bat_hang", m[0])]:
        troca(n, q)
    mb = comps("motoboy")
    # javali.png: 0-3 trotando, 4 raspando a pata, 5 investindo, 6 caído (quadros 210x140, pés em 105,136)
    k = 136.0 / 330.0
    salva(folha([mb[0], mb[1], mb[0], mb[1], mb[1], mb[2], mb[6]], 210, 140, k, 105, 136), SPR, "javali.png")
    salva(caber(mb[3], 420, 280, 210, 272), SPR, "boss_charge.png")
    return c, r, m, mb


# ======================================================================
#  OBJETOS E ÍCONES
# ======================================================================
def objetos():
    p = comps("props")
    i = comps("itens")
    troca("o_fire_off", p[0])
    troca("o_fire_on", p[1])
    troca("p_crate", p[2])
    troca("p_crate_heart", p[3])
    troca("crate_coin", p[4])
    troca("crate_heart", p[3])
    troca("crate_armor", p[5])
    troca("crate_push", p[5])
    for n in ["mu_0", "mu_1", "mu_2"]:
        troca(n, p[6])
    moeda = p[7]
    for n in ["coin1", "coin2", "coin3", "coin4"]:
        troca(n, moeda)
    # as milhas ("lápis"): desenho fino e alto no atlas antigo; a moeda fica do mesmo tamanho na tela
    for n in ["pen_vermelho", "pen_laranja", "pen_amarelo", "pen_verde", "pen_azul", "pen_roxo"]:
        NOVO[n] = (cel(moeda, 30, 30, 28 / max(moeda.size), 15, 15, False), 15.0, 15.0)
    NOVO["pen_gold"] = (cel(ImageOps.colorize(moeda.convert("L"), "#6a4a00", "#ffe066").convert("RGBA"), 36, 36, 34 / max(moeda.size), 18, 18, False), 18.0, 18.0)
    NOVO["pen_gold"][0].putalpha(cel(moeda, 36, 36, 34 / max(moeda.size), 18, 18, False).getchannel("A"))
    troca("drawing", p[8])
    troca("hud_paper", p[8])
    troca("hud_lantern_full", p[9])
    troca("hud_lantern_empty", ImageOps.grayscale(p[9]).convert("RGBA"))
    NOVO["hud_lantern_empty"][0].putalpha(caber(p[9], NOVO["hud_lantern_empty"][0].width, NOVO["hud_lantern_empty"][0].height, NOVO["hud_lantern_empty"][1], NOVO["hud_lantern_empty"][2]).getchannel("A"))
    troca("o_ladder", p[10])
    troca("p_ladder", p[10])
    troca("door_closed", p[11])
    troca("door_open", p[12])
    # itens da fase (nomes novos)
    for n, q in [("it_cartao_acesso", i[0]), ("it_cordao", i[1]), ("it_cracha", i[2]), ("it_fusivel", i[3]),
                 ("it_fita", i[4]), ("it_fusivel_ok", i[5]), ("it_picareta", None)]:
        if q is None:
            continue
        troca(n, q, 72, 56, 36, 28)
    # pistas: ícone no chão (cl_N) e cartão grande (clb_N)
    for cid, q in enumerate([i[6], i[7], i[8], i[9], i[10], i[11]], start=1):
        troca("cl_%d" % cid, q, 60, 60, 30, 30)
        troca("clb_%d" % cid, q, 219, 220, 109, 110)
    return p, i


def bastao(info):
    """o bastão de sinalização (no lugar da picareta): recorta da pose de golpe a parte laranja"""
    g = info["golpe"]
    import numpy as np
    a = np.asarray(g).astype(int)
    lar = (a[..., 0] > 200) & (a[..., 1] > 80) & (a[..., 1] < 200) & (a[..., 2] < 90) & (a[..., 3] > 100)
    ys, xs = np.where(lar)
    if len(xs) > 20:
        cx0, cx1, cy0, cy1 = xs.min(), xs.max(), ys.min(), ys.max()
        b = g.crop((max(0, cx0 - 6), max(0, cy0 - 6), cx1 + 6, cy1 + 6))
    else:
        b = g
    NOVO["it_picareta"] = (caber(b, 102, 110, 51, 55), 51.0, 55.0)
    im = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    im.alpha_composite(cel(b, 256, 256, 220 / max(b.size), 128, 128, False))
    salva(im, UI, "btn_golpe.png")


# ======================================================================
#  PISOS E FUNDOS
# ======================================================================
def pisos():
    im = Image.open(os.path.join(G, "pisos.jpg")).convert("RGB")
    a = abrir_sem_verde(os.path.join(G, "pisos.jpg"))
    import numpy as np
    al = np.asarray(a)[..., 3] > 100
    rows = al.mean(axis=1) > .5
    # faixas horizontais cheias
    faixas, ini = [], None
    for y, r in enumerate(rows):
        if r and ini is None:
            ini = y
        elif not r and ini is not None:
            if y - ini > 20:
                faixas.append((ini, y))
            ini = None
    if ini is not None and len(rows) - ini > 20:
        faixas.append((ini, len(rows)))
    print("pisos: faixas", faixas)
    def tira(i, dest, W=515, H=150, borda=32):
        y0, y1 = faixas[i]
        s = im.crop((0, y0, im.width, y1))
        # topo (borda) + corpo esticado até H
        s = s.resize((W, int(s.height * W / s.width)), Image.LANCZOS)
        out = Image.new("RGB", (W, H))
        if s.height >= H:
            out.paste(s.crop((0, 0, W, H)), (0, 0))
        else:
            out.paste(s, (0, 0))
            fundo = s.crop((0, s.height - 4, W, s.height)).resize((W, H - s.height))
            out.paste(fundo, (0, s.height))
        # emenda sem costura: mistura as pontas
        o = out.convert("RGBA")
        o.save(os.path.join(SPR, dest))
        return o
    if len(faixas) >= 3:
        tira(0, "chao_vila.png")
        tira(1, "chao_mina.png")
        c = tira(2, "chao.png", W=127)
    if len(faixas) >= 4:
        y0, y1 = faixas[3]
        s = a.crop((0, y0, a.width, y1))
        bb = s.getbbox()
        s = s.crop(bb) if bb else s
        troca("p_seesaw_plank", s)
        troca("p_plank", s)


def fundos():
    m = {"bosque": "bg_terminal", "vila": "bg_terminal", "tarde": "bg_seguranca", "noite": "bg_mezanino",
         "mina": "bg_subsolo", "pantano": "bg_patio", "moinho": "bg_hangar", "esconderijo": "bg_hangar",
         "neve": "bg_pista"}
    for k, src in m.items():
        im = Image.open(os.path.join(G, src + ".jpg")).convert("RGB")
        if im.size != (1792, 592):
            # recorta a faixa do meio na proporção 3:1
            h = int(im.width / (1792 / 592))
            y0 = max(0, (im.height - h) // 2)
            im = im.crop((0, y0, im.width, y0 + h)).resize((1792, 592), Image.LANCZOS)
        im.save(os.path.join(BG, k + ".jpg"), quality=90)
    print("fundos ok")


def cabo():
    """cabo de aço (no lugar do cipó): trançado cinza com contorno escuro, emenda sem costura na vertical"""
    from PIL import ImageDraw
    r = PNT["vine"]
    w, h = int(r[2]), int(r[3])
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx = w / 2
    d.rectangle((cx - 12, 0, cx + 12, h), fill=(32, 34, 38, 255))
    d.rectangle((cx - 8, 0, cx + 8, h), fill=(150, 158, 166, 255))
    for y in range(-30, h + 30, 15):
        d.line((cx - 8, y, cx + 8, y + 14), fill=(88, 94, 102, 255), width=4)
        d.line((cx - 7, y + 5, cx + 2, y + 13), fill=(214, 220, 226, 255), width=2)
    NOVO["p_vine"] = (im, float(r[4]), float(r[5]))


if __name__ == "__main__":
    cabo()
    info = milis()
    bag()
    inimigos()
    objetos()
    bastao(info)
    pisos()
    fundos()
    grava_atlas()
