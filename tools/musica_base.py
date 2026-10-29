"""Compõe e grava as músicas, os ambientes e parte dos efeitos do Find Her com instrumentos reais
(amostras gravadas de piano, harpa, violoncelo, violino, flauta, clarinete, violão de náilon e de aço,
xilofone, contrabaixo, trompa, trompete, fagote e harmônio — pacotes npm tonejs-instrument-*-mp3,
licença MIT; amostras originais do projeto nbrosowsky/tonejs-instruments, CC-BY 3.0). A percussão
(bumbo, caixa, escovinha, chocalho, guizos, pandeiro, triângulo, bloco, tímpano, trilho) é sintetizada.

Uso:
  mkdir -p /tmp/tj && cd /tmp/tj && for p in piano harp cello violin flute clarinet guitar-nylon \
     guitar-acoustic xylophone contrabass french-horn trumpet bassoon harmonium; do npm pack tonejs-instrument-$p-mp3; done
  for f in *.tgz; do mkdir -p ${f%.tgz}; tar xzf $f -C ${f%.tgz}; done
  python3 tools/make_music.py /tmp/tj            (tudo)
  python3 tools/make_music.py /tmp/tj chuva cavalo (só essas)
Saída: assets/audio/mus_*.ogg, amb_*.ogg e alguns efeitos .wav (requer numpy, scipy e ffmpeg).
"""
import glob, os, re, subprocess, sys
import numpy as np
from scipy.signal import fftconvolve

SR = 32000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'audio')
SRC = sys.argv[1] if len(sys.argv) > 1 else '/tmp/tj'
rng = np.random.default_rng(11)

# ----------------------------------------------------------------- amostras
NOTE = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}

def midi_of(name):
    m = re.match(r'^([A-G])(s|#|b)?(-?\d)$', name)
    if not m:
        return None
    n = NOTE[m.group(1)] + (1 if m.group(2) in ('s', '#') else -1 if m.group(2) == 'b' else 0)
    return n + 12 * (int(m.group(3)) + 1)

def decode(path):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-ac', '1', '-ar', str(SR), '-f', 'f32le', '-'],
                         capture_output=True, check=True).stdout
    x = np.frombuffer(raw, dtype=np.float32).astype(np.float64)
    pk = np.max(np.abs(x)) if len(x) else 1
    idx = np.argmax(np.abs(x) > pk * .02)          # corta o silêncio inicial
    x = x[max(0, idx - 40):]
    return x / (pk + 1e-9)

INST = {}
def inst(name):
    if name not in INST:
        d = {}
        for f in glob.glob(os.path.join(SRC, f'tonejs-instrument-{name}-mp3*', 'package', '*.mp3')):
            m = midi_of(os.path.basename(f)[:-4])
            if m is not None:
                d[m] = decode(f)
        if not d:
            raise SystemExit(f'amostras de {name} não encontradas em {SRC}')
        INST[name] = d
    return INST[name]

PAN = {'piano': 0, 'harp': -.35, 'cello': .3, 'violin': -.25, 'flute': .25, 'clarinet': .2, 'guitar-nylon': -.3,
       'xylophone': .35, 'contrabass': .1, 'french-horn': -.15, 'bassoon': .15}

class Track:
    def __init__(self, secs):
        self.n = int(secs * SR)
        self.buf = np.zeros((2, self.n + SR * 8))
        self.dry = np.zeros((2, self.n + SR * 8))

    def note(self, name, midi, t, dur, vel=.7, rel=.25, pan=None, dry=.0):
        d = inst(name)
        k = min(d, key=lambda m: abs(m - midi))
        s = d[k]
        ratio = 2 ** ((midi - k) / 12)
        ln = int((dur + rel) * SR)
        pos = np.arange(ln) * ratio
        pos = pos[pos < len(s) - 1]
        if len(pos) == 0:
            return
        y = np.interp(pos, np.arange(len(s)), s)
        e = np.ones(len(y))
        a = min(len(y), int(.004 * SR))
        e[:a] = np.linspace(0, 1, a)
        hold = int(dur * SR)
        if hold < len(y):
            r = len(y) - hold
            e[hold:] *= np.exp(-np.linspace(0, 6, r))
        y = y * e * vel
        p = PAN.get(name, 0) if pan is None else pan
        if t < 0:                         # anacruse antes do começo: entra no fim do loop
            t += self.n / SR
        i = int(t * SR)
        end = min(i + len(y), self.buf.shape[1])
        y = y[:end - i]
        tgt = self.dry if dry else self.buf
        tgt[0, i:end] += y * np.sqrt((1 - p) / 2) * 1.41
        tgt[1, i:end] += y * np.sqrt((1 + p) / 2) * 1.41

    def raw(self, y, t, pan=0.0, dry=True):
        if t < 0:
            t += self.n / SR
        i = int(t * SR)
        end = min(i + len(y), self.buf.shape[1])
        y = y[:end - i]
        tgt = self.dry if dry else self.buf
        tgt[0, i:end] += y * np.sqrt((1 - pan) / 2) * 1.41
        tgt[1, i:end] += y * np.sqrt((1 + pan) / 2) * 1.41

    def render(self, wet=.32, room=2.2, loop=True):
        ir_n = int(room * SR)
        tt = np.arange(ir_n) / SR
        ir = np.stack([rng.standard_normal(ir_n), rng.standard_normal(ir_n)]) * np.exp(-tt * 6.9 / room)
        ir[:, :int(.012 * SR)] = 0
        ir /= np.sqrt(np.sum(ir ** 2, axis=1, keepdims=True))
        rev = np.stack([fftconvolve(self.buf[c], ir[c])[:self.buf.shape[1]] for c in range(2)])
        mix = self.buf + self.dry + rev * wet
        if loop:
            out = mix[:, :self.n].copy()
            tail = mix[:, self.n:]
            k = 0
            while k < tail.shape[1]:      # o rabo (reverberação) volta para o começo: emenda sem corte
                seg = tail[:, k:k + self.n]
                out[:, :seg.shape[1]] += seg
                k += self.n
        else:
            out = mix
            nz = np.where(np.max(np.abs(out), axis=0) > 1e-4)[0]
            out = out[:, :nz[-1] + SR // 4] if len(nz) else out
        pk = np.max(np.abs(out)) + 1e-9
        out = np.tanh(out / pk * 1.15) / np.tanh(1.15) * .89
        return out

def save_ogg(name, x, q=4):
    path = os.path.join(OUT, name + '.ogg')
    pcm = (np.clip(x.T, -1, 1) * 32767).astype('<i2').tobytes()
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 's16le', '-ar', str(SR), '-ac', '2', '-i', '-',
                    '-c:a', 'libvorbis', '-q:a', str(q), path], input=pcm, check=True)
    print('ok', name, f'{x.shape[1] / SR:.1f}s', os.path.getsize(path) // 1024, 'KB')

def save_wav(name, x):
    import wave
    m = x.mean(axis=0) if x.ndim == 2 else x
    m = m / (np.max(np.abs(m)) + 1e-9) * .9
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((m * 32767).astype('<i2').tobytes())
    print('ok', name + '.wav')

# ----------------------------------------------------------------- teoria
def P(s):
    """'E4' -> midi; aceita # e b"""
    return midi_of(s.replace('#', 's'))

def mel(s, bar=None):
    """'E4:2 G4:1 r:1' -> [(beat, dur, midi|None)]; '|' separa compassos e, com bar, confere a soma"""
    out, b, acc, k = [], 0.0, 0.0, 1
    for tok in s.split() + ['|']:
        if tok == '|':
            if bar and acc:
                assert abs(acc - bar) < 1e-6, f'compasso {k} com {acc} tempos em vez de {bar}: {s[:50]}...'
            acc, k = 0.0, k + 1
            continue
        n, d = tok.split(':')
        d = float(d)
        out.append((b, d, None if n == 'r' else P(n)))
        b += d
        acc += d
    return out

CH = {'': [0, 4, 7], 'm': [0, 3, 7], '7': [0, 4, 7, 10], 'm7': [0, 3, 7, 10], 'sus': [0, 5, 7], 'dim': [0, 3, 6]}
def chord(sym, octave=3):
    m = re.match(r'^([A-G][#b]?)(.*)$', sym)
    root = P(m.group(1) + str(octave))
    return [root + i for i in CH[m.group(2)]]

def play_mel(T, name, notes, spb, t0=0, vel=.7, legato=1.0, octave=0, rel=.3, hum=0.0):
    for b, d, m in notes:
        if m is None:
            continue
        v = vel * (1 + rng.uniform(-.08, .08))
        T.note(name, m + 12 * octave, t0 + b * spb + rng.uniform(0, hum), d * spb * legato, v, rel)

def song_manha():
    bpm = 108
    spb = 60 / bpm
    chs = 'G D Em C G D C D Em C G D C D G G'.split()
    T = Track(16 * 4 * spb)
    for i, c in enumerate(chs):
        ch = chord(c, 3)
        t = i * 4 * spb
        tones = [ch[0], ch[2], ch[0] + 12, ch[1] + 12, ch[2] + 12, ch[1] + 12, ch[0] + 12, ch[2]]
        for k, m in enumerate(tones):                          # violão dedilhado
            T.note('guitar-nylon', m, t + k * spb / 2 + rng.uniform(0, .01), spb * .9, .42 if k % 2 == 0 else .3, .5)
        for k in (0, 2):                                       # baixo
            T.note('cello', ch[0] - 12, t + k * spb, spb * .7, .3, .25)
    fl = mel('B4:1 D5:1 E5:1.5 D5:.5 B4:2 A4:2 G4:1 A4:1 B4:1 D5:1 A4:4 '
             'B4:1 D5:1 E5:1.5 G5:.5 F#5:1 E5:1 D5:2 E5:1 D5:1 B4:1 A4:1 G4:4 '
             'E5:2 D5:1 B4:1 C5:2 B4:1 A4:1 B4:1 A4:1 G4:1 A4:1 G4:4')
    play_mel(T, 'flute', fl, spb, t0=4 * 4 * spb, vel=.5, legato=.95, rel=.3)
    for i in (0, 2, 8, 10):                                    # brilhos de xilofone
        for k, m in enumerate(['D6', 'G6', 'B6']):
            T.note('xylophone', P(m), (i * 4 + 3 + k * .5) * spb, .4, .14)
    return T.render(.26, 1.8)

def drum_kick():
    n = int(.35 * SR); t = np.arange(n) / SR
    f = 50 + 90 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9) * .9

