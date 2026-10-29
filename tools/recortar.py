"""Recorta as folhas geradas no Gemini (fundo verde liso) em quadros transparentes do mesmo tamanho.

Uso típico (em Python):
    from recortar import abrir_sem_verde, quadros, montar_folha
    img = abrir_sem_verde("gemini/mascote_corre.png")
    qs = quadros(img, n=8)                      # separa pelas colunas vazias
    montar_folha(qs, "assets/sprites/mascote_corre.png", quadro=(256, 256), pe=(128, 248), altura=205)
"""
import numpy as np
from PIL import Image


def abrir_sem_verde(caminho, limiar=40):
    """Tira o fundo verde (chroma key) com borda suave e remove o reflexo verde nas bordas."""
    im = Image.open(caminho).convert("RGBA")
    a = np.asarray(im).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    verdice = g - np.maximum(r, b)              # quanto o pixel é "mais verde" que o resto
    alfa = np.clip(1.0 - (verdice - limiar) / 60.0, 0.0, 1.0)
    alfa[(g > 150) & (verdice > limiar + 60)] = 0.0
    # tira o verde que vazou nas bordas
    g2 = np.where(verdice > 0, np.maximum(r, b) + np.clip(verdice, 0, 10), g)
    a[..., 1] = np.where(alfa < 1.0, g2, g)
    a[..., 3] = np.minimum(a[..., 3], alfa * 255)
    out = Image.fromarray(a.astype(np.uint8), "RGBA")
    return limpar_ruido(out)


def limpar_ruido(im, minimo=60):
    """Apaga pontinhos soltos (manchas pequenas) que sobraram do fundo."""
    a = np.asarray(im).copy()
    m = a[..., 3] > 20
    from collections import deque
    vis = np.zeros_like(m)
    H, W = m.shape
    for y in range(0, H, 1):
        xs = np.where(m[y] & ~vis[y])[0]
        for x in xs:
            if vis[y, x]:
                continue
            fila = deque([(y, x)]); vis[y, x] = True; pix = [(y, x)]
            while fila:
                cy, cx = fila.popleft()
                for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                    if 0 <= ny < H and 0 <= nx < W and m[ny, nx] and not vis[ny, nx]:
                        vis[ny, nx] = True; fila.append((ny, nx)); pix.append((ny, nx))
            if len(pix) < minimo:
                for py, px in pix:
                    a[py, px, 3] = 0
    return Image.fromarray(a, "RGBA")


def _faixas(perfil, gap_min):
    cheio = perfil > 0
    faixas, ini, vazio = [], None, 0
    for i, c in enumerate(cheio):
        if c:
            if ini is None:
                ini = i
            vazio = 0
        elif ini is not None:
            vazio += 1
            if vazio >= gap_min:
                faixas.append((ini, i - vazio + 1)); ini = None; vazio = 0
    if ini is not None:
        faixas.append((ini, len(cheio)))
    return faixas


def quadros(im, n=None, linhas=1, gap_min=6):
    """Separa os desenhos. Com linhas>1, corta primeiro em faixas horizontais."""
    a = np.asarray(im)[..., 3]
    res = []
    if linhas > 1:
        fa = _faixas((a > 20).sum(axis=1), gap_min * 2)
        if len(fa) != linhas:
            h = im.height // linhas
            fa = [(i * h, (i + 1) * h) for i in range(linhas)]
        for (y0, y1) in fa:
            res += quadros(im.crop((0, y0, im.width, y1)), None, 1, gap_min)
        return res
    fx = _faixas((a > 20).sum(axis=0), gap_min)
    fx = [f for f in fx if f[1] - f[0] > 12]
    if n is not None and len(fx) != n:
        # junta os pedaços mais próximos até dar n, ou divide em partes iguais
        while len(fx) > n:
            dist = [fx[i + 1][0] - fx[i][1] for i in range(len(fx) - 1)]
            k = int(np.argmin(dist)); fx[k] = (fx[k][0], fx[k + 1][1]); del fx[k + 1]
        if len(fx) < n:
            w = im.width / n
            fx = [(int(i * w), int((i + 1) * w)) for i in range(n)]
    for (x0, x1) in fx:
        q = im.crop((x0, 0, x1, im.height))
        bb = q.getbbox()
        if bb:
            res.append(q.crop(bb))
    return res


