"""Gera as fases (assets/fases/<id>.txt). Cada letra da grade é um quadrado de 40 x 40.

Legenda:
  ' ' vazio            '#' piso/parede do tema   'M' metal   'C' concreto   'K' caixote
  'W' parede verde (o Milis sobe correndo)        '=' plataforma fina (atravessa por baixo)
  '>' '<' esteira rolante (a favor da seta)        '~' chão molhado (escorrega mais rápido)
  'S'/'s' início (correndo p/ direita/esquerda)  'T' totem de check-in   'G' portão de embarque
  'o' milha   '$' cartão dourado (10 milhas)     'A' asas de avião (libera o planar)
  'p'/'q' passageiro andando (p/ esq./dir.)  'P' passageiro parado
  'c'/'x' carrinho de bagagem desgovernado (p/ esq./dir.)
  'm'/'n' calha de malas no teto (as malas rolam p/ esq./dir.)
  'k' capanga (cambista)   'r' robô falsificado   'v' mala voadora
  'l' laser de chão (pule)   'j' laser de teto (não pule)   'L' laser que pisca (teto ao chão)
  'D' porta automática (do quadrado até o chão)    'F' ventilador (sobe ar; planando, leva para cima)
  '^' mola (balança de bagagem)   '?' dica (os textos 'dica=' na ordem da esquerda para a direita)

Uso: python3 tools/fases.py
"""
import math, os

AQUI = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.join(AQUI, "..", "assets", "fases")


class Grade:
    def __init__(s, w, h):
        s.w, s.h = w, h
        s.g = [[" "] * w for _ in range(h)]

    def put(s, x, y, ch):
        if 0 <= x < s.w and 0 <= y < s.h:
            s.g[y][x] = ch

    def ret(s, x0, y0, x1, y1, ch):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                s.put(x, y, ch)

    def chao(s, x0, x1, y, ch="#"):
        s.ret(x0, y, x1, s.h - 1, ch)

    def vazio(s, x0, y0, x1, y1):
        s.ret(x0, y0, x1, y1, " ")

    def buraco(s, x0, x1, y):
        s.vazio(x0, y, x1, s.h - 1)

    def linha(s, x0, x1, y, ch="o", passo=1):
        for x in range(x0, x1 + 1, passo):
            s.put(x, y, ch)

    def coluna(s, x, y0, y1, ch="o"):
        for y in range(y0, y1 + 1):
            s.put(x, y, ch)

    def arco(s, x0, x1, y_base, alt):
        """milhas num arco (como o caminho de um pulo)"""
        n = x1 - x0
        for i in range(n + 1):
            k = i / n if n else 0
            y = y_base - round(alt * 4 * k * (1 - k))
            s.put(x0 + i, y, "o")

    def salva(s, fid, meta, dicas):
        os.makedirs(DEST, exist_ok=True)
        with open(os.path.join(DEST, fid + ".txt"), "w", encoding="utf-8") as f:
            for k, v in meta.items():
                f.write("%s=%s\n" % (k, v))
            for d in dicas:
                f.write("dica=%s\n" % d)
            f.write("---\n")
            for row in s.g:
                f.write("".join(row).rstrip() + "\n")
        n = sum(row.count("o") for row in s.g) + 10 * sum(row.count("$") for row in s.g)
        print(fid, "%dx%d" % (s.w, s.h), "milhas:", n)