def drum_snare():
    n = int(.25 * SR); t = np.arange(n) / SR
    nz = rng.standard_normal(n)
    nz = np.convolve(nz, [1, -1], 'same')
    return (nz * .35 + np.sin(2 * np.pi * 190 * t) * .5) * np.exp(-t * 18)

def drum_hat():
    n = int(.06 * SR); t = np.arange(n) / SR
    nz = np.convolve(rng.standard_normal(n), [1, -2, 1], 'same')
    return nz * np.exp(-t * 70) * .12

def drum_tom():
    n = int(.6 * SR); t = np.arange(n) / SR
    f = 70 + 40 * np.exp(-t * 12)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 5) * .8

def song_perseguicao():
    bpm = 148
    spb = 60 / bpm
    chs = 'Dm Dm Bb Bb Dm Dm Bb A Gm Gm A Dm Dm Dm Bb A'.split()
    T = Track(16 * 4 * spb)
    K, S, H, TM = drum_kick(), drum_snare(), drum_hat(), drum_tom()
    for i, c in enumerate(chs):
        ch = chord(c, 2)
        t = i * 4 * spb
        r = ch[0] + 12
        pat = [r, r, r + 12, r, ch[1] + 12, r, ch[2] + 12, r]
        for k, m in enumerate(pat):                            # ostinato em staccato
            T.note('cello', m, t + k * spb / 2, spb * .28, .5 if k % 2 == 0 else .38, .06)
        T.note('contrabass', ch[0], t, spb * 1.6, .45, .1)
        T.note('contrabass', ch[0], t + 2 * spb, spb * 1.6, .4, .1)
        if i % 2 == 0 or i >= 12:
            for m in chord(c, 3):
                T.note('french-horn', m, t, spb * 1.6, .3, .3)
        for k in range(8):
            T.raw(H, t + k * spb / 2, .3)
        T.raw(K, t); T.raw(K, t + 2.5 * spb)
        T.raw(S, t + spb, -.1); T.raw(S, t + 3 * spb, -.1)
        if i % 4 == 3:
            T.raw(TM, t + 3.5 * spb, .2); T.raw(TM * .8, t + 3.75 * spb, -.2)
    vl = mel('A4:1.5 A4:.5 D5:1 E5:1 F5:2 E5:1 D5:1 D5:1.5 C5:.5 Bb4:1 A4:1 A4:4 '
             'G4:1.5 A4:.5 Bb4:1 C5:1 D5:2 C5:1 Bb4:1 A4:1 Bb4:1 C#5:1 E5:1 D5:4')
    play_mel(T, 'violin', vl, spb, t0=4 * 4 * spb, vel=.5, legato=.9, rel=.15)
    play_mel(T, 'violin', vl[:12], spb, t0=12 * 4 * spb, vel=.45, legato=.9, rel=.15, octave=1)
    return T.render(.18, 1.4)

def song_vitoria():
    bpm = 70
    spb = 60 / bpm
    chs = 'C Am F G C Am F C'.split()
    T = Track(8 * 4 * spb)
    for i, c in enumerate(chs):
        ch = chord(c, 3)
        t = i * 4 * spb
        T.note('cello', ch[0] - 12, t, 4 * spb, .3, 1)
        T.note('violin', ch[1] + 12, t, 4 * spb, .1, 1)
        for k, m in enumerate([ch[0], ch[1], ch[2], ch[1] + 12, ch[2] + 12, ch[0] + 24]):
            T.note('harp', m, t + k * spb * .5, 1.5, .2, 1.5)
    pm = mel('E5:2 G5:1 A5:1 G5:3 E5:1 F5:2 E5:1 D5:1 D5:4 E5:2 G5:1 A5:1 C6:2 B5:1 A5:1 G5:2 E5:1 D5:1 C5:4')
    play_mel(T, 'piano', pm, spb, vel=.5, rel=1.2)
    return T.render(.4, 3.0)

# ----------------------------------------------------------------- utilidades de arranjo
from scipy.signal import butter, lfilter

def _filt(x, kind, fc, order=2):
    w = np.clip(np.asarray(fc, dtype=float) / (SR / 2), 1e-4, .99)
    b, a = butter(order, w if w.ndim else float(w), kind)
    return lfilter(b, a, x)

def hpf(x, fc):
    return _filt(x, 'high', fc)

def bpf(x, lo, hi):
    return _filt(x, 'band', [lo, hi])

def bars(spec):
    """'F C Bb.C' -> [(tempo de início, duração em tempos, acorde)]; '.' divide o compasso"""
    return [tok.split('.') for tok in spec.split()]

def events(prog, bpb):
    out = []
    for i, bar in enumerate(prog):
        d = bpb / len(bar)
        for k, c in enumerate(bar):
            out.append((i * bpb + k * d, d, c))
    return out

def chord_at(evs, beat):
    for b, d, c in evs:
        if b <= beat + 1e-6 < b + d:
            return c
    return evs[-1][2]

def harm(notes, evs, above=True, octave=0):
    """segunda voz: para cada nota, a nota do acorde mais próxima uma terça acima (ou abaixo)"""
    out = []
    for b, d, m in notes:
        if m is None:
            out.append((b, d, None))
            continue
        pcs = [x % 12 for x in chord(chord_at(evs, b), 3)]
        rng_ = range(m + 3, m + 6) if above else range(m - 3, m - 6, -1)
        h = next((x for x in rng_ if x % 12 in pcs), m + (4 if above else -3))
        out.append((b, d, h + 12 * octave))
    return out

def shift(notes, beats):
    return [(b + beats, d, m) for b, d, m in notes]

def strum(T, name, ms, t, dur, vel, rel=.2, gap=.007, pan=None):
    for k, m in enumerate(ms):
        T.note(name, m, t + k * gap, dur, vel * (1 + rng.uniform(-.06, .06)), rel, pan)

def five(c, octave=2):
    """a quinta do acorde para o baixo alternar (abaixo da fundamental se ficaria aguda demais)"""
    r = chord(c, octave)[0]
    return r + 7 if r + 7 <= P('C3') + 12 * (octave - 2) else r - 5

# ----------------------------------------------------------------- percussão (sintetizada com cuidado:
# ruído filtrado, parciais inarmônicos e envelopes de verdade — nada de bipe cru)
def p_kick(v=1.0):
    n = int(.32 * SR); t = np.arange(n) / SR
    f = 46 + 85 * np.exp(-t * 34)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 11)
    click = hpf(rng.standard_normal(n), 1500) * np.exp(-t * 300) * .12
    return (body + click) * .75 * v

def p_rim(v=1.0):
    n = int(.1 * SR); t = np.arange(n) / SR
    y = np.sin(2 * np.pi * 1720 * t) * np.exp(-t * 95) * .6 + bpf(rng.standard_normal(n), 1800, 6000) * np.exp(-t * 130) * .5
    return y * .35 * v

def p_brush(v=1.0):
    n = int(.22 * SR); t = np.arange(n) / SR
    y = bpf(rng.standard_normal(n), 900, 7000)
    return y * (1 - np.exp(-t * 500)) * np.exp(-t * 15) * .22 * v

def p_snare(v=1.0):
    n = int(.24 * SR); t = np.arange(n) / SR
    nz = bpf(rng.standard_normal(n), 1200, 8000) * np.exp(-t * 17)
    tone = np.sin(2 * np.pi * (185 + 30 * np.exp(-t * 40)) * t) * np.exp(-t * 22)
    return (nz * .5 + tone * .45) * .55 * v