def montar_folha(qs, destino, quadro=(256, 256), pe=(128, 248), altura=None, escala=None, alinhar="base", ref=0):
    """Coloca cada desenho num quadro de tamanho fixo, com os pés em 'pe'. 'altura' define a escala
    pela altura do quadro de referência (ref); todos os quadros usam a mesma escala."""
    if escala is None:
        escala = (altura / qs[ref].height) if altura else 1.0
    W, H = quadro
    folha = Image.new("RGBA", (W * len(qs), H), (0, 0, 0, 0))
    for i, q in enumerate(qs):
        q2 = q.resize((max(1, round(q.width * escala)), max(1, round(q.height * escala))), Image.LANCZOS)
        if q2.width > W or q2.height > H:
            k = min(W / q2.width, H / q2.height)
            q2 = q2.resize((max(1, int(q2.width * k)), max(1, int(q2.height * k))), Image.LANCZOS)
        x = int(pe[0] - q2.width / 2)
        y = int(pe[1] - q2.height) if alinhar == "base" else int((H - q2.height) / 2)
        x = max(0, min(W - q2.width, x)); y = max(0, min(H - q2.height, y))
        folha.alpha_composite(q2, (i * W + x, y))
    folha.save(destino)
    return escala


def objeto(q, destino, largura_m=None, altura_m=None, pxm=132, margem=10):
    """Salva um objeto único na escala do jogo (132 px por metro), com margem e base embaixo."""
    if largura_m:
        k = largura_m * pxm / q.width
    else:
        k = altura_m * pxm / q.height
    q2 = q.resize((max(1, round(q.width * k)), max(1, round(q.height * k))), Image.LANCZOS)
    out = Image.new("RGBA", (q2.width + margem * 2, q2.height + margem * 2), (0, 0, 0, 0))
    out.alpha_composite(q2, (margem, margem))
    out.save(destino)
    return {"w": out.width / pxm, "h": out.height / pxm, "pxm": pxm, "base": margem / pxm, "quadros": 1}


def componentes(im, dil=9, area_min=1500, linha_tol=0.5):
    """Separa cada desenho pelo contorno (para folhas sem grade). Ordem: linha por linha, da esquerda
    para a direita. Desenhos que se tocam por pouco ficam juntos."""
    from scipy import ndimage
    a = np.asarray(im)[..., 3] > 30
    m = ndimage.binary_dilation(a, iterations=dil)
    lab, n = ndimage.label(m)
    caixas = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        if sl is None:
            continue
        y0, y1, x0, x1 = sl[0].start, sl[0].stop, sl[1].start, sl[1].stop
        if (a[y0:y1, x0:x1] & (lab[y0:y1, x0:x1] == i + 1)).sum() < area_min:
            continue
        caixas.append((x0, y0, x1, y1, i + 1))
    # agrupa em linhas pelo centro vertical
    caixas.sort(key=lambda c: (c[1] + c[3]) / 2)
    linhas = []
    for c in caixas:
        cy = (c[1] + c[3]) / 2; h = c[3] - c[1]
        for L in linhas:
            if abs(L["cy"] - cy) < linha_tol * max(h, L["h"]):
                L["itens"].append(c); break
        else:
            linhas.append({"cy": cy, "h": h, "itens": [c]})
    res = []
    arr = np.asarray(im)
    for L in linhas:
        for (x0, y0, x1, y1, k) in sorted(L["itens"], key=lambda c: c[0]):
            sub = arr[y0:y1, x0:x1].copy()
            mask = (lab[y0:y1, x0:x1] == k)
            sub[..., 3] = np.where(mask, sub[..., 3], 0)
            q = Image.fromarray(sub, "RGBA")
            res.append(q.crop(q.getbbox()))
    return res


def contato(qs, destino, alt=160):
    """Prancha numerada para conferir a ordem dos pedaços."""
    from PIL import ImageDraw
    thumbs = []
    for q in qs:
        k = alt / max(q.height, 1)
        thumbs.append(q.resize((max(1, int(q.width * k)), alt)))
    W = 1600; x = y = 0; lin = 0; pos = []
    for t in thumbs:
        if x + t.width > W:
            x = 0; y += alt + 30
        pos.append((x, y)); x += t.width + 20
    out = Image.new("RGBA", (W, y + alt + 30), (90, 110, 130, 255))
    d = ImageDraw.Draw(out)
    for i, (t, p) in enumerate(zip(thumbs, pos)):
        out.alpha_composite(t, (p[0], p[1] + 24)); d.text((p[0] + 4, p[1] + 4), str(i), fill=(255, 255, 0, 255))
    out.convert("RGB").save(destino)
