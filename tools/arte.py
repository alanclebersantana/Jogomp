"""Prepara a arte do jogo a partir das folhas do Gemini (art_src/gemini) e dos desenhos feitos em código
(tools/desenhos.py). Grava as tiras de animação em assets/art/*.png e o índice em assets/art/arte.json.

Escala: o mundo do jogo usa 1 unidade = 1 px lógico; as imagens ficam no dobro do tamanho (s = 0.5)
para continuarem nítidas no celular. Cada animação é uma tira horizontal de quadros iguais (w x h) com
a âncora (ax, ay) — os pés, ou o centro para objetos que flutuam.

Uso: python3 tools/arte.py
"""
import json, os, sys
from PIL import Image, ImageOps, ImageFilter, ImageEnhance

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
from recortar import abrir_sem_verde, componentes, quadros  # noqa: E402
import desenhos  # noqa: E402

ROOT = os.path.join(AQUI, "..")
G = os.path.join(ROOT, "art_src", "gemini")
OUT = os.path.join(ROOT, "assets", "art")
os.makedirs(OUT, exist_ok=True)

IDX = {}
_cache = {}


def comps(nome):
    if nome not in _cache:
        _cache[nome] = componentes(abrir_sem_verde(os.path.join(G, nome + ".jpg")), dil=6, area_min=2500)
    return _cache[nome]


def cel(q, W, H, k, fx, fy, base=True):
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    q2 = q.resize((max(1, round(q.width * k)), max(1, round(q.height * k))), Image.LANCZOS)
    if q2.width > W or q2.height > H:
        kk = min(W / q2.width, H / q2.height)
        q2 = q2.resize((max(1, int(q2.width * kk)), max(1, int(q2.height * kk))), Image.LANCZOS)
    x = int(round(fx - q2.width / 2))
    y = int(round(fy - q2.height)) if base else int(round(fy - q2.height / 2))
    x = max(0, min(W - q2.width, x))
    y = max(0, min(H - q2.height, y))
    out.alpha_composite(q2, (x, y))
    return out


def anim(nome, qs, W, H, k, fx, fy, base=True, fps=10):
    """grava a tira e registra no índice (medidas já na escala do mundo: metade das da imagem)"""
    tira = Image.new("RGBA", (W * len(qs), H), (0, 0, 0, 0))
    for i, q in enumerate(qs):
        tira.alpha_composite(cel(q, W, H, k, fx, fy, base), (i * W, 0))
    tira.save(os.path.join(OUT, nome + ".png"))
    IDX[nome] = {"file": nome + ".png", "w": W, "h": H, "n": len(qs), "ax": fx, "ay": fy, "fps": fps}


