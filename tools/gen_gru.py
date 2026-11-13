#!/usr/bin/env python3
"""Gera as fases de Guarulhos (Episódio 1 · Brasil) do "Milhas Plus – Cadê as milhas?!".

  level1.json  1-1 Terminal    saguão, check-in, segurança, mezanino e o portão
  level2.json  1-2 Bagagens    subsolo das esteiras (escuro: farol dos olhos), a Bag presa na esteira
  level3.json  1-3 Hangar      pátio na garoa, turbinas, guindastes e o hangar de manutenção
  level4.json  1-4 Chefe       a pista: o Motoboy Turbo, capanga do Barão

O chão fica em y = 500 (o motor conta com isso). Milhas = "coins". Cartões de embarque dourados =
"drawings". Totens de check-in = "checks". Pistas do Barão = "clues" (textos em scripts/data.gd).

Alcances do Milis (física do Encontre-a): pulo ~110 px de altura (segurando), pulo duplo ~200 px;
vão de ~160 px andando e ~250 px correndo; com as asas (planar) bem mais longe.

Rodar:  python3 tools/gen_gru.py
"""
import json, math, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GY = 500
LISTS = ["sections", "darkZones", "caves", "solids", "swamp", "lily", "mud", "climb", "entrances", "bushes",
         "items", "locks", "clues", "specials", "drawings", "vines", "springs", "crates", "enemies", "coins",
         "clocks", "checks", "hints", "pits", "water", "mirrors", "crystals", "ghost", "secrets", "chalk",
         "plates", "traps", "decor", "bars", "oil", "cranks", "movers", "comics", "relics", "fireflies"]

L = {}
S = []


def novo(nome, intro, **kw):
    global L, S
    L = {"name": nome, "intro": intro, "theme": "aeroporto", "seed": 5, "weather": "limpo",
         "top": -620, "bottom": 1150, "under": 640, "spawn": {"x": 190, "y": GY}, "combat": "stomp",
         "time": 420, "results": 1, "rails": [0, 0]}
    for k in LISTS:
        L[k] = []
    L.update(kw)
    S = L["solids"]


# ------------------------------------------------------------------ ajudantes
def chao(x0, x1, y=GY, h=None):
    S.append({"t": "ground", "x": x0, "y": y, "w": x1 - x0, "h": h if h is not None else (640 - y if y < 640 else 140)})