def p_clap(v=1.0):
    n = int(.25 * SR); t = np.arange(n) / SR
    nz = bpf(rng.standard_normal(n), 800, 3200)
    e = np.zeros(n)
    for o in (0, .009, .019):
        k = int(o * SR)
        e[k:] += np.exp(-(t[:n - k]) * 140)
    e += np.exp(-t * 22) * .5 * (t > .02)
    return nz * e * .25 * v

def p_shaker(v=1.0):
    n = int(.11 * SR); t = np.arange(n) / SR
    y = hpf(rng.standard_normal(n), 4800)
    return y * (1 - np.exp(-t * 260)) * np.exp(-t * 40) * .11 * v

def p_jingle(v=1.0, n_bells=6, secs=.42):
    """guizos de trenó / platinelas do pandeiro: vários sininhos agudos levemente fora de tempo"""
    n = int(secs * SR); t = np.arange(n) / SR
    y = np.zeros(n)
    for _ in range(n_bells):
        o = rng.uniform(0, .028)
        tt = t - o
        m = tt >= 0
        for f in rng.uniform(4800, 9600, 2):
            y[m] += np.sin(2 * np.pi * f * tt[m] + rng.uniform(0, 6.3)) * np.exp(-tt[m] * rng.uniform(16, 30)) * rng.uniform(.4, 1)
    y /= n_bells
    nz = hpf(rng.standard_normal(n), 6500) * np.exp(-t * 55) * .35
    return (y + nz) * .3 * v

def p_tamb(v=1.0):
    n = int(.25 * SR); t = np.arange(n) / SR
    skin = np.sin(2 * np.pi * 380 * t) * np.exp(-t * 45) * .25
    return p_jingle(v * .8, 4, .25) + skin * .15 * v

def p_triangle(v=1.0):
    n = int(1.6 * SR); t = np.arange(n) / SR
    y = sum(a * np.sin(2 * np.pi * 1210 * r * t) * np.exp(-t * dcy) for r, a, dcy in
            [(1, 1, 2.6), (2.93, .55, 3.4), (4.11, .4, 4.0), (5.34, .3, 5.0), (7.42, .18, 6)])
    return y * (1 - np.exp(-t * 2000)) * .06 * v

def p_block(f=900, v=1.0):
    """bloco de madeira: o casco do cavalo, o 'toc' do coco"""
    n = int(.12 * SR); t = np.arange(n) / SR
    y = np.sin(2 * np.pi * f * t) * np.exp(-t * 60) + .45 * np.sin(2 * np.pi * f * 1.61 * t) * np.exp(-t * 85)
    y += hpf(rng.standard_normal(n), 2500) * np.exp(-t * 500) * .25
    return y * .32 * v

def p_timp(midi, v=1.0):
    n = int(1.4 * SR); t = np.arange(n) / SR
    f = 440 * 2 ** ((midi - 69) / 12)
    fr = f * (1 + .03 * np.exp(-t * 18))
    ph = 2 * np.pi * np.cumsum(fr) / SR
    y = np.sin(ph) * np.exp(-t * 3.0) + .45 * np.sin(1.5 * ph) * np.exp(-t * 5) + .25 * np.sin(1.99 * ph) * np.exp(-t * 6)
    y += _filt(rng.standard_normal(n), 'low', 500) * np.exp(-t * 45) * .6
    return y * .45 * v

def p_anvil(v=1.0):
    """pancada de metal (trilho, picareta) para o carrinho da mina"""
    n = int(.9 * SR); t = np.arange(n) / SR
    y = sum(a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) * np.exp(-t * d) for f, a, d in
            [(612, 1, 7), (1418, .7, 9), (2333, .5, 11), (3577, .35, 15), (4810, .2, 18)])
    y += hpf(rng.standard_normal(n), 3000) * np.exp(-t * 200) * .4
    return y * .09 * v

def hits(T, y, beats, spb, t0=0.0, pan=0.0, wet=False, vel=1.0, hum=.004):
    for b in beats:
        T.raw(y * vel * (1 + rng.uniform(-.1, .1)), t0 + b * spb + rng.uniform(0, hum), pan, not wet)

def render_stems(Ts, wet=.3, room=2.0):
    """renderiza camadas da mesma música com a mesma reverberação e o mesmo ganho: tocadas juntas,
    em sincronia, somam exatamente a música completa (a camada 1 sozinha fica com o volume de antes)"""
    ir_n = int(room * SR)
    tt = np.arange(ir_n) / SR
    ir = np.stack([rng.standard_normal(ir_n), rng.standard_normal(ir_n)]) * np.exp(-tt * 6.9 / room)
    ir[:, :int(.012 * SR)] = 0
    ir /= np.sqrt(np.sum(ir ** 2, axis=1, keepdims=True))
    outs = []
    for T in Ts:
        rev = np.stack([fftconvolve(T.buf[c], ir[c])[:T.buf.shape[1]] for c in range(2)])
        mix = T.buf + T.dry + rev * wet
        out = mix[:, :T.n].copy()
        tail = mix[:, T.n:]
        k = 0
        while k < tail.shape[1]:
            seg = tail[:, k:k + T.n]
            out[:, :seg.shape[1]] += seg
            k += T.n
        outs.append(out)
    g = .89 / (np.max(np.abs(outs[0])) + 1e-9)
    top = max(np.max(np.abs(o)) for o in outs) * g
    if top > .97:
        g *= .97 / top
    return [o * g for o in outs]

def layered(name, f):
    stems = f()
    for i, x in enumerate(stems):
        save_ogg('mus_' + name + ('' if i == 0 else '_%d' % (i + 1)), x)

# ----------------------------------------------------------------- tema da Lia (canção de ninar)
LIA = mel('E4:2 G4:1 A4:2 G4:1 E4:1 D4:1 C4:1 D4:3 '
          'E4:2 G4:1 A4:1 C5:1 B4:1 A4:1 G4:1 E4:1 G4:3 '
          'A4:2 C5:1 B4:2 G4:1 A4:1 G4:1 E4:1 D4:3 '
          'E4:2 G4:1 A4:1 G4:1 E4:1 D4:1 E4:1 D4:1 C4:3')
LIA_CH = 'C F C G C F Am G F Em Am G C F G C'.split()

## Músicas calmas e longas em três camadas sincronizadas (o jogo vai somando as camadas conforme o
## Tomé avança no trecho): 1 = a música calma de sempre; 2 = pulso (baixo, violão, percussão leve);
## 3 = brilho e animação (contracanto, xilofone, pandeiro, metais).

def song_tema():
    """a neve (e os menus): a canção de ninar da Lia, que vira uma valsa alegre de inverno"""
    bpm, bar = 80, 3
    spb = 60 / bpm
    prog = [[c] for c in LIA_CH * 2]
    evs = events(prog, bar)
    secs = 32 * bar * spb
    L1, L2, L3 = Track(secs), Track(secs), Track(secs)
    # 1: piano canta, harpa embala, violoncelo segura; na volta, a flauta canta uma oitava acima
    play_mel(L1, 'piano', LIA, spb, vel=.62, rel=.8)
    play_mel(L1, 'flute', shift(LIA, 16 * bar), spb, vel=.4, legato=.95, octave=1, rel=.4)
    play_mel(L1, 'piano', shift(LIA, 16 * bar), spb, vel=.22, rel=.8)
    for i, (b, d, c) in enumerate(evs):
        ch = chord(c, 3)
        t = b * spb
        L1.note('cello', ch[0] - 12, t, bar * spb * .98, .32, .6)
        for k, idx in enumerate([0, 1, 2, 1, 2, 0]):
            L1.note('harp', ch[idx] + (12 if k in (2, 4) else 0), t + k * spb / 2, spb, .26 + (.08 if k == 0 else 0), 1.2)
        if 8 <= i % 16:
            L1.note('violin', ch[2] + 12, t, bar * spb, .12, .8)
    # 2: valsa — baixo no 1, violão no 2 e no 3, escovinha e guizos de neve
    for i, (b, d, c) in enumerate(evs):
        ch = chord(c, 3)
        t = b * spb
        L2.note('contrabass', ch[0] - 12 if i % 2 == 0 else five(c), t, spb * .5, .42, .15)
        for k in (1, 2):
            strum(L2, 'guitar-nylon', chord(c, 4), t + k * spb, spb * .45, .2 + (.03 if k == 1 else 0), .2)
        hits(L2, p_brush(), [b + 1, b + 2], spb, vel=.5, wet=True)
        hits(L2, p_jingle(), [b], spb, pan=.3, vel=.35, wet=True)
        if i % 4 == 0:
            hits(L2, p_triangle(), [b], spb, pan=-.3, vel=.4, wet=True)
    # 3: brilho — xilofone em colcheias, violino em contracanto, trompa, bumbo e guizos em todo tempo
    for i, (b, d, c) in enumerate(evs):
        ch = chord(c, 4)
        t = b * spb
        arp = [ch[0] + 12, ch[1] + 12, ch[2] + 12, ch[0] + 24, ch[2] + 12, ch[1] + 12]
        for k, m in enumerate(arp):
            L3.note('xylophone', m, t + k * spb / 2, spb * .4, .13 + (.04 if k == 0 else 0), .4)
        L3.note('french-horn', chord(c, 3)[0], t, bar * spb * .9, .13, .4)
        L3.note('french-horn', chord(c, 3)[2], t, bar * spb * .9, .1, .4)
        hits(L3, p_kick(), [b], spb, vel=.4)
        hits(L3, p_jingle(), [b + 1, b + 2], spb, pan=.35, vel=.24, wet=True)
        hits(L3, p_shaker(), [b + k * .5 for k in range(6)], spb, pan=-.4, vel=.7, wet=True)
    play_mel(L3, 'violin', harm(LIA, evs, True, 1), spb, vel=.2, legato=.95, rel=.3)
    play_mel(L3, 'violin', harm(shift(LIA, 16 * bar), evs, False, 1), spb, vel=.2, legato=.95, rel=.3)
    return render_stems([L1, L2, L3], .34, 2.6)

