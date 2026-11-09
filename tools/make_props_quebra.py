#!/usr/bin/env python3
"""Cenário que reage + lavadora com operador (art_src/gemini/props_quebra.jpg, fundo verde)
-> assets/sprites/brk_*.png e aero_lavadora.png (recortados no tamanho do desenho).
Rodar: python3 tools/make_props_quebra.py && python3 tools/make_sil.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recortar import abrir_sem_verde, componentes
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
c = componentes(abrir_sem_verde(os.path.join(ROOT, "art_src", "gemini", "props_quebra.jpg")), dil=4, area_min=1500)
assert len(c) == 7, len(c)
for q, n in zip(c, ["brk_lanche", "brk_lanche_q", "brk_vaso", "brk_vaso_q", "brk_vaso2", "brk_carrinho", "aero_lavadora"]):
    q.save(os.path.join(ROOT, "assets", "sprites", n + ".png"))
print("ok")
