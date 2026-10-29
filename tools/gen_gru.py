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


def caixa(x, y=GY, n=4, item=None):
    d = {"t": "break", "x": x, "y": y - 38}
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
     "O Barão das Milhas Falsas invadiu o Aeroporto de Guarulhos e espalhou as milhas LATAM dos clientes pelo "
     "terminal. Recupere as milhas, ache os cartões de embarque dourados e descubra para onde o Barão foi. "
     "Cuidado com os capangas dele!",
     introSub="Episódio 1 · Brasil — São Paulo", endTitle="FIM DO TERMINAL",
     periods=["Saguão", "Check-in", "Segurança", "Mezanino"], clueIds=[1, 2, 3])

# --- A · Saguão (0 .. 3400): aprender a andar, pular, quebrar malas, pulo duplo
L["sections"].append({"x": 0, "song": "manha", "bg": "vila", "gt": "vila", "per": 0})
chao(-200, 1500)
dica(0, 520, "Guarulhos! O Barão espalhou as milhas LATAM pelo terminal. Ande com ← → e pule com o botão de pulo.")
milhas(300, 700, 470)
caixa(820, n=5)
dica(700, 950, "Malas abandonadas do Barão: pise em cima ou bata com o bastão para soltar as milhas.")
plat(980, 410, 140)                 # balcão de informações (dá para subir)
milhas(1000, 1100, 380, 40)
cambista(1300, [1150, 1450])
dica(1120, 1320, "Um cambista do Barão! Pule na cabeça dele ou dê um golpe com o bastão de sinalização.")
totem(1460)
# fileira de bancos e a primeira subida dupla
bloco(1500, 1700, 430, 500)         # bancos do saguão
chao(1500, 3400)
bloco(1880, 2040, 300, 500)         # coluna com painel de voos
milhas(1890, 2030, 270, 35)
dica(1720, 1900, "Alto demais? Pule de novo no ar: pulo duplo!")
arco(2050, 2300, 470, 90, 6)
robo_falso(2450, [2350, 2600])
caixa(2700, item="heart")
plat(2780, 380, 120)
plat(2960, 280, 120)
plat(3140, 180, 120)
coluna(3200, 140, 20)
cartao(3200, 180, "Cartão de embarque dourado 1/3 (Terminal): GRU → ??? — o destino está raspado.")
pombo(2900, 250, [2700, 3200])
totem(3300)

# --- B · Check-in (3400 .. 7200): fila em zigue-zague, balcões, esteira de despacho, catraca da placa
L["sections"].append({"x": 3400, "song": "manha", "bg": "vila", "gt": "vila", "per": 1})
chao(3400, 6300)
chao(6370, 7200)
# balcões de check-in: blocos de altura média com esteira de despacho atrás
for i, bx in enumerate([3600, 3900, 4200]):
    bloco(bx, bx + 140, 410, 500)
    milhas(bx + 20, bx + 120, 380, 50)
caixa(3810, n=3)
cambista(4100, [3760, 4180])
dica(3420, 3700, "Fila do check-in. Os balcões dão bons degraus.")
# esteira de despacho que sobe (plataforma que anda)
L["movers"].append({"k": "path", "x0": 4400, "x1": 4680, "y0": 400, "y1": 230, "w": 110, "per": 260})
bloco(4800, 5100, 230, 500)         # o alto das balanças
milhas(4830, 5080, 200, 50)
pista(5050, 230, 1)
dica(4380, 4600, "A esteira de despacho sobe e desce: espere ela chegar e pule em cima.")
totem(4880, 230)
# lá de cima, planar com as asas por cima da fila até a ilha seguinte
plat(5500, 300, 120)
plat(5900, 260, 120)
arco(5120, 5480, 230, 50, 7)
arco(5640, 5880, 250, 40, 5)
dica(5000, 5250, "Segure o pulo depois do pulo duplo (ou o botão de planar) e as asas de avião abrem: você plana!",
     yl=260)
drone(5700, 360, [5550, 5850])
# a fila em zigue-zague lá embaixo: fitas (plataformas baixas) e um caixote para a placa
for i in range(4):
    plat(5200 + i * 160, 440 - (i % 2) * 40, 100)