def song_tarde():
    """a tarde no bosque: harpa e clarinete; depois violão e baixo; depois flauta e xilofone"""
    bpm = 92
    spb = 60 / bpm
    prog = [[c] for c in 'D G D A D Bm G A G D Em A D G A D'.split()]
    evs = events(prog, 4)
    secs = 16 * 4 * spb
    L1, L2, L3 = Track(secs), Track(secs), Track(secs)
    for b, d, c in evs:
        ch = chord(c, 3)
        t = b * spb
        L1.note('cello', ch[0] - 12, t, 4 * spb * .98, .3, .6)
        pat = [ch[0], ch[1], ch[2], ch[0] + 12, ch[1] + 12, ch[0] + 12, ch[2], ch[1]]
        for k, m in enumerate(pat):
            L1.note('harp', m + 12, t + k * spb / 2, spb, .24, 1.0)
    cl = mel('F#4:2 A4:1 B4:1 | A4:3 r:1 | F#4:1 E4:1 D4:1 E4:1 | F#4:4 | '
             'F#4:2 A4:1 B4:1 | D5:1 C#5:1 B4:1 A4:1 | B4:2 A4:1 F#4:1 | A4:4 | '
             'B4:2 D5:1 C#5:1 | B4:2 A4:2 | G4:1 F#4:1 E4:1 F#4:1 | E4:4 | '
             'F#4:2 A4:1 B4:1 | A4:1 F#4:1 E4:1 D4:1 | E4:2 F#4:1 E4:1 | D4:4', 4)
    play_mel(L1, 'clarinet', cl, spb, vel=.45, legato=.96, rel=.35)
    for i, (b, d, c) in enumerate(evs):
        t = b * spb
        L2.note('contrabass', chord(c, 2)[0], t, spb * .6, .42, .15)
        L2.note('contrabass', five(c), t + 2 * spb, spb * .6, .36, .15)
        for k, v in ((0, .22), (1.5, .17), (2, .2), (3.5, .17)):
            strum(L2, 'guitar-nylon', chord(c, 4), t + k * spb, spb * .4, v, .25)
        hits(L2, p_kick(), [b, b + 2], spb, vel=.38)
        hits(L2, p_brush(), [b + 1, b + 3], spb, vel=.55, wet=True)
    play_mel(L3, 'flute', harm(cl, evs, True, 1), spb, vel=.26, legato=.92, rel=.3)
    for i, (b, d, c) in enumerate(evs):
        ch = chord(c, 5)
        if i % 2 == 1:
            for k, m in enumerate([ch[0], ch[1], ch[2], ch[0] + 12]):
                L3.note('xylophone', m, (b + 2 + k * .5) * spb, .3, .13, .4)
        hits(L3, p_tamb(), [b + 1, b + 3], spb, pan=.35, vel=.5, wet=True)
        hits(L3, p_shaker(), [b + k * .5 for k in range(8)], spb, pan=-.35, vel=.6, wet=True)
    return render_stems([L1, L2, L3], .3, 2.2)

def song_chuva():
    """o pântano, o lago e o rio (Ep. 1): uma dança saltitante de sapos e gotas, em Fá maior"""
    bpm = 112
    spb = 60 / bpm
    prog = bars('F F C C Dm Bb C F  F F C C Dm Bb Bb.C F  Bb Bb F F Gm C F.Dm Gm.C  F F C C Dm Bb Bb.C F')
    evs = events(prog, 4)
    secs = 32 * 4 * spb
    A1 = ('C5:.5 A4:.5 C5:.5 A4:.5 F5:1 r:.5 E5:.5 | D5:.5 C5:.5 A4:.5 F4:.5 G4:1 A4:1 | '
          'G4:.5 E4:.5 G4:.5 C5:.5 E5:1 r:.5 D5:.5 | C5:.5 Bb4:.5 G4:.5 E4:.5 G4:2 | ')
    ma = mel(A1 + 'A4:.5 D5:.5 F5:.5 D5:.5 A4:1 D5:1 | D5:.5 F5:.5 D5:.5 Bb4:.5 F4:1 D5:1 | '
             'E5:.75 D5:.25 C5:.5 Bb4:.5 A4:.5 G4:.5 E4:1 | F4:1 A4:.5 C5:.5 F5:1.5 r:.5', 4)
    ma2 = mel(A1 + 'F5:.5 E5:.5 D5:.5 A4:.5 F5:1 E5:1 | D5:.5 C5:.5 Bb4:.5 D5:.5 F5:2 | '
              'G5:1 F5:.5 E5:.5 D5:.5 E5:.5 C5:1 | F5:1 C5:.5 A4:.5 F4:1 r:1', 4)
    mb = mel('F5:1.5 D5:.5 Bb4:1 D5:1 | F5:.5 G5:.5 F5:.5 D5:.5 Bb4:2 | A5:1.5 F5:.5 C5:1 F5:1 | '
             'A5:.5 Bb5:.5 A5:.5 F5:.5 C5:2 | G5:1 Bb5:1 A5:.5 G5:.5 F5:.5 D5:.5 | E5:1 G5:1 C6:1.5 Bb5:.5 | '
             'A5:1 C6:.5 A5:.5 F5:1 D5:1 | Bb4:1 D5:.5 G5:.5 E5:1 C5:1', 4)
    L1, L2, L3 = Track(secs), Track(secs), Track(secs)
    play_mel(L1, 'clarinet', ma, spb, vel=.5, legato=.82, rel=.12)
    play_mel(L1, 'clarinet', shift(ma2, 32), spb, vel=.5, legato=.82, rel=.12)
    play_mel(L1, 'flute', shift(mb, 64), spb, vel=.5, legato=.9, rel=.2)
    play_mel(L1, 'clarinet', shift(ma2, 96), spb, vel=.5, legato=.82, rel=.12)
    for b, d, c in evs:                                       # baixo pulando e violão no contratempo
        t = b * spb
        r = chord(c, 2)[0]
        L1.note('contrabass', r, t, spb * .45, .55, .08)
        if d >= 4:
            L1.note('contrabass', five(c), t + 2 * spb, spb * .45, .48, .08)
        for k in range(int(d)):
            strum(L1, 'guitar-nylon', chord(c, 4), t + (k + .5) * spb, spb * .3, .25 + (.05 if k % 2 else 0), .12, .005)
        hits(L1, p_shaker(), [b + k * .5 for k in range(int(d * 2))], spb, pan=.4, vel=.55, wet=True)
    for bb in (7, 15, 23, 31):                                 # harpa escorrendo no fim das frases
        ch = chord(chord_at(evs, bb * 4 + 2), 4)
        for k, m in enumerate([ch[0], ch[1], ch[2], ch[0] + 12, ch[1] + 12, ch[2] + 12, ch[0] + 24, ch[1] + 24]):
            L1.note('harp', m, (bb * 4 + 2 + k * .25) * spb, .6, .17, 1.0)
    # 2: bateria leve, piano no contratempo, gotas de xilofone e o fagote "sapo"
    for i, (b, d, c) in enumerate(evs):
        t = b * spb
        hits(L2, p_kick(), [b] + ([b + 2] if d >= 4 else []), spb, vel=.5)
        for k in range(int(d)):
            if (b + k) % 2 == 1:
                hits(L2, p_rim(), [b + k], spb, pan=-.15, vel=.6, wet=True)
                strum(L2, 'piano', chord(c, 4), t + k * spb, spb * .22, .17, .1, .004)
        ch = chord(c, 5)
        hits_x = [(1.75, ch[2]), (3.75, ch[1] + 12)] if d >= 4 else [(d - .25, ch[2])]
        for o, m in hits_x:
            L2.note('xylophone', m, t + o * spb, .25, .16, .4)
        if 64 > b or b >= 96:                                  # o sapo: fagote saltitante nas partes A
            for k in range(int(d)):
                m = chord(c, 3)[[0, 2, 1, 2][k % 4]]
                L2.note('bassoon', m, t + k * spb, spb * .35, .3 + (.06 if k == 0 else 0), .08)
    # 3: segunda voz no violino, trompas, pandeiro e corrida de xilofone na parte B
    play_mel(L3, 'violin', harm(ma, evs, True), spb, vel=.26, legato=.82, rel=.12)
    play_mel(L3, 'violin', harm(shift(ma2, 32), evs, True), spb, vel=.26, legato=.82, rel=.12)
    play_mel(L3, 'violin', harm(shift(mb, 64), evs, False), spb, vel=.28, legato=.9, rel=.2)
    play_mel(L3, 'flute', shift(ma2, 96), spb, vel=.3, legato=.82, octave=1, rel=.12)
    for i, (b, d, c) in enumerate(evs):
        t = b * spb
        ch = chord(c, 3)
        if b % 4 == 0:
            L3.note('french-horn', ch[0], t, spb * 1.8, .16, .3)
            L3.note('french-horn', ch[2], t, spb * 1.8, .12, .3)
        hits(L3, p_tamb(), [b + k for k in range(int(d)) if (b + k) % 2 == 1], spb, pan=.3, vel=.55, wet=True)
        hits(L3, p_shaker(), [b + k * .25 for k in range(int(d * 4))], spb, pan=-.4, vel=.45, wet=True)
        if 64 <= b < 96:
            c5 = chord(c, 5)
            for k in range(int(d * 2)):
                L3.note('xylophone', [c5[0], c5[1], c5[2], c5[1]][k % 4], t + k * spb / 2, .2, .1, .3)
    return render_stems([L1, L2, L3], .26, 1.9)

