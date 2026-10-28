# Gera fases/guarulhos.json — fonte única da fase, lida pela versão HTML e pela versão Godot.
# Unidades em metros. x = sentido da corrida, y = altura, z = faixa (só importa na visão de trás).
import json, math, os

F = {
    "id": "guarulhos",
    "nome": "Guarulhos",
    "estado": "SP",
    "subtitulo": "Garoa, multidão e o trem entre terminais",
    "cia": {"nome": "LATAM", "cor": "#E8114B", "cor2": "#1B0088"},
    "tempo": 100,
    "fim": 582,
    "proxima": "Maringá",
    "secoes": [], "chao": [], "solidos": [], "perigos": [], "zonas": [],
    "molas": [], "plataformas": [], "milhas": [], "dicas": [], "decor": [],
    "zonas_tras": [], "mala_dourada": None,
}

S = F["secoes"].append
def chao(x0, x1, y=0.0): F["chao"].append({"x0": x0, "x1": x1, "y": y})
def solido(tipo, x, w, h, y=0.0, z=0.0, d=6.0, **k):
    o = {"tipo": tipo, "x": x, "w": w, "h": h, "y": y, "z": z, "d": d}; o.update(k); F["solidos"].append(o)
def perigo(tipo, x, w, y0, y1, z=0.0, d=6.0, **k):
    o = {"tipo": tipo, "x": x, "w": w, "y0": y0, "y1": y1, "z": z, "d": d}; o.update(k); F["perigos"].append(o)
def pessoa(x, vx=-1.3, z=0.0, ativa=22, cor=None):
    perigo("pessoa", x, 0.7, 0.0, 1.75, z=z, d=0.8, vx=vx, ativa=ativa, cor=cor)
def zona(tipo, x0, x1, **k):
    o = {"tipo": tipo, "x0": x0, "x1": x1}; o.update(k); F["zonas"].append(o)
def mola(x, y=0.0, forca=17.0): F["molas"].append({"x": x, "y": y, "forca": forca})
def plataforma(x0, x1, y, tipo="mezanino"): F["plataformas"].append({"x0": x0, "x1": x1, "y": y, "tipo": tipo})
def dica(x, texto): F["dicas"].append({"x": x, "texto": texto})
def decor(tipo, x, **k):
    o = {"tipo": tipo, "x": x}; o.update(k); F["decor"].append(o)
def m(x, y=0.9, z=0.0): F["milhas"].append([round(x, 2), round(y, 2), z])
def linha(x0, x1, y=0.9, passo=1.2, z=0.0):
    n = int((x1 - x0) / passo) + 1
    for i in range(n): m(x0 + i * passo, y, z)
def arco(xc, larg=5.0, base=0.9, alt=2.0, n=5, z=0.0):
    for i in range(n):
        t = i / (n - 1)
        m(xc - larg / 2 + larg * t, base + alt * math.sin(math.pi * t), z)

# ---------------- 1. Calçada (garoa) -----------------------------------------
S({"tipo": "calcada", "x0": -30, "x1": 42, "titulo": "Desembarque · garoa"})
chao(-30, 152)
dica(4, "Toque ou arraste ↑ para pular")
solido("mala", 14, 0.9, 0.75, cor="#c0392b")
arco(14, 4.5, 1.0, 1.9)
dica(22, "Arraste ↓ para rolar")
perigo("placa", 31, 1.6, 0.95, 2.7, texto="EMBARQUE")
linha(29, 33, 0.45, 1.0)
solido("mala", 38, 0.9, 0.75, cor="#2c3e50")
solido("mala", 39.1, 0.8, 0.6, cor="#16a085")
arco(38.5, 5, 1.0, 1.8)
decor("taxi", -20); decor("taxi", -8); decor("taxi", 6); decor("taxi", 20); decor("porta", 42)

