# junta 2 capturas 800x600 de uma imagem quadrada (a 2ª deslocada 'off' px para baixo) -> 800x800,
# corta a moldura branca/preta do quadrinho e grava em JPG (assets/comic/<id>.jpg)
import sys
from PIL import Image
import numpy as np
out, a, b = sys.argv[1], sys.argv[2], sys.argv[3]
off = int(sys.argv[4]) if len(sys.argv) > 4 else 200
im = Image.new("RGB", (800, 800))
im.paste(Image.open(a).convert("RGB"), (0, 0))
tb = Image.open(b).convert("RGB")
im.paste(tb.crop((0, 600 - off, 800, 600)), (0, 600))
# moldura: anda das bordas para dentro enquanto a linha for quase toda branca ou quase toda preta
g = np.asarray(im.convert("L")).astype(float)
def borda(lines):
    k = 0
    for ln in lines:
        m = ln.mean()
        if m > 225 or m < 45 or ln.std() < 12:
            k += 1
        else:
            break
    return k
t = borda(g); bt = borda(g[::-1]); l = borda(g.T); r = borda(g.T[::-1])
t, bt, l, r = [min(v + 4, 120) for v in (t, bt, l, r)]
c = im.crop((l, t, 800 - r, 800 - bt))
s = min(c.size)
c = c.crop(((c.width - s) // 2, (c.height - s) // 2, (c.width - s) // 2 + s, (c.height - s) // 2 + s))
c.resize((640, 640), Image.LANCZOS).save(out, quality=90)
print(out, (l, t, r, bt), c.size)