def song_noite():
    """a noite: flauta e harpa; depois o pulso (pizzicato, tímpano baixinho); depois contracanto e brilho"""
    bpm, bar = 64, 3
    spb = 60 / bpm
    prog = [[c] for c in 'Em C Em B Em C Em B Am G C B Em C B Em'.split() * 2]
    evs = events(prog, bar)
    secs = 32 * bar * spb
    fl = mel('G4:2 B4:1 | C5:2 B4:1 | G4:1 F#4:1 E4:1 | F#4:3 | G4:2 B4:1 | C5:1 E5:1 D5:1 | C5:1 B4:1 G4:1 | B4:3 | '
             'C5:2 E5:1 | D5:2 B4:1 | C5:1 B4:1 G4:1 | F#4:3 | G4:2 B4:1 | C5:1 B4:1 G4:1 | F#4:1 G4:1 F#4:1 | E4:3', 3)
    L1, L2, L3 = Track(secs), Track(secs), Track(secs)
    play_mel(L1, 'flute', fl, spb, vel=.4, legato=.97, rel=.4)
    play_mel(L1, 'clarinet', shift(fl, 16 * bar), spb, vel=.4, legato=.95, rel=.35)
    play_mel(L1, 'xylophone', fl[:8], spb, vel=.08, octave=1, rel=.5)
    for i, (b, d, c) in enumerate(evs):
        ch = chord(c, 3)
        t = b * spb
        L1.note('contrabass', ch[0] - 12, t, bar * spb * .95, .3, .6)
        for k, idx in enumerate([0, 1, 2, 1, 2, 1]):
            L1.note('harp', ch[idx] + (12 if k >= 2 else 0), t + k * spb / 2, spb, .22, 1.4)
    for i, (b, d, c) in enumerate(evs):
        ch = chord(c, 3)
        t = b * spb
        L2.note('cello', ch[0], t, spb * .4, .34, .12)
        L2.note('cello', ch[2], t + 2 * spb, spb * .4, .26, .12)
        for k, v in ((1, .16), (2, .14)):
            strum(L2, 'guitar-nylon', chord(c, 4), t + k * spb, spb * .5, v, .3)
        hits(L2, p_timp(chord(c, 2)[0]), [b], spb, vel=.55)
        hits(L2, p_shaker(), [b + k * .5 for k in range(6)], spb, pan=.4, vel=.5, wet=True)
    play_mel(L3, 'violin', harm(fl, evs, True), spb, vel=.2, legato=.95, rel=.3)
    play_mel(L3, 'flute', harm(shift(fl, 16 * bar), evs, True), spb, vel=.24, legato=.95, rel=.3)
    for i, (b, d, c) in enumerate(evs):
        c5 = chord(c, 5)
        t = b * spb
        seq = [c5[0], c5[1], c5[2], c5[0] + 12, c5[2], c5[1]]
        for k in range(12):
            L3.note('xylophone', seq[k % 6], t + k * spb / 4, .2, .085 + (.03 if k % 4 == 0 else 0), .3)
        hits(L3, p_kick(), [b], spb, vel=.38)
        hits(L3, p_brush(), [b + 1, b + 2], spb, vel=.5, wet=True)
        hits(L3, p_tamb(), [b + 1.5, b + 2.5], spb, pan=-.3, vel=.35, wet=True)
        if i % 2 == 0:
            L3.note('french-horn', chord(c, 3)[0], t, 2 * bar * spb * .9, .12, .5)
    return render_stems([L1, L2, L3], .45, 3.2)

def song_tunel():
    """o túnel e a mina: grave e misterioso; depois um pulso de coração; depois a aventura (cordas em semicolcheias)"""
    bpm = 56
    spb = 60 / bpm
    secs = 16 * 4 * spb
    L1, L2, L3 = Track(secs), Track(secs), Track(secs)
    bs = mel('D3:2 F3:2 | E3:4 | D3:2 C3:2 | D3:4 | F3:2 G3:1 F3:1 | E3:4 | D3:2 C#3:2 | D3:4', 4)
    cl = mel('A4:2 F4:2 | G4:3 F4:.5 E4:.5 | F4:2 A4:2 | D5:4 | C5:2 A4:2 | C5:2 G4:2 | A4:2 E4:2 | D4:4', 4)
    for i in range(16):
        t = i * 4 * spb
        L1.note('cello', P('D2'), t, 4 * spb, .32, 1.0)
        if i % 2 == 1:
            L1.note('cello', P('A2'), t + spb * 2, 2 * spb, .22, 1.0)
    play_mel(L1, 'bassoon', bs, spb, vel=.36, legato=.95, rel=.5)
    play_mel(L1, 'bassoon', shift(bs, 32), spb, vel=.34, legato=.95, rel=.5)
    play_mel(L1, 'clarinet', shift(bs, 32), spb, vel=.14, legato=.95, octave=1, rel=.5)
    for k, (b, m) in enumerate([(3, 'Eb6'), (9.5, 'A5'), (14, 'D6'), (21, 'Bb5'), (27.5, 'E6'), (37, 'A5'), (45.5, 'D6'), (54, 'F5')]):
        L1.note('harp', P(m), b * spb, 1, .14, 2)
    for b in (0, 32):
        for m in ('D2', 'A2', 'Eb3'):
            L1.note('piano', P(m), b * spb, 3 * spb, .2, 1.5)
    ost = ['D2', 'D2', 'A2', 'D3', 'D2', 'D2', 'A2', 'C3']
    for i in range(16):
        t = i * 4 * spb
        for k, m in enumerate(ost):
            L2.note('contrabass', P(m), t + k * spb / 2, spb * .38, .4 + (.08 if k % 4 == 0 else 0), .1)
        hits(L2, p_timp(P('D2')), [i * 4, i * 4 + 2], spb, vel=.5)
        hits(L2, p_shaker(), [i * 4 + k * .5 for k in range(8)], spb, pan=.35, vel=.45, wet=True)
    play_mel(L2, 'clarinet', cl, spb, vel=.3, legato=.9, rel=.3)
    c16 = ['D3', 'D3', 'F3', 'D3', 'E3', 'D3', 'C3', 'D3', 'D3', 'D3', 'A3', 'D3', 'G3', 'F3', 'E3', 'C#3']
    for i in range(16):
        t = i * 4 * spb
        for k, m in enumerate(c16):
            L3.note('cello', P(m), t + k * spb / 4, spb * .14, .24 + (.07 if k % 4 == 0 else 0), .05)
        hits(L3, p_kick(), [i * 4, i * 4 + 1.5, i * 4 + 2, i * 4 + 3.5], spb, vel=.4)
        hits(L3, p_rim(), [i * 4 + 1, i * 4 + 3], spb, pan=-.2, vel=.55, wet=True)
        hits(L3, p_shaker(), [i * 4 + k * .25 for k in range(16)], spb, pan=-.35, vel=.35, wet=True)
        for k, m in enumerate(['D6', 'A5', 'F5', 'A5']):
            L3.note('harp', P(m), t + (k + .5) * spb, .4, .09, .8)
    play_mel(L3, 'violin', shift(cl, 32), spb, vel=.24, legato=.9, octave=1, rel=.3)
    play_mel(L3, 'french-horn', shift(bs, 0), spb, vel=.14, legato=.95, octave=0, rel=.4)
    return render_stems([L1, L2, L3], .55, 3.6)