# ---------------- 2. Check-in -----------------------------------------------
S({"tipo": "checkin", "x0": 42, "x1": 148, "titulo": "Check-in"})
dica(46, "Arraste → (ou toque 2x) para acelerar")
linha(46, 56, 0.9)
solido("fita", 60.8, 1.85, 0.95, cor="#1B0088")
arco(60.8, 4.5, 1.1, 1.8)
pessoa(70)
linha(66, 72, 0.9)
solido("balcao", 78, 3.2, 1.2, cor="#ecf0f1", texto="CHECK-IN")
linha(77, 80, 1.9, 1.0)
perigo("placa", 86, 1.8, 0.95, 2.7, texto="CHECK-IN 1-20")
linha(84, 88, 0.45, 1.0)
solido("carrinho", 92, 1.8, 1.1, cor="#7f8c8d")
solido("balcao", 98, 3.2, 1.2, cor="#ecf0f1", texto="CHECK-IN")
plataforma(101, 128, 3.5)                    # mezanino: rota de cima
linha(102, 127, 4.4, 1.25)
pessoa(108); pessoa(116, vx=-0.8)
linha(104, 114, 0.9, 1.5)
solido("mala", 112, 0.9, 0.75, cor="#8e44ad")
perigo("placa", 121, 1.8, 0.95, 2.7, texto="DESPACHO")
zona("esteira", 126, 140, boost=3.0)
linha(127, 139, 0.9, 1.1)
dica(138, "Segure ↑ no pulo para planar")
for x in [52, 72, 92, 112, 132]: decor("painel", x)
for x in [65, 85, 105, 125, 145]: decor("janela", x)

# ---------------- 3. Buraco: rota de cima x subsolo (bagagens) ---------------
S({"tipo": "subsolo", "x0": 148, "x1": 208, "titulo": "Esteiras de bagagem"})
# chão de cima com dois buracos
chao(161, 199); chao(204, 600)
# rota de cima (planando)
arco(156.5, 8, 1.6, 2.2, 7)
pessoa(172, vx=-1.0)
solido("carrinho", 180, 1.8, 1.1, cor="#7f8c8d")
arco(180, 4.5, 1.2, 1.9)
linha(184, 196, 0.9, 1.2)
arco(201.5, 5, 1.3, 1.8)
# subsolo
chao(146, 210, -5.0)
zona("esteira", 152, 176, boost=3.5, y=-5.0)
linha(153, 175, -4.1, 1.1)
solido("mala", 164, 1.0, 0.8, y=-5.0, cor="#d35400")
solido("mala", 171, 1.0, 0.8, y=-5.0, cor="#27ae60")
solido("carrinho", 184, 1.8, 1.1, y=-5.0, cor="#95a5a6")
arco(184, 4.5, -3.9, 1.7)
linha(188, 198, -4.1, 1.1)
mola(200.5, -5.0, 22.0)
dica(194, "Mola de bagagem!")

# ---------------- 4. Segurança ----------------------------------------------
S({"tipo": "seguranca", "x0": 208, "x1": 278, "titulo": "Raio-x e detectores"})
solido("fita", 212.8, 1.85, 0.95, cor="#1B0088")
arco(212.8, 4.5, 1.1, 1.8)
dica(219, "Role pelo detector de metal ↓")
decor("detector", 228); perigo("detector", 227.8, 0.6, 0.85, 2.3)
linha(225, 231, 0.45, 1.0)
solido("raiox", 236, 3.6, 1.05, cor="#bdc3c7", esteira=5.0)
linha(234.5, 237.5, 1.95, 1.0)
solido("bandeja", 242, 0.7, 0.35, cor="#7f8c8d")
solido("bandeja", 244.5, 0.7, 0.35, cor="#7f8c8d")
decor("detector", 250); perigo("detector", 249.8, 0.6, 0.85, 2.3)
linha(247, 253, 0.45, 1.0)
solido("raiox", 257, 3.6, 1.05, cor="#bdc3c7", esteira=5.0)
linha(255.5, 258.5, 1.95, 1.0)
dica(259, "Piso molhado: escorregue!")
zona("molhado", 262, 273)
perigo("placa", 268, 1.8, 0.95, 2.7, texto="PISO MOLHADO")
linha(262.5, 272.5, 0.45, 0.9)
decor("porta", 278)

