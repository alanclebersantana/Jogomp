#!/usr/bin/env python3
"""Falso segurança (art_src/gemini/seguranca.jpg, fundo verde) -> assets/sprites/seg_*.png
Cada pose num quadro 260x230 com os pés em (130, 224) (mesma escala em todas). O escudo voando sai sozinho.
Rodar: python3 tools/make_seguranca.py && python3 tools/make_sil.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recortar import abrir_sem_verde, componentes
from make_arte import cel, salva, SPR, G

c = componentes(abrir_sem_verde(os.path.join(G, "seguranca.jpg")), dil=6, area_min=2500)
assert len(c) == 10, len(c)
K = .6
nomes = ["seg_parado", "seg_andaA", "seg_andaB", "seg_bravo", "seg_firme", "seg_guarda", "seg_investe", "seg_tonto", None, "seg_caido"]
for q, n in zip(c, nomes):
    if n:
        salva(cel(q, 260, 230, K, 130, 224), SPR, n + ".png")
salva(cel(c[8], 120, 120, K, 60, 60, False), SPR, "seg_escudo.png")
print("ok")