# ======================================================================
def fase_1_1():
    W, H, G = 250, 30, 24
    m = Grade(W, H)
    m.chao(0, W - 1, G)
    m.put(3, G - 1, "S")
    m.put(5, G - 1, "?")
    m.linha(7, 11, G - 1)
    # caixotes
    m.put(15, G - 1, "K")
    m.arco(13, 17, G - 2, 3)
    m.ret(21, G - 2, 21, G - 1, "K")
    m.arco(19, 23, G - 3, 3)
    # primeiro buraco
    m.buraco(27, 29, G)
    m.arco(26, 30, G - 2, 3)
    m.linha(32, 35, G - 1)
    # passageiros e esteira
    m.put(37, G - 1, "?")
    m.put(46, G - 1, "p")
    m.linha(44, 47, G - 4)
    m.put(49, G - 1, "?")
    m.linha(50, 58, G, ">")
    m.linha(51, 57, G - 1)
    m.put(61, G - 1, "T")
    # sala com a parede: o Milis vai e volta até pular na plataforma
    m.buraco(64, 85, G)
    m.chao(64, 85, G + 3)
    m.put(65, G + 2, "?")
    m.linha(66, 70, G + 2)
    m.linha(71, 83, G, "=")
    m.linha(73, 81, G - 1)
    m.chao(86, 120, G - 2)
    m.linha(88, 93, G - 3)
    # mezanino com o carrinho
    m.put(95, G - 3, "?")
    m.put(110, G - 3, "c")
    m.arco(100, 106, G - 4, 3)
    m.linha(112, 118, G - 3)
    # chão molhado e buraco
    m.linha(125, 133, G, "~")
    m.linha(126, 132, G - 1)
    m.buraco(135, 138, G)
    m.arco(134, 139, G - 2, 4)
    m.put(142, G - 1, "T")
    m.put(150, G - 1, "p")
    m.put(155, G - 1, "q")
    m.linha(148, 157, G - 5, "o", 2)
    # pulo duplo
    m.put(161, G - 1, "?")
    m.ret(168, G - 5, 170, G - 1, "#")
    m.coluna(166, G - 5, G - 3)
    m.linha(168, 170, G - 6)
    m.put(169, G - 8, "$")
    m.linha(176, 184, G, "<")
    m.linha(177, 183, G - 1, "o", 2)
    m.buraco(188, 193, G)
    m.arco(187, 194, G - 3, 4)
    # asas e o vão com ventilador
    m.put(198, G - 1, "T")
    m.put(204, G - 2, "A")
    m.buraco(211, 225, G)
    m.ret(217, G + 3, 218, H - 1, "M")
    m.put(217, G + 2, "F")
    m.linha(212, 216, G - 3)
    m.coluna(217, G - 9, G - 4)
    m.linha(219, 224, G - 6)
    m.put(218, G - 10, "$")
    # portão
    m.linha(229, 234, G - 1)
    m.put(238, G - 1, "G")
    m.ret(W - 1, 0, W - 1, H - 1, "#")
    meta = {
        "nome": "Saguão de Check-in", "voo": "LA 3410", "destino": "MARINGÁ", "portao": "12",
        "tempo": 55, "meta": 15, "fundo": "terminal", "piso": "terminal", "parede": "terminal",
        "asas": 0, "musica": "corrida", "cia": "latam",
        "intro": "O Barão espalhou milhas roubadas pelo saguão de Guarulhos. O voo LA 3410 está na última chamada: corra até o portão 12 e recupere o que puder no caminho!",
    }
    dicas = [
        "O Milis corre sozinho. Toque na tela para pular!",
        "Passageiros com pressa! Pule por cima deles.",
        "Esteira rolante: o Milis corre mais rápido.",
        "Bateu na parede? O Milis vira! Pule na plataforma e de lá para o alto.",
        "Carrinho desgovernado! Pule por cima, ou pise nele para quicar.",
        "Toque de novo no ar: pulo duplo!",
    ]
    m.salva("1-1", meta, dicas)