def bloco(x0, x1, y0, y1, t="ground"):
    """bloco maciço (balcão alto, parede, mezanino)"""
    S.append({"t": t, "x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0})


def teto(x0, x1, y0, y1):
    S.append({"t": "rockw", "x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0, "ceil": 1})


def plat(x, y, w, **kw):
    d = {"t": "plat", "x": x, "y": y, "w": w}
    d.update(kw)
    S.append(d)


def milhas(x0, x1, y, step=44):
    x = x0
    while x <= x1:
        L["coins"].append([int(x), int(y)])
        x += step


def arco(x0, x1, y, h, n=5):
    for i in range(n):
        u = i / (n - 1)
        L["coins"].append([int(x0 + (x1 - x0) * u), int(y - math.sin(u * math.pi) * h)])


def coluna(x, y0, y1, step=40):
    y = y0
    while y >= y1:
        L["coins"].append([int(x), int(y)])
        y -= step


def totem(x, y=GY, rest=None):
    L["checks"].append([x, y] if rest is None else [x, y, "rest", rest])


def dica(a, b, t, **kw):
    d = {"a": a, "b": b, "t": t}
    d.update(kw)
    L["hints"].append(d)


def icone(a, b, x, y, g):
    """dica sem texto: um balão com o gesto (botões) aparece em cima do lugar quando o Milis chega perto"""
    L.setdefault("icons", []).append({"a": a, "b": b, "x": x, "y": y, "g": g})


def inimigo(k, x, r, y=GY, **kw):
    d = {"k": k, "x": x, "y": y, "r": list(r)}
    d.update(kw)
    L["enemies"].append(d)


def cambista(x, r, y=GY):
    """cambista de terno: anda, vê o Milis e corre para cima dele (comportamento do javali)"""
    inimigo("boar", x, r, y)


def robo_falso(x, r, y=GY):
    """robô falsificado: pula na direção do Milis (comportamento do sapo)"""
    inimigo("frog", x, r, y)


def pombo(x, cy, r):
    """pombo: plana e mergulha quando o Milis passa embaixo (corvo)"""
    inimigo("crow", x, r, cy, cy=cy)


def drone(x, cy, r):
    """drone: vai e volta no ar (mosca)"""
    inimigo("fly", x, r, cy, cy=cy)


def drone_gancho(x, top, y=GY):
    """drone de gancho: desce do teto pelo cabo (aranha)"""
    inimigo("spider", x, [x, x], y, top=top)


def mala_monstro(x, cy, r):
    """mala-monstro pendurada no teto que se solta e voa (morcego)"""
    inimigo("bat", x, r, cy, cy=cy)


def caixa(x, y=GY, n=4, item=None, soft=False):
    d = {"t": "break", "x": x, "y": y - 38}
    if soft:
        d["soft"] = 1
    if item:
        d["item"] = item
    else:
        d["n"] = n
    L["crates"].append(d)


def caixote(x, y=GY, w=70, h=70):
    L["crates"].append({"t": "push", "x": x, "y": y - h, "w": w, "h": h})


def mola(x, y=GY, pow=-21):
    L["springs"].append({"x": x, "y": y, "pow": pow, "k": "glow"})


def escada(x, y_top, y_bot=GY, kind="ladder"):
    L["climb"].append({"x": x, "y": y_top, "w": 30, "h": y_bot - y_top, "kind": kind})


def cartao(x, y, txt):
    L["drawings"].append({"x": x, "y": y - 30, "txt": txt})


def pista(x, y, cid):
    L["clues"].append({"x": x, "y": y - 30, "id": cid})


def bateria(x, y=GY):
    L["oil"].append([x, y - 32])


def portao(gid, x, y_top, y_bot=GY, **kw):
    d = {"t": "pgate", "id": gid, "x": x, "y": y_top, "w": 22, "h": y_bot - y_top}
    d.update(kw)
    S.append(d)


def fim(x, y=GY - 90, kind="exit"):
    L["door"] = {"x": x, "y": y, "kind": kind}


def deposito(xc, sid, aid):
    """alçapão de 60 px no chão em xc (o chão precisa ter um vão [xc, xc+60]): o mergulho abre, uma escada
    desce até um depósito (y 760..960) e, atrás de uma parede falsa à esquerda, a sala secreta"""
    S.append({"t": "crack", "x": xc, "y": GY, "w": 60, "h": 22, "kind": "slam", "id": aid, "ladder": [xc + 15, GY, 460],
              "msg": "O mergulho abriu o alçapão! Tem uma escada descendo (↓)."})
    L["caves"].append({"x": xc, "y": GY, "w": 60, "h": 260})
    L["caves"].append({"x": xc - 110, "y": 760, "w": 520, "h": 200})
    L["caves"].append({"x": xc - 310, "y": 860, "w": 180, "h": 100})
    S.append({"t": "dirt", "x": xc - 130, "y": 960, "w": 560, "h": 60})
    S.append({"t": "dirt", "x": xc - 330, "y": 960, "w": 200, "h": 60})
    S.append({"t": "dirt", "x": xc - 130, "y": 740, "w": 130, "h": 20})
    S.append({"t": "dirt", "x": xc + 60, "y": 740, "w": 370, "h": 20})
    S.append({"t": "dirt", "x": xc + 410, "y": 740, "w": 20, "h": 220})
    S.append({"t": "dirt", "x": xc - 130, "y": 740, "w": 20, "h": 140})
    S.append({"t": "fakewall", "x": xc - 130, "y": 880, "w": 20, "h": 80, "deco": 1})
    S.append({"t": "dirt", "x": xc - 330, "y": 840, "w": 20, "h": 180})
    S.append({"t": "dirt", "x": xc - 330, "y": 840, "w": 200, "h": 20})
    L["secrets"].append({"id": sid, "x": xc - 310, "y": 860, "w": 180, "h": 100})
    milhas(xc + 120, xc + 370, 930, 50)
    milhas(xc - 280, xc - 160, 930, 40)


def peca(x0, x1, y0, y1, sprite, ox=0, oy=0, ob=4, dx=0):
    """bloco maciço desenhado com um móvel pintado (balcão, bancos, cabine...)"""
    S.append({"t": "peca", "x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0, "sprite": sprite, "ox": ox, "oy": oy, "ob": ob, "dx": dx})


def escada_rolante(x0, yb, yt, dir=1, spd=1.6, run=20, rise=10):
    """escada rolante de verdade: degraus baixos (o Milis sobe sozinho de degrau em degrau) que andam.
    Sobe para a direita: de (x0, yb) até (x1, yt). dir=1 leva para cima; dir=-1 é a contramão (desce)."""
    n = int(round((yb - yt) / rise))
    for i in range(n):
        S.append({"t": "ground", "x": x0 + i * run, "y": yb - rise * (i + 1), "w": run, "h": rise * (i + 1), "esc": 3})
    x1 = x0 + n * run
    L.setdefault("walks", []).append({"x0": x0, "x1": x1, "y": yt, "yb": yb, "esc": 1, "dir": dir, "spd": spd})
    return x1


def elevador_vidro(x, y_top, y_bot=GY, w=80):
    """elevador panorâmico de vidro: entre e toque em ✋ USAR; chamado de longe, ele vem buscar"""
    L["movers"].append({"k": "lift", "x": x, "w": w, "y0": y_top, "y1": y_bot, "start": "bottom", "skin": "vidro"})


def passarela(x0, x1, y0, y1):
    """passarela suspensa: piso de grade com corrimão (a arte sobe acima do piso)"""
    w = x1 - x0
    alt = w * 120.0 / 612.0
    oy = int(alt * .55)
    peca(x0, x1, y0, y1, "p_pc_passarela_topo", 0, oy, int(alt - oy - (y1 - y0)))


def movel(x, nome, w, y=GY, **kw):
    """móvel só de cenário (atrás de tudo), base no chão"""
    d = {"k": "pc", "x": x, "y": y, "n": "p_pc_" + nome, "w": w}
    d.update(kw)
    L["decor"].append(d)


def atendente(x, y, fid, falas, pose="parado"):
    """Seu Barros, o atendente simpático: fica parado e fala com o Milis quando ele chega perto"""
    L.setdefault("npcs", []).append({"x": x, "y": y, "id": fid, "pose": pose, "lines": falas})


def quebra(x, k, w, y=GY):
    """cenário que reage ao golpe: placa, vaso, malas, lanche (máquina), carrinho"""
    L.setdefault("brk", []).append({"x": x, "y": y, "k": k, "w": w})


def obj(x, nome, w, y=GY, **kw):
    """objeto pequeno do chão (passaporte, copo, papéis, placa, lixeiras...): só cenário"""
    d = {"k": "pc", "x": x, "y": y, "n": "p_ob_" + nome, "w": w}
    d.update(kw)
    L["decor"].append(d)


def pax(x, n, k="walk", r=None, y=GY, **kw):
    """passageiro de cenário: anda (walk) entre r, fica sentado (sit) ou parado (stand)"""
    d = {"x": x, "n": "pax_" + n, "k": k, "y": y}
    if r:
        d["r"] = list(r)
    d.update(kw)
    L.setdefault("pax", []).append(d)


def painel(x, y=230, w=150, h=64):
    L.setdefault("boards", []).append({"x": x, "y": y, "w": w, "h": h})


def neon(x, c, y=GY):
    L.setdefault("neon", []).append({"x": x, "y": y, "c": c})


def molhado(x, w, y=GY):
    """piso molhado fixo (escorrega), com a placa amarela"""
    L.setdefault("wet", []).append({"x": x, "w": w, "y": y})


def faxineiro(x, r, y=GY):
    """faxineiro capanga: anda com a enceradeira e deixa o piso molhado (só dá para pisar por trás)"""
    inimigo("janitor", x, r, y)


def andaime(x, w, niveis):
    """andaime de manutenção com lona: tábuas para subir e uma escada"""
    for ny in niveis:
        plat(x, ny, w)
    escada(x + w - 34, min(niveis), GY)
    L["decor"].append({"k": "scaf", "x": x, "y": GY, "w": w, "top": min(niveis), "lv": list(niveis)})


def porta_auto(gid, x, per=220, ph=0):
    """porta automática de vidro: abre e fecha no ritmo"""
    S.append({"t": "pgate", "id": gid, "x": x, "y": GY - 230, "w": 18, "h": 230, "auto": True, "per": per, "ph": ph})


def _fix_coin(c):
    for _ in range(12):
        moved = False
        for so in S:
            if so.get("deco") or so["t"] in ("plat", "barrier", "pgate"):
                continue
            if so["x"] - 14 <= c[0] <= so["x"] + so["w"] + 14 and so["y"] - 18 <= c[1] <= so["y"] + so.get("h", 0) + 8:
                c[1] = int(so["y"] + so["h"] + 30) if so.get("ceil") else int(so["y"] - 30)
                moved = True
        if not moved:
            return


def salvar(n):
    for c in L["coins"]:
        _fix_coin(c)
    out = os.path.join(ROOT, "assets", "data", "level%d.json" % n)
    json.dump(L, open(out, "w"), ensure_ascii=False, indent=1)
    print("level%d.json: %s · %d sólidos, %d milhas, %d inimigos, %d totens, spanX %d" % (
        n, L["name"], len(S), len(L["coins"]), len(L["enemies"]), len(L["checks"]), L["spanX"]))


# ======================================================================
#  1-1 · TERMINAL
# ======================================================================
novo("Guarulhos · 1-1 Terminal",
     "Alguém está roubando as milhas dos clientes da Milhas Plus! Um vulto de capuz fugiu pelo terminal de "
     "Guarulhos com uma mala brilhando. Recupere as milhas LATAM, ache os cartões de embarque dourados e junte "
     "as pistas para descobrir quem é o ladrão. Cuidado com os capangas dele!",
     introSub="Episódio 1 · Brasil — São Paulo", endTitle="FIM DO TERMINAL", introImg="res://assets/ui/intro_1.jpg",
     periods=["Saguão", "Check-in", "Segurança", "Mezanino"], clueIds=[1, 2, 3],
     rests={"1": ["CHECK-IN DO TERMINAL", "No balcão, um bilhete esquecido pelo vulto: \"Despachar tudo pelo subsolo das bagagens\".",
                  "Então as milhas estão descendo pelas esteiras. Mas quem escreve com uma letra tão caprichada?"]},
     endStory="O vulto de capuz escapou de novo, mas deixou rastros: um recibo com um cifrão dourado, um fio de bigode "
              "grisalho e uma lista assinada com um B. Quem está por trás disso? As pistas apontam para o subsolo das bagagens.")

# --- A · Saguão (0 .. 3400): aprender a andar, pular, quebrar malas, pulo duplo
L["sections"].append({"x": 0, "song": "gru_saguao", "bg": "vila", "gt": "vila", "per": 0})
chao(-200, 1500)
# cenário: colunas com painel de voos, carrinhos e bancos atrás
for cx in [640, 2740, 3500, 5600]:
    movel(cx, "coluna", 92)
movel(1240, "carrinhos", 110)
movel(2250, "bancos", 230)
movel(3300, "carrinhos", 110)
movel(4650, "carrinhos", 110)
movel(7700, "raiox", 230)
movel(8000, "raiox", 230)
movel(10200, "carrinhos", 110)
movel(13900, "bancos", 230)
# Seu Barros, o atendente simpático (dá dicas... será que é só simpatia?)
atendente(1040, 410, "barros1", [
    ["SEU BARROS", "Ei, robozinho da Milhas Plus! Vi um sujeito de capuz correndo com uma mala brilhando, direto para o check-in.", "barros"],
    ["MILIS", "Era ele! O saldo da família sumiu na hora em que ele passou. Obrigado, senhor!", "tome"],
    ["SEU BARROS", "Barros, ao seu dispor. Corre que ainda dá tempo... hehe.", "barros"]], "aponta")
atendente(14280, GY, "barros2", [
    ["SEU BARROS", "Psiu! Você de novo? A segurança está estranha hoje. Aquele fiscal da cabine não é daqui, não...", "barros"],
    ["MILIS", "Seu Barros? Como o senhor chegou aqui antes de mim?", "tome"],
    ["SEU BARROS", "Atalhos de quem trabalha no aeroporto há muitos anos. Boa sorte, robozinho!", "barros"]], "cochicha")

# ---------- vida do aeroporto na 1-1 (só cenário) ----------
# saguão
# passageiros só nos trechos calmos (nunca perto de capangas, armadilhas ou piso molhado):
# começo do saguão, a pausa antes do check-in, depois do carrinho e antes do Fiscal
pax(300, "exec", r=[150, 900], spd=.9, re=1)
pax(620, "cel", r=[480, 860], spd=.5, re=1)
# mais vida no terminal: gente passando (com passos de verdade) e um senhor cochilando no banco
pax(1640, "piloto", r=[1560, 2020], spd=.7)
pax(2236, "dorme", k="sit", y=GY - 14, look=False, z="z")
pax(2500, "comissaria", r=[2300, 2720], spd=.8)
pax(5150, "exec", r=[4980, 5520], spd=1.0)
pax(6500, "cel", r=[6400, 6820], spd=.5)
pax(9300, "turista", k="stand", look=False)
pax(12900, "idosa", k="stand")
painel(220)
painel(1240, 210, 170)
painel(2060)
obj(420, "papeis", 60)
obj(980, "cafe", 46)
obj(1180, "passaportes", 44)
obj(1440, "lixeiras", 96)
obj(2100, "ursinho", 30)
obj(2960, "folhetos", 40)
obj(3240, "etiqueta", 26)
molhado(2860, 140)
quebra(2875, "placa", 34)   # na beira da poça (sem encostar no vaso)
L.setdefault("carts", []).append({"x0": 9230, "x1": 9800})   # fora da arena do 3º segurança
andaime(2860, 220, [380, 260])
milhas(2880, 3060, 230, 44)
# nada de "voltar depois": tudo o que aparece dá para pegar na hora.
# começo: a viga em cima do painel de partidas tem um degrau (prateleira embaixo do painel) — pulo duplo alcança
plat(140, 210, 170)
plat(330, 360, 90)
milhas(160, 290, 180, 26)
caixa(290, y=210, n=8)   # começa com a vida cheia: lá em cima é caixa de milhas, não de coração
# malas presas no alto dos painéis (só o gancho magnético alcança) — todas DEPOIS do gancho (x 7030)
L.setdefault("stuck", []).extend([{"x": 8785, "y": 195, "n": 20}, {"x": 12775, "y": 185, "n": 20}])
# ímã no teto em cima do vão das bandejas: com o gancho, atravessa balançando
L.setdefault("anchors", []).append({"x": 8340, "y": 230})
# cartazes de PROCURADO do vulto (aparecem e se completam conforme as pistas)
L["posters"] = [{"x": 3500, "y": 330}, {"x": 2740, "y": 330, "rot": .05}, {"x": 5600, "y": 380}, {"x": 6500, "y": 240, "rot": .04},
                {"x": 7420, "y": 170}, {"x": 10590, "y": 180, "rot": .05}, {"x": 13080, "y": 390}]
# cenário que reage: máquinas de lanche (soltam milhas), vasos e um carrinho de bagagem desgovernado
quebra(1185, "lanche", 64)      # dentro da arena do 1º segurança (a investida dele bate na máquina)
quebra(9960, "carrinho", 70)    # arena do 3º segurança: empurre o carrinho nele
quebra(11250, "lanche", 64)
# check-in
pax(3195, "menino", k="stand", sc=.62)
# esteiras rolantes do piso: no check-in a favor (ajuda a correr), no mezanino contra (segura o Milis)
# a favor: ajuda a alcançar o vulto que foge pelo check-in
L.setdefault("walks", []).append({"x0": 3220, "x1": 3580, "y": GY, "dir": 1, "spd": 1.8})
icone(3150, 3300, 3270, 420, "»")
# a favor, levando direto para a esteira do raio-x que dá choque: espere o choque passar antes de subir nela
L["walks"].append({"x0": 7490, "x1": 7598, "y": GY, "dir": 1, "spd": 2.0})
# a favor antes do vão das bandejas: o embalo dá o pulo comprido
L["walks"].append({"x0": 8010, "x1": 8196, "y": GY, "dir": 1, "spd": 2.4})
icone(7990, 8090, 8100, 420, "» ↑")
# contra, embaixo da porta automática de vidro: passe correndo enquanto a porta está aberta
L["walks"].append({"x0": 8760, "x1": 8996, "y": GY, "dir": -1, "spd": 1.7})
pax(3040, "mae", r=[2880, 3160], spd=.6)   # mãe e filha passeando antes da esteira rolante (fora dela)
painel(3700, 200, 170)
painel(5150, 180)
painel(6180, 210)
for fx in [3560, 3860, 4160]:
    obj(fx, "fila", 70)
quebra(4400, "malas", 70)
obj(5200, "passaportes", 40)
obj(5480, "papeis", 60)
obj(5960, "cafe", 44)
obj(6020, "lixeiras", 96)   # longe do caminho do caixote
molhado(5980, 140)
quebra(5960, "placa", 34)
faxineiro(6900, [6650, 7150])
# segurança: luz fluorescente, porta automática, fios e malas caindo
pax(10750, "comissaria", r=[10670, 10840], spd=.7, re=1)
painel(8700, 200)
obj(7300, "fila", 70)
obj(8560, "etiqueta", 26)
quebra(9300, "malas", 72)
obj(10300, "lixeiras", 96)
porta_auto("auto1", 8900, 240)
L["traps"].append({"k": "icicle", "x": 9900, "y": 40, "len": 30, "floor": GY, "reach": 60})
L["traps"].append({"k": "icicle", "x": 10180, "y": 40, "len": 30, "floor": GY, "reach": 60})
# (a grade de escalar que ficava ao lado do vento saiu: ela tirava a graça da saída de ar)
# mezanino à noite: neon do duty free
neon(12400, "#ff4fb4")
neon(12950, "#4fd8ff")
neon(13500, "#ffd84a")
neon(13950, "#9b6bff")
milhas(12260, 12540, 470, 40)
# mini-perseguições do vulto de capuz: alcançou, ele larga a mala (milhas extras + uma pista a mais)
L["chases"] = [
    {"trig": 230, "x0": 390, "x1": 990, "y": GY, "spd": 4.8, "bonus": 15,
     "pista": "Na mala, um lenço bordado com um B dourado..."},
    {"trig": 3150, "x0": 3320, "x1": 3740, "y": GY, "spd": 4.8, "bonus": 15,
     "pista": "Caiu do bolso dele um bilhete: Encontro no portão 7. Assinado: B."}]
# objetos em primeiro plano (escuros e desfocados, passando na frente da câmera): poucos, longe da ação
L["fg"] = [{"x": 760, "k": "coluna"}, {"x": 3500, "k": "fila"}, {"x": 6350, "k": "lixeira"},
           {"x": 8020, "k": "coluna"}, {"x": 10720, "k": "bancos"}, {"x": 12380, "k": "coluna"}, {"x": 14300, "k": "fila", "flip": True},
           # mais coisas passando na frente da câmera (desfocadas), como numa filmagem
           {"x": 2050, "k": "bancos", "flip": True}, {"x": 4650, "k": "coluna"}, {"x": 5450, "k": "lixeira", "flip": True},
           {"x": 9300, "k": "coluna"}, {"x": 11800, "k": "lixeira"}, {"x": 13300, "k": "bancos"}, {"x": 15300, "k": "coluna"}]
# alguém atrasado correndo pelo terminal (passo apressado)
pax(7700, "exec", r=[7260, 8000], spd=2.3)
pax(14380, "piloto", r=[14360, 14540], spd=.6)
pax(14470, "teen", k="stand", re=1, bal="oi!")
painel(12700, 190)
obj(13270, "folhetos", 40)
obj(13460, "papeis", 60)
obj(13820, "cafe", 44)
molhado(13650, 130)
quebra(13630, "placa", 34)
faxineiro(13300, [13100, 13560])
L["traps"].append({"k": "roll", "x": 12390, "y": GY, "trig": 12205, "tw": 90, "dir": -1, "vmax": 3.6, "end": 12192, "r": 30, "aero": True})
dica(0, 520, "Guarulhos! O ladrão espalhou as milhas LATAM pelo terminal. Ande com ← → e pule com o botão de pulo.")
milhas(300, 700, 470)
caixa(820, n=5)
dica(700, 950, "Malas abandonadas pelo ladrão: pise em cima ou bata com o bastão para soltar as milhas.")
plat(980, 410, 140)                 # balcão de informações (dá para subir)
milhas(1000, 1100, 380, 40)
totem(945)                           # check-in logo antes da arena do 1º segurança
cambista(1300, [1150, 1450])
# fileira de bancos e a primeira subida dupla
peca(1500, 1700, 456, 500, "p_pc_bancos", 30, 57, 2)   # bancos do saguão (o Milis pisa no assento)
chao(1500, 2070)
chao(2150, 3400)
peca(1880, 2040, 300, 500, "p_pc_cabine", -4, 0, 4)   # cabine de informações (de vidro)
milhas(1890, 2030, 270, 35)
icone(1720, 1900, 1800, 360, "↑↑")
dica(2160, 2300, "Parado, segure ↑ para olhar para cima: tem coisa lá no mezanino!")
arco(2050, 2300, 470, 90, 6)
robo_falso(2450, [2580, 2760])
# elevador panorâmico de vidro até o mirante (o único jeito de chegar lá): uma pista do ladrão
elevador_vidro(2070, -40)
bloco(2070, 2150, 511, 640)   # fundo do poço do elevador (um degrauzinho abaixo do piso)
passarela(2160, 2488, -40, 0)
pista(2440, -40, 1)
milhas(2190, 2400, -70, 42)
icone(1990, 2160, 2070, 380, "✋")
caixa(2700, item="heart")
plat(2780, 380, 120)
plat(2960, 280, 120)
plat(3140, 180, 120)
coluna(3200, 140, 20)
cartao(3200, 180, "Cartão de embarque dourado 1/3 (Terminal): GRU → ??? — o destino está raspado.")
pombo(2900, 250, [2700, 3200])
pombo(2000, 180, [1750, 2300])
totem(3300)

# --- B · Check-in (3400 .. 7200): fila em zigue-zague, balcões, esteira de despacho, catraca da placa
L["sections"].append({"x": 3400, "song": "gru_saguao", "bg": "vila", "gt": "vila", "per": 1})
chao(3400, 6300)
chao(6370, 7200)
# balcões de check-in: blocos de altura média com esteira de despacho atrás
for i, bx in enumerate([3600, 3900, 4200]):
    peca(bx, bx + 140, 410, 500, "p_pc_balcao", 75, 40, 4, 58)
    milhas(bx + 20, bx + 120, 380, 50)
caixa(3810, n=3)
totem(4270, 410)                     # em cima do último balcão: volta aqui se perder a vida na arena
cambista(4100, [3760, 4180])
drone(4560, 300, [4420, 4700])
# (o quadrinho do drone aparece sozinho quando o 1º drone surge na tela: Game._comic_check)
cambista(4950, [4820, 5080], y=230)

# esteira de despacho que sobe (plataforma que anda)
L["movers"].append({"k": "path", "x0": 4400, "x1": 4680, "y0": 330, "y1": 230, "w": 110, "per": 260})
peca(4800, 5100, 230, 500, "p_pc_porta", 6, 2)   # parede do despacho, com a porta restrita
milhas(4830, 5080, 200, 50)
milhas(5030, 5080, 200, 40)
icone(4200, 4345, 4270, 360, "↑↑")
totem(4880, 230)
# lá de cima, planar com as asas por cima da fila até a ilha seguinte
plat(5500, 300, 120)
plat(5900, 260, 120)
arco(5120, 5480, 230, 50, 7)
arco(5640, 5880, 250, 40, 5)
dica(5000, 5250, "Segure o pulo depois do pulo duplo (ou o botão de planar) e as asas de avião abrem: você plana!",
     yl=260)
drone(5700, 360, [5550, 5850])
robo_falso(5420, [5250, 5650])
# a fila em zigue-zague lá embaixo: fitas (plataformas baixas) e um caixote para a placa
for i in range(4):
    plat(5200 + i * 160, 440 - (i % 2) * 40, 100)
caixote(6170)   # pertinho da placa do chão (6300)
S.append({"t": "dirt", "x": 6300, "y": 520, "w": 70, "h": 120})
L["plates"].append({"x": 6300, "y": 520, "w": 70, "gate": "cat1"})
portao("cat1", 6500, 380, GY)
bloco(6460, 6540, -620, 380, t="brickw")     # parede da área restrita acima da catraca
dica(6000, 6320, "A catraca da área restrita está fechada. Empurre o caixote até a placa no chão!")
milhas(6100, 6450, 470, 50)
robo_falso(6800, [6600, 7000])
# escada rolante na contramão (desce): correndo contra ela, chega a um nicho secreto no alto
escada_rolante(6560, GY, 280, dir=-1, spd=1.7)
bloco(7000, 7120, 280, GY)
S[-1]["esc"] = 2
milhas(7010, 7110, 250, 34)
milhas(7010, 7110, 200, 34)
caixa(7095, y=280, item="heart")
L.setdefault("gadgets", []).append({"x": 7030, "y": 280, "id": "gancho"})

totem(7170, GY, 1)
caixa(7240, n=4)

# --- C · Segurança (7200 .. 10600): raio-x com pinos elétricos, ar-condicionado que sopra para cima, crachá
L["sections"].append({"x": 7200, "song": "gru_seguranca", "bg": "tarde", "gt": "vila", "per": 2})
chao(7200, 8000)
dica(7200, 7500, "A segurança! Alguém ligou as esteiras do raio-x na tomada errada: cuidado com os choques.")
# esteiras do raio-x: piso que dá choque de tempos em tempos (espinhos com ritmo)
L["traps"].append({"k": "spikes", "x": 7600, "y": GY, "w": 96, "per": 150, "ph": 0})
L["traps"].append({"k": "spikes", "x": 7820, "y": GY, "w": 96, "per": 150, "ph": 75})
milhas(7560, 7960, 430, 40)
chao(8000, 8200)
L["pits"].append([8200, 8480])      # vão das esteiras de bandejas
plat(8260, 420, 90, crumble=1)
plat(8380, 380, 90, crumble=1)
arco(8220, 8470, 400, 60, 6)
chao(8480, 10600)

pombo(8700, 300, [8500, 9000])
drone(8340, 300, [8220, 8460])
mala_monstro(9700, -160, [9450, 9880])
# saída de ar-condicionado: o vento leva o Milis planando até o mezanino de cima
L["traps"].append({"k": "wind", "x": 9000, "y": -90, "w": 120, "h": 590, "pow": 1.0})
L["comics"].append({"id": "vento", "x": 8760})
passarela(9200, 9900, -40, 0)       # mezanino da segurança
milhas(9020, 9100, 300, 40)
coluna(9060, 260, -60)
milhas(9220, 9880, -70, 50)
cartao(9850, -40, "Cartão de embarque dourado 2/3: carimbado \"VOO ESPECIAL — PORTÃO 2??\". Quem será o passageiro?")
L["items"].append({"x": 9500, "y": -64, "id": "cartao_acesso"})
icone(8900, 9150, 9010, 420, "↑")
mala_monstro(9600, -200, [9300, 9850])
L["items"].append({"x": 8560, "y": 476, "id": "cordao"})
drone(9500, 360, [9300, 9750])
cambista(10000, [9800, 10300])
totem(8500)
# a porta da área restrita: precisa do crachá (cartão de acesso + cordão)
L["locks"].append({"x": 10350, "y": 380, "w": 80, "h": 120, "id": "porta_cracha", "kind": "gate", "gate": "seg1",
                   "short": "a porta da área restrita",
                   "need": "cracha", "parts": ["cartao_acesso", "cordao"],
                   "where": {"cartao_acesso": "no mezanino da segurança (suba com o vento do ar-condicionado)",
                             "cordao": "no chão, logo depois das bandejas que caem"},
                   "pre": "A porta da área restrita só abre com crachá.",
                   "place": "Chegue perto da leitora de crachá e toque em ✦ USAR.",
                   "use": "Toque em ✦ USAR na leitora de crachá.",
                   "msg": "Crachá aceito! A porta da área restrita abriu."})
portao("seg1", 10440, 380, GY)
bloco(10420, 10480, -620, 380, t="brickw")
dica(10325, 10440, "A porta só abre com crachá. Junte o cartão de acesso com o cordão no compartimento do Milis.")
totem(9860)

# --- D · Mezanino e portão (10600 .. 14200): escada de serviço, corrimãos, escada rolante, sala secreta
L["sections"].append({"x": 10600, "song": "gru_seguranca", "bg": "noite", "gt": "vila", "night": .4, "per": 3})
chao(10600, 11460)
# parede de grade de manutenção para escalar até a passarela (longe de qualquer saída de vento)
escada(10880, 160, kind="net")
icone(10820, 10960, 10890, 400, "↑")
passarela(10930, 11450, 160, 200)   # passarela de serviço
milhas(10960, 11420, 130, 50)
robo_falso(11300, [11000, 11550], y=160)
L["pits"].append([11460, 12200])
# por baixo da passarela: caminho alternativo com recompensa (milhas no chão, máquina de lanche que
# solta milhas, caixa com coração no fim) — mas com o faxineiro e o piso molhado; no fim, uma escada
# volta para a ponta da passarela (sem precisar voltar até a grade)
milhas(10990, 11190, 470, 40)
caixa(11320, item="heart")
escada(11452, 160, kind="ladder")
# fio de treino em cima da passarela, ainda sem buraco embaixo: o jogador descobre o balanço sem risco
L["vines"].append({"x": 11230, "y": -200, "len": 262, "aim": [11400, 160], "nosh": 1})
# vão das bagagens: só atravessa balançando de fio em fio (3 fios de manutenção soltos do teto).
# As passarelas ficam longe demais uma da outra para pular.
for vx, aim in ((11590, [11840, 120]), (11840, [12090, 120]), (12090, [12290, 160])):
    L["vines"].append({"x": vx, "y": -200, "len": 350, "aim": aim, "nosh": 1})
milhas(11690, 11750, 150, 30)
milhas(11940, 12000, 150, 30)
dica(11380, 11460, "Fios soltos sobre o vão: balance e salte de um fio para o outro até a outra passarela.", yl=220)
passarela(12230, 12500, 160, 200)
chao(12200, 13580)
chao(13640, 14200)
mala_monstro(12900, 260, [12600, 13200])
cambista(13080, [12980, 13190], y=GY - 180)
# escada rolante subindo até o mezanino do duty free: o único caminho até o cartão dourado 3/3
escada_rolante(12480, GY, 260, dir=1, spd=1.6)
bloco(12960, 13200, 260, GY)
S[-1]["esc"] = 2
plat(13030, 140, 130)
milhas(12990, 13180, 230, 46)
cartao(13095, 140, "Cartão de embarque dourado 3/3: a hora do voo — 23h59.")
icone(12380, 12560, 12470, 330, "↑↑")
# sala secreta embaixo do piso (mergulho no alçapão)
deposito(13580, "s1", "alc1")
pista(13330, 960, 2)
L["gold"] = {"x": 13380, "y": 930}
icone(13450, 13600, 13610, 420, "↑ ↓")
cambista(13900, [13750, 14050])
pista(14000, GY, 3)
totem(13450)
# --- E · Controle de segurança do portão (14200 .. 15900): o mini-chefe FISCAL FALSO
chao(14200, 16300)
milhas(14250, 14450, 470, 50)
totem(14380)
FZ0, FZ1 = 14600, 15600
bloco(FZ1 - 190, FZ1 - 50, 330, GY)          # cabine de controle (o Fiscal fica em cima)
bloco(FZ1 - 50, FZ1 + 30, -620, 210)         # parede do fundo da arena (porta em cima da cabine)
bloco(FZ1 - 50, FZ1 + 30, 330, GY)
L["boss"] = {"x0": FZ0, "x1": FZ1, "trig": FZ0 + 160, "spawn": FZ1 - 120, "hp": 3,
             "item": [(FZ0 + FZ1) // 2, 470], "skin": "fiscal", "open": "fiscal_porta"}
L["boss_song"] = "fiscal"
S.append({"t": "pgate", "x": FZ1 - 50, "y": 210, "w": 80, "h": 120, "id": "fiscal_porta"})
dica(FZ0, FZ1, "Fiscal: pule malas e lasers baixos, abaixe (↓) nos altos, saia das faixas acesas do chão. Painel piscando? Corra até ele e bata!", boss=1)
milhas(15700, 15880, 470, 45)
fim(15900)
L["spanX"] = 16300   # a porta (15900) não fica atrás dos botões da direita
# tapumes de obra: parede de tábuas até o teto com um vão embaixo — só passa rolando (corra e abaixe)
# ou se arrastando abaixado
for tx in (2490, 7360, 10530):
    bloco(tx, tx + 120, -620, GY - 34, t="tapume")
icone(2300, 2480, 2420, 420, "» ↓")
# um capanga por vez na tela: só estes ficam na 1-1 (os patrulhamentos ficam a ~1 tela de distância
# um do outro), e a variedade continua: cambista, robô, faxineiro, mala voadora e drone
_FICA_1_1 = {1300, 2450, 4100, 5700, 10000, 13300}
L["enemies"] = [e for e in L["enemies"] if int(e["x"]) in _FICA_1_1]
# onde cada um fica de verdade (longe de balcões, blocos, tapumes e passagens baixas). Os falsos
# seguranças são mini-chefes: cada um tem uma ARENA — as grades descem quando o Milis entra e só sobem
# quando ele derruba o segurança (não dá para passar sem lutar)
_AJUSTE = {
    1300: {"r": [1225, 1430], "arena": [1130, 1488]},
    4100: {"r": [4480, 4740], "arena": [4350, 4795], "radio": 1},  # embaixo da esteira de despacho; chama reforço no rádio
    10000: {"r": [10040, 10290], "arena": [9905, 10340]},  # entre o mezanino e a porta do crachá
    2450: {"r": [8700, 8780]},                             # robô depois das bandejas (longe de tapume e de arena)
    5700: {"r": [5620, 5980], "cy": 330, "y": 330},        # drone na fila do check-in
    13300: {"r": [10950, 11350]},                          # faxineiro embaixo da passarela do mezanino
}
for e in L["enemies"]:
    a = _AJUSTE.get(int(e["x"]))
    if a:
        e.update(a)
        e["x"] = sum(e["r"]) // 2
for e in L["enemies"]:
    if e.get("r") and not (e["r"][0] <= e["x"] <= e["r"][1]):
        e["x"] = (e["r"][0] + e["r"][1]) // 2
# drones em lugares abertos, com espaço para lutar (nunca em cima de vão, fio ou corrimão)
pombo(1800, 250, [1730, 1870])        # drone espião nos bancos do saguão, depois da arena do 1º segurança
pombo(9560, -230, [9380, 9740])
# falso carregador no check-in: para, ergue uma mala e arremessa (rebata com o bastão)
inimigo("porter", 5250, [5060, 5460])
# dicas só aparecem em cima do piso do terminal (no subsolo das bagagens elas não valem)
for h in L["hints"]:
    h.setdefault("yl", L.get("under", 640))
# hora do dia no nome de cada trecho: o tempo passa enquanto o Milis atravessa o terminal
L["periods"] = ["Saguão · 14:00", "Check-in · 16:00", "Segurança · 18:00", "Mezanino · 20:00"]
# mais caixas de coração pelo caminho (uma a cada trecho, sempre na rota — sem precisar voltar)
caixa(1600, y=456, item="heart", soft=True)
caixa(3660, y=410, item="heart", soft=True)
caixa(4880, item="heart", soft=True)
caixa(6560, item="heart", soft=True)
caixa(7900, item="heart", soft=True)
caixa(9050, item="heart", soft=True)
caixa(10450, item="heart", soft=True)
caixa(12350, item="heart", soft=True)
caixa(13450, item="heart", soft=True)
caixa(14900, item="heart", soft=True)
# segredos no alto: uma grade de ventilação torta na parede é a pista; em cima, um coração e milhas
def segredo_alto(x, y, gx, gy):
    plat(x - 50, y, 100)
    caixa(x, y=y, item="heart")
    milhas(x - 40, x + 40, y - 70, 40)
    L.setdefault("grilles", []).append({"x": gx, "y": gy})
segredo_alto(9480, 340, 9480, 440)
segredo_alto(7060, 140, 7060, 236)
salvar(1)


# ======================================================================
#  1-2 · BAGAGENS
# ======================================================================
novo("Guarulhos · 1-2 Bagagens",
     "Uma pista leva ao subsolo das bagagens. Lá embaixo está escuro: o farol dos olhos do Milis gasta bateria, "
     "então pegue as pilhas pelo caminho. Dizem que uma mala muito esperta ficou presa nas esteiras...",
     introSub="Episódio 1 · Brasil — São Paulo", endTitle="FIM DAS BAGAGENS", introImg="res://assets/ui/intro_2.jpg",
     periods=["Esteiras", "A Bag", "Elevadores", "Túnel de serviço"], clueIds=[4, 5],
     rests={"1": ["CHECK-IN DAS BAGAGENS", "Entre as malas extraviadas, uma está piscando um LED. Malas não piscam... ou piscam?",
                  "Alguém aí? Eu juro que essa mala olhou para mim."]},
     endStory="Milis e Bag descobriram o esquema: as milhas viajam escondidas em malas com etiqueta trocada, direto para o Hangar 7.")

L["sections"].append({"x": 0, "song": "tunel", "bg": "mina", "gt": "mina", "dark": .5, "night": 1, "per": 0})
L["darkZones"].append({"x": 0, "w": 13600, "dark": .78})
teto(-200, 13800, -620, -150)
# --- A · Esteiras
chao(-200, 1600)
dica(0, 600, "O subsolo das bagagens. Está escuro: o farol dos olhos clareia o caminho. Segure ✦ para focar a luz.")
milhas(300, 800, 470)
bateria(700)
L["movers"].append({"k": "path", "x0": 1000, "x1": 1400, "y0": 420, "y1": 420, "w": 140, "per": 300})
caixa(1500, n=5)
totem(1550)
L["pits"].append([1600, 2600])
L["movers"].append({"k": "path", "x0": 1650, "x1": 2050, "y0": 430, "y1": 330, "w": 120, "per": 280})
L["movers"].append({"k": "path", "x0": 2450, "x1": 2150, "y0": 430, "y1": 330, "w": 120, "per": 280})
arco(1650, 2450, 380, 80, 12)
drone(2050, 220, [1800, 2400])
drone(2350, 300, [2200, 2500])
dica(1600, 1900, "Esteiras suspensas! Pule de uma para a outra. Não caia no fosso das malas.")
chao(2600, 4400)
chao(4460, 5200)
bateria(2700)
drone_gancho(3000, 0)
drone_gancho(3300, -50)
milhas(2700, 3500, 470, 50)
L["traps"].append({"k": "spikes", "x": 3600, "y": GY, "w": 120, "per": 180, "ph": 0})
dica(2900, 3200, "Drones de gancho descem do teto! Passe quando eles subirem.")
# pilha de caixas para quebrar com o mergulho
for i in range(3):
    caixa(3900, GY - 38 * i, n=3)
dica(3800, 3950, "Pilha de malas: pule e mergulhe (↓ no ar) para quebrar tudo de uma vez.")
cambista(4300, [4100, 4600])
robo_falso(3200, [3000, 3500])
pista(4700, GY, 4)
totem(4100)
deposito(4400, "s1", "alc1")
L["gold"] = {"x": 4150, "y": 930}
dica(4250, 4400, "Esse piso de grade parece solto... pule e mergulhe (↓ no ar) em cima dele.")
# estaca: o mergulho no botão grande abaixa a ponte
L["slam"] = {"stakes": [{"x": 5100, "y": GY, "bridge": {"x": 5200, "y": GY, "w": 360}}], "seesaw": [], "fruit": []}
L["pits"].append([5200, 5560])
dica(4950, 5150, "Um botão gigante no chão: pule e mergulhe em cima dele para baixar a ponte.")
chao(5560, 7600)

# --- B · A Bag presa na esteira (5560 .. 7600)
L["sections"].append({"x": 5560, "song": "tunel", "bg": "mina", "gt": "mina", "dark": .5, "night": 1, "per": 1})
L["dog"] = {"x": 6300, "y": GY}
dica(5800, 6300, "Uma mala de rodinhas presa na esteira... ela está piscando para você! Chegue perto e toque em ✦ USAR.")
milhas(5600, 6200, 470, 50)
bateria(5900)
totem(5700, GY, 1)
# passagem baixa que só a Bag passa e uma placa do outro lado
# portão de carga com uma portinhola embaixo: só a Bag passa; do outro lado, a placa abre o portão
portao("bag1", 6990, -150, GY, dogpass=1)
L["plates"].append({"x": 7150, "y": GY, "w": 70, "gate": "bag1"})
cartao(7080, GY, "Cartão de embarque dourado 1/3 (Bagagens): \"Assento 1A — Barão\".")
dica(6650, 6990, "Só a Bag passa pela portinhola. Troque para ela (botão da mala), passe e pare em cima da placa.")
milhas(6700, 6960, 470, 40)

# --- C · Elevadores de carga (7600 .. 10400)
L["sections"].append({"x": 7600, "song": "tunel", "bg": "mina", "gt": "mina", "dark": .5, "night": 1, "per": 2})
chao(7600, 8300)
L["movers"].append({"k": "lift", "x": 8300, "w": 96, "y0": 60, "y1": 500, "start": "bottom"})
S.append({"t": "dirt", "x": 8300, "y": 590, "w": 108, "h": 50})
L["pits"].append([8300, 8408])
bloco(8408, 9800, 60, 500)
S.append({"t": "ground", "x": 8408, "y": 60, "w": 1392, "h": 30, "mine": 1})
dica(8100, 8300, "Elevador de carga: suba na plataforma e aperte ✦ USAR.")
totem(8150)
milhas(8460, 9700, 30, 50)
mala_monstro(9000, -60, [8600, 9500])
bateria(9300, 60)
L["items"].append({"x": 9100, "y": 36, "id": "fusivel"})
robo_falso(9600, [9300, 9750], y=60)
cambista(8900, [8600, 9200], y=60)
chao(9800, 10400)
L["cranks"].append({"x": 10000, "y": GY, "gate": "cg1"})
portao("cg1", 10100, 376, GY, crank=1)
bloco(10060, 10170, -150, 376, t="brickw")
dica(9850, 10100, "Porta de manivela: aperte ✦ USAR várias vezes seguidas para levantar.")
milhas(9820, 9980, 470, 40)

# --- D · Túnel de serviço e a sala do gerador (10400 .. 13600)
L["sections"].append({"x": 10400, "song": "tunel", "bg": "mina", "gt": "mina", "dark": .5, "night": 1, "per": 3})
chao(10400, 13600)
L["traps"].append({"k": "gust", "x": 10700, "y": 100, "w": 120, "h": 400, "per": 240, "ph": 0, "on": 120})
plat(10660, 300, 200)
milhas(10680, 10840, 270, 40)
dica(10500, 10700, "Um duto de ventilação sopra forte de tempos em tempos: segure ↓ para se abaixar e aguentar.")
cambista(11200, [11000, 11500])
caixa(11600, item="armor")
L["items"].append({"x": 11900, "y": 476, "id": "fita"})
drone_gancho(12200, -100)
cambista(12450, [12300, 12800])
mala_monstro(11400, 0, [11200, 11700])
cartao(12500, GY, "Cartão de embarque dourado 2/3: \"Conexão em Guarulhos — Hangar 7\".")
L["locks"].append({"x": 12850, "y": 380, "w": 80, "h": 120, "id": "gerador", "kind": "gate", "gate": "ger1",
                   "short": "o gerador de emergência",
                   "need": "fusivel_ok", "parts": ["fusivel", "fita"],
                   "where": {"fusivel": "no alto dos elevadores de carga", "fita": "no túnel de serviço, depois do cambista"},
                   "pre": "O portão de saída está sem energia. O fusível do gerador está queimado.",
                   "place": "Chegue perto do gerador e toque em ✦ USAR.",
                   "use": "Toque em ✦ USAR no gerador.",
                   "msg": "O fusível emendado aguentou! O gerador ligou e o portão abriu."})
portao("ger1", 13000, -150, GY)
dica(12600, 12850, "O gerador de emergência está sem fusível. Emende um fusível com fita isolante.")
milhas(12560, 12820, 470, 40)
bateria(12300)
cartao(13300, GY, "Cartão de embarque dourado 3/3: um carimbo de hangar com uma cartola desenhada.")
pista(13400, GY, 5)
totem(12600)
fim(13500)
L["spanX"] = 13600
salvar(2)


# ======================================================================
#  1-3 · HANGAR
# ======================================================================
novo("Guarulhos · 1-3 Hangar",
     "A pista leva ao pátio, debaixo da garoa paulistana. Turbinas ligadas, guindastes e rebocadores: "
     "atravesse o pátio e entre no Hangar 7, onde os capangas do Barão guardam as milhas roubadas.",
     introSub="Episódio 1 · Brasil — São Paulo", endTitle="FIM DO HANGAR", introImg="res://assets/ui/intro_3.jpg", weather="garoa",
     periods=["Pátio", "Turbinas", "Guindastes", "Hangar 7"], clueIds=[6],
     rests={"1": ["CHECK-IN DO HANGAR 7", "A Bag buzina baixinho: lá dentro, um motoboy de capacete prende um malote cheio de milhas na moto.",
                  "Se ele chegar na pista, as milhas vão embora com o Barão. Vamos, Bag!"]},
     endStory="O plano de voo do Barão: o Motoboy Turbo leva o malote até a pista e o Barão foge para Maringá às 23h59.")

L["sections"].append({"x": 0, "song": "chuva", "bg": "pantano", "gt": "", "rain": .6, "per": 0})
chao(-200, 2200)
dica(0, 600, "O pátio de Guarulhos, debaixo da garoa. O chão molhado escorrega um pouco!")
milhas(300, 900, 470)
caixa(1000, n=4)
caixa(1040, GY - 38, n=4)
robo_falso(1400, [1250, 1650])
# escada de embarque (degraus) e a asa de um avião estacionado
for i in range(5):
    bloco(1700 + i * 50, 1750 + i * 50, GY - 40 * (i + 1), GY)
bloco(1950, 2050, GY - 200, GY)
plat(2050, 300, 650)                # asa do avião
milhas(2120, 2680, 270, 50)
L["pits"].append([2200, 3000])
pombo(2500, 150, [2200, 2800])
robo_falso(3250, [3100, 3400])
chao(3000, 5400)
totem(3100)
cartao(2650, 300, "Cartão de embarque dourado 1/3 (Hangar): \"Embarque pela porta dos fundos\".")
# --- turbinas: rajadas que empurram (gust) e pneus que rolam
L["sections"].append({"x": 3400, "song": "chuva", "bg": "pantano", "gt": "", "rain": .7, "per": 1})
L["traps"].append({"k": "gust", "x": 3500, "y": 80, "w": 140, "h": 420, "per": 200, "ph": 0, "on": 100})
plat(3460, 280, 120)
plat(3700, 200, 140)
milhas(3720, 3820, 170, 40)
dica(3400, 3600, "A turbina de um avião sopra de tempos em tempos! Segure ↓ para se abaixar e não ser empurrado.")
L["traps"].append({"k": "roll", "x": 4400, "y": GY, "trig": 3950, "dir": -1, "vmax": 4.5, "end": 3300, "r": 34})
dica(3950, 4200, "Um pneu solto vem rolando! Pule por cima.")
cambista(4700, [4500, 5000])
caixa(5200, item="heart")
totem(5300)
# --- guindastes: cabos para balançar e ganchos balançando
L["sections"].append({"x": 5400, "song": "chuva", "bg": "pantano", "gt": "", "rain": .6, "per": 2})
L["pits"].append([5400, 7100])
L["vines"].append({"x": 5560, "y": 0, "len": 300, "aim": [5960, 280]})
L["vines"].append({"x": 5960, "y": 0, "len": 300, "aim": [6400, 250]})
bloco(6320, 6520, 280, 500)
L["vines"].append({"x": 6720, "y": 0, "len": 280, "aim": [7200, 470]})
arco(5440, 5720, 320, 80, 6)
arco(5820, 6120, 320, 80, 6)
milhas(6340, 6500, 250, 40)
arco(6600, 7000, 320, 80, 7)
dica(5350, 5600, "Cabos dos guindastes: pule para agarrar, balance com ← → e solte com o pulo.")
drone(6250, 150, [6000, 6450])
pombo(5800, 60, [5500, 6100])
pombo(6900, 80, [6650, 7100])
chao(7100, 9800)
totem(7700)
L["traps"].append({"k": "swing", "x": 8100, "y": 170, "len": 300, "amp": 1.0, "per": 160, "ph": 0})
L["traps"].append({"k": "swing", "x": 8450, "y": 170, "len": 300, "amp": 1.0, "per": 160, "ph": 80})
dica(7900, 8100, "Ganchos de carga balançando. Passe na hora certa!")
milhas(7950, 8700, 470, 50)
pista(8900, GY, 6)
cartao(9300, 300, "Cartão de embarque dourado 2/3: \"Barão — 1ª classe — destino: Maringá\".")
bloco(9200, 9400, GY - 200, GY)
robo_falso(9600, [9450, 9750])
cambista(8700, [8550, 8850])
# --- Hangar 7: dentro, escuro, com o portão das alavancas
L["sections"].append({"x": 9800, "song": "noite", "bg": "mina", "gt": "mina", "dark": .3, "night": 1, "per": 3})
chao(9800, 11300)
chao(11360, 12800)
teto(9800, 12800, -620, -100)
deposito(11300, "s1", "alc1")
L["gold"] = {"x": 11050, "y": 930}
totem(9900, GY, 1)
caixote(10200)
bloco(10500, 10560, 300, 500)
bloco(10560, 10900, 300, 340)
milhas(10580, 10880, 270, 50)
mala_monstro(10700, 100, [10300, 11000])
cambista(11200, [11000, 11450])
drone(12000, 300, [11850, 12300])
robo_falso(12450, [12300, 12600])
L["levers"] = {"y": GY, "list": [{"x": 11600}, {"x": 11700}], "gate": {"x": 11800, "y": 380, "w": 22, "h": 120}}
bloco(11780, 11850, -100, 380, t="brickw")
dica(11450, 11780, "Duas alavancas: puxe as duas (✦ USAR) para abrir o portão do hangar.")
cartao(12300, GY, "Cartão de embarque dourado 3/3: \"Assento 1A, voo das 23h59\". O Barão vai fugir!")
milhas(11900, 12600, 470, 50)
totem(12100)
fim(12700)
L["spanX"] = 12800
salvar(3)


# ======================================================================
#  1-4 · CHEFE: MOTOBOY TURBO
# ======================================================================
novo("Guarulhos · Chefe: Motoboy Turbo",
     "Na pista, um capanga do Barão numa moto de entrega carrega o malote com as milhas roubadas. "
     "Ele vem acelerando: desvie subindo nas plataformas, faça ele bater nas barreiras e ataque quando "
     "ele ficar tonto!",
     introSub="Episódio 1 · Brasil — São Paulo", endTitle="GUARULHOS COMPLETO", introImg="res://assets/ui/intro_4.jpg", weather="garoa",
     periods=["A pista"], clueIds=[],
     endStory="As milhas LATAM voltaram para os clientes! Mas o Barão já decolou para Maringá... A próxima parada é o Paraná.")
L["sections"].append({"x": 0, "song": "chuva", "bg": "noite", "gt": "", "rain": .4, "night": .5, "per": 0})
chao(-200, 1200)
milhas(300, 650, 470)
dica(0, 500, "A pista de Guarulhos, à noite. Lá na frente, o ronco de uma moto...")
totem(520)
caixa(760, item="heart")
robo_falso(1000, [850, 1150])
# vala de drenagem com placas soltas
L["pits"].append([1200, 1500])
plat(1260, 440, 90, crumble=1)
plat(1390, 400, 90, crumble=1)
arco(1210, 1490, 400, 70, 7)
chao(1500, 4600)
# turbina de um avião taxiando e pneus soltos
L["traps"].append({"k": "gust", "x": 1700, "y": 80, "w": 140, "h": 420, "per": 200, "ph": 0, "on": 100})
dica(1550, 1750, "Turbina ligada! Segure ↓ para aguentar a rajada, ou passe quando ela desligar.")
pombo(2000, 300, [1800, 2250])
L["traps"].append({"k": "roll", "x": 2400, "y": GY, "trig": 1950, "dir": -1, "vmax": 4.6, "end": 1500, "r": 34})
milhas(1880, 2300, 470, 50)
drone(2350, 330, [2200, 2500])
totem(2600)
PZ0, PZ1 = 2900, 3900
plat(PZ0 + 40, 395, 130)
plat(PZ1 - 170, 395, 130)
L["boss"] = {"x0": PZ0, "x1": PZ1, "trig": PZ0 + 180, "spawn": PZ1 - 120, "hp": 4, "item": [(PZ0 + PZ1) // 2, 470]}
dica(PZ0, PZ1, "Suba nas plataformas quando ele acelerar. Quando ele bater e ficar tonto, ataque!", boss=1)
milhas(4000, 4400, 470, 50)
fim(4500)
L["spanX"] = 4600
salvar(4)


# ======================================================================
#  2-1 · GALEÃO (Rio de Janeiro)
# ======================================================================
novo("Galeão · 2-1 Terminal",
     "As pistas do Barão levam ao Rio de Janeiro! No Galeão, os capangas estão trocando as milhas roubadas num "
     "ponto secreto do terminal. Atravesse o desembarque, os quiosques e o bondinho sobre a vista da Baía de "
     "Guanabara, junte os biscoitos de polvilho e descubra o próximo passo da quadrilha.",
     introSub="Episódio 2 · Brasil — Rio de Janeiro", endTitle="FIM DO GALEÃO", introImg="res://assets/bg/gig_dia.jpg",
     bgset="gig", snackName="Biscoitos de polvilho", clueIds=[7, 8, 9],
     rain=[6300, 8200], nightAt=9300,
     periods=["Desembarque · 10:00", "Quiosques · 13:00", "Bondinho · 17:30", "Píer · 20:00"],
     rests={"1": ["CHECK-IN DO GALEÃO", "No balcão, alguém deixou um guardanapo com a baía desenhada e um X vermelho.",
                  "Um ponto de troca de milhas aqui no Galeão? O Barão não brinca em serviço."]},
     endStory="No píer do terminal 2, o envelope lacrado com o B dourado confirma: as milhas do Rio já seguem "
              "para o próximo destino. O Barão está sempre um voo à frente... mas o Milis também sabe voar!")
L["spawn"] = {"x": 190, "y": GY}

# --- A · Desembarque (0 .. 3000)
L["sections"].append({"x": 0, "song": "manha", "bg": "vila", "gt": "vila", "per": 0})
chao(-200, 3000)
dica(0, 520, "Rio de Janeiro! Os capangas do Barão espalharam milhas pelo desembarque do Galeão. E tem biscoito de polvilho pelo caminho!")
milhas(300, 700, 470)
caixa(820, n=5)
for cx in [640, 1900, 2700]:
    movel(cx, "coluna", 92)
movel(1150, "carrinhos", 110)
movel(2300, "bancos", 230)
painel(260)
painel(1300, 210, 170)
obj(460, "papeis", 60)
obj(1020, "passaportes", 44)
obj(1480, "lixeiras", 96)
obj(2120, "cafe", 46)
obj(2580, "etiqueta", 26)
pax(320, "turista", r=[200, 900], spd=.8, re=1)
pax(700, "cel", r=[560, 880], spd=.5)
pax(1700, "piloto", r=[1600, 2050], spd=.7)
pax(2290, "dorme", k="sit", y=GY - 14, look=False, z="z")
pax(2520, "comissaria", r=[2400, 2700], spd=.8)
atendente(1040, 410, "barros_gig1", [
    ["SEU BARROS", "Olha só, o robozinho da Milhas Plus no Rio! Bem-vindo ao Galeão!", "barros"],
    ["MILIS", "Seu Barros?! O senhor também veio para o Rio?", "tome"],
    ["SEU BARROS", "Folga, folga... vim ver o Pão de Açúcar. Hehe. Dizem que tem gente de capuz no bondinho, viu?", "barros"]], "aponta")
plat(980, 410, 140)                 # balcão de informações
milhas(1000, 1100, 380, 40)
totem(780)
# pombo (drone espião) nos bancos
pombo(1600, 250, [1480, 1760])
# torre de malas até o cartão dourado 1/3 (pulo duplo)
plat(1950, 400, 110)
plat(2120, 300, 110)
plat(1950, 200, 110)
milhas(1960, 2050, 370, 30)
milhas(2130, 2220, 270, 30)
cartao(2005, 200, "Cartão de embarque dourado 1/3 (Galeão): GIG → ??? — carimbo com um B floreado.")
icone(1850, 2000, 1950, 420, "↑↑")
robo_falso(2550, [2420, 2760])
caixa(2860, item="heart", soft=True)
totem(2900)
# o vulto de capuz aparece de novo e foge pelo desembarque
L["chases"] = [{"trig": 120, "x0": 300, "x1": 900, "y": GY, "spd": 4.8, "bonus": 15,
                "pista": "Na mala, um bilhete: \"Troca no terminal 2, depois do bondinho.\" Assinado: B."}]

# --- B · Quiosques (3000 .. 6200): praça de alimentação, carregadores e o 1º segurança
L["sections"].append({"x": 3000, "song": "aero_tema", "bg": "vila", "gt": "vila", "per": 1})
chao(3000, 5250)
chao(5370, 6100)
inimigo("porter", 3550, [3380, 3720])
dica(3100, 3350, "Carregador falso! Quando ele erguer a mala, rebata com o bastão na hora certa.")
painel(3300, 200, 170)
quebra(3260, "lanche", 64)
for kx in [3850, 4060]:               # quiosques (balcões baixos para subir)
    peca(kx, kx + 140, 410, 500, "p_pc_balcao", 75, 40, 4, 58)
    milhas(kx + 20, kx + 120, 380, 50)
plat(3920, 260, 130)                   # toldo do quiosque
pista(3985, 260, 7)
milhas(3930, 4040, 230, 36)
icone(3820, 3960, 3900, 360, "↑↑")
totem(4200, 410)
# arena do 1º segurança (praça de alimentação)
inimigo("boar", 4600, [4430, 4780], arena=[4330, 4860])
quebra(4470, "carrinho", 70)
caixa(4900, item="heart", soft=True)
obj(4950, "cafe", 44)
obj(5180, "folhetos", 40)
# tapume da obra: passe rolando (corra e abaixe)
bloco(5000, 5120, -620, GY - 34, t="tapume")
icone(4870, 4990, 4960, 420, "» ↓")
L["pits"].append([5250, 5370])         # vãozinho logo depois do tapume (pulo curto)
arco(5240, 5380, 450, 50, 4)
faxineiro(5700, [5420, 5960])
molhado(5800, 130)
quebra(5785, "placa", 34)
pax(5450, "mae", r=[5360, 5560], spd=.6)
pax(6000, "idosa", k="stand")
painel(5600, 200)
milhas(5400, 5700, 470, 50)
totem(6000, GY, 1)
caixa(5900, n=4, soft=True)

# --- C · Átrio do bondinho (6100 .. 9200): o vão da vidraça com a vista da baía, só atravessa de bondinho
L["sections"].append({"x": 6100, "song": "tarde", "bg": "tarde", "gt": "vila", "per": 2})
chao(6100, 6180)
chao(6260, 6500)
# elevador panorâmico até o mirante (uma pista lá em cima)
elevador_vidro(6180, 60)
bloco(6180, 6260, 511, 640)
passarela(6270, 6490, 60, 100)
pista(6440, 60, 8)
milhas(6290, 6420, 30, 40)
icone(6100, 6270, 6180, 380, "✋")
dica(6250, 6500, "O átrio da vidraça! Só dá para atravessar de bondinho. Pule para dentro da cabine quando ela chegar perto.")
L["pits"].append([6500, 7700])
L["movers"].append({"k": "path", "x0": 6520, "x1": 6980, "y0": 420, "y1": 330, "w": 130, "per": 320, "skin": "bondinho"})
L["movers"].append({"k": "path", "x0": 7560, "x1": 7090, "y0": 420, "y1": 330, "w": 130, "per": 320, "skin": "bondinho"})
arco(6560, 7660, 280, 70, 16)
drone(7080, 170, [6860, 7300])
# torre do cabo no meio, com o cartão dourado 2/3 no topo (pule de dentro do bondinho)
plat(7030, 150, 60)
cartao(7060, 150, "Cartão de embarque dourado 2/3: \"VOO ESPECIAL — saída do Rio às 21h\". Para onde?")
chao(7700, 9200)
caixa(7780, item="heart", soft=True)
totem(7820)
# arena do 2º segurança (chama reforço no rádio)
inimigo("boar", 8250, [8080, 8420], arena=[7980, 8520], radio=1)
quebra(8120, "malas", 72)
milhas(8600, 8900, 470, 50)
inimigo("porter", 8900, [8720, 9100])
painel(8400, 190)
obj(8650, "lixeiras", 96)
pax(9080, "exec", r=[9000, 9180], spd=1.0)
totem(9150)

# --- D · Píer do terminal 2 (9200 .. 12300): noite, esteira rolante, escada rolante e a saída
L["sections"].append({"x": 9200, "song": "noite", "bg": "noite", "gt": "vila", "night": .4, "per": 3})
chao(9200, 12300)
neon(9500, "#ff4fb4")
neon(10100, "#4fd8ff")
neon(10900, "#ffd84a")
neon(11600, "#9b6bff")
L.setdefault("walks", []).append({"x0": 9300, "x1": 9700, "y": GY, "dir": 1, "spd": 1.8})
icone(9220, 9320, 9330, 420, "»")
milhas(9320, 9680, 470, 45)
pombo(9950, 250, [9800, 10100])
# escada rolante até o mezanino: o cartão dourado 3/3
escada_rolante(10200, GY, 260, dir=1, spd=1.6)
bloco(10680, 10920, 260, GY)
S[-1]["esc"] = 2
plat(10740, 140, 130)
milhas(10700, 10900, 230, 46)
cartao(10805, 140, "Cartão de embarque dourado 3/3: o destino aparece em letras douradas... a caçada continua!")
icone(10100, 10280, 10190, 330, "↑↑")
caixa(10980, item="heart", soft=True)
robo_falso(11250, [11080, 11420])
painel(11300, 190)
obj(11500, "papeis", 60)
pax(11620, "teen", k="stand", re=1, bal="oi!")
pista(11720, GY, 9)
totem(11500)
milhas(11760, 11900, 470, 45)
fim(11980)
L["spanX"] = 12300
L["fg"] = [{"x": 760, "k": "coluna"}, {"x": 2150, "k": "bancos", "flip": True}, {"x": 3480, "k": "lixeira"},
           {"x": 5500, "k": "coluna"}, {"x": 7900, "k": "coluna"}, {"x": 9050, "k": "lixeira", "flip": True},
           {"x": 10450, "k": "coluna"}, {"x": 11800, "k": "bancos"}]
# biscoitos de polvilho (o petisco típico): 10 pelo caminho, alguns em lugares mais difíceis
L["snacks"] = [[560, 440], [1050, 330], [2170, 160], [3985, 200], [4700, 420], [5310, 380],
               [6360, 0], [7300, 260], [9500, 420], [10805, 90]]
for h in L["hints"]:
    h.setdefault("yl", L.get("under", 640))
salvar(5)