# ---------------- 5. Trem entre terminais (visão de trás) --------------------
S({"tipo": "trem", "x0": 278, "x1": 404, "titulo": "Trem entre terminais"})
F["zonas_tras"].append({"x0": 282, "x1": 402})
L = 1.8  # distância entre faixas
dica(283, "Arraste ← → para trocar de faixa")
# barreiras baixas
for z in (-L, 0.0): solido("barreira", 300, 0.5, 0.8, z=z, d=1.5, cor="#f39c12")
linha(296, 304, 0.9, 1.2, z=L)
# vagão parado com rampa na faixa do meio
solido("vagao", 316, 10, 2.5, z=0.0, d=1.6, rampa=4.0, cor="#ecf0f1")
linha(312, 320, 3.3, 1.0, z=0.0)
solido("vagao", 318, 9, 2.5, z=-L, d=1.6, cor="#dfe6e9")
# trem vindo na faixa da direita
perigo("trem", 336, 9, 0.0, 2.5, z=L, d=1.6, vx=-7.0, ativa=45)
perigo("placa", 334, 0.5, 0.9, 2.6, z=-L, d=1.6, texto="PARE")
linha(330, 338, 0.9, 1.0, z=0.0)
for z in (0.0, L): solido("barreira", 348, 0.5, 0.8, z=z, d=1.5, cor="#f39c12")
linha(344, 352, 0.9, 1.0, z=-L)
solido("vagao", 362, 10, 2.5, z=-L, d=1.6, rampa=4.0, cor="#ecf0f1")
linha(359, 368, 3.3, 1.0, z=-L)
perigo("trem", 372, 9, 0.0, 2.5, z=0.0, d=1.6, vx=-7.0, ativa=45)
perigo("placa", 380, 0.5, 0.9, 2.6, z=L, d=1.6, texto="PARE")
linha(376, 384, 0.45, 1.0, z=L)
for z in (-L, L): solido("barreira", 392, 0.5, 0.8, z=z, d=1.5, cor="#f39c12")
linha(388, 398, 0.9, 1.0, z=0.0)

# ---------------- 6. Embarque -----------------------------------------------
S({"tipo": "embarque", "x0": 404, "x1": 546, "titulo": "Área de embarque"})
zona("esteira", 410, 432, boost=3.0)
linha(411, 431, 0.9, 1.1)
pessoa(424, vx=-0.6)
solido("banco", 444, 2.2, 0.6, cor="#34495e")
solido("banco", 451, 2.2, 0.6, cor="#34495e")
arco(447.5, 9, 1.2, 1.6, 7)
decor("pastel", 458)
perigo("placa", 462, 1.8, 0.95, 2.7, texto="PORTÕES 201-230")
linha(460, 464, 0.45, 1.0)
mola(470, 0.0, 17.0)
dica(466, "Mola: vá pelo alto")
plataforma(472, 502, 3.6)
linha(473, 490, 4.5, 1.3)
F["mala_dourada"] = [497.0, 4.6, 0.0]
solido("carrinho", 478, 1.8, 1.1, cor="#7f8c8d")
pessoa(486, vx=-1.4)
linha(480, 496, 0.9, 1.6)
solido("mala", 494, 0.9, 0.75, cor="#c0392b")
decor("freeshop", 432); decor("freeshop", 484)
decor("painel", 505, ultima=True)
pessoa(512); pessoa(520, vx=-0.9)
solido("banco", 528, 2.2, 0.6, cor="#34495e")
arco(528, 5, 1.0, 1.8)
linha(532, 544, 0.9, 1.2)
for x in [415, 440, 470, 500, 530]: decor("janela", x)

# ---------------- 7. Portão e ponte de embarque ------------------------------
S({"tipo": "finger", "x0": 546, "x1": 600, "titulo": "Portão 218 · última chamada"})
decor("portao", 547)
solido("mala", 556, 0.6, 0.55, cor="#2980b9")
perigo("placa", 563, 1.0, 1.0, 2.7, texto="CUIDADO")
solido("mala", 570, 0.6, 0.55, cor="#e67e22")
linha(551, 578, 0.9, 1.4)
decor("aviao", 585)

F["alvo_milhas"] = int(len(F["milhas"]) * 0.6)

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "data", "guarulhos.json")
with open(out, "w", encoding="utf-8") as f:
    json.dump(F, f, ensure_ascii=False, indent=1)
print("milhas:", len(F["milhas"]), "alvo:", F["alvo_milhas"], "solidos:", len(F["solidos"]), "perigos:", len(F["perigos"]))