def fase_1_2():
    W, H, G = 266, 40, 34
    m = Grade(W, H)
    m.chao(0, 41, G)
    m.put(3, G - 1, "S")
    m.put(6, G - 1, "?")
    m.put(12, G - 1, "l")
    m.arco(9, 15, G - 1, 4)
    m.put(20, G - 1, "l")
    m.arco(17, 23, G - 1, 4)
    # túnel com laser no teto
    m.put(24, G - 1, "?")
    m.ret(26, G - 8, 38, G - 7, "M")
    m.put(32, G - 6, "j")
    m.put(28, G - 6, "j")
    m.linha(27, 37, G - 1)
    # sala da porta automática
    m.chao(42, 100, G + 3)
    m.put(44, G + 2, "?")
    m.linha(46, 53, G + 2)
    m.ret(56, G - 8, 56, G - 1, "M")
    m.put(56, G, "D")
    m.put(60, G + 2, "T")
    # malas caindo
    m.ret(62, G - 6, 100, G - 5, "M")
    m.put(64, G + 2, "?")
    m.put(72, G - 4, "m")
    m.put(88, G - 4, "m")
    m.linha(66, 98, G + 2, "o", 3)
    m.linha(74, 84, G - 1, "o", 2)
    # capangas
    m.chao(101, 145, G + 3)
    m.put(102, G + 2, "T")
    m.put(105, G + 2, "?")
    m.put(114, G + 2, "k")
    m.put(124, G + 2, "k")
    m.put(134, G + 2, "r")
    m.linha(112, 116, G - 1)
    m.linha(122, 126, G - 1)
    m.linha(132, 136, G - 1)
    # parede verde
    m.put(140, G + 2, "?")
    m.chao(146, 176, G - 12)
    m.ret(146, G - 12, 146, G + 2, "W")
    m.coluna(145, G - 10, G + 1)
    # chaminé: parede verde da direita (com tampa cinza em cima) e da esquerda, que leva ao andar de cima
    m.ret(147, G - 12, 176, G + 2, "#")
    m.ret(176, G - 24, 176, G - 13, "W")
    m.ret(176, G - 28, 176, G - 21, "#")
    m.ret(171, G - 28, 171, G - 16, "W")
    m.linha(148, 169, G - 13, "o", 3)
    m.coluna(173, G - 26, G - 17, "o")
    m.put(150, G - 13, "?")
    # andar de cima: à esquerda da chaminé (prêmio) e à direita (depois de pular a boca da chaminé)
    m.ret(150, G - 28, 170, G - 28, "#")
    m.ret(177, G - 28, 200, G - 28, "#")
    m.linha(172, 175, G - 28, "=")
    m.ret(148, G - 34, 149, G - 28, "#")
    m.linha(152, 168, G - 29, "o", 2)
    m.put(152, G - 30, "$")
    m.arco(170, 177, G - 29, 3)
    m.put(186, G - 31, "v")
    m.linha(180, 198, G - 29, "o", 3)
    # descida planando até o pátio dos portões
    m.chao(177, 265, G + 3)
    m.vazio(177, G - 11, 200, G + 2)
    m.chao(201, 265, G + 3)
    m.put(205, G - 20, "v")
    m.coluna(205, G - 16, G - 10, "o")
    m.linha(210, 220, G - 8, "o", 2)
    m.put(222, G + 2, "T")
    m.put(232, G + 2, "l")
    m.put(240, G + 2, "l")
    m.arco(229, 235, G + 2, 4)
    m.arco(237, 243, G + 2, 4)
    m.put(246, G + 2, "^")
    m.coluna(247, G - 6, G - 2, "o")
    m.ret(250, G - 3, 265, G + 2, "#")
    m.put(259, G - 4, "G")
    m.ret(W - 1, 0, W - 1, H - 1, "#")
    meta = {
        "nome": "Raio-X e Portas", "voo": "LA 3522", "destino": "BRASÍLIA", "portao": "27",
        "tempo": 70, "meta": 18, "fundo": "seguranca", "piso": "metal", "parede": "metal",
        "asas": 1, "musica": "corrida", "cia": "latam",
        "intro": "Os capangas do Barão estão escondidos na área de segurança. Passe pelo raio-X, pelas portas automáticas e suba as paredes verdes até o portão 27!",
    }
    dicas = [
        "Laser do raio-X no chão: pule por cima!",
        "Laser no teto: aqui NÃO pule.",
        "Porta fechada? O Milis volta e tenta de novo.",
        "Malas caindo da esteira! Pule por cima ou pise nelas.",
        "Capangas do Barão! Pule na cabeça deles.",
        "Parede verde: o Milis sobe correndo!",
        "Na chaminé, toque para saltar de uma parede para a outra.",
    ]
    m.salva("1-2", meta, dicas)


if __name__ == "__main__":
    fase_1_1()
    fase_1_2()
