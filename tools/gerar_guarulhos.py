# Gera assets/data/guarulhos.json — a Fase 1 (Guarulhos).
# Unidades em metros. x = sentido da corrida, y = altura, z = faixa (só importa nos trechos de trás).
# A partir do terminal, as posições são escritas com OFF = 140 (o começo do terminal antigo era o metro 0).
import json, math, os

F = {
    "id": "guarulhos", "nome": "Guarulhos", "estado": "SP",
    "subtitulo": "Garoa, Marginal, multidão e o trem entre terminais",
    "cia": {"nome": "LATAM", "cor": "#E8114B", "cor2": "#1B0088"},
    "tempo": 118, "fim": 722, "proxima": "Maringá", "inicio": 2.0,
    "secoes": [], "chao": [], "solidos": [], "perigos": [], "zonas": [], "molas": [], "plataformas": [],
    "milhas": [], "dicas": [], "decor": [], "zonas_tras": [], "mala_dourada": None,
    "ataques": [], "perseguidores": [], "portas": [], "pocas": [], "cartao": [], "itens": [], "alcapoes": [],
    "guarda_entra": 110.0,
}
OFF = 0.0
BURACOS = []      # buracos no chão principal (y = 0)
SUB = []          # pisos de baixo: (x0, x1, y)

def X(x): return round(x + OFF, 2)
def secao(tipo, x0, x1, titulo): F["secoes"].append({"tipo": tipo, "x0": X(x0), "x1": X(x1), "titulo": titulo})
def buraco(x0, x1): BURACOS.append((X(x0), X(x1)))
def piso_baixo(x0, x1, y): SUB.append((X(x0), X(x1), y))
def solido(tipo, x, w, h, y=0.0, z=0.0, d=6.0, **k):
    o = {"tipo": tipo, "x": X(x), "w": w, "h": h, "y": y, "z": z, "d": d}; o.update(k); F["solidos"].append(o)
def perigo(tipo, x, w, y0, y1, z=0.0, d=6.0, **k):
    o = {"tipo": tipo, "x": X(x), "w": w, "y0": y0, "y1": y1, "z": z, "d": d}; o.update(k); F["perigos"].append(o)
def pessoa(x, vx=-1.3, z=0.0, ativa=22):
    perigo("pessoa", x, 0.7, 0.0, 1.75, z=z, d=0.8, vx=vx, ativa=ativa, var=int(x) % 2)
def mala_rolando(x, y, ativa=24):
    perigo("mala_rolando", x, 0.7, y, y + 0.75, d=6.0, vx=-4.0, ativa=ativa)
def zona(tipo, x0, x1, **k):
    o = {"tipo": tipo, "x0": X(x0), "x1": X(x1)}; o.update(k); F["zonas"].append(o)
def mola(x, y=0.0, forca=17.0): F["molas"].append({"x": X(x), "y": y, "forca": forca})
def plataforma(x0, x1, y): F["plataformas"].append({"x0": X(x0), "x1": X(x1), "y": y})
def dica(x, texto): F["dicas"].append({"x": X(x), "texto": texto})
def decor(tipo, x, **k):
    o = {"tipo": tipo, "x": X(x)}; o.update(k); F["decor"].append(o)
def ataque(x, tipo): F["ataques"].append({"x": X(x), "tipo": tipo})
def porta(x, aberta=2.2, fechada=0.7, fase=0.0): F["portas"].append({"x": X(x), "aberta": aberta, "fechada": fechada, "fase": fase})
def poca(x, z): F["pocas"].append({"x": X(x), "z": z})
def cartao(x, y, z=0.0): F["cartao"].append([X(x), y, z])
def item(tipo, x, y): F["itens"].append({"tipo": tipo, "x": X(x), "y": y})
def m(x, y=0.9, z=0.0): F["milhas"].append([X(x), round(y, 2), z])
def linha(x0, x1, y=0.9, passo=1.2, z=0.0):
    for i in range(int((x1 - x0) / passo) + 1): m(x0 + i * passo, y, z)
def arco(xc, larg=5.0, base=0.9, alt=2.0, n=5, z=0.0):
    for i in range(n):
        t = i / (n - 1); m(xc - larg / 2 + larg * t, base + alt * math.sin(math.pi * t), z)