caixote(6050)
S.append({"t": "dirt", "x": 6300, "y": 520, "w": 70, "h": 120})
L["plates"].append({"x": 6300, "y": 520, "w": 70, "gate": "cat1"})
portao("cat1", 6500, 380, GY)
bloco(6460, 6540, -620, 380, t="brickw")     # parede da área restrita acima da catraca
dica(6000, 6320, "A catraca da área restrita está fechada. Empurre o caixote até a placa no chão!")
milhas(6100, 6450, 470, 50)
robo_falso(6800, [6600, 7000])
totem(6600, GY, 1)
caixa(7050, n=4)

# --- C · Segurança (7200 .. 10600): raio-x com pinos elétricos, ar-condicionado que sopra para cima, crachá
L["sections"].append({"x": 7200, "song": "tarde", "bg": "tarde", "gt": "vila", "per": 2})
chao(7200, 8000)
dica(7200, 7500, "A segurança! O Barão ligou as esteiras do raio-x na tomada errada: cuidado com os choques.")
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
dica(8100, 8300, "Bandejas soltas: elas caem logo depois que você pisa!")
pombo(8700, 300, [8500, 9000])
# saída de ar-condicionado: o vento leva o Milis planando até o mezanino de cima
L["traps"].append({"k": "wind", "x": 9000, "y": -90, "w": 120, "h": 590, "pow": 1.0})
bloco(9200, 9900, -40, 0)           # mezanino da segurança
milhas(9020, 9100, 300, 40)
coluna(9060, 260, -60)
milhas(9220, 9880, -70, 50)
cartao(9850, -40, "Cartão de embarque dourado 2/3: carimbado \"VOO DO BARÃO — PORTÃO 2??\".")
L["items"].append({"x": 9500, "y": -24, "id": "cartao_acesso"})
dica(8900, 9150, "Saída de ar-condicionado: abra as asas (planar) em cima dela e o vento leva você lá para cima.")
mala_monstro(9600, -200, [9300, 9850])
L["items"].append({"x": 8620, "y": 476, "id": "cordao"})
drone(9500, 360, [9300, 9750])
cambista(10000, [9800, 10300])
totem(8560)
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
dica(10150, 10400, "A porta só abre com crachá. Junte o cartão de acesso com o cordão no compartimento do Milis.")
totem(10200)

# --- D · Mezanino e portão (10600 .. 14200): escada de serviço, corrimãos, escada rolante, sala secreta
L["sections"].append({"x": 10600, "song": "noite", "bg": "noite", "gt": "vila", "night": .4, "per": 3})
chao(10600, 11400)
escada(10900, 160)
bloco(10930, 11600, 160, 200)       # passarela de serviço
milhas(10960, 11560, 130, 50)
robo_falso(11300, [11000, 11550], y=160)
L["pits"].append([11400, 12200])
# corrimão (pendurar e ir mão por mão)
L["bars"].append({"x0": 11640, "x1": 12160, "y": 120})
milhas(11660, 12140, 210, 52)
dica(11550, 11700, "Um cabo esticado: pule e segure-se nele para atravessar.", yl=220)
bloco(12160, 12500, 160, 200)
chao(12200, 13580)
chao(13640, 14200)
mala_monstro(12900, 260, [12600, 13200])
# escada rolante (degraus que sobem) e mola
for i in range(6):
    bloco(12600 + i * 60, 12660 + i * 60, GY - 30 * (i + 1), GY)
bloco(12960, 13200, GY - 180, GY)
milhas(12620, 12940, 440, 64)
mola(13280, pow=-23)
plat(13250, 170, 160)
cartao(13330, 170, "Cartão de embarque dourado 3/3: a hora do voo — 23h59.")
dica(13200, 13350, "Uma balança de bagagem com mola: pule em cima para ir bem alto!")
# sala secreta embaixo do piso (mergulho no alçapão)
S.append({"t": "crack", "x": 13580, "y": GY, "w": 60, "h": 22, "kind": "slam", "id": "alc1", "ladder": [13595, GY, 460],
          "msg": "O mergulho abriu o alçapão! Tem uma escada descendo (↓)."})
