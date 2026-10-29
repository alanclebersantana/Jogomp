"""Música e sons do jogo, gerados em código (numpy). Gera assets/audio/*.wav.
Música: um sambinha em loop (surdo, tamborim, ganzá, baixo, cavaquinho e melodia)."""
import os
import numpy as np
from scipy.io import wavfile
from scipy.signal import lfilter, butter

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def salvar(nome, x, vol=0.9):
    x = np.asarray(x, dtype=np.float64)
    pico = np.max(np.abs(x)) or 1.0
    x = x / pico * vol
    wavfile.write(os.path.join(OUT, nome + ".wav"), SR, (x * 32767).astype(np.int16))


def t_(d): return np.arange(int(d * SR)) / SR
def env(n, a=0.005, r=0.2, sus=0.0):
    t = np.arange(n) / SR
    e = np.minimum(1, t / max(a, 1e-4)) * np.exp(-t / max(r, 1e-4))
    return np.maximum(e, sus * (t < n / SR))
def nota(m): return 440.0 * 2 ** ((m - 69) / 12)
def passa_baixa(x, fc): b, a = butter(2, fc / (SR / 2)); return lfilter(b, a, x)
def passa_alta(x, fc): b, a = butter(2, fc / (SR / 2), "high"); return lfilter(b, a, x)


def pluck(f, d, brilho=0.5):
    """Corda dedilhada (Karplus-Strong) — cavaquinho."""
    n = int(d * SR); p = max(2, int(SR / f))
    buf = rng.uniform(-1, 1, p); out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % p]
        buf[i % p] = brilho * buf[i % p] + (1 - brilho) * 0.5 * (buf[i % p] + buf[(i + 1) % p]) * 0.996 / 1.0
        buf[i % p] *= 0.996
    return out


def mix(alvo, som, pos):
    i = int(pos * SR)
    if i >= len(alvo): return
    j = min(len(alvo), i + len(som)); alvo[i:j] += som[:j - i]