def alcapao(x0, x1_baixo, y=-4.5):
    """Alçapão: buraco de 2,5 m em x0, caminho de baixo até x1_baixo e mola embaixo de outro buraco no fim."""
    buraco(x0, x0 + 2.5)
    piso_baixo(x0 - 1.0, x1_baixo + 8.0, y)
    buraco(x1_baixo - 3.0, x1_baixo)
    mola(x1_baixo - 1.5, y, 21.5)
    F["alcapoes"].append({"x0": X(x0), "x1": X(x0 + 2.5), "x2": X(x1_baixo - 3.0), "x3": X(x1_baixo), "y": y, "fim": X(x1_baixo)})

L = 1.8   # distância entre faixas

# ======================= 0. Marginal Tietê (abertura no táxi) =======================
secao("marginal", -12, 40, "Marginal Tietê · trânsito parado")
decor("taxi_parado", 0.6)
dica(5, "Toque ou arraste ↑ para pular")
solido("cone", 14, 0.55, 0.5)
arco(14, 4.0, 1.0, 1.8)
linha(18, 22, 0.9)
solido("cone", 26, 0.55, 0.5); solido("cone", 27.0, 0.55, 0.5)
arco(26.5, 4.5, 1.0, 1.9)
linha(31, 38, 0.9)

# ======================= 1. Estacionamento (carrinho de bagagem) =====================
secao("estacionamento", 40, 110, "Estacionamento · desce de carrinho!")
decor("carrinho_vazio", 47)
dica(43, "Pegue o carrinho de bagagem!")
zona("carrinho", 47, 104)
linha(50, 58, 0.9, 1.0)
solido("cone", 62, 0.55, 0.5)
arco(62, 5, 1.1, 2.0)
linha(66, 74, 0.9, 1.0)
solido("carrinho", 79, 1.8, 1.3)
arco(79, 6, 1.4, 2.2, 6)
solido("cone", 90, 0.55, 0.5); solido("cone", 91.0, 0.55, 0.5)
arco(90.5, 6, 1.1, 2.0, 6)
linha(95, 103, 0.9, 1.0)
cartao(85, 3.0)

# ======================= Terminal (posições antigas + 140) ===========================
OFF = 140.0

# ---------------- 2. Calçada (garoa) ---------------------------------------------
secao("calcada", -30, 42, "Desembarque · garoa")
dica(-29, "O guarda viu você! Corre!")
decor("vendedor", 1)
item("guarda_chuva", 7, 1.2)
dica(5, "Guarda-chuva: no pulo, segure para planar mais longe")
solido("mala", 14, 0.6, 0.9, cor="#c0392b")
arco(14, 4.5, 1.0, 2.0)
dica(22, "Arraste ↓ para rolar")
perigo("placa", 31, 1.6, 0.95, 2.7, texto="EMBARQUE")
linha(29, 33, 0.45, 1.0)
dica(35, "A porta abre e fecha: acelere (→) na hora certa!")
porta(42)
for x in (-20, -8, 20): decor("taxi", x)

# ---------------- 3. Check-in --------------------------------------------------
secao("checkin", 42, 148, "Check-in")
F["perseguidores"].append({"tipo": "atendente", "x": X(44), "texto": "A atendente pulou o balcão!"})
dica(45, "Fila: arraste ← → para trocar de faixa")
F["zonas_tras"].append({"x0": X(47), "x1": X(66)})
for zz in (-L, 0.0): solido("fita", 52, 0.3, 0.95, z=zz, d=1.5)
for zz in (0.0, L): solido("fita", 57.5, 0.3, 0.95, z=zz, d=1.5)
for zz in (-L, L): solido("fita", 63, 0.3, 0.95, z=zz, d=1.5)
linha(48, 53, 0.9, 1.0, z=L); linha(54.5, 59, 0.9, 1.0, z=-L); linha(60, 65, 0.9, 1.0, z=0.0)
pessoa(72)
linha(68, 74, 0.9)
ataque(70, "etiqueta")
solido("balcao", 78, 2.7, 1.5)
linha(77, 80, 2.4, 1.0)
perigo("placa", 86, 1.8, 0.95, 2.7, texto="CHECK-IN 1-20")
linha(84, 88, 0.45, 1.0)
solido("carrinho", 91.5, 1.8, 1.3)
dica(93, "Escada rolante: suba ao mezanino")
solido("escada", 98, 6.0, 3.5, rampa=6.0, esteira=3.0)
plataforma(101, 128, 3.5)
linha(102, 127, 4.4, 1.25)
ataque(104, "etiqueta")
ataque(112, "etiqueta")
cartao(126.5, 5.6)
zona("esteira", 126, 140, boost=3.0)
linha(131.5, 139, 0.9, 1.1)
alcapao(128.5, 145.5)
linha(129, 141, -3.6, 1.2)
cartao(136, -3.4)
dica(137, "Segure ↑ no pulo para planar")
for x in [52, 72, 92, 112, 132]: decor("painel", x)

