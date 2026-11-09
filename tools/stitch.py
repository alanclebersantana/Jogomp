# junta 4 tiles 800x600 (ordem: tl,tr,bl,br) -> imagem
import sys
from PIL import Image
out, w, h = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
fs = sys.argv[4:]
im = Image.new("RGB", (w, h))
for k, f in enumerate(fs):
    t = Image.open(f).convert("RGB")
    im.paste(t, ((k % 2) * 800, (k // 2) * 600))
im.save(out)