# ----------------------------------------------------------------- trechos especiais (uma faixa animada cada)
def song_cavalo():
    """a cavalgada na neve: galope em 2/4 (colcheia + duas semicolcheias), trompete heroico, cascos de madeira"""
    bpm = 144
    spb = 60 / bpm
    prog = bars('A A D A A A E E A A D D E E A A  F#m F#m D D A A E E D E A F#m D E A A')
    evs = events(prog, 2)
    T = Track(32 * 2 * spb)
    ma = mel('E5:.5 C#5:.25 E5:.25 A5:1 | E5:.5 C#5:.25 E5:.25 A5:1 | F#5:.5 D5:.25 F#5:.25 A5:.5 F#5:.5 | E5:1 C#5:1 | '
             'A4:.5 C#5:.5 E5:.5 A5:.5 | G#5:.5 F#5:.5 E5:1 | B4:.5 D5:.5 E5:.5 G#5:.5 | B5:1.5 r:.5 | '
             'E5:.5 C#5:.25 E5:.25 A5:1 | B5:.5 A5:.5 F#5:.5 E5:.5 | D5:.5 F#5:.5 A5:1 | F#5:.5 E5:.5 D5:.5 F#5:.5 | '
             'E5:.5 G#5:.5 B5:1 | A5:.5 G#5:.5 F#5:.5 D5:.5 | C#5:1 E5:.5 A5:.5 | A5:1.5 r:.5', 2)
    mb = mel('C#6:1 A5:.5 F#5:.5 | C#6:.5 B5:.5 A5:.5 F#5:.5 | D6:1 A5:.5 F#5:.5 | A5:.5 B5:.5 A5:.5 F#5:.5 | '
             'E5:.5 A5:.5 C#6:1 | B5:.5 A5:.5 E5:1 | G#5:1 B5:.5 G#5:.5 | E5:.5 F#5:.5 G#5:.5 B5:.5 | '
             'A5:1 F#5:1 | B5:1 G#5:1 | C#6:.5 B5:.5 A5:.5 E5:.5 | F#5:1 C#5:1 | '
             'D6:.5 C#6:.5 B5:.5 A5:.5 | B5:.5 C#6:.5 B5:.5 G#5:.5 | A5:2 | A5:1 E5:.25 F#5:.25 G#5:.25 B5:.25', 2)
    play_mel(T, 'trumpet', ma, spb, vel=.5, legato=.85, rel=.12)
    play_mel(T, 'violin', ma, spb, vel=.22, legato=.85, rel=.12, octave=-1)
    play_mel(T, 'violin', shift(mb, 32), spb, vel=.5, legato=.88, rel=.12)
    play_mel(T, 'flute', shift(mb, 32), spb, vel=.26, legato=.88, rel=.12)
    for i, (b, d, c) in enumerate(evs):
        t = b * spb
        ch3 = chord(c, 3)
        for k in range(2):                                     # o galope: ta-taca, ta-taca
            m = ch3[0] if k == 0 else ch3[2]
            for o, v in ((0, .42), (.5, .3), (.75, .32)):
                T.note('cello', m, t + (k + o) * spb, spb * .16, v, .05)
            T.note('contrabass', chord(c, 2)[0] if k == 0 else five(c), t + k * spb, spb * .4, .5, .08)
            hits(T, p_block(980 if k == 0 else 820), [b + k, b + k + .5, b + k + .75], spb, pan=-.35 + .7 * k, vel=.7)
        hits(T, p_kick(), [b], spb, vel=.6)
        hits(T, p_snare(), [b + 1], spb, vel=.5, wet=True)
        if b >= 32:                                            # trompas e acordes na parte B
            for m in ch3:
                T.note('french-horn', m, t, spb * 1.7, .2, .3)
        else:
            strum(T, 'piano', chord(c, 4), t + .5 * spb, spb * .25, .16, .1)
            strum(T, 'piano', chord(c, 4), t + 1.5 * spb, spb * .25, .16, .1)
        if i % 8 == 7:                                         # rufar no fim da frase
            hits(T, p_snare(), [b + 1 + k * .125 for k in range(8)], spb, vel=.3, wet=True)
        if i % 4 == 0:
            T.raw(p_timp(chord(c, 2)[0]) * .8, t)
            hits(T, p_jingle(), [b], spb, pan=.4, vel=.5, wet=True)
    return T.render(.2, 1.6)

def song_treno():
    """o trenó: valsa ligeira em Fá com guizos o tempo todo, baixo e acordes no 'pum-tchá-tchá'"""
    bpm = 176
    spb = 60 / bpm
    prog = bars('F F C7 C7 C7 C7 F F F F Bb Bb F C7 F F  Bb Bb F F C7 C7 F F Bb Bb F Dm Gm C7 F F')
    evs = events(prog, 3)
    T = Track(32 * 3 * spb)
    mm = mel('C5:2 F5:1 | A5:2 G5:1 | E5:2 G5:1 | Bb5:2 A5:1 | G5:1 E5:1 C5:1 | D5:1 E5:1 G5:1 | F5:3 | A5:1 G5:1 F5:1 | '
             'C6:2 A5:1 | F5:2 C5:1 | D5:1 F5:1 Bb5:1 | D6:2 Bb5:1 | A5:1 C6:1 A5:1 | G5:1 Bb5:1 E5:1 | F5:3 | F5:1 r:1 C5:1 | '
             'D5:2 F5:1 | Bb5:2 A5:1 | A5:2 C5:1 | F5:2 E5:1 | E5:1 G5:1 Bb5:1 | C6:2 Bb5:1 | A5:1 F5:1 C5:1 | A5:3 | '
             'D6:2 Bb5:1 | F5:2 D5:1 | C6:2 A5:1 | F5:2 D5:1 | G5:1 Bb5:1 D6:1 | C6:1 Bb5:1 G5:1 | F5:3 | r:1 C5:1 E5:1', 3)
    play_mel(T, 'flute', mm, spb, vel=.5, legato=.9, rel=.15)
    play_mel(T, 'violin', mm, spb, vel=.24, legato=.9, rel=.15, octave=-1)
    play_mel(T, 'xylophone', [n for n in mm if 24 <= n[0] < 48 or n[0] >= 72], spb, vel=.16, legato=.5, rel=.3)
    for i, (b, d, c) in enumerate(evs):
        t = b * spb
        T.note('contrabass', chord(c, 2)[0] if i % 2 == 0 else five(c), t, spb * .7, .52, .1)
        for k in (1, 2):
            strum(T, 'guitar-nylon', chord(c, 4)[:3], t + k * spb, spb * .4, .22, .12, .005)
            strum(T, 'harp', [x + 12 for x in chord(c, 4)[:3]], t + k * spb, spb * .3, .12, .3, .004)
        hits(T, p_jingle(), [b], spb, pan=.25, vel=.75, wet=True)
        hits(T, p_jingle(), [b + 1, b + 2], spb, pan=.25, vel=.45, wet=True)
        hits(T, p_jingle(v=.6, n_bells=3, secs=.2), [b + .5, b + 1.5, b + 2.5], spb, pan=.35, vel=.35, wet=True)
        hits(T, p_kick(), [b], spb, vel=.45)
        hits(T, p_brush(), [b + 1, b + 2], spb, vel=.5, wet=True)
        if i % 4 == 0:
            hits(T, p_triangle(), [b], spb, pan=-.4, vel=.6, wet=True)
        if i >= 16 and i % 2 == 0:
            T.note('french-horn', chord(c, 3)[0], t, spb * 2.6, .15, .3)
            T.note('french-horn', chord(c, 3)[1], t, spb * 2.6, .11, .3)
    return T.render(.24, 1.8)

