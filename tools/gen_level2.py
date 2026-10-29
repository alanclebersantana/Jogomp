#!/usr/bin/env python3
"""Gera assets/data/level2.json — Episódio 2: As Profundezas da Mina.

Quatro trechos (cada um termina numa fogueira grande, menos o último):
  A  Boca da mina      0 .. 9800      escuro, lanterna, trilhos, porta de manivela, elevador, lago tóxico
  B  Vale do moinho    9800 .. 16800  campo ao entardecer; a vela nova faz o moinho girar e as tábuas
                                      das pás levam o Tomé até o alto do barranco
  C  Telhados da vila  16800 .. 27000 noite; de telhado em telhado, varais, fumaça das chaminés
  D  Profundezas       27000 .. 31600 porteira (chave), carrinho nos trilhos atrás do Vargas, porta do cofre

Rodar:  python3 tools/gen_level2.py
"""
import json, math, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GY = 500

L = {
    "name": "As Profundezas da Mina",
    "theme": "mine", "seed": 7, "weather": "limpo", "top": -620, "bottom": 1150, "under": 640,
    "spawn": {"x": 190, "y": 500}, "combat": "stomp", "time": 480, "results": 1,
    "intro": "A trilha de lápis entra mina adentro. Desça pelos túneis, atravesse o vale do moinho e os "
             "telhados da vila dos mineiros. O Vargas está levando a Isis para o fundo da mina.",
    "introImg": "res://assets/ui/cut_ep2_a.jpg",
    "endTitle": "FIM DAS PROFUNDEZAS",
    "periods": ["Boca da mina", "Vale do moinho", "Telhados da vila", "Profundezas", "A fuga da Isis"],
    "clueIds": [7, 8, 9, 10, 11, 12],
    "rests": {
        "1": ["FIM DA BOCA DA MINA", "Ela tinha medo do escuro. Eu deixava a lanterna acesa na porta do quarto.", "Estou com a lanterna, filha. O escuro não vence a gente."],
        "2": ["FIM DO VALE", "No domingo a gente ia ver o moinho girar. Ela contava as voltas até dormir no meu colo.", "Mais uma volta, Isis. Estou chegando."],
        "3": ["FIM DOS TELHADOS", "Ela subia no telhado do galpão para ver as estrelas. Eu fingia que brigava.", "Lá embaixo, nos trilhos. Aguenta firme, filha."],
    },
    "sections": [], "darkZones": [], "caves": [], "solids": [], "swamp": [], "lily": [], "mud": [],
    "climb": [], "entrances": [], "bushes": [], "items": [], "locks": [], "clues": [], "specials": [],
    "drawings": [], "vines": [], "springs": [], "crates": [], "enemies": [], "coins": [], "clocks": [],
    "checks": [], "hints": [], "pits": [], "water": [], "mirrors": [], "crystals": [], "ghost": [],
    "secrets": [], "chalk": [], "plates": [], "traps": [], "decor": [], "bars": [], "oil": [],
    "cranks": [], "movers": [], "comics": [], "relics": [], "fireflies": [],
}
S = L["solids"]


def ground(x0, x1, y=GY, h=None):
    S.append({"t": "ground", "x": x0, "y": y, "w": x1 - x0, "h": h if h is not None else (640 - y if y < 640 else 140)})


