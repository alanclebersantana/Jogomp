"""Monta as folhas do jogo a partir das artes do Gemini (art_src/gemini/*.jpg, fundo verde).
Gera assets/sprites/*.png, assets/bg/*.png e assets/sprites/arte.json (tamanhos em metros).
Escala: 132 px por metro em personagens e objetos."""
import json, os
from PIL import Image, ImageOps
from recortar import abrir_sem_verde, quadros, componentes, montar_folha, objeto

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
G = os.path.join(RAIZ, "art_src", "gemini")
SPR = os.path.join(RAIZ, "assets", "sprites")
BG = os.path.join(RAIZ, "assets", "bg")
A = 132
META = {}


def src(n):
    return abrir_sem_verde(os.path.join(G, n + ".jpg"))


def folha_personagem(nome, qs, altura_m, quadro=(300, 300), espelhar=False, ref=0, escala=None):
    if espelhar:
        qs = [ImageOps.mirror(q) for q in qs]
    pe = (quadro[0] // 2, quadro[1] - 8)
    esc = montar_folha(qs, os.path.join(SPR, nome + ".png"), quadro=quadro, pe=pe,
                       altura=None if escala else altura_m * A, escala=escala, ref=ref)
    META[nome] = {"tipo": "folha", "quadros": len(qs), "qw": quadro[0], "qh": quadro[1], "pe": list(pe), "pxm": A}
    return esc


def obj(nome, q, largura_m=None, altura_m=None, espelhar=False):
    if espelhar:
        q = ImageOps.mirror(q)
    m = objeto(q, os.path.join(SPR, nome + ".png"), largura_m, altura_m, A)
    m["tipo"] = "obj"
    META[nome] = m


def obj_folha(nome, qs, largura_m):
    """Vários quadros do mesmo objeto (mesma caixa)."""
    k = largura_m * A / max(q.width for q in qs)
    W = int(max(q.width for q in qs) * k) + 20
    H = int(max(q.height for q in qs) * k) + 20
    out = Image.new("RGBA", (W * len(qs), H), (0, 0, 0, 0))
    for i, q in enumerate(qs):
        q2 = q.resize((max(1, int(q.width * k)), max(1, int(q.height * k))), Image.LANCZOS)
        out.alpha_composite(q2, (i * W + (W - q2.width) // 2, H - 10 - q2.height))
    out.save(os.path.join(SPR, nome + ".png"))
    META[nome] = {"tipo": "obj", "w": W / A, "h": H / A, "pxm": A, "base": 10 / A, "quadros": len(qs)}


def fundo(nome, arquivo, alt_m, chao_frac=1.0):
    im = Image.open(os.path.join(G, arquivo + ".jpg")).convert("RGB")
    im.save(os.path.join(BG, nome + ".jpg"), quality=88)
    pxm = im.height / alt_m
    META[nome] = {"tipo": "bg", "w": im.width / pxm, "h": alt_m, "pxm": pxm, "chao": chao_frac}


if __name__ == "__main__":
    os.makedirs(SPR, exist_ok=True); os.makedirs(BG, exist_ok=True)
    # ---------------- mascote
    corre = quadros(src("mascote_corre"), linhas=2)[:6]
    esc = folha_personagem("m_corre", corre, 1.55)
    acoes = componentes(src("mascote_acoes"), dil=4, area_min=4000)
    # ordem do Gemini: sobe, cai, plana, dash, alegre | tropeça, tropeça2, joinha, bola, parado
    folha_personagem("m_acoes", [acoes[i] for i in (0, 1, 2, 3, 5, 7, 8, 9)], 1.55, quadro=(420, 320), escala=esc)
    META["m_acoes"]["poses"] = ["sobe", "cai", "plana", "dash", "tropeca", "vitoria", "bola", "parado"]
    costas = quadros(src("mascote_costas"), linhas=2)[:5]
    folha_personagem("m_costas", costas, 1.55, escala=esc)
    car = quadros(src("carrinho2"))
    folha_personagem("m_carrinho", car, 1.75, quadro=(360, 320))
    # ---------------- perseguidores e pessoas
    gq = componentes(src("guarda"), dil=1, area_min=4000)
    folha_personagem("guarda", gq[:5], 1.85)
    pq = componentes(src("perseguidores"), dil=1, area_min=4000)
    folha_personagem("atendente", pq[0:6], 1.72)
    folha_personagem("cao", pq[6:11], 0.95, quadro=(360, 220))
    folha_personagem("patio", pq[11:16], 1.8)
    it = componentes(src("itens_taxi"), dil=9)
    folha_personagem("vendedor", it[0:2], 1.75, quadro=(340, 300))
    obj_folha("guarda_chuva", [it[2], it[3]], 1.1)
    obj("cone", it[4], 0.6)
    obj("etiqueta", it[5], 0.55)
    obj("mala_dourada", it[6], 0.8)
    obj("milha", it[7], 0.72)
    obj("taxi", it[8], 4.4)
    obj("taxi_aberto", it[9], 4.4)
    if os.path.exists(os.path.join(G, "passageiros2.jpg")):
        pp = quadros(src("passageiros2"), linhas=2)
        print("passageiros", len(pp))
        folha_personagem("passageiro0", pp[0:5], 1.75, quadro=(320, 300), espelhar=True)
        folha_personagem("passageiro1", pp[5:10], 1.75, quadro=(320, 300), espelhar=True)
    # ---------------- obstáculos e peças
    ob = componentes(src("obstaculos"), dil=9)
    obj("mala", ob[0], 0.62)
    obj("fita", ob[1], 1.85)
    obj("carrinho", ob[2], 1.8)
    obj("balcao", ob[3], 3.2)
    obj("raiox", ob[4], 3.6)
    obj("bandeja", ob[5], 0.7)
    obj("detector", ob[6], 1.3)
    obj("banco", ob[8], 2.2)
    obj("cavalete", ob[9], 0.6)
    pe = componentes(src("pecas"), dil=9)
    obj("placa", pe[0], 2.0)
    obj("mola", pe[2], 1.4)
    obj("painel", pe[3], 4.2)
    obj("escada", pe[4], 6.0)
    obj("porta", pe[5], 3.2)
    obj("porta_aberta", pe[6], 3.2)
    obj("pastel", pe[7], 4.2)
    obj("freeshop", pe[8], 3.6)
    obj("portao", pe[9], 3.4)
    obj("monitor_raiox", pe[10], 1.6)
    # cartão de embarque: 4 pedaços (o 5º repete o 1º espelhado)
    cart = pe[11]
    w = cart.width
    cortes = [0, int(w * 0.25), int(w * 0.48), int(w * 0.63), w]
    pedacos = [cart.crop((cortes[i], 0, cortes[i + 1], cart.height)) for i in range(4)]
    pedacos = [p.crop(p.getbbox()) for p in pedacos]
    pedacos.append(ImageOps.mirror(pedacos[0]))
    obj_folha("cartao", pedacos, 0.55)
    tr = componentes(src("trem_frente"), dil=9)
    obj("trem_f", tr[0], 1.7)
    obj("vagao_f", tr[1], 1.7)
    obj("placa_pare", tr[2], 1.9)
    obj("barreira_f", tr[3], 1.6)
    obj("rampa_f", tr[4], 1.6)
    obj("poca", tr[6], 1.7)
    av = componentes(src("aviao_carrinho"), dil=9)
    obj("aviao", av[0], 22.0, espelhar=True)
    obj("aviao_decola", av[1], 22.0)
    mp = componentes(src("carrinho_mapa"), dil=9)
    obj("mapa", mp[-1], 6.0)
    # ---------------- fundos
    fundo("ceu_sp", "bg_sp", 14.0)
    fundo("parede_checkin", "bg_checkin", 8.6)
    fundo("parede_seguranca", "bg_seguranca", 8.6)
    fundo("parede_embarque", "bg_embarque", 8.6)
    fundo("parede_subsolo", "bg_subsolo", 5.4)
    fundo("parede_finger", "bg_finger", 3.6)
    fundo("marginal", "bg_marginal", 12.0)
    fundo("estacionamento", "bg_estacionamento", 9.0)
    im = Image.open(os.path.join(G, "bg_trem_frente.jpg")).convert("RGB")
    im.save(os.path.join(BG, "frente_trem.jpg"), quality=88)
    META["frente_trem"] = {"tipo": "bg", "w": im.width, "h": im.height, "pxm": 1, "fuga": [0.5, 0.565]}
    json.dump(META, open(os.path.join(SPR, "arte.json"), "w"), indent=1)
    print("ok", len(META))