def solta(nome, im, ax=None, ay=None, fps=10):
    """uma imagem pronta (ou tira com n quadros se 'im' for lista)"""
    ims = im if isinstance(im, list) else [im]
    W = max(i.width for i in ims)
    H = max(i.height for i in ims)
    tira = Image.new("RGBA", (W * len(ims), H), (0, 0, 0, 0))
    for n, i in enumerate(ims):
        tira.alpha_composite(i, (n * W + (W - i.width) // 2, H - i.height))
    tira.save(os.path.join(OUT, nome + ".png"))
    IDX[nome] = {"file": nome + ".png", "w": W, "h": H, "n": len(ims),
                 "ax": W / 2 if ax is None else ax, "ay": H if ay is None else ay, "fps": fps}


def caber(q, alvo_w=None, alvo_h=None):
    k = (alvo_w / q.width) if alvo_w else (alvo_h / q.height)
    return q.resize((max(1, round(q.width * k)), max(1, round(q.height * k))), Image.LANCZOS)


# ======================================================================
def milis():
    corre = comps("milis_corre")
    A = comps("milis_poses_a")
    B = comps("milis_poses_b")
    C = comps("milis_poses_c")
    golpe, defesa, plana1, plana2, mergulho = quadros(B[6], n=5)
    k = 172.0 / 330.0          # Milis em pé: 86 de altura no mundo (172 px na imagem)
    W, H, fx, fy = 240, 240, 120, 234
    anim("milis_corre", corre[6:12], W, H, k, fx, fy, fps=14)
    anim("milis_anda", corre[0:6], W, H, k, fx, fy, fps=10)
    anim("milis_parado", [A[0], C[7]], W, H, k, fx, fy, fps=1.5)
    anim("milis_sobe", [A[1]], W, H, k, fx, fy)
    anim("milis_duplo", [A[2], A[3]], W, H, k, fx, fy, fps=12)
    anim("milis_cai", [mergulho], W, H, k, fx, fy)
    anim("milis_plana", [plana1, plana2], W, H, k, fx, fy, fps=6)
    anim("milis_tonto", [A[6]], W, H, k, fx, fy)
    anim("milis_sentado", [C[6]], W, H, k, fx, fy)
    anim("milis_festa", [A[7], A[3]], W, H, k, fx, fy, fps=4)
    anim("milis_acena", [C[8], C[7]], W, H, k, fx, fy, fps=2)
    anim("milis_cansado", [A[11]], W, H, k, fx, fy)
    anim("milis_escala", [C[0], C[1]], W, H, k, fx, fy, fps=8)
    # retrato para botões e ícone
    ret = A[7].crop((0, 0, A[7].width, int(A[7].height * .56)))
    solta("ret_milis", cel(ret, 200, 200, 190 / max(ret.size), 100, 100, False), 100, 100)
    return A, C


def capangas():
    c = comps("cambista")
    k = 188.0 / 296.0
    anim("cambista_anda", c[0:6], 260, 250, k, 130, 244, fps=9)
    anim("cambista_tonto", [c[8]], 260, 250, k, 130, 244)
    anim("cambista_ko", [c[9]], 300, 250, k, 150, 244)
    anim("cambista_corre", [c[7]], 300, 250, k, 150, 244)
    r = comps("robo_falso")
    k = 168.0 / 330.0
    anim("robo_anda", [r[6], r[7], r[8], r[9]], 240, 240, k, 120, 234, fps=8)
    anim("robo_corre", [r[1], r[3]], 240, 240, k, 120, 234, fps=8)
    anim("robo_ko", [r[10]], 300, 240, k, 150, 234)
    m = comps("mala_monstro")
    k = 140.0 / 303.0
    anim("mala_voa", [m[2], m[4], m[2], m[3]], 190, 150, k, 95, 75, base=False, fps=6)
    anim("mala_tonta", [m[5]], 190, 150, k, 95, 75, base=False)
    mb = comps("motoboy")
    k = 230.0 / 330.0
    anim("motoboy", mb[0:3], 300, 260, k, 150, 252, fps=8)
    b = comps("barao")
    anim("barao", [b[1]], 320, 460, 440.0 / 631.0, 160, 452)


def objetos():
    p = comps("props")
    solta("totem", [caber(p[0], alvo_h=170), caber(p[1], alvo_h=170)])
    moeda = caber(p[7], alvo_w=64)
    solta("milha", moeda, 32, 32)
    # LATAM (Guarulhos): anel azul-índigo e centro vermelho-coral
    solta("milha_latam", recolore(moeda, [(285, 246, 1.15), (340, 348, 1.1)]), 32, 32)
    solta("cartao", caber(p[8], alvo_w=110), 55, 36)
    solta("mola", caber(p[6], alvo_h=110))
    solta("caixote", caber(p[5], alvo_w=84), 42, 84)
    solta("caixa", caber(p[4], alvo_w=84), 42, 84)
    solta("porta_saida", [caber(p[11], alvo_h=250), caber(p[12], alvo_h=250)])
    solta("bateria", caber(p[9], alvo_h=70), None, None)


def recolore(im, trocas):
    """troca as cores da moeda das milhas pelas da companhia: trocas = [(matiz_max, matiz_novo, k_sat)]"""
    import numpy as np, colorsys
    a = np.asarray(im.convert("RGBA")).astype(np.float32) / 255
    rgb = a[..., :3]
    mx = rgb.max(-1); mn = rgb.min(-1); d = mx - mn
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    m = d > 1e-6
    h = np.zeros_like(mx)
    h = np.where((mx == r) & m, ((g - b) / np.maximum(d, 1e-6)) % 6, h)
    h = np.where((mx == g) & m, (b - r) / np.maximum(d, 1e-6) + 2, h)
    h = np.where((mx == b) & m, (r - g) / np.maximum(d, 1e-6) + 4, h)
    h = h * 60
    s = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
    v = mx
    alvo = (s > 0.18) & (h > 200) & (h < 340)
    h2 = h.copy(); s2 = s.copy()
    for (hmax, hn, ks) in trocas:
        sel = alvo & (h < hmax)
        h2 = np.where(sel, hn, h2)
        s2 = np.where(sel, np.clip(s * ks, 0, 1), s2)
        alvo = alvo & ~sel
    # hsv -> rgb
    hh = (h2 % 360) / 60
    c = v * s2
    x = c * (1 - np.abs(hh % 2 - 1))
    z = np.zeros_like(c)
    i = np.floor(hh).astype(int) % 6
    rr = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5], [c, x, z, z, x, c])
    gg = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5], [x, c, c, x, z, z])
    bb = np.select([i == 0, i == 1, i == 2, i == 3, i == 4, i == 5], [z, z, x, c, c, x])
    mm = v - c
    out = np.stack([rr + mm, gg + mm, bb + mm, a[..., 3]], -1)
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), "RGBA")