def rock(x0, x1, y0, y1, ceil=False):
    """maciço de rocha da mina (teto ou parede)"""
    d = {"t": "rockw", "x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0}
    if ceil:
        d["ceil"] = 1
    S.append(d)


def plat(x, y, w, **kw):
    d = {"t": "plat", "x": x, "y": y, "w": w}
    d.update(kw)
    S.append(d)


def coins_line(x0, x1, y, step=44):
    x = x0
    while x <= x1:
        L["coins"].append([int(x), int(y)])
        x += step


def coins_arc(x0, x1, y, h, n=5):
    for i in range(n):
        u = i / (n - 1)
        L["coins"].append([int(x0 + (x1 - x0) * u), int(y - math.sin(u * math.pi) * h)])


def check(x, y=GY, rest=None):
    L["checks"].append([x, y] if rest is None else [x, y, "rest", rest])


def hint(a, b, t, **kw):
    d = {"a": a, "b": b, "t": t}
    d.update(kw)
    L["hints"].append(d)


def bat(x, cy, r, ceil_y):
    """morcego pendurado numa ponta de rocha que desce do teto (não fica solto no ar)"""
    L["enemies"].append({"k": "bat", "x": x, "y": cy, "cy": cy, "r": r})
    rock(x - 34, x + 34, ceil_y - 10, cy - 14, True)


def lake(x, w, stake_x):
    """lago de veneno com estaca: o mergulho na estaca baixa a ponte"""
    L["swamp"].append({"x": x, "y": 530, "w": w, "h": 110, "fumes": 1, "pit": 1})
    S.append({"t": "dirt", "x": x, "y": 560, "w": w, "h": 580, "deco": 1})
    L.setdefault("slam", {"stakes": [], "seesaw": [], "fruit": []})
    L["slam"]["stakes"].append({"x": stake_x, "y": GY, "bridge": {"x": x, "y": GY, "w": w}})


# ======================================================================
#  A · BOCA DA MINA  (0 .. 9800)
# ======================================================================
L["sections"].append({"x": 0, "song": "tunel", "bg": "mina", "gt": "mina", "dark": .5, "night": 1, "per": 0,
                      "tint": "rgba(60,35,10,.16)"})
L["darkZones"].append({"x": 0, "w": 9800, "dark": .82})
# (sem "tunnel": o teto baixo do túnel do Episódio 1 cobriria as galerias altas)
# teto de rocha ao longo de quase todo o trecho (com aberturas mais altas)
rock(-200, 1350, -620, 40, True)
rock(1350, 2750, -620, -40, True)
rock(2750, 4180, -620, 40, True)
rock(4180, 4380, -620, -220, True)
rock(4380, 9800, -620, -160, True)

# A1: o salão de entrada
ground(-200, 1400)
L["crates"].append({"t": "break", "x": 640, "y": 462, "n": 5})
L["chalk"].append({"x": 760, "y": 440, "k": "seta", "d": 1})
plat(900, 400, 130, trestle=1)
coins_line(300, 860, 470)
coins_line(920, 1010, 370, 40)
L["clues"].append({"x": 1220, "y": 470, "id": 7})
L["oil"].append([1100, 468])
hint(0, 700, "Episódio 2 · A boca da mina. Siga os lápis da Isis pelos trilhos. A lanterna clareia o caminho: pegue o óleo pelo caminho.")
check(1300)

# A2: o poço com cavaletes (tábuas sobre o vão)
L["pits"].append([1400, 1900])
plat(1450, 450, 96, trestle=1)
plat(1600, 410, 96, trestle=1)
plat(1760, 440, 96, trestle=1)
coins_arc(1430, 1560, 430, 50, 4)
coins_arc(1590, 1710, 390, 50, 4)
coins_arc(1740, 1880, 420, 50, 4)
L["specials"].append({"x": 1650, "y": 300, "c": "vermelho"})
bat(1650, 250, [1450, 1880], -40)
ground(1900, 3720)
hint(1300, 1500, "Cavaletes sobre o poço: pule de tábua em tábua. Cuidado com o morcego!")
check(2000)

# A3: porta de manivela e a porta da placa
L["cranks"].append({"x": 3020, "y": GY, "gate": "cg1"})
S.append({"t": "pgate", "id": "cg1", "x": 3100, "y": 376, "w": 22, "h": 124, "crank": 1})
rock(3060, 3170, -620, 376)
coins_line(2100, 2950, 470)
L["oil"].append([2700, 468])
hint(2850, 3110, "Porta de manivela: aperte USAR várias vezes seguidas para girar e a porta sobe.")
L["enemies"].append({"k": "spider", "x": 3380, "y": 500, "top": 300, "r": [3380, 3380]})
L["crates"].append({"t": "push", "x": 3480, "y": 430, "w": 70, "h": 70})
S.append({"t": "dirt", "x": 3720, "y": 520, "w": 70, "h": 120})
L["plates"].append({"x": 3720, "y": 520, "w": 70, "gate": "g1"})
ground(3790, 4272)
# poço do elevador (rasinho: dá para sair pulando se o elevador estiver lá em cima)
S.append({"t": "dirt", "x": 4272, "y": 590, "w": 108, "h": 50})
L["pits"].append([4272, 4380])
S.append({"t": "pgate", "x": 3880, "y": -700, "w": 22, "h": 1200, "id": "g1"})
hint(3420, 3760, "Empurre a caixa até o buraco da placa: o portão de ferro sobe.")
check(3250)
coins_line(3950, 4250, 470)

# A4: elevador da mina até a galeria de cima
rock(4380, 5700, 60, 500)                      # maciço (o chão de cima é o topo dele)
S.append({"t": "ground", "x": 4380, "y": 60, "w": 1320, "h": 30, "mine": 1})
L["movers"].append({"k": "lift", "x": 4280, "w": 96, "y0": 60, "y1": 500, "start": "bottom"})
hint(4100, 4380, "Elevador da mina: suba na gaiola e aperte USAR.")
check(4150)
L["items"].append({"x": 4760, "y": 36, "id": "corda"})
coins_line(4450, 5600, 30)
bat(5100, -100, [4700, 5500], -160)
L["specials"].append({"x": 5250, "y": -60, "c": "laranja"})
L["oil"].append([5450, 28])
L["drawings"].append({"x": 5560, "y": 26, "txt": "Um desenho da Isis: o papai de capacete, com a lanterna, descendo na gaiola."})
check(4600, 60)
# desce do alto (chão de baixo volta em 5700)
ground(5700, 5860)
lake(5860, 360, 5800)
ground(6220, 7480)
L["enemies"].append({"k": "fly", "x": 6040, "y": 380, "r": [5880, 6200], "cy": 380})
L["enemies"].append({"k": "fly", "x": 7300, "y": 400, "r": [7150, 7450], "cy": 400})
hint(5700, 5900, "Lago de veneno! Pule e mergulhe (↓ no ar) em cima da estaca: a ponte desce.")
check(5740)
coins_arc(5870, 6210, 450, 60, 7)

# A5: carrinhos parados e espinhos de pedra
S.append({"t": "cart", "x": 6520, "y": 446, "w": 84, "h": 54})
S.append({"t": "cart", "x": 6830, "y": 446, "w": 84, "h": 54})
plat(6950, 340, 120, trestle=1)
L["traps"].append({"k": "spikes", "x": 6640, "y": GY, "w": 96, "per": 150, "ph": 0})
coins_line(6300, 6500, 470)
coins_line(6530, 6600, 420, 35)
coins_line(6840, 6910, 420, 35)
coins_line(6970, 7060, 310, 40)
L["oil"].append([6400, 468])
L["drawings"].append({"x": 7010, "y": 306, "txt": "Um desenho da Isis: um carrinho de mina cheio de estrelas."})
check(7200)

# A6: a saída: degraus de pedra subindo e o portão das alavancas
for i, (sx, sh) in enumerate([(7480, 60), (7630, 130), (7780, 200), (7930, 270)]):
    S.append({"t": "stone", "x": sx, "y": GY - sh, "w": 150 if i < 3 else 140, "h": sh})
ground(7480, 9800)
S.append({"t": "ground", "x": 8070, "y": 230, "w": 520, "h": 270})
for sx, top in [(7555, 440), (7705, 370), (7855, 300), (8000, 230)]:
    L["coins"].append([sx, top - 30])
coins_line(8100, 8560, 200)
bat(8300, 60, [8100, 8560], -160)
L["levers"] = {"y": GY, "list": [{"x": 8860}, {"x": 8930}], "gate": {"x": 9020, "y": 380, "w": 22, "h": 120}}
rock(8990, 9080, -620, 380)
hint(8700, 9000, "Duas alavancas: puxe as duas (USAR) para o portão subir.")
coins_line(8650, 8980, 470)
check(8650)
check(9450, GY, 1)
coins_line(9100, 9400, 470)

# ======================================================================
#  B · VALE DO MOINHO  (9800 .. 16800)
# ======================================================================
L["sections"].append({"x": 9800, "song": "tarde", "bg": "moinho", "per": 1, "tint": "rgba(255,160,70,.10)",
                      "leaves": 24, "flock": "birds", "toucans": 1})
ground(9800, 12650)
for x, s in []:
    L["decor"].append({"k": "pine", "x": x, "y": GY, "s": s})
hint(9800, 10300, "O vale do moinho. Lá longe, um moinho velho com as velas rasgadas...")
coins_line(9850, 10500, 470)
L["enemies"].append({"k": "crow", "x": 10800, "y": 300, "cy": 300, "r": [10500, 11200]})
L["traps"].append({"k": "flower", "x": 10950, "y": GY, "to": [11230, 200]})
S.append({"t": "stone", "x": 11180, "y": 200, "w": 110, "h": 300})
L["specials"].append({"x": 11235, "y": 150, "c": "amarelo"})
coins_arc(10960, 11220, 330, 120, 6)
check(10600)
# o celeiro: a lona está lá dentro (porta baixa: entre abaixado)
S.append({"t": "shed", "x": 11500, "y": 380, "w": 300, "h": 20})
S.append({"t": "wall", "x": 11500, "y": 380, "w": 20, "h": 96})
S.append({"t": "wall", "x": 11780, "y": 380, "w": 20, "h": 96})
L["items"].append({"x": 11650, "y": 476, "id": "lona"})
hint(11380, 11520, "O celeiro tem a porta baixa: segure ↓ para entrar abaixado.")
coins_line(11540, 11760, 470, 55)
L["clues"].append({"x": 12100, "y": 470, "id": 8})
L["enemies"].append({"k": "frog", "x": 12300, "y": GY, "r": [12200, 12450]})
L["enemies"].append({"k": "frog", "x": 10250, "y": GY, "r": [10120, 10380]})
L["enemies"].append({"k": "fly", "x": 10450, "y": 400, "r": [10300, 10650], "cy": 400})
L["enemies"].append({"k": "fly", "x": 12860, "y": 380, "r": [12700, 13020], "cy": 380})
check(12000)
# riacho: pedras para atravessar
L["water"].append({"x": 12650, "y": 520, "w": 420, "h": 160})
S.append({"t": "dirt", "x": 12650, "y": 680, "w": 420, "h": 460})
for sx in [12730, 12880]:
    S.append({"t": "stone", "x": sx, "y": 470, "w": 60, "h": 60})
coins_arc(12660, 13060, 420, 80, 7)
ground(13070, 14000)
L["enemies"].append({"k": "crow", "x": 13300, "y": 220, "cy": 220, "r": [13100, 13500]})
# O MOINHO: as tábuas nas pontas das pás só giram depois das velas novas
MILL_X, MILL_HUB = 13620, 113
L["movers"].append({"k": "wheel", "x": MILL_X, "y": MILL_HUB, "r": 300, "n": 4, "w": 96, "spd": .0075,
                    "a0": math.pi / 4, "lock": "mill1", "tower": 300, "gy": GY})
L["locks"].append({"x": MILL_X - 40, "y": 380, "w": 80, "h": 120, "id": "mill1", "kind": "mill", "short": "a porta do moinho",
                   "need": "vela", "parts": ["lona", "corda"],
                   "where": {"lona": "dentro do celeiro do vale (entre abaixado pela porta baixa)",
                             "corda": "na galeria de cima da mina (suba pelo elevador)"},
                   "pre": "As velas do moinho estão rasgadas: o vento passa direto.",
                   "place": "Vá até a porta do moinho e toque em ✦ USAR.",
                   "use": "Toque em ✦ USAR na porta do moinho para pôr a vela nova.",
                   "msg": "Vela nova! O vento pegou e as pás começaram a girar. Suba numa tábua e vá lá para cima!"})
L["comics"].append({"id": "moinho", "x": 13200})
hint(13250, 13650, "As tábuas presas nas pás do moinho só giram se ele tiver velas. Junte a lona com a corda na mochila.")
check(13300)
coins_arc(MILL_X - 300, MILL_X + 300, 120, 0, 2)
for k in range(10):
    a = math.pi / 2 + k * 2 * math.pi / 10
    L["coins"].append([int(MILL_X + math.cos(a) * 300), int(MILL_HUB + math.sin(a) * 300 - 6)])
# o alto do barranco (só se chega pelas pás)
PY = -150
S.append({"t": "ground", "x": 14000, "y": PY, "w": 470, "h": 650})
S.append({"t": "ground", "x": 14470, "y": PY + 20, "w": 70, "h": 630})       # o vão da placa: o caixote encaixa nele
S.append({"t": "ground", "x": 14540, "y": PY, "w": 160, "h": 650})
hint(13960, 14200, "Pule da tábua para o alto do barranco quando ela passar perto!", yl=-100)
check(14100, PY)
# quebra-cabeça: o caixote na placa abre a cancela
L["crates"].append({"t": "push", "x": 14220, "y": PY - 60, "w": 60, "h": 60})
L["plates"].append({"x": 14470, "y": PY + 20, "w": 70, "gate": "gv1"})
S.append({"t": "pgate", "id": "gv1", "x": 14630, "y": -700, "w": 22, "h": 550})
hint(14150, 14450, "Uma cancela fechada... e uma placa no chão. Empurre o caixote até a placa para segurar a cancela aberta.", yl=-100)
coins_line(14120, 14420, PY - 30, 50)
L["enemies"].append({"k": "frog", "x": 14560, "y": PY, "r": [14480, 14620]})
L["enemies"].append({"k": "fly", "x": 14350, "y": -300, "r": [14150, 14600], "cy": -300})
check(14670, PY)
# o lago do moinho: fundo, com uma laje de pedra por cima (só passa mergulhando)
LK0, LK1 = 14700, 16000
L["water"].append({"x": LK0, "y": PY + 20, "w": LK1 - LK0, "h": 600})
L["caves"].append({"x": LK0, "y": PY + 20, "w": LK1 - LK0, "h": 600, "wet": 1})   # fundo de terra atrás da água
S.append({"t": "dirt", "x": LK0, "y": PY + 620, "w": LK1 - LK0, "h": 60})
S.append({"t": "dirt", "x": LK0 - 20, "y": PY + 140, "w": 20, "h": 480})
S.append({"t": "rockw", "x": 14960, "y": -420, "w": 900, "h": 310})       # laje sobre a água
S.append({"t": "dirt", "x": 14720, "y": 300, "w": 190, "h": 20})          # prateleira do equipamento
L["gear"] = [{"id": "capacete", "x": 14770, "y": 292}, {"id": "arpao", "x": 14860, "y": 292}]
L["vents"] = [{"x": 14760, "y": 470}]
hint(14600, 14720, "Lago fundo! Lá embaixo, na prateleira de pedra, o velho equipamento de mergulho do moinheiro.", yl=-120)
L["fish"] = {"x0": 15000, "x1": 15880, "y0": -60, "y1": 460, "trig": 15060, "hp": 4, "skin": "frog"}
L["currents"] = [{"x": 15890, "w": 110, "y0": PY + 20, "y1": 470}]
L["specials"].append({"x": 15440, "y": 420, "c": "verde"})
coins_arc(14760, 14950, 180, 60, 5)
# a margem de lá
S.append({"t": "ground", "x": LK1, "y": PY, "w": 16820 - LK1, "h": 650})
L["drawings"].append({"x": 16120, "y": PY - 50, "txt": "Um desenho da Isis: o moinho girando, com o papai e ela de mãos dadas."})
coins_line(16050, 16700, PY - 30, 60)
L["enemies"].append({"k": "crow", "x": 15300, "y": -560, "cy": -560, "r": [14900, 15700]})
L["enemies"].append({"k": "frog", "x": 16480, "y": PY, "r": [16380, 16600]})
L["enemies"].append({"k": "fly", "x": 16550, "y": -320, "r": [16350, 16750], "cy": -320})
check(16300, -150, 2)

# ======================================================================
#  C · TELHADOS DA VILA  (16800 .. 27000)
# ======================================================================
L["sections"].append({"x": 16800, "song": "noite", "bg": "vila", "gt": "vila", "night": 1, "dark": .35, "per": 2,
                      "tint": "rgba(20,28,70,.26)", "leaves": 8, "flock": "bats"})
L["comics"].append({"id": "telhados", "x": 16700})

# casas: (largura e altura da pintura, caminho do telhado [x0, x1, topo], abas [[x0, x1, topo]], chaminé)
HOUSE = [
    {"w": 421, "h": 515, "walk": [40, 380, 58], "sides": [[10, 40, 150], [380, 410, 150]], "chim": [290, 345, 5]},
    {"w": 461, "h": 483, "walk": [70, 420, 58], "sides": [[20, 70, 125], [420, 452, 125]], "chim": [85, 150, 3]},
    {"w": 490, "h": 476, "walk": [50, 440, 55], "sides": [[5, 50, 170], [440, 485, 170]], "chim": [100, 165, 0]},
]
houses = []
L["watchmen"] = []
L["dogs"] = []
L["hotchims"] = []
L["tilefall"] = []
L["awnings"] = []
ROOF_H = 24     # o telhado é uma laje fina: a rua passa por baixo, na frente das casas


def house(x, v, sc, flip=False, smoke=False, hot=False):
    hv = HOUSE[v]
    w = hv["w"] * sc
    top = GY - hv["h"] * sc

    def fx(a):
        return x + (w - a * sc if flip else a * sc)
    S.append({"t": "house", "x": round(x), "y": GY, "w": round(w), "v": v, "flip": flip, "deco": 1})
    xa, xb = sorted([fx(hv["walk"][0]), fx(hv["walk"][1])])
    wt = top + hv["walk"][2] * sc
    S.append({"t": "roof", "x": round(xa), "y": round(wt), "w": round(xb - xa), "h": ROOF_H, "walk": 1})
    for sd in hv["sides"]:
        a, b = sorted([fx(sd[0]), fx(sd[1])])
        st = top + sd[2] * sc
        S.append({"t": "roof", "x": round(a), "y": round(st), "w": round(b - a), "h": ROOF_H, "oneway": 1})   # beiral: dá para pular de baixo
    ca, cb = sorted([fx(hv["chim"][0]), fx(hv["chim"][1])])
    ct = top + hv["chim"][2] * sc
    if hot:
        ct -= 40          # chaminé quente: mais alta (pulo duplo) e queima quem pisa em cima
    S.append({"t": "roof", "x": round(ca), "y": round(ct), "w": round(cb - ca), "h": round(wt - ct), "chim": 1, "hot": 1 if hot else 0})
    if hot:
        L["hotchims"].append({"x": round(ca), "w": round(cb - ca), "y": round(ct), "h": round(wt - ct), "per": 210, "ph": int(x) % 210})
    if smoke or hot:
        L["traps"].append({"k": "wind", "smoke": 1, "x": round(ca) - 10, "y": round(ct) - 430, "w": round(cb - ca) + 20,
                           "h": 430, "pow": 1.0})
    info = {"x": x, "w": w, "wx0": xa, "wx1": xb, "wt": wt, "st": top + hv["sides"][0][2] * sc,
            "edge0": min(fx(hv["sides"][0][0]), fx(hv["sides"][1][1])),
            "edge1": max(fx(hv["sides"][0][0]), fx(hv["sides"][1][1])), "ch": (ca, cb, ct), "hot": hot}
    houses.append(info)
    return info


# (vão antes, variante, escala, espelhada, fumaça, chaminé quente)
plan = [
    (40, 1, .62, False, False, False),    # 0 o primeiro telhado
    (120, 0, .68, False, True, False),    # 1 fumaça para planar
    (300, 2, .60, True, False, False),    # 2 depois de um vão largo (plane na fumaça)
    (130, 1, .70, True, False, True),     # 3 chaminé quente no meio do caminho
    (300, 0, .48, False, False, False),   # 4 (telhas soltas no vão antes dela) — bem baixa
    (150, 2, 1.10, False, False, False),  # 5 o sobrado: alto demais para o pulo duplo, suba pelo toldo
    (120, 1, .78, False, False, False),   # 6 telhas soltas no meio do telhado
    (390, 0, .66, False, False, False),   # 7 varal sobre o esgoto
    (130, 2, .70, True, False, True),     # 8 chaminé quente com labaredas
    (140, 1, .62, False, True, False),    # 9
    (280, 0, .68, True, False, False),    # 10 telhas soltas no vão
    (120, 2, .62, False, False, False),   # 11 a última
]
x = 16940
for gap, v, sc, fl, sm, hot in plan:
    x += gap
    h = house(x, v, sc, fl, sm, hot)
    x += h["w"]
VILLAGE_END = x
# o quintal do vigia-chefe: arena do Brutus, o cão do Vargas
PZ0 = round(VILLAGE_END + 80)
PZ1 = PZ0 + 1000
gx = round(PZ1 + 460)
S.append({"t": "ground", "x": 16860, "y": GY, "w": gx + 22 - 16860, "h": 140, "street": 1})    # a rua (pedras)
# a beira do barranco desce um degrau até o primeiro telhado
S.append({"t": "stone", "x": 16820, "y": -10, "w": 120, "h": 510})
hint(16820, 17300, "Vigias e cães de guarda andam pela rua. Fique lá em cima: de telhado em telhado!", yl=100)
check(16880, -10)


def gapx(i):
    """vão entre a casa i e a próxima (x0, x1) no nível da rua"""
    a, b = houses[i], houses[i + 1]
    return a["x"] + a["w"], b["x"]


# lápis em cima dos telhados e arcos sobre os vãos
for i, h in enumerate(houses):
    coins_line(h["wx0"] + 20, h["wx1"] - 20, h["wt"] - 30, 52)
    if i + 1 < len(houses):
        n = houses[i + 1]
        coins_arc(h["wx1"] - 10, n["wx0"] + 10, min(h["wt"], n["wt"]) - 40, 70, 5)

# escadas nas paredes (quem cair na rua volta por elas)
for i in [1, 4, 7, 9, 11]:
    h = houses[i]
    L["climb"].append({"x": round(h["edge0"] - 30), "y": round(h["st"]), "w": 30, "h": round(GY - h["st"]), "kind": "ladder"})

# telhas soltas nos vãos 3→4 e 10→11 (pise e corra: elas despencam)
for i in [3, 10]:
    a, b = houses[i], houses[i + 1]
    y = round(a["wt"])
    x0 = a["wx1"]
    span = b["wx0"] - x0
    n = 3
    for k in range(n):
        S.append({"t": "plat", "x": round(x0 + 6 + k * (span - 12) / n), "y": y, "w": round((span - 12) / n - 4), "crumble": 1, "tile": 1})
hint(round(houses[3]["wx1"] - 120), round(houses[3]["wx1"] + 60), "Telhas soltas! Elas despencam logo depois que você pisa: não pare.", yl=-150)

# toldo: da casa 4 (baixa) para a 5 (alta)
h4, h5 = houses[4], houses[5]
L["awnings"].append({"x": round(h5["x"] - 92), "y": round(h4["wt"] + 34), "w": 100, "pow": 17, "wall": "right"})
hint(round(h4["wx0"]), round(h5["wx0"]), "A casa ao lado é alta demais: pule no toldo de pano e ele joga você para cima!", yl=-150)

# telhas soltas no meio do telhado da casa 6: pisou, despencou (pule por cima delas)
h6 = houses[6]
walk6 = [o for o in S if o["t"] == "roof" and o.get("walk") and abs(o["x"] - h6["wx0"]) < 2][0]
a6 = round(h6["wx0"] + (h6["wx1"] - h6["wx0"]) * .45)
b6 = a6 + 88
S.remove(walk6)
S.append({"t": "roof", "x": walk6["x"], "y": walk6["y"], "w": a6 - walk6["x"], "h": ROOF_H, "walk": 1})
S.append({"t": "roof", "x": b6, "y": walk6["y"], "w": walk6["x"] + walk6["w"] - b6, "h": ROOF_H, "walk": 1})
for k in range(2):
    S.append({"t": "plat", "x": a6 + k * 44, "y": walk6["y"], "w": 44, "crumble": 1, "tile": 1, "roofhole": 1})
h6["loose"] = (a6, b6)
hint(round(h6["wx0"] - 40), round(a6), "Telhas soltas no meio do telhado! Se pisar, elas despencam e você cai na rua. Pule por cima.", yl=-150)

# varal sobre o esgoto entre as casas 7 e 8
a, b = houses[7], houses[8]
L["bars"].append({"x0": round(a["wx1"] - 30), "x1": round(b["wx0"] + 30), "y": round(min(a["wt"], b["wt"]) + 30), "clothes": 1})
x0, x1 = gapx(7)
L["swamp"].append({"x": round(x0 + 20), "y": 530, "w": round(x1 - x0 - 40), "h": 110, "fumes": 1, "pit": 1})
S.append({"t": "dirt", "x": round(x0 + 20), "y": 560, "w": round(x1 - x0 - 40), "h": 580, "deco": 1})
hint(round(a["wx1"] - 160), round(a["wx1"]), "Esgoto lá embaixo! Pule no varal e ande pendurado; PULAR dá impulso para subir.", yl=-150)
hint(round(houses[3]["wx0"]), round(houses[3]["ch"][0] + 10), "Chaminé quente: não pise nela! Pule por cima (pulo duplo) — a fumaça ajuda a planar.", yl=-150)

# vigias e cães na rua
L["watchmen"].append({"x0": round(houses[1]["x"]), "x1": round(houses[3]["x"] + houses[3]["w"]), "spd": 1.1})
L["watchmen"].append({"x0": round(houses[5]["x"]), "x1": round(houses[7]["x"] + houses[7]["w"]), "spd": 1.2})
L["watchmen"].append({"x0": round(houses[9]["x"]), "x1": round(houses[11]["x"] - 20), "spd": 1.0})
gx3a, gx3b = houses[3]["x"] + houses[3]["w"], houses[5]["x"] + 40
L["dogs"].append({"x": round((gx3a + gx3b) / 2), "r": [round(gx3a - 40), round(gx3b + 200)]})
L["dogs"].append({"x": round(houses[8]["x"] + houses[8]["w"] / 2), "r": [round(houses[8]["x"]), round(houses[9]["x"] + 200)]})


def hpos(i, u=.5):
    h = houses[i]
    return h["wx0"] + (h["wx1"] - h["wx0"]) * u, h["wt"]


# objetos e pistas nos telhados
x, y = hpos(2)
L["items"].append({"x": round(x), "y": round(y) - 24, "id": "chave_a"})
x, y = hpos(5, .65)
L["clues"].append({"x": round(x), "y": round(y) - 30, "id": 9})
x, y = hpos(1, .7)
L["specials"].append({"x": round(x), "y": round(y) - 170, "c": "azul"})       # em cima da fumaça
x, y = hpos(9, .4)
L["items"].append({"x": round(x), "y": round(y) - 24, "id": "chave_b"})
x, y = hpos(11, .5)
L["clues"].append({"x": round(x), "y": round(y) - 30, "id": 10})
x, y = hpos(6, .85)
L["drawings"].append({"x": round(x), "y": round(y) - 36, "txt": "Um desenho da Isis: a vila de noite, com o papai pulando nos telhados."})
for i in [2, 9]:
    x, y = hpos(i)
    L["enemies"].append({"k": "crow", "x": round(x), "y": round(y) - 160, "cy": round(y) - 160, "r": [round(x) - 300, round(x) + 300]})
for i, u in [(2, .2), (6, .93), (9, .8)]:
    x, y = hpos(i, u)
    check(round(x), round(y))

# fim dos telhados: o quintal do vigia-chefe, guardado pelo Brutus (o cão do Vargas)
check(PZ0 + 60, GY)
L["boss"] = {"x0": PZ0, "x1": PZ1, "trig": PZ0 + 160, "spawn": PZ1 - 220, "hp": 3, "item": [round((PZ0 + PZ1) / 2), 470],
             "skin": "dog", "open": "plazaR"}
S.append({"t": "wall", "x": PZ1, "y": 250, "w": 26, "h": 250, "id": "plazaR"})
for bx in [PZ0 + 230, PZ1 - 370]:
    plat(bx, 400, 140, trestle=1)                                       # bancas da feira (para fugir da investida)
hint(PZ0 - 40, PZ0 + 160, "O quintal do vigia-chefe... e o cachorro dele. Suba nas bancas quando ele vier e faça ele bater no portão!")
coins_line(PZ0 + 240, PZ0 + 360, 370, 40)
coins_line(PZ1 - 360, PZ1 - 240, 370, 40)
# fim da vila: a rua continua até a porteira da mina (chave) na boca da mina
check(round(PZ1 + 140), GY, 3)
S.append({"t": "portal", "x": gx - 90, "y": GY, "w": 260, "tun": 560, "deco": 1})   # túnel até as galerias
S.append({"t": "pgate", "id": "vgate", "x": gx, "y": -700, "w": 22, "h": 1200, "crank": 1})
L["locks"].append({"x": gx - 60, "y": 380, "w": 80, "h": 120, "id": "vgate", "kind": "gate", "gate": "vgate", "short": "a porteira da mina",
                   "need": "chave", "parts": ["chave_a", "chave_b"],
                   "where": {"chave_a": "num telhado no começo da vila", "chave_b": "num telhado depois do esgoto"},
                   "pre": "A porteira da mina está trancada.",
                   "place": "Vá até a porteira da mina e toque em ✦ USAR.",
                   "use": "Toque em ✦ USAR na porteira para destrancar.",
                   "msg": "A chave girou! A porteira da mina está subindo..."})
hint(round(gx - 300), round(gx + 10), "A porteira da mina: junte as duas metades da chave na mochila.")
coins_line(PZ1 + 40, gx - 100, 470)

# ======================================================================
#  D · PROFUNDEZAS E O CARRINHO
# ======================================================================
D0 = round(gx + 40)
L["sections"].append({"x": D0 + 420, "song": "tunel", "bg": "mina", "gt": "mina", "dark": .6, "night": 1, "per": 3,
                      "tint": "rgba(60,35,10,.2)"})
L["darkZones"].append({"x": D0 + 200, "w": 7600, "dark": .85})
ground(round(gx + 22), D0 + 2300)
rock(D0, D0 + 760, -620, 120, True)
rock(D0 + 760, D0 + 1960, -620, -120, True)                     # a caverna alta do Morcego-Rei
rock(D0 + 1960, D0 + 4800, -620, 120, True)
L["oil"].append([D0 + 200, 468])
L["clues"].append({"x": D0 + 600, "y": 470, "id": 11})
check(D0 + 150)
# a caverna do Morcego-Rei: ele mergulha onde a sombra marca; errou, as garras prendem: picareta!
L["hawk"] = {"x0": D0 + 820, "x1": D0 + 1900, "y": GY, "trig": D0 + 960, "hp": 4, "skin": "bat"}
check(D0 + 760)
hint(D0 + 640, D0 + 880, "Uma caverna enorme... algo grande dorme pendurado lá no alto.")
L["specials"].append({"x": D0 + 1360, "y": 360, "c": "roxo"})
plat(D0 + 1300, 400, 120, trestle=1)
coins_line(D0 + 80, D0 + 700, 470)
coins_line(D0 + 900, D0 + 1850, 470, 60)
CART_X = D0 + 2100
L["sled"] = {"x": CART_X, "x1": CART_X + 1500, "y": GY, "tx0": 60000, "len": 7000, "skin": "cart", "vargas": 1,
             "endMsg": "O carrinho bateu no fim dos trilhos. O Vargas sumiu por uma porta de ferro...",
             "pts": [[0, 300], [400, 300], [900, 380], [1300, 400], [1900, 470], [2300, 490], [2900, 560], [3300, 580],
                     [3900, 640], [4300, 660], [4900, 720], [5300, 740], [5900, 800], [6400, 810], [7000, 815]],
             "obs": [{"k": "rock", "u": 900}, {"k": "branch", "u": 1800}, {"k": "crack", "u": 2700, "w": 90},
                     {"k": "log", "u": 3600}, {"k": "branch", "u": 4500}, {"k": "crack", "u": 5400, "w": 100},
                     {"k": "rock", "u": 6200}]}
hint(CART_X - 300, CART_X + 60, "Um carrinho de mina! Chegue nele para subir e ir atrás do Vargas.")
check(CART_X - 120)
# depois do carrinho: a porta do cofre
E0 = CART_X + 1500
rock(CART_X + 200, E0 - 200, -620, 500)          # rocha: até a porta do cofre, só pelos trilhos
ground(E0 - 200, E0 + 900)
rock(E0 - 200, E0 + 900, -620, 100, True)
check(E0 + 60)
L["clues"].append({"x": E0 + 400, "y": 470, "id": 12})
coins_line(E0 + 100, E0 + 600, 470)
L["door"] = {"x": E0 + 700, "y": 410, "kind": "vault"}
L["rails"] = [E0 - 200, E0 + 900]
hint(E0, E0 + 600, "A porta de ferro do Vargas... Pegue a pista e vá até a porta.")

# ======================================================================
#  E · A FUGA DA ISIS  (do outro lado da porta de ferro: joga-se com a Isis)
#  A Isis é pequena (cabe nos buracos), pula mais baixo e não tem pulo duplo nem planar.
#  Quarto de pedra → depósito (lampião do Vargas, caixote para empurrar) → poço (telhas, tábua
#  que vai e vem, corda) → túnel baixo → prateleiras e passarela → saída... e o Vargas.
# ======================================================================
IX = E0 + 2300
rock(E0 + 900, IX - 140, -620, 640)                   # rocha maciça entre o cofre e o esconderijo
L["sections"].append({"x": IX - 140, "song": "tunel", "bg": "esconderijo", "gt": "mina", "dark": .5, "night": 1,
                      "per": 4, "map": "isis", "tint": "rgba(60,35,10,.16)"})
L["darkZones"].append({"x": IX - 140, "w": 7800, "dark": .72})
L["isisPart"] = {"x0": IX - 140, "spawn": [IX + 170, GY]}
L.setdefault("shafts", [])
L["watchmen"] = L.get("watchmen", [])
L["hides"] = []
L["drops"] = []
rock(IX - 140, IX + 7780, -620, 130, True)


def ihide(x, w, k="crate", h=48):
    L["hides"].append({"x": IX + x, "w": w, "k": k, "h": h})


def idrop(x, c, msg):
    L["drops"].append({"x": IX + x, "c": c, "msg": msg})


def brick(x0, x1, y0, y1):
    S.append({"t": "brickw", "x": IX + x0, "y": y0, "w": x1 - x0, "h": y1 - y0})


# E1 · o quarto de pedra: desenhos de giz da Isis e uma fresta embaixo da parede
ground(IX - 140, IX + 2150)
brick(-140, 40, 130, GY)
for x, k in [(90, "papai"), (170, "coracao"), (250, "sol"), (330, "estrela"), (400, "flor")]:
    L["chalk"].append({"x": IX + x, "y": 400 if k != "sol" else 360, "k": k, "d": 1})
brick(480, 560, 130, GY - 30)                         # 30 px: a Isis passa em pé, um adulto não
hint(IX + 200, IX + 480, "Uma fresta embaixo da parede! A Isis é pequena: ela cabe. Vá para a direita.", yl=200)
idrop(610, "#e04a3a", "A Isis deixou cair um lápis vermelho: o papai vai achar a trilha.")
check(IX + 650)
coins_line(IX + 700, IX + 900, 470)

# E2 · o depósito: o Vargas faz a ronda com o lampião; caixote para empurrar até a parede alta
L["watchmen"].append({"x0": IX + 980, "x1": IX + 1500, "spd": .9, "any": 1, "bribed": 1})
ihide(760, 66)
ihide(1080, 46, "barrel", 54)
ihide(1330, 70)
hint(IX + 700, IX + 980, "Um vigia da vila aqui embaixo! O Vargas pagou os vigias com o ouro roubado. Quando a luz vier, segure ↓ atrás de um caixote ou barril: escondida, ele não vê.", yl=200)
L["crates"].append({"t": "push", "x": IX + 1640, "y": GY - 56, "w": 56, "h": 56})
S.append({"t": "wall", "x": IX + 1820, "y": GY - 84, "w": 130, "h": 84})
hint(IX + 1560, IX + 1820, "Alto demais para a Isis! Empurre o caixote até a parede e suba nele.", yl=200)
coins_line(IX + 1835, IX + 1935, GY - 114, 34)
idrop(2010, "#e8a030", "Um lápis laranja no chão. A Isis está deixando uma trilha.")

# o primeiro poço: telhas de madeira podre, cada uma numa altura
L["shafts"].append([IX + 2150, IX + 2560, GY])
for x, y in [(2180, 470), (2300, 445), (2420, 470)]:
    S.append({"t": "plat", "x": IX + x, "y": y, "w": 72, "crumble": 1})
coins_arc(IX + 2170, IX + 2540, 420, 40, 6)
hint(IX + 2060, IX + 2150, "Tábuas podres! Elas despencam logo depois que você pisa: pule de uma para a outra sem parar.", yl=200)
ground(IX + 2560, IX + 2800)
check(IX + 2620)

# E3 · o poço grande: tábua que vai e vem e uma corda para atravessar pendurada
L["shafts"].append([IX + 2800, IX + 3350, GY])
L["movers"].append({"k": "path", "x0": IX + 2815, "x1": IX + 3250, "y0": 470, "y1": 470, "w": 90, "per": 380})
hint(IX + 2700, IX + 2800, "Espere a tábua chegar e pule nela.", yl=200)
ground(IX + 3350, IX + 3500)
L["shafts"].append([IX + 3500, IX + 3900, GY])
L["bars"].append({"x0": IX + 3470, "x1": IX + 3930, "y": 432})
hint(IX + 3360, IX + 3500, "Uma corda esticada: pule nela e vá pendurada até o outro lado.", yl=200)
coins_line(IX + 3540, IX + 3860, 400, 40)
ground(IX + 3900, IX + 7780)
idrop(3960, "#3a7ad8", "Mais um lápis no chão, o azul. Siga a trilha, papai!")
check(IX + 4020)

# E4 · o túnel baixo: só engatinhando (↓)
brick(4300, 4780, 130, GY - 24)
hint(IX + 4180, IX + 4320, "Um túnel bem baixinho: segure ↓ e passe engatinhando.", yl=200)
coins_line(IX + 4340, IX + 4740, 485, 50)

# E5 · prateleiras e a passarela: lá em cima o lampião não alcança
L["watchmen"].append({"x0": IX + 5330, "x1": IX + 5900, "spd": 1.0, "any": 1, "bribed": 1})
for x, y, w, kw in [(5000, 455, 100, {}), (5090, 410, 100, {}), (5180, 365, 290, {}), (5470, 365, 90, {"crumble": 1}),
                    (5560, 365, 240, {}), (5800, 260, 300, {}), (6100, 320, 90, {}), (6180, 380, 90, {}), (6260, 440, 90, {})]:
    d = {"t": "plat", "x": IX + x, "y": y, "w": w, "trestle": 1}
    d.update(kw)
    S.append(d)
L["climb"].append({"x": IX + 5770, "y": 260, "w": 30, "h": 105, "kind": "ladder"})
ihide(5420, 46, "barrel", 54)
ihide(5700, 66)
hint(IX + 4900, IX + 5100, "Suba nas prateleiras: lá em cima a luz do lampião não chega. Cuidado com a prateleira podre!", yl=200)
coins_line(IX + 5200, IX + 5440, 335, 40)
coins_line(IX + 5820, IX + 6080, 230, 40)
idrop(5950, "#3aa04a", "Lápis verde: ela deixou um em cada lugar por onde passou.")
check(IX + 6420)

# E6 · a saída... o último lampião e o Vargas
L["watchmen"].append({"x0": IX + 6760, "x1": IX + 7020, "spd": 1.2, "any": 1, "bribed": 1})
ihide(6600, 66)
ihide(6880, 46, "barrel", 54)
ihide(7080, 70)
hint(IX + 6450, IX + 6600, "O ar fresco da noite... a saída está perto! Mais um vigia subornado: esconda-se e espere a hora certa.", yl=200)
L["chalk"].append({"x": IX + 7230, "y": 420, "k": "seta", "d": 1})
coins_line(IX + 7160, IX + 7360, 470)
L["isisCatch"] = {"x": IX + 7390}
L["isisExit"] = {"x": IX + 7500}
brick(7700, 7780, 130, GY)
L["spanX"] = IX + 7780

# ----------------------------------------------------------------------
L["solids"] = [s for s in S if s]

# nenhum lápis dentro de pedra, parede ou telhado: sobe para cima do sólido (ou desce, se for teto)
def _fix_coin(c):
    for _ in range(12):
        moved = False
        for so in L["solids"]:
            if so.get("deco") or so["t"] in ("plat", "branch", "barrier", "pgate", "house"):
                continue
            if so["x"] - 14 <= c[0] <= so["x"] + so["w"] + 14 and so["y"] - 18 <= c[1] <= so["y"] + so.get("h", 0) + 8:
                if so.get("ceil"):
                    c[1] = int(so["y"] + so["h"] + 30)
                else:
                    c[1] = int(so["y"] - 30)
                moved = True
        if not moved:
            return
for c in L["coins"]:
    _fix_coin(c)
out = os.path.join(ROOT, "assets", "data", "level2.json")
json.dump(L, open(out, "w"), ensure_ascii=False, indent=1)
print("level2.json:", len(L["solids"]), "sólidos,", len(L["coins"]), "lápis, spanX", L["spanX"],
      "casas", len(houses), "vila até", round(VILLAGE_END))