def song_jangada():
    """a jangada no rio: dança de rabeca (violino) com sanfona (harmônio), violão, pandeiro e bumbo de remada"""
    bpm = 132
    spb = 60 / bpm
    prog = bars('G G C G G G D D G G C C D D G G  Em Em C C G G D D')
    evs = events(prog, 4)
    T = Track(24 * 4 * spb)
    mv = mel('D5:.5 B4:.5 G4:.5 B4:.5 D5:1 G5:1 | F#5:.5 G5:.5 A5:.5 G5:.5 D5:1 B4:1 | C5:.5 E5:.5 G5:.5 E5:.5 C6:1 G5:1 | '
             'B5:.5 A5:.5 G5:.5 F#5:.5 G5:2 | D5:.5 B4:.5 G4:.5 B4:.5 D5:1 G5:1 | B5:.5 A5:.5 G5:.5 B5:.5 D6:1 B5:1 | '
             'A5:.5 F#5:.5 D5:.5 F#5:.5 A5:1 D6:1 | C6:.5 A5:.5 F#5:.5 A5:.5 D5:2 | '
             'D5:.5 B4:.5 G4:.5 B4:.5 D5:1 G5:1 | F#5:.5 G5:.5 A5:.5 B5:.5 C6:.5 B5:.5 A5:.5 G5:.5 | '
             'E5:.5 G5:.5 C6:.5 G5:.5 E5:1 C6:1 | B5:.5 C6:.5 E6:.5 C6:.5 G5:2 | F#5:.5 A5:.5 D6:.5 A5:.5 F#5:1 A5:1 | '
             'C6:.5 B5:.5 A5:.5 F#5:.5 D5:1 F#5:1 | G5:.5 A5:.5 B5:.5 D6:.5 B5:.5 A5:.5 G5:.5 B5:.5 | G5:2 r:1 D5:1 | '
             'E5:1 G5:.5 B5:.5 E6:1 B5:1 | D6:.5 C6:.5 B5:.5 A5:.5 G5:1 E5:1 | C6:1 E5:.5 G5:.5 C6:1 G5:1 | '
             'B5:.5 A5:.5 G5:.5 E5:.5 C5:2 | D5:1 G5:.5 B5:.5 D6:1 B5:1 | A5:.5 B5:.5 C6:.5 B5:.5 G5:1 D5:1 | '
             'F#5:.5 G5:.5 A5:.5 F#5:.5 D5:.5 E5:.5 F#5:.5 A5:.5 | D6:1.5 C6:.5 A5:.5 F#5:.5 D5:1', 4)
    play_mel(T, 'violin', mv, spb, vel=.52, legato=.8, rel=.1)
    play_mel(T, 'flute', [n for n in mv if n[0] >= 64], spb, vel=.24, legato=.8, rel=.1)
    for i, (b, d, c) in enumerate(evs):
        t = b * spb
        L = chord(c, 4)
        T.note('contrabass', chord(c, 2)[0], t, spb * .55, .52, .1)
        T.note('contrabass', five(c), t + 2 * spb, spb * .55, .46, .1)
        for k in range(8):                                     # violão de aço em colcheias (pra baixo e pra cima)
            dn = k % 2 == 0
            strum(T, 'guitar-acoustic', L if dn else L[::-1], t + k * spb / 2, spb * .35, .2 if dn else .13, .1, .006)
        for k in (1, 3):                                       # a sanfona no 2 e no 4
            for m in chord(c, 3):
                T.note('harmonium', m + 12, t + k * spb, spb * .45, .16, .1)
        if b >= 64:
            for m in chord(c, 3)[:2]:
                T.note('harmonium', m, t, spb * 3.8, .1, .3)
        hits(T, p_kick(), [b, b + 2], spb, vel=.58)
        hits(T, p_snare(), [b + 1, b + 3], spb, vel=.45, wet=True)
        hits(T, p_tamb(), [b + k * .5 for k in range(8)], spb, pan=.35, vel=.38, wet=True)
        if i % 4 == 3:
            hits(T, p_timp(chord(c, 2)[0]), [b + 3, b + 3.5], spb, vel=.6)
    return T.render(.22, 1.7)

def song_voo():
    """o voo: céu aberto em Dó — piano em arpejos, flauta e violino planando, bateria leve"""
    bpm = 116
    spb = 60 / bpm
    prog = bars('C G Am F C G F G  F G Em Am F G C C  Am Em F C Dm G C G')
    evs = events(prog, 4)
    T = Track(24 * 4 * spb)
    mf = mel('E5:1.5 G5:.5 C6:2 | B5:1 A5:.5 G5:.5 D5:2 | C6:1.5 B5:.5 A5:1 E5:1 | F5:1 A5:1 C6:2 | '
             'G5:1.5 E5:.5 C5:1 E5:1 | D5:1 G5:1 B5:2 | A5:1 C6:.5 A5:.5 F5:1 A5:1 | G5:3 r:1 | '
             'A5:2 C6:1 A5:1 | B5:2 D6:1 B5:1 | G5:1 B5:1 E6:1 D6:1 | C6:3 B5:.5 A5:.5 | '
             'A5:1.5 G5:.5 F5:1 A5:1 | G5:1.5 F5:.5 D5:1 B4:1 | C5:1 E5:1 G5:1 C6:1 | E6:2 D6:1 C6:1 | '
             'E5:2 A5:2 | G5:2 B5:2 | A5:1 C6:1 F6:2 | E6:2 C6:1 G5:1 | F5:1 A5:1 D6:1 C6:1 | B5:1.5 A5:.5 G5:1 F5:1 | '
             'E5:1 G5:1 C6:1 E6:1 | D6:2 B5:1 G5:1', 4)
    play_mel(T, 'flute', mf, spb, vel=.5, legato=.95, rel=.3)
    play_mel(T, 'violin', [n for n in mf if n[0] >= 32], spb, vel=.3, legato=.95, rel=.3, octave=-1)
    play_mel(T, 'trumpet', [n for n in mf if n[0] >= 64], spb, vel=.18, legato=.9, rel=.2, octave=-1)
    for i, (b, d, c) in enumerate(evs):
        t = b * spb
        ch = chord(c, 4)
        arp = [chord(c, 3)[0], ch[0], ch[1], ch[2], ch[0] + 12, ch[2], ch[1], ch[0]]
        for k, m in enumerate(arp):
            T.note('piano', m, t + k * spb / 2, spb * .6, .26 + (.06 if k == 0 else 0), .4)
        T.note('cello', chord(c, 2)[0] + 12, t, 4 * spb * .95, .2, .4)
        T.note('violin', ch[1] + 12, t, 4 * spb * .95, .07, .5)
        T.note('contrabass', chord(c, 2)[0], t, spb * .7, .5, .1)
        T.note('contrabass', chord(c, 2)[0], t + 2.5 * spb, spb * .4, .4, .1)
        T.note('contrabass', five(c), t + 3 * spb, spb * .7, .42, .1)
        hits(T, p_kick(), [b, b + 2.5], spb, vel=.5)
        hits(T, p_clap(), [b + 1, b + 3], spb, vel=.55, wet=True)
        hits(T, p_shaker(), [b + k * .5 for k in range(8)], spb, pan=.35, vel=.7, wet=True)
        if i % 8 == 0:                                         # rajada de harpa: o avião subindo
            for k, m in enumerate(sorted(set([x + 12 * o for o in (0, 1, 2) for x in chord(c, 4)]))):
                T.note('harp', m, t - spb + k * spb / 9, .7, .16, 1)
            hits(T, p_triangle(), [b], spb, pan=-.3, vel=.5, wet=True)
    return T.render(.3, 2.2)

def song_carrinho():
    """o carrinho da mina (Ep. 2): polca ligeira em Lá menor com violão 'pum-tchá', rabeca correndo,
    trem de escovinhas em semicolcheias e pancadas de trilho"""
    bpm = 168
    spb = 60 / bpm
    prog = bars('Am Am E E E E Am Am Am Am Dm Dm Am E Am Am  C C G G G G C C F F C Am Dm E Am Am')
    evs = events(prog, 4)
    T = Track(32 * 4 * spb)
    mv = mel('A4:.5 B4:.5 C5:.5 E5:.5 A5:1 E5:1 | C5:.5 E5:.5 A5:.5 E5:.5 C5:.5 B4:.5 A4:1 | '
             'G#4:.5 B4:.5 E5:.5 B4:.5 G#5:1 E5:1 | D5:.5 E5:.5 F5:.5 E5:.5 D5:.5 B4:.5 G#4:1 | '
             'B4:.5 G#4:.5 E4:.5 G#4:.5 B4:.5 D5:.5 E5:.5 G#5:.5 | B5:1 A5:.5 G#5:.5 F5:.5 E5:.5 D5:.5 B4:.5 | '
             'C5:.5 E5:.5 A5:.5 B5:.5 C6:1 A5:1 | E5:.5 C5:.5 A4:.5 C5:.5 A4:2 | '
             'A5:.5 G#5:.5 A5:.5 E5:.5 C5:.5 E5:.5 A5:.5 C6:.5 | B5:.5 A5:.5 G#5:.5 A5:.5 E5:2 | '
             'F5:.5 E5:.5 F5:.5 A5:.5 D6:1 A5:1 | F5:.5 D5:.5 A4:.5 D5:.5 F5:1 E5:1 | '
             'C5:.5 E5:.5 A5:.5 E5:.5 C6:1 A5:1 | B5:.5 G#5:.5 E5:.5 G#5:.5 B5:1 G#5:1 | '
             'A5:.5 E5:.5 C5:.5 E5:.5 A4:.5 C5:.5 E5:.5 A5:.5 | A5:2 r:1 E5:.5 G#5:.5 | '
             'G5:.5 E5:.5 C5:.5 E5:.5 G5:1 C6:1 | E6:.5 D6:.5 C6:.5 G5:.5 E5:1 G5:1 | '
             'D5:.5 G5:.5 B5:.5 G5:.5 D6:1 B5:1 | A5:.5 B5:.5 D6:.5 B5:.5 G5:2 | '
             'F5:.5 G5:.5 A5:.5 B5:.5 D6:.5 B5:.5 G5:.5 F5:.5 | D5:.5 F5:.5 G5:.5 B5:.5 D6:2 | '
             'C6:.5 G5:.5 E5:.5 G5:.5 C6:1 E6:1 | D6:.5 C6:.5 B5:.5 C6:.5 G5:2 | '
             'A5:.5 C6:.5 A5:.5 F5:.5 C6:1 A5:1 | F5:.5 G5:.5 A5:.5 C6:.5 A5:2 | '
             'G5:.5 E5:.5 C5:.5 E5:.5 G5:1 C6:1 | E6:.5 C6:.5 A5:.5 C6:.5 E5:2 | '
             'F5:.5 A5:.5 D6:.5 A5:.5 F5:.5 D5:.5 F5:.5 A5:.5 | G#5:.5 B5:.5 E6:.5 B5:.5 G#5:.5 E5:.5 D5:.5 B4:.5 | '
             'C5:.5 E5:.5 A5:.5 C6:.5 B5:.5 G#5:.5 A5:1 | A5:1 r:1 E5:.5 D5:.5 C5:.5 B4:.5', 4)
    play_mel(T, 'violin', mv, spb, vel=.5, legato=.75, rel=.08)
    play_mel(T, 'xylophone', [n for n in mv if n[0] >= 64], spb, vel=.2, legato=.5, rel=.2)
    play_mel(T, 'clarinet', [n for n in mv if 32 <= n[0] < 64 or n[0] >= 96], spb, vel=.22, legato=.75, rel=.08, octave=-1)
    for i, (b, d, c) in enumerate(evs):
        t = b * spb
        T.note('contrabass', chord(c, 2)[0], t, spb * .5, .55, .08)
        T.note('contrabass', five(c), t + 2 * spb, spb * .5, .5, .08)
        T.note('guitar-acoustic', chord(c, 2)[0] + 12, t, spb * .4, .3, .1)
        T.note('guitar-acoustic', five(c) + 12, t + 2 * spb, spb * .4, .28, .1)
        for k in (1, 3):
            strum(T, 'guitar-acoustic', chord(c, 4), t + k * spb, spb * .3, .22, .08, .005)
        hits(T, p_kick(), [b, b + 2], spb, vel=.6)
        hits(T, p_snare(), [b + 1, b + 3], spb, vel=.48, wet=True)
        for k in range(16):                                    # o trem: escovinha em semicolcheias, acento no 2 de cada tempo
            hits(T, p_brush(), [b + k * .25], spb, vel=.35 + (.25 if k % 4 == 2 else 0), hum=.002)
        if i % 2 == 0:
            hits(T, p_anvil(), [b], spb, pan=.4, vel=.9, wet=True)
        if i % 8 == 7:
            for k in range(4):
                T.raw(p_timp(chord(c, 2)[0] + [7, 5, 3, 0][k]) * .7, t + (2 + k * .5) * spb)
    return T.render(.2, 1.5)

