"""Ferramentas de desenho no estilo do Encontre-a: formas chapadas, contorno escuro grosso,
uma faixa de sombra e um brilho. Tudo em pycairo (pip install pycairo)."""
import math, os, cairo

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SPR = os.path.join(RAIZ, "assets", "sprites")
BG = os.path.join(RAIZ, "assets", "bg")
os.makedirs(SPR, exist_ok=True); os.makedirs(BG, exist_ok=True)

TINTA = "#1f1a17"   # contorno
LW = 5.0            # espessura padrão do contorno


def cor(h, a=1.0):
    h = h.lstrip("#")
    return (int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255, a)


def misturar(h1, h2, t):
    a, b = cor(h1), cor(h2)
    return "#%02x%02x%02x" % tuple(int((a[i] * (1 - t) + b[i] * t) * 255) for i in range(3))


def escurecer(h, t=0.22): return misturar(h, "#000000", t)
def clarear(h, t=0.3): return misturar(h, "#ffffff", t)


class Tela:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.s = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h)
        self.c = cairo.Context(self.s)
        self.c.set_line_join(cairo.LINE_JOIN_ROUND)
        self.c.set_line_cap(cairo.LINE_CAP_ROUND)

    def salvar(self, nome, pasta=SPR):
        p = os.path.join(pasta, nome)
        self.s.write_to_png(p)
        return p

    # ---------- caminhos
    def elipse(self, cx, cy, rx, ry):
        c = self.c; c.new_sub_path(); c.save(); c.translate(cx, cy); c.scale(max(rx, 0.01), max(ry, 0.01)); c.arc(0, 0, 1, 0, 2 * math.pi); c.restore()

    def rret(self, x, y, w, h, r):
        c = self.c; r = min(r, w / 2, h / 2)
        c.new_sub_path()
        c.arc(x + w - r, y + r, r, -math.pi / 2, 0); c.arc(x + w - r, y + h - r, r, 0, math.pi / 2)
        c.arc(x + r, y + h - r, r, math.pi / 2, math.pi); c.arc(x + r, y + r, r, math.pi, 1.5 * math.pi)
        c.close_path()

    def poli(self, pts, fechar=True):
        c = self.c; c.move_to(*pts[0])
        for p in pts[1:]: c.line_to(*p)
        if fechar: c.close_path()

    def curva(self, pts, fechar=True):
        """Caminho suave passando pelos pontos (Catmull-Rom)."""
        c = self.c; n = len(pts)
        c.move_to(*pts[0])
        rng = range(n) if fechar else range(n - 1)
        for i in rng:
            p0 = pts[(i - 1) % n] if (fechar or i > 0) else pts[i]
            p1 = pts[i]; p2 = pts[(i + 1) % n]
            p3 = pts[(i + 2) % n] if (fechar or i + 2 < n) else p2
            c.curve_to(p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6,
                       p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6, p2[0], p2[1])
        if fechar: c.close_path()

    # ---------- pintura
    def pintar(self, preench, contorno=True, lw=LW, tinta=TINTA):
        c = self.c
        if preench is not None:
            c.set_source_rgba(*cor(preench) if isinstance(preench, str) else preench)
            c.fill_preserve() if contorno else c.fill()
        if contorno:
            c.set_source_rgba(*cor(tinta)); c.set_line_width(lw); c.stroke()
        else:
            c.new_path()

    def gradiente(self, x0, y0, x1, y1, paradas, contorno=False, lw=LW):
        g = cairo.LinearGradient(x0, y0, x1, y1)
        for t, h in paradas: g.add_color_stop_rgba(t, *cor(h) if isinstance(h, str) else h)
        self.c.set_source(g)
        if contorno:
            self.c.fill_preserve(); self.c.set_source_rgba(*cor(TINTA)); self.c.set_line_width(lw); self.c.stroke()
        else:
            self.c.fill()

    def traco(self, pts, larg, h, contorno=True, lw=LW):
        """Linha grossa com contorno (membros de desenho animado)."""
        c = self.c
        if contorno:
            self.poli(pts, False); c.set_source_rgba(*cor(TINTA)); c.set_line_width(larg + lw * 2); c.stroke()
        self.poli(pts, False); c.set_source_rgba(*cor(h)); c.set_line_width(larg); c.stroke()

    def linha(self, pts, larg, h, a=1.0):
        self.poli(pts, False); self.c.set_source_rgba(*cor(h, a)); self.c.set_line_width(larg); self.c.stroke()

    def sombra_em(self, desenhar_forma, desenhar_sombra, h, a=1.0):
        """Pinta 'desenhar_sombra' recortado dentro de 'desenhar_forma'."""
        c = self.c; c.save(); desenhar_forma(); c.clip(); desenhar_sombra()
        c.set_source_rgba(*cor(h, a)); c.fill(); c.restore()

    def brilho(self, cx, cy, rx, ry, a=0.75, rot=0):
        c = self.c; c.save(); c.translate(cx, cy); c.rotate(rot); self.elipse(0, 0, rx, ry); c.set_source_rgba(1, 1, 1, a); c.fill(); c.restore()

    def texto(self, s, x, y, tam, h="#ffffff", negrito=True, centro=True, contorno=None, lw=3, fonte="DejaVu Sans"):
        c = self.c
        c.select_font_face(fonte, cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD if negrito else cairo.FONT_WEIGHT_NORMAL)
        c.set_font_size(tam)
        ext = c.text_extents(s)
        px = x - ext.width / 2 - ext.x_bearing if centro else x
        py = y - ext.height / 2 - ext.y_bearing if centro else y
        if contorno:
            c.move_to(px, py); c.text_path(s); c.set_source_rgba(*cor(contorno)); c.set_line_width(lw); c.stroke()
        c.move_to(px, py); c.set_source_rgba(*cor(h)); c.show_text(s)
        return ext.width

    def caber_texto(self, s, x, y, larg, alt, h="#ffffff", contorno=None):
        c = self.c; c.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
        tam = alt
        while tam > 6:
            c.set_font_size(tam)
            if c.text_extents(s).width <= larg: break
            tam -= 1
        self.texto(s, x, y, tam, h, contorno=contorno)

    def girar(self, cx, cy, ang):
        self.c.translate(cx, cy); self.c.rotate(ang); self.c.translate(-cx, -cy)


def folha(quadros, nome, pasta=SPR):
    """Junta quadros (Telas do mesmo tamanho) numa folha horizontal."""
    w, h = quadros[0].w, quadros[0].h
    t = Tela(w * len(quadros), h)
    for i, q in enumerate(quadros):
        t.c.set_source_surface(q.s, i * w, 0); t.c.paint()
    return t.salvar(nome, pasta)