def pisos():
    """tiras de piso emendáveis (topo do chão) e o enchimento das paredes"""
    im = Image.open(os.path.join(G, "pisos.jpg")).convert("RGB")
    a = abrir_sem_verde(os.path.join(G, "pisos.jpg"))
    import numpy as np
    al = np.asarray(a)[..., 3] > 100
    rows = al.mean(axis=1) > .5
    faixas, ini = [], None
    for y, r in enumerate(rows):
        if r and ini is None:
            ini = y
        elif not r and ini is not None:
            if y - ini > 20:
                faixas.append((ini, y))
            ini = None
    nomes = ["piso_terminal", "piso_metal", "piso_asfalto", "piso_viga"]
    for i, (y0, y1) in enumerate(faixas[:4]):
        s = im.crop((4, y0 + 2, im.width - 4, y1 - 2))
        Hh = 96 if i != 3 else 64
        s = s.resize((int(s.width * Hh / s.height), Hh), Image.LANCZOS)
        # emenda sem costura: mistura o fim com o começo
        L = 80
        s = s.convert("RGBA")
        W = s.width - L
        out = s.crop((0, 0, W, Hh))
        fim = s.crop((W, 0, W + L, Hh))
        mask = Image.linear_gradient("L").rotate(90).resize((L, Hh))   # 255 à esquerda -> 0 à direita
        ini_ = out.crop((0, 0, L, Hh))
        mix = Image.composite(fim, ini_, mask)
        out.paste(mix, (0, 0))
        out.convert("RGB").save(os.path.join(OUT, nomes[i] + ".png"))
        IDX[nomes[i]] = {"file": nomes[i] + ".png", "w": out.width, "h": Hh, "n": 1, "ax": 0, "ay": 0, "fps": 1}
    desenhos.enchimentos(OUT, IDX)


def fundos():
    for n in ["terminal", "seguranca", "mezanino", "subsolo", "patio", "hangar", "pista"]:
        im = Image.open(os.path.join(G, "bg_%s.jpg" % n)).convert("RGB")
        k = 1100 / im.height
        im = im.resize((int(im.width * k), 1100), Image.LANCZOS)
        im.save(os.path.join(OUT, "bg_%s.jpg" % n), quality=86)
        IDX["bg_" + n] = {"file": "bg_%s.jpg" % n, "w": im.width, "h": im.height, "n": 1, "ax": 0, "ay": 0, "fps": 1}


def titulo():
    im = Image.open(os.path.join(G, "titulo_v1.jpg")).convert("RGB")
    im.save(os.path.join(OUT, "titulo.jpg"), quality=88)


if __name__ == "__main__":
    milis()
    capangas()
    objetos()
    pisos()
    fundos()
    desenhos.todos(OUT, IDX)
    json.dump(IDX, open(os.path.join(OUT, "arte.json"), "w"), indent=1, sort_keys=True)
    print(len(IDX), "peças em assets/art")
