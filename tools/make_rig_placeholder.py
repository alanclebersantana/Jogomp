"""Gera peças PROVISÓRIAS do Tomé recortando a folha antiga (assets/sprites/pai.png), só para testar o
sistema de ossos. As peças de verdade vêm dos prompts de docs/ARTES_RIG.md.
Uso: python3 tools/make_rig_placeholder.py <pasta_destino>"""
import sys, os
from PIL import Image
out = sys.argv[1]
os.makedirs(out, exist_ok=True)
src = Image.open(os.path.join(os.path.dirname(__file__), '..', 'assets', 'sprites', 'pai.png')).convert('RGBA').crop((0, 0, 130, 160))
S = 3
src = src.resize((130 * S, 160 * S), Image.LANCZOS)
def cut(name, box):
    x0, y0, x1, y1 = [v * S for v in box]
    src.crop((x0, y0, x1, y1)).save(os.path.join(out, name + '.png'))
cut('cabeca', (26, 20, 100, 96))
cut('tronco', (22, 86, 100, 128))
cut('braco_frente', (96, 58, 130, 112))
cut('braco_tras', (22, 92, 44, 124))
cut('perna_tras', (44, 118, 72, 152))
cut('perna_frente', (70, 118, 100, 152))
print('ok', out)