# o depósito embaixo do piso, com a sala secreta atrás da parede falsa
L["caves"].append({"x": 13580, "y": GY, "w": 60, "h": 260})
L["caves"].append({"x": 13470, "y": 760, "w": 520, "h": 200})
L["caves"].append({"x": 13270, "y": 860, "w": 180, "h": 100})
S.append({"t": "dirt", "x": 13450, "y": 960, "w": 560, "h": 60})
S.append({"t": "dirt", "x": 13250, "y": 960, "w": 200, "h": 60})
S.append({"t": "dirt", "x": 13450, "y": 740, "w": 130, "h": 20})
S.append({"t": "dirt", "x": 13640, "y": 740, "w": 370, "h": 20})
S.append({"t": "dirt", "x": 13990, "y": 740, "w": 20, "h": 220})
S.append({"t": "dirt", "x": 13450, "y": 740, "w": 20, "h": 140})
S.append({"t": "fakewall", "x": 13450, "y": 880, "w": 20, "h": 80, "deco": 1})
S.append({"t": "dirt", "x": 13250, "y": 840, "w": 20, "h": 180})
S.append({"t": "dirt", "x": 13250, "y": 840, "w": 200, "h": 20})
L["secrets"].append({"id": "s1", "x": 13270, "y": 860, "w": 180, "h": 100})
milhas(13700, 13950, 930, 50)
milhas(13300, 13420, 930, 40)
pista(13330, 960, 2)
dica(13450, 13600, "Esse piso parece oco... pule e mergulhe (↓ no ar) em cima dele.")
cambista(13900, [13750, 14050])
pista(14000, GY, 3)
totem(13450)
fim(14120)
L["spanX"] = 14200
salvar(1)


# ======================================================================
#  1-2 · BAGAGENS
# ======================================================================
novo("Guarulhos · 1-2 Bagagens",
     "Uma pista leva ao subsolo das bagagens. Lá embaixo está escuro: o farol dos olhos do Milis gasta bateria, "
     "então pegue as pilhas pelo caminho. Dizem que uma mala muito esperta ficou presa nas esteiras...",
     introSub="Episódio 1 · Brasil — São Paulo", endTitle="FIM DAS BAGAGENS",
     periods=["Esteiras", "A Bag", "Elevadores", "Túnel de serviço"], clueIds=[4, 5])

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
L["movers"].append({"k": "path", "x0": 2150, "x1": 2450, "y0": 330, "y1": 430, "w": 120, "per": 240})
arco(1650, 2450, 380, 80, 12)
drone(2050, 220, [1800, 2400])
dica(1600, 1900, "Esteiras suspensas! Pule de uma para a outra. Não caia no fosso das malas.")
chao(2600, 5200)
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
pista(4700, GY, 4)
totem(4100)
# estaca: o mergulho no botão grande abaixa a ponte
L["slam"] = {"stakes": [{"x": 5100, "y": GY, "bridge": {"x": 5200, "y": GY, "w": 360}}], "seesaw": [], "fruit": []}
L["pits"].append([5200, 5560])
dica(4950, 5150, "Um botão gigante no chão: pule e mergulhe em cima dele para baixar a ponte.")
chao(5560, 7150)
chao(7220, 7600)