# ----------------------------------------------------------------- ambientes (loops)
def lp(x, fc):
    a = np.exp(-2 * np.pi * fc / SR)
    from scipy.signal import lfilter
    return lfilter([1 - a], [1, -a], x)

def amb(name, secs, fill, wet=.25, room=1.6):
    T = Track(secs)
    fill(T, secs)
    save_ogg('amb_' + name, T.render(wet, room), 2)

def chirp(f0, f1, d, vib=0):
    n = int(d * SR); t = np.arange(n) / SR
    f = np.linspace(f0, f1, n) + vib * np.sin(2 * np.pi * 30 * t) * 300
    e = np.sin(np.pi * np.arange(n) / n) ** 2
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * e

def fill_birds(T, secs):
    wind = lp(rng.standard_normal(int(secs * SR)), 400) * .06
    T.raw(wind, 0, 0, True)
    t = .3
    while t < secs - 1:
        pan = rng.uniform(-.8, .8)
        kind = rng.integers(3)
        for k in range(rng.integers(2, 6)):
            if kind == 0:
                y = chirp(3200, 4600, .06)
            elif kind == 1:
                y = chirp(5200, 2800, .09)
            else:
                y = chirp(2600, 2700, .12, 1)
            T.raw(y * rng.uniform(.05, .12), t + k * rng.uniform(.08, .14), pan, False)
        t += rng.uniform(.6, 1.8)

def fill_crickets(T, secs):
    for c in range(4):
        f = rng.uniform(3900, 4900)
        rate = rng.uniform(.55, .9)
        pan = rng.uniform(-.9, .9)
        t = rng.uniform(0, rate)
        while t < secs - .3:
            for k in range(3):
                n = int(.035 * SR); tt = np.arange(n) / SR
                y = np.sin(2 * np.pi * f * tt) * np.sin(np.pi * np.arange(n) / n) * .05
                T.raw(y, t + k * .05, pan, False)
            t += rate
    T.raw(lp(rng.standard_normal(int(secs * SR)), 300) * .05, 0, 0, True)

def fill_frogs(T, secs):
    t = .2
    while t < secs - 1:
        f = rng.uniform(150, 260)
        n = int(rng.uniform(.18, .32) * SR); tt = np.arange(n) / SR
        pulse = (np.sin(2 * np.pi * 28 * tt) > 0).astype(float)
        saw = 2 * ((f * tt) % 1) - 1
        y = lp(saw * pulse, 900) * np.sin(np.pi * np.arange(n) / n) * .2
        T.raw(y, t, rng.uniform(-.8, .8), False)
        if rng.random() < .5:
            T.raw(y * .7, t + .35, rng.uniform(-.8, .8), False)
        t += rng.uniform(.9, 2.4)
    T.raw(lp(rng.standard_normal(int(secs * SR)), 250) * .05, 0, 0, True)

def fill_wind(T, secs):
    n = int(secs * SR)
    x = lp(rng.standard_normal(n), 500)
    tt = np.arange(n) / SR
    m = .55 + .45 * np.sin(2 * np.pi * tt / secs * 2) * np.sin(2 * np.pi * tt / secs * 3 + 1)
    T.raw(x * m * .16, 0, -.2, True)
    T.raw(lp(rng.standard_normal(n), 1200) * m[::-1] * .05, 0, .3, True)

def fill_cave(T, secs):
    n = int(secs * SR)
    T.raw(lp(lp(rng.standard_normal(n), 120), 120) * .5, 0, 0, True)
    t = .4
    while t < secs - 1:
        d = int(.07 * SR); tt = np.arange(d) / SR
        f0 = rng.uniform(900, 1700)
        f = f0 * np.exp(-tt * 9)
        y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 40) * .25
        T.raw(y, t, rng.uniform(-.7, .7), False)
        t += rng.uniform(.7, 2.2)

# ----------------------------------------------------------------- efeitos com instrumentos
def sfx(name, secs, fill, wet=.2):
    T = Track(secs)
    fill(T)
    save_wav(name, T.render(wet, 1.2, loop=False))

if __name__ == '__main__':
    songs = {'manha': song_manha, 'perseguicao': song_perseguicao, 'vitoria': song_vitoria,
             'cavalo': song_cavalo, 'treno': song_treno, 'jangada': song_jangada, 'voo': song_voo, 'carrinho': song_carrinho}
    # músicas calmas e longas: mus_X (camada 1), mus_X_2 e mus_X_3 (o jogo soma as camadas aos poucos)
    layers = {'tema': song_tema, 'tarde': song_tarde, 'chuva': song_chuva, 'noite': song_noite, 'tunel': song_tunel}
    only = sys.argv[2:] if len(sys.argv) > 2 else None
    for k, f in songs.items():
        if only and k not in only:
            continue
        save_ogg('mus_' + k, f())
    for k, f in layers.items():
        if only and k not in only:
            continue
        layered(k, f)
    if not only or 'amb' in only:
        amb('passaros', 12, fill_birds)
        amb('grilos', 8, fill_crickets)
        amb('sapos', 12, fill_frogs)
        amb('vento', 10, fill_wind, .1)
        amb('caverna', 12, fill_cave, .6, 2.6)
    if not only or 'sfx' in only:
        sfx('clue', 1.6, lambda T: [T.note('harp', P(m), i * .09, .8, .6, 1) for i, m in enumerate(['C5', 'E5', 'G5', 'C6'])])
        sfx('item', .9, lambda T: [T.note('xylophone', P(m), i * .08, .3, .6, .5) for i, m in enumerate(['G5', 'C6', 'E6'])])
        sfx('pen', .5, lambda T: T.note('xylophone', P('C7'), 0, .15, .5, .3))
        sfx('special', 1.8, lambda T: ([T.note('harp', P(m), i * .05, .6, .5, 1) for i, m in enumerate(['C5', 'D5', 'E5', 'G5', 'A5', 'C6', 'D6', 'E6'])],
                                       T.note('xylophone', P('G6'), .45, .4, .5, .6)))
        sfx('door', 2.2, lambda T: ([T.note('french-horn', P(m), 0, 1.2, .5, .6) for m in ('C3', 'G3', 'E4')],
                                    [T.note('harp', P(m), .3 + i * .1, 1, .4, 1) for i, m in enumerate(['C5', 'E5', 'G5', 'C6'])]))
        sfx('combine', 1.0, lambda T: [T.note('guitar-nylon', P(m), i * .025, .7, .6, .4) for i, m in enumerate(['C3', 'G3', 'C4', 'E4', 'G4', 'C5'])])
        sfx('die', 1.8, lambda T: [T.note('piano', P(m), i * .2, .5, .6, 1) for i, m in enumerate(['E4', 'D4', 'C4', 'A3', 'G#3'])])
        sfx('fire', 1.4, lambda T: ([T.note('harp', P(m), i * .07, .6, .45, 1) for i, m in enumerate(['G4', 'C5', 'E5'])],
                                    T.raw(lp(rng.standard_normal(int(.6 * SR)), 900) * np.linspace(.3, 0, int(.6 * SR)), 0)))