# ------------------------------------------------------------ música
def musica():
    bpm = 100; tempo = 60 / bpm; compasso = tempo * 2   # 2/4
    barras = 16
    dur = barras * compasso
    L = np.zeros(int(dur * SR) + SR)
    # instrumentos
    tt = t_(0.35)
    surdo = np.sin(2 * np.pi * (70 - 25 * tt / 0.35) * tt) * env(len(tt), 0.002, 0.18)
    surdo_fraco = surdo * 0.45
    tam_t = t_(0.06)
    tamborim = (rng.uniform(-1, 1, len(tam_t)) * 0.5 + np.sin(2 * np.pi * 900 * tam_t)) * env(len(tam_t), 0.001, 0.02)
    ganza = passa_alta(rng.uniform(-1, 1, int(0.05 * SR)), 5000) * env(int(0.05 * SR), 0.004, 0.02)
    acordes = [[60, 64, 67, 72], [57, 60, 64, 69], [62, 65, 69, 74], [55, 59, 62, 67]]   # C Am Dm G
    baixos = [36, 33, 38, 31]
    melodia = [76, None, 74, 72, 74, None, 76, 79, 77, None, 76, 74, 72, None, None, None,
               72, None, 74, 76, 77, None, 76, 74, 76, None, 74, 72, 71, None, 67, None]
    sem = compasso / 8   # semicolcheia
    tam_padrao = [1, 0, 1, 1, 0, 1, 1, 0]
    for b in range(barras):
        t0 = b * compasso
        ac = acordes[(b // 2) % 4]; bx = baixos[(b // 2) % 4]
        mix(L, surdo_fraco, t0); mix(L, surdo, t0 + tempo)
        for k in range(8):
            if tam_padrao[k]: mix(L, tamborim * (0.9 if k in (0, 3, 6) else 0.5), t0 + k * sem)
            mix(L, ganza * (0.6 if k % 2 == 0 else 0.35), t0 + k * sem)
        # baixo: tônica e quinta
        for k, (m, d) in enumerate([(bx, 0.3), (bx + 7, 0.25), (bx + 12, 0.2), (bx + 7, 0.25)]):
            tb = t_(d); f = nota(m)
            som = (np.sin(2 * np.pi * f * tb) + 0.3 * np.sin(4 * np.pi * f * tb)) * env(len(tb), 0.005, 0.15) * 0.55
            mix(L, som, t0 + k * compasso / 4)
        # cavaquinho: batida em semicolcheias acentuadas
        for k in (0, 2, 3, 5, 6):
            for i, m in enumerate(ac):
                mix(L, pluck(nota(m + 12), 0.22, 0.4) * (0.18 if k in (0, 3, 6) else 0.1), t0 + k * sem + i * 0.006)
        # melodia (sax suave)
        for k in range(2):
            m = melodia[(b * 2 + k) % len(melodia)]
            if m is None: continue
            d = compasso / 2 * 0.95; tm = t_(d); f = nota(m)
            vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * tm)
            som = (np.sin(2 * np.pi * f * vib * tm) + 0.25 * np.sin(4 * np.pi * f * tm) + 0.1 * np.sin(6 * np.pi * f * tm))
            som *= np.minimum(1, tm / 0.03) * np.exp(-tm / 0.7) * 0.32
            mix(L, som, t0 + k * compasso / 2)
    L = L[:int(dur * SR)]
    # emenda suave do loop
    f = int(0.01 * SR); L[:f] *= np.linspace(0, 1, f); L[-f:] *= np.linspace(1, 0, f)
    salvar("musica", L, 0.75)


def chuva():
    n = int(6 * SR)
    x = passa_baixa(rng.normal(0, 1, n), 3500) * 0.6 + passa_alta(rng.normal(0, 1, n), 6000) * 0.25
    for _ in range(140):   # pingos
        p = int(rng.uniform(0, n - 400)); x[p:p + 300] += rng.normal(0, 1, 300) * np.exp(-np.arange(300) / 40) * 1.5
    f = int(0.3 * SR); x[:f] = x[:f] * np.linspace(0, 1, f) + x[-f:] * np.linspace(1, 0, f); x = x[:-f]
    salvar("chuva", x, 0.5)


def varredura(f0, f1, d, onda="sin", vol=1.0, r=None):
    tt = t_(d); f = f0 * (f1 / f0) ** (tt / d); fase = 2 * np.pi * np.cumsum(f) / SR
    s = np.sin(fase) if onda == "sin" else np.sign(np.sin(fase)) * 0.6 if onda == "quad" else 2 * (fase / (2 * np.pi) % 1) - 1
    return s * env(len(tt), 0.004, r or d / 2.5) * vol


def ruido(d, fc_lo=200, fc_hi=4000, r=None):
    n = int(d * SR); x = rng.normal(0, 1, n)
    x = passa_baixa(passa_alta(x, fc_lo), fc_hi)
    return x * env(n, 0.005, r or d / 3)


def sons():
    salvar("pulo", varredura(300, 720, 0.16, "quad", r=0.08), 0.6)
    salvar("pouso", ruido(0.08, 60, 600, 0.03), 0.7)
    a = varredura(1320, 1320, 0.08, "sin", r=0.05); b = varredura(1760, 1760, 0.18, "sin", r=0.09)
    m = np.zeros(int(0.26 * SR)); mix(m, a, 0); mix(m, b, 0.06); salvar("milha", m, 0.55)
    salvar("rolar", ruido(0.25, 300, 2500, 0.1), 0.5)
    salvar("mergulho", varredura(900, 180, 0.22, "saw", r=0.1), 0.5)
    salvar("dash", ruido(0.3, 800, 6000, 0.1) * np.linspace(0.3, 1, int(0.3 * SR)), 0.6)
    salvar("faixa", ruido(0.12, 1500, 7000, 0.05), 0.5)
    t1 = np.zeros(int(0.45 * SR)); mix(t1, ruido(0.12, 50, 500, 0.05), 0); mix(t1, varredura(500, 140, 0.35, "sin", r=0.15), 0.05); salvar("tropeco", t1, 0.8)
    salvar("pisao", varredura(260, 900, 0.18, "sin", r=0.1), 0.6)
    tt = t_(0.5); salvar("mola", np.sin(2 * np.pi * (180 + 500 * tt) * tt) * np.exp(-tt * 5) * (1 + 0.6 * np.sin(2 * np.pi * 18 * tt)), 0.7)
    a = np.zeros(int(0.35 * SR)); mix(a, varredura(990, 990, 0.12, r=0.06), 0); mix(a, varredura(1480, 1480, 0.2, r=0.1), 0.1); salvar("ok", a, 0.5)
    al = np.zeros(int(0.8 * SR))
    for k in range(3): mix(al, varredura(1250, 1250, 0.18, "quad", r=0.5) * env(int(0.18 * SR), 0.002, 1.0), k * 0.25)
    salvar("alarme", al, 0.55)
    tt = t_(0.7); ap = np.sin(2 * np.pi * (2900 + 120 * np.sin(2 * np.pi * 28 * tt)) * tt) * np.minimum(1, tt / 0.02) * np.exp(-tt * 2.5)
    salvar("apito", ap + 0.2 * ruido(0.7, 2000, 6000, 0.3), 0.55)
    dd = np.zeros(int(2.2 * SR))
    for k, m in enumerate([76, 72, 79]):
        tt = t_(1.4); f = nota(m)
        mix(dd, (np.sin(2 * np.pi * f * tt) + 0.4 * np.sin(2 * np.pi * 2.01 * f * tt)) * np.exp(-tt * 2.2), k * 0.45)
    salvar("dingdong", dd, 0.6)
    tt = t_(0.22); lat = (np.sign(np.sin(2 * np.pi * (520 - 300 * tt / 0.22) * tt)) * 0.5 + rng.normal(0, 0.6, len(tt))) * env(len(tt), 0.005, 0.07)
    lat = passa_baixa(lat, 2500); l2 = np.zeros(int(0.5 * SR)); mix(l2, lat, 0); mix(l2, lat * 0.8, 0.24); salvar("latido", l2, 0.7)
    tt = t_(0.7); bz = (np.sign(np.sin(2 * np.pi * 415 * tt)) + np.sign(np.sin(2 * np.pi * 523 * tt))) * np.minimum(1, tt / 0.01) * (tt < 0.62)
    salvar("buzina", passa_baixa(bz, 2500), 0.6)
    salvar("porta", ruido(0.6, 300, 2500, 0.3) * np.sin(np.linspace(0, np.pi, int(0.6 * SR))), 0.45)
    salvar("splash", ruido(0.4, 400, 7000, 0.12), 0.6)
    salvar("etiqueta", ruido(0.25, 2000, 8000, 0.08), 0.45)
    salvar("cone", ruido(0.15, 100, 1500, 0.04) + varredura(220, 180, 0.15, r=0.06)[:int(0.15 * SR)], 0.6)
    j = np.zeros(int(1.6 * SR))
    for k, m in enumerate([72, 76, 79, 84, 79, 84]):
        mix(j, varredura(nota(m), nota(m), 0.3, "quad", r=0.15), k * 0.13 if k < 4 else 0.52 + (k - 4) * 0.3)
    salvar("vitoria", j, 0.55)
    d = np.zeros(int(1.4 * SR))
    for k, m in enumerate([67, 64, 60, 55]): mix(d, varredura(nota(m), nota(m) * 0.97, 0.35, "sin", r=0.2), k * 0.25)
    salvar("derrota", d, 0.6)
    mm = np.zeros(int(0.8 * SR))
    for k, m in enumerate([84, 88, 91, 96, 100]): mix(mm, varredura(nota(m), nota(m), 0.25, r=0.12), k * 0.08)
    salvar("mala", mm, 0.5)
    salvar("cartao", mm[:int(0.5 * SR)], 0.5)
    n = int(3.5 * SR); tt = np.arange(n) / SR
    jato = passa_baixa(rng.normal(0, 1, n), 900) * np.minimum(1, tt / 1.5) * np.exp(-np.maximum(0, tt - 2.5) * 2)
    salvar("aviao", jato + 0.3 * np.sin(2 * np.pi * (180 + 60 * tt) * tt) * np.minimum(1, tt / 1.5), 0.7)
    salvar("carrinho", ruido(1.0, 300, 3000, 10) * (1 + 0.5 * np.sign(np.sin(2 * np.pi * 14 * t_(1.0)))), 0.35)
    salvar("guarda_chuva", varredura(400, 1200, 0.3, r=0.12)[:int(0.3 * SR)] + ruido(0.3, 2000, 7000, 0.1)[:int(0.3 * SR)], 0.5)


if __name__ == "__main__":
    sons(); chuva(); musica()
    print("ok", sorted(os.listdir(OUT)))