# ---------------- 4. Buraco grande: rota de cima x subsolo (bagagens) -------------
secao("subsolo", 148, 208, "Esteiras de bagagem")
buraco(152, 161); buraco(199, 204)
arco(156.5, 8, 1.6, 2.2, 7)
pessoa(172, vx=-1.0)
solido("carrinho", 180, 1.8, 1.3)
arco(180, 4.5, 1.2, 1.9)
linha(184, 196, 0.9, 1.2)
arco(201.5, 5, 1.3, 1.8)
piso_baixo(146, 214, -5.0)
F["alcapoes"].append({"x0": X(152), "x1": X(161), "x2": X(199), "x3": X(204), "y": -5.0, "fim": X(204), "grande": True})
zona("esteira", 152, 176, boost=3.5, y=-5.0)
linha(153, 175, -4.1, 1.1)
solido("mala", 166, 0.6, 0.9, y=-5.0, cor="#d35400")
solido("mala", 173, 0.6, 0.9, y=-5.0, cor="#27ae60")
mala_rolando(182, -5.0)
solido("carrinho", 186, 1.8, 1.3, y=-5.0)
arco(186, 4.5, -3.9, 1.7)
mala_rolando(197, -5.0)
linha(189, 198, -4.1, 1.1)
mola(200.5, -5.0, 22.0)
dica(194, "Malas rolando! Pule!")

# ---------------- 5. Segurança ----------------------------------------------------
secao("seguranca", 208, 278, "Raio-x e detectores")
F["perseguidores"].append({"tipo": "cao", "x": X(209), "texto": "Cão farejador! Pule o bote"})
solido("fita", 212.8, 1.85, 0.95)
arco(212.8, 4.5, 1.1, 1.8)
ataque(211, "cao")
dica(219, "Role pelo detector de metal ↓")
decor("detector", 228); perigo("detector", 227.8, 0.6, 0.85, 2.3)
linha(225, 231, 0.45, 1.0)
solido("raiox", 236, 3.6, 0.45, esteira=5.0)
linha(234.5, 237.5, 1.3, 1.0)
dica(233, "Role na esteira do raio-x: bônus!")
alcapao(241.5, 249.0)
linha(241, 247, -3.6, 1.0)
cartao(244.5, -3.4)
decor("detector", 252.4); perigo("detector", 252.2, 0.6, 0.85, 2.3)
linha(251, 254, 0.45, 1.0)
solido("raiox", 257.5, 3.6, 0.45, esteira=5.0)
linha(256, 259, 1.3, 1.0)
ataque(232, "cao")
dica(260, "Piso molhado: escorregue!")
zona("molhado", 262, 273)
perigo("placa", 268, 1.8, 0.95, 2.7, texto="PISO MOLHADO")
linha(262.5, 272.5, 0.45, 0.9)
porta(278, 2.2, 0.7, 0.6)