# --- B · A Bag presa na esteira (5560 .. 7600)
L["sections"].append({"x": 5560, "song": "tunel", "bg": "mina", "gt": "mina", "dark": .5, "night": 1, "per": 1})
L["dog"] = {"x": 6300, "y": GY}
dica(5800, 6300, "Uma mala de rodinhas presa na esteira... ela está piscando para você! Chegue perto e toque em ✦ USAR.")
milhas(5600, 6200, 470, 50)
bateria(5900)
totem(5700, GY, 1)
# passagem baixa que só a Bag passa e uma placa do outro lado
bloco(6800, 7000, -150, 440)        # parede com um vão de 60 px embaixo (Bag passa)
S.append({"t": "dirt", "x": 7150, "y": 520, "w": 70, "h": 120})
L["plates"].append({"x": 7150, "y": 520, "w": 70, "gate": "bag1"})
portao("bag1", 7400, -150, GY)
cartao(7080, GY, "Cartão de embarque dourado 1/3 (Bagagens): \"Assento 1A — Barão\".")
dica(6600, 6800, "Só a Bag passa por esse vão. Troque para ela (botão da mala), passe e pare em cima da placa.")
milhas(6820, 6980, 470, 40)

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
     introSub="Episódio 1 · Brasil — São Paulo", endTitle="FIM DO HANGAR", weather="garoa",
     periods=["Pátio", "Turbinas", "Guindastes", "Hangar 7"], clueIds=[6])

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
plat(2100, 300, 600)                # asa do avião
milhas(2120, 2680, 270, 50)
L["pits"].append([2200, 3000])
pombo(2500, 150, [2200, 2800])
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
L["pits"].append([5400, 7600])
L["vines"].append({"x": 5650, "y": 0, "len": 300, "aim": [5900, 250]})
L["vines"].append({"x": 6100, "y": 0, "len": 300, "aim": [6350, 250]})
bloco(6450, 6650, 280, 500)
L["vines"].append({"x": 6900, "y": 0, "len": 280, "aim": [7150, 250]})
arco(5550, 5850, 320, 80, 6)
arco(6000, 6300, 320, 80, 6)
milhas(6470, 6630, 250, 40)
arco(6800, 7100, 320, 80, 6)
dica(5350, 5600, "Cabos dos guindastes: pule para agarrar, balance com ← → e solte com o pulo.")
drone(6250, 150, [6000, 6450])
chao(7600, 9800)
totem(7700)
L["traps"].append({"k": "swing", "x": 8100, "y": 170, "len": 300, "amp": 1.0, "per": 160, "ph": 0})
L["traps"].append({"k": "swing", "x": 8450, "y": 170, "len": 300, "amp": 1.0, "per": 160, "ph": 80})
dica(7900, 8100, "Ganchos de carga balançando. Passe na hora certa!")
milhas(7950, 8700, 470, 50)
pista(8900, GY, 6)
cartao(9300, GY - 230, "Cartão de embarque dourado 2/3: \"Barão — 1ª classe — destino: Maringá\".")
bloco(9200, 9400, GY - 200, GY)
robo_falso(9600, [9450, 9750])
# --- Hangar 7: dentro, escuro, com o portão das alavancas
L["sections"].append({"x": 9800, "song": "noite", "bg": "mina", "gt": "mina", "dark": .3, "night": 1, "per": 3})
chao(9800, 12800)
teto(9800, 12800, -620, -100)
totem(9900, GY, 1)
caixote(10200)
bloco(10500, 10560, 300, 500)
bloco(10560, 10900, 300, 340)
milhas(10580, 10880, 270, 50)
mala_monstro(10700, 100, [10300, 11000])
cambista(11200, [11000, 11450])
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
     introSub="Episódio 1 · Brasil — São Paulo", endTitle="GUARULHOS COMPLETO", weather="garoa",
     periods=["A pista"], clueIds=[])
L["sections"].append({"x": 0, "song": "chuva", "bg": "noite", "gt": "", "rain": .4, "night": .5, "per": 0})
chao(-200, 3400)
milhas(300, 900, 470)
dica(0, 500, "A pista de Guarulhos. Lá na frente, o Motoboy Turbo acelera a moto...")
totem(900)
PZ0, PZ1 = 1300, 2300
plat(PZ0 + 40, 395, 130)
plat(PZ1 - 170, 395, 130)
L["boss"] = {"x0": PZ0, "x1": PZ1, "trig": PZ0 + 180, "spawn": PZ1 - 120, "hp": 4, "item": [(PZ0 + PZ1) // 2, 470]}
dica(PZ0, PZ1, "Suba nas plataformas quando ele acelerar. Quando ele bater e ficar tonto, ataque!", boss=1)
milhas(2400, 3100, 470, 50)
fim(3250)
L["spanX"] = 3400
salvar(4)