# ---------------- 6. Trem entre terminais (visão de trás, temporal) ----------------
secao("trem", 278, 404, "Trem entre terminais · temporal")
F["zonas_tras"].append({"x0": X(282), "x1": X(402)})
dica(283, "Temporal! Poças fazem escorregar")
for zz in (-L, 0.0): solido("barreira", 300, 0.5, 0.8, z=zz, d=1.5)
linha(296, 304, 0.9, 1.2, z=L)
poca(295, L)
solido("vagao", 316, 10, 2.5, z=0.0, d=1.6, rampa=4.0)
linha(312, 320, 3.3, 1.0, z=0.0)
solido("vagao", 318, 9, 2.5, z=-L, d=1.6)
perigo("trem", 336, 9, 0.0, 2.5, z=L, d=1.6, vx=-7.0, ativa=45)
perigo("placa", 334, 0.5, 0.9, 2.6, z=-L, d=1.6, texto="PARE")
linha(330, 338, 0.9, 1.0, z=0.0)
poca(328, 0.0)
for zz in (0.0, L): solido("barreira", 348, 0.5, 0.8, z=zz, d=1.5)
linha(344, 352, 0.9, 1.0, z=-L)
solido("vagao", 362, 10, 2.5, z=-L, d=1.6, rampa=4.0)
linha(359, 368, 3.3, 1.0, z=-L)
cartao(366, 3.4, -L)
perigo("trem", 372, 9, 0.0, 2.5, z=0.0, d=1.6, vx=-7.0, ativa=45)
perigo("placa", 380, 0.5, 0.9, 2.6, z=L, d=1.6, texto="PARE")
linha(376, 384, 0.45, 1.0, z=L)
poca(386, 0.0)
for zz in (-L, L): solido("barreira", 392, 0.5, 0.8, z=zz, d=1.5)
linha(388, 398, 0.9, 1.0, z=0.0)

# ---------------- 7. Embarque -------------------------------------------------------
secao("embarque", 404, 546, "Área de embarque")
zona("esteira", 410, 432, boost=3.0)
linha(411, 431, 0.9, 1.1)
pessoa(424, vx=-0.6)
alcapao(434.0, 449.0)
linha(434.5, 444, -3.6, 1.1)
F["mala_dourada"] = [X(441.0), -3.7, 0.0]
solido("banco", 444, 2.2, 0.65)
solido("banco", 451.5, 2.2, 0.65)
arco(447.5, 9, 1.4, 1.8, 7)
decor("pastel", 458)
perigo("placa", 461, 1.8, 0.95, 2.7, texto="PORTÕES 201-230")
linha(459, 463, 0.45, 1.0)
dica(464, "Esta escada rolante desce: suba contra ela!")
solido("escada", 469, 6.0, 3.6, rampa=6.0, esteira=-3.5, contra=True)
plataforma(472, 502, 3.6)
linha(473, 500, 4.5, 1.3)
decor("freeshop", 432); decor("freeshop", 486)
decor("painel", 505, ultima=True)
F["perseguidores"].append({"tipo": "patio", "x": X(506), "texto": "Equipe de pátio chutando cones!"})
pessoa(512); pessoa(520, vx=-0.9)
solido("banco", 528, 2.2, 0.65)
arco(528, 5, 1.0, 1.8)
ataque(529, "cone")
linha(532, 544, 0.9, 1.2)

# ---------------- 8. Portão e ponte de embarque ---------------------------------------
secao("finger", 546, 600, "Portão 218 · última chamada")
decor("portao", 547)
ataque(541, "cone")
solido("mala", 556, 0.5, 0.7, cor="#2980b9")
perigo("placa", 563, 1.0, 1.0, 2.7, texto="CUIDADO")
cartao(568, 3.1)
solido("mala", 571, 0.5, 0.7, cor="#e67e22")
linha(551, 578, 0.9, 1.4)
decor("aviao", 585)

# ---------------- chão principal (y = 0) a partir dos buracos ---------------------------
x = -12.0
for (b0, b1) in sorted(BURACOS):
    F["chao"].append({"x0": x, "x1": b0, "y": 0.0}); x = b1
F["chao"].append({"x0": x, "x1": 760.0, "y": 0.0})
for (a, b, y) in SUB:
    F["chao"].append({"x0": a, "x1": b, "y": y})

F["alvo_milhas"] = int(len(F["milhas"]) * 0.6)
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "data", "guarulhos.json")
with open(out, "w", encoding="utf-8") as f:
    json.dump(F, f, ensure_ascii=False, indent=1)
print("milhas:", len(F["milhas"]), "alvo:", F["alvo_milhas"], "solidos:", len(F["solidos"]), "perigos:", len(F["perigos"]), "buracos:", len(BURACOS))
