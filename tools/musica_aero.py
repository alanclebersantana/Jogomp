"""Músicas próprias do Cadê as milhas?! (ritmos brasileiros por cidade), com instrumentos gravados
(mesmo motor de tools/make_music.py). Guarulhos: samba-rock e MPB.

  aero_tema     bossa do saguão para os menus (3 camadas)
  gru_saguao    hip hop boom bap do terminal (3 camadas: batida leve, baixo e piano / batida e gancho / batida cheia e cordas)
  gru_seguranca hip hop tenso da área de segurança (3 camadas)
  fiscal        trap da luta com o Fiscal Falso
  seg_luta      trap da luta com os falsos seguranças (mini-chefes: grades fechadas)
  vitoria       samba curto de festa para o placar

Uso: python3 tools/musica_aero.py /tmp/tj [nomes...]
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_music as mm  # noqa: E402
from make_music import (Track, mel, chord, play_mel, strum, hits, p_kick, p_snare, p_clap, p_shaker,  # noqa: E402
                        p_rim, p_brush, p_tamb, p_triangle, p_block, p_timp, P, save_ogg, render_stems, rng)

mm.SRC = sys.argv[1] if len(sys.argv) > 1 else '/tmp/tj'
mm.CH['maj7'] = [0, 4, 7, 11]
mm.CH['m7b5'] = [0, 3, 6, 10]


def baixo_quinta(r):
    return r + 7 if r + 7 < P('A2') else r - 5


def surdo(v=1.0):
    """surdo de samba: tímpano grave e abafado"""
    return p_timp(P('D2'), v * .9)


# ----------------------------------------------------------------- menus: bossa do saguão
def aero_tema():
    """Bossa do menu, ~2 min sem repetir: introdução, A (flauta), A' (xilofone respondendo),
    B (clarinete), ponte em Fá (trompa e violinos), A final com a banda toda e um final que volta
    para o começo. Cada parte troca o instrumento da melodia e o acompanhamento."""
    bpm = 100
    spb = 60 / bpm
    partes = [
        ('intro', 'Dmaj7 Bm7 Em7 A7'),
        ('A', 'Dmaj7 Bm7 Em7 A7 Dmaj7 Bm7 Gmaj7 A7'),
        ('A2', 'Dmaj7 Bm7 Em7 A7 Dmaj7 Bm7 Gmaj7 A7'),
        ('B', 'Gmaj7 Gm7 F#m7 B7 Em7 A7 Dmaj7 D7'),
        ('C', 'Fmaj7 Dm7 Gm7 C7 Fmaj7 Bbmaj7 Em7 A7'),
        ('D', 'Bm7 Em7 Gmaj7 F#m7 Bm7 Em7 Gmaj7 A7'),
        ('B2', 'Gmaj7 Gm7 F#m7 B7 Em7 A7 Dmaj7 D7'),
        ('A3', 'Dmaj7 Bm7 Em7 A7 Dmaj7 Bm7 Gmaj7 A7'),
        ('fim', 'Dmaj7 Gmaj7 Em7 A7'),
    ]
    seq = [(nome, c) for nome, cs in partes for c in cs.split()]
    n = len(seq)
    T1, T2, T3 = Track(n * 4 * spb), Track(n * 4 * spb), Track(n * 4 * spb)
    A = ('A4:1 D5:.5 E5:.5 F#5:1.5 A5:.5 | F#5:1 E5:.5 D5:.5 B4:2 | G4:.5 B4:.5 D5:.5 E5:.5 G5:1 F#5:1 | E5:2 r:1 A4:1 | '
         'A4:1 D5:.5 E5:.5 F#5:1 A5:1 | B5:1.5 A5:.5 F#5:1 D5:1 | E5:.5 F#5:.5 G5:1 B5:1 A5:1 | A5:1 G5:.5 E5:.5 C#5:2')
    A2 = ('D5:.5 F#5:.5 A5:1 r:.5 A5:.5 B5:.5 A5:.5 | F#5:.5 D5:.5 B4:1 r:1 D5:.5 E5:.5 | G5:.5 E5:.5 B4:.5 G5:.5 F#5:1 E5:1 | '
          'C#5:1 E5:1 A5:1.5 r:.5 | D6:.5 C#6:.5 A5:1 F#5:1 A5:1 | B5:.5 A5:.5 F#5:1 D5:1 B4:1 | G5:1 B5:.5 D6:.5 C#6:1 B5:1 | '
          'A5:2 G5:.5 E5:.5 C#5:1')
    B = ('B4:1.5 D5:.5 F#5:2 | Bb4:1.5 D5:.5 F5:2 | A4:1 C#5:1 E5:1.5 F#5:.5 | D#5:2 B4:1 F#4:1 | '
         'G4:1 B4:.5 D5:.5 G5:1 F#5:1 | E5:1 G5:.5 E5:.5 C#5:2 | D5:1 F#5:1 A5:1.5 B5:.5 | A5:1 F#5:.5 E5:.5 C5:2')
    C = ('C5:1 F5:1 A5:1.5 G5:.5 | F5:1 D5:1 A4:2 | Bb4:1 D5:.5 F5:.5 G5:1.5 F5:.5 | E5:2 C5:1 G4:1 | '
         'A4:1 C5:.5 F5:.5 A5:1 C6:1 | D6:1.5 A5:.5 F5:1 D5:1 | E5:1 G5:.5 B5:.5 D6:1 B5:1 | C#6:2 A5:1 E5:1')
    FIM = 'F#5:2 A5:2 | B5:2 G5:1 F#5:1 | E5:2 B4:1 G5:1 | A5:3 r:1'
    # D: piano sozinho, mais calmo (respiro no meio da música)
    D = ('D5:1.5 F#5:.5 B5:2 | G5:1 E5:1 B4:2 | D5:.5 E5:.5 F#5:1 B5:1.5 A5:.5 | A5:1 F#5:1 C#5:2 | '
         'B4:1 D5:1 F#5:1 A5:1 | G5:2 E5:1 B4:1 | F#5:1 A5:.5 B5:.5 D6:1 B5:1 | C#6:1 A5:1 E5:1 C#5:1')
    B2 = ('D5:1 B4:.5 D5:.5 G5:2 | F5:1 D5:.5 Bb4:.5 G4:2 | E5:1.5 C#5:.5 A4:2 | F#5:1 D#5:1 B4:2 | '
          'E5:1 G5:.5 B5:.5 E6:1 D6:1 | C#6:1 A5:.5 G5:.5 E5:2 | F#5:1.5 D5:.5 A5:2 | C6:1 A5:.5 F#5:.5 D5:2')
    bar0 = {}
    k = 0
    for nome, cs in partes:
        bar0[nome] = k
        k += len(cs.split())
    t_of = lambda nome: bar0[nome] * 4 * spb
    # melodias: cada parte com outro instrumento (é isso que tira a sensação de repetição)
    play_mel(T1, 'flute', mel(A, 4), spb, t0=t_of('A'), vel=.4, legato=.92, rel=.3)
    play_mel(T1, 'xylophone', mel(A2, 4), spb, t0=t_of('A2'), vel=.34, legato=.5, rel=.4)
    play_mel(T1, 'flute', mel(A2, 4), spb, t0=t_of('A2'), vel=.12, legato=.9, rel=.2, octave=-1)
    play_mel(T1, 'clarinet', mel(B, 4), spb, t0=t_of('B'), vel=.38, legato=.95, rel=.25)
    play_mel(T1, 'french-horn', mel(C, 4), spb, t0=t_of('C'), vel=.34, legato=.95, rel=.3, octave=-1)
    play_mel(T1, 'violin', mel(C, 4), spb, t0=t_of('C') + 8 * spb, vel=.12, legato=.98, rel=.4)
    play_mel(T1, 'piano', mel(D, 4), spb, t0=t_of('D'), vel=.32, legato=.95, rel=.7)
    play_mel(T1, 'guitar-nylon', mel(B2, 4), spb, t0=t_of('B2'), vel=.36, legato=.9, rel=.4)
    play_mel(T1, 'violin', mel(B2, 4), spb, t0=t_of('B2') + 16 * spb, vel=.1, legato=.98, rel=.5, octave=-1)
    play_mel(T1, 'flute', mel(A, 4), spb, t0=t_of('A3'), vel=.38, legato=.92, rel=.3)
    play_mel(T1, 'violin', mel(A, 4), spb, t0=t_of('A3'), vel=.16, legato=.95, rel=.4, octave=-1)
    play_mel(T1, 'piano', mel(FIM, 4), spb, t0=t_of('fim'), vel=.34, legato=.9, rel=.6)
    for i, (nome, c) in enumerate(seq):
        t = i * 4 * spb
        b = i * 4
        ch3 = chord(c, 3)
        r = chord(c, 2)[0]
        if nome == 'D':
            # só piano e contrabaixo, acordes abertos e longos
            for kk, m in enumerate([ch3[0], ch3[2], ch3[-1] + 12]):
                T1.note('piano', m, t + kk * .33 * spb, 3.5 * spb, .13, .9)
            T1.note('contrabass', r, t, 3.8 * spb, .3, .4)
            continue
        if nome == 'B2':
            for (bt, v) in [(0, .14), (2, .12)]:
                strum(T1, 'harp', chord(c, 3), t + bt * spb, spb * 1.8, v, .4, .03)
            T1.note('contrabass', r, t, 1.8 * spb, .34, .3)
            T1.note('contrabass', baixo_quinta(r), t + 2 * spb, 1.8 * spb, .3, .3)
            hits(T1, p_brush(), [b + kk for kk in range(4)], spb, vel=.25)
            continue
        if nome in ('intro', 'fim'):
            # piano dedilhado e baixo longo, sem bateria
            for kk, m in enumerate([ch3[0], ch3[1] + 12, ch3[2] + 12, ch3[-1] + 12] * 2):
                T1.note('piano', m, t + kk * .5 * spb, spb * 1.2, .2 if kk % 4 else .26, .6)
            T1.note('contrabass', r, t, 3.6 * spb, .36, .3)
            if nome == 'fim' and i == n - 1:
                hits(T1, p_triangle(), [b + 3], spb, vel=.5, wet=True)
            continue
        # baixo: tônica e quinta da bossa, caminhando na parte B
        if nome == 'B':
            for bt, m in [(0, r), (1, r + 7), (2, r + 12), (3, r + 7)]:
                T1.note('contrabass', m, t + bt * spb, .9 * spb, .38, .1)
        else:
            T1.note('contrabass', r, t, 1.4 * spb, .42, .2)
            T1.note('contrabass', baixo_quinta(r), t + 2 * spb, 1.4 * spb, .38, .2)
        if nome in ('A', 'A3', 'A2'):
            for (bt, v) in [(0, .2), (1.5, .18), (2.5, .18), (3.5, .16)]:
                strum(T1, 'guitar-nylon', chord(c, 3), t + bt * spb, spb * .6, v, .2, .012)
            hits(T1, p_brush(), [b + kk * .5 for kk in range(8)], spb, vel=.45)
            hits(T1, p_rim(), [b + .5, b + 1.5, b + 3], spb, pan=-.2, vel=.28)
        if nome in ('A2', 'A3', 'B'):
            for kk in (0, 2):
                T1.note('piano', chord(c, 4)[1], t + (kk + .5) * spb, spb * .4, .12, .4)
                T1.note('piano', chord(c, 4)[-1], t + (kk + .5) * spb, spb * .4, .1, .4)
        if nome == 'A3':
            hits(T1, p_shaker(), [b + kk * .5 for kk in range(8)], spb, pan=.3, vel=.3)
            hits(T1, p_kick(), [b, b + 2.5], spb, vel=.32)
        if nome == 'B':
            for (bt, v) in [(0, .16), (2, .14)]:
                strum(T1, 'guitar-nylon', chord(c, 3), t + bt * spb, spb * 1.5, v, .3, .02)
            hits(T1, p_rim(), [b + 1, b + 2.5, b + 3.5], spb, pan=.2, vel=.3)
            hits(T1, p_brush(), [b + kk for kk in range(4)], spb, vel=.35)
        if nome == 'C':
            # violinos sustentando e harpa em arpejo
            for m in chord(c, 4)[1:]:
                T1.note('violin', m, t, 3.9 * spb, .07, .8)
            for kk, m in enumerate(chord(c, 3) + [chord(c, 3)[0] + 12]):
                T1.note('harp', m, t + kk * .5 * spb, 2 * spb, .2, .8)
                T1.note('harp', m + 12, t + (kk + 4) * .5 * spb, 2 * spb, .16, .8)
            hits(T1, p_kick(), [b], spb, vel=.25)
        if i % 16 == 15:
            hits(T1, p_triangle(), [b + 3], spb, vel=.3, wet=True)
    # camadas 2 e 3 quase vazias: no menu toca a mixagem inteira (ver ACTION no audio.gd)
    T2.note('piano', P('D6'), 0, .1, .0001, .1)
    T3.note('piano', P('D6'), 0, .1, .0001, .1)
    return render_stems([T1, T2, T3], .3, 2.0)


# ----------------------------------------------------------------- HIP HOP (pedido do Alan)
# Fase em hip hop: batida boom bap com balanço (bumbo seco, caixa + palma, chimbal com swing),
# baixo curto e marcado, acordes de piano "lo-fi" e um gancho de flauta/xilofone. Nada de metais,
# surdo ou notas graves longas (era o "buuum" de buzina que irritava). As lutas usam a mesma pegada,
# mais rápida e pesada (chimbal em semicolcheias com rufadas, caixa no 3).
import numpy as np  # noqa: E402
mm.CH['m9'] = [0, 3, 7, 10, 14]
mm.CH['maj9'] = [0, 4, 7, 11, 14]
mm.CH['7b9'] = [0, 4, 7, 10, 13]
SRh = mm.SR


def kick_hh(v=1.0):
    """bumbo de hip hop: curto e seco (sem cauda grave longa)"""
    n = int(.22 * SRh); t = np.arange(n) / SRh
    f = 52 + 95 * np.exp(-t * 38)
    body = np.sin(2 * np.pi * np.cumsum(f) / SRh) * np.exp(-t * 16)
    click = rng.standard_normal(n) * np.exp(-t * 400) * .25
    return (body + click) * v * .95


def snare_hh(v=1.0):
    """caixa gorda: caixa + palma juntas"""
    a = p_snare(v)
    b = p_clap(v)
    n = max(len(a), len(b))
    y = np.zeros(n)
    y[:len(a)] += a * .8
    y[:len(b)] += b * .55
    return y


def swing(k, sw=.07):
    """semicolcheia k do compasso (0..15) com balanço nas fracas"""
    return k * .25 + (sw if k % 2 == 1 else 0.0)


def beat_boombap(T, b, spb, cheio=False):
    hits(T, kick_hh(), [b, b + .75 + .07, b + 2.5], spb, vel=.8, hum=.003)
    hits(T, snare_hh(), [b + 1, b + 3], spb, vel=.62, wet=True, hum=.003)
    for k in range(0, 16, 2):
        hits(T, p_shaker(), [b + swing(k)], spb, pan=.25, vel=.38 + (.12 if k % 4 == 2 else 0), hum=.002)
    if cheio:
        hits(T, kick_hh(.7), [b + 3.5 + .07], spb, vel=.55)
        for k in range(1, 16, 2):
            hits(T, p_shaker(), [b + swing(k)], spb, pan=.25, vel=.22, hum=.002)
        hits(T, p_rim(), [b + 1.75 + .07, b + 3.25 + .07], spb, pan=-.3, vel=.3)


def beat_trap(T, b, spb, rufada=False):
    """luta: meio-tempo (caixa no 3), chimbal em semicolcheias e rufadas"""
    hits(T, kick_hh(), [b, b + .75, b + 1.5 + .25, b + 3.25], spb, vel=.85, hum=.002)
    hits(T, snare_hh(), [b + 2], spb, vel=.7, wet=True)
    for k in range(16):
        hits(T, p_shaker(), [b + k * .25], spb, pan=.25, vel=.3 + (.15 if k % 4 == 0 else 0), hum=.001)
    if rufada:
        for k in range(8):
            hits(T, p_shaker(), [b + 3 + k * .125], spb, pan=.25, vel=.25 + k * .03, hum=.0)
        hits(T, snare_hh(.5), [b + 3.5, b + 3.75], spb, vel=.4)


def baixo_hh(T, c, t, spb, vel=.55, pad=((0, .5), (.75, .25), (1.75, .25), (2.5, .5), (3.25, .25))):
    """baixo curto e marcado (nunca nota longa grave)"""
    r = chord(c, 2)[0]
    for k, (bt, d) in enumerate(pad):
        m = r + (12 if k == 3 else 0)
        T.note('contrabass', m, t + bt * spb, d * spb, vel, .03)


def piano_lofi(T, c, t, spb, hits_=(0, 1.5 + .07, 2.75 + .07), vel=.17):
    ch = chord(c, 3)
    for bt in hits_:
        for k, m in enumerate(ch):
            T.note('piano', m + (12 if k == 0 else 0), t + bt * spb + k * .006, spb * .6, vel, .25)


# ----------------------------------------------------------------- 1-1: terminal (hip hop)
def gru_saguao():
    bpm = 90
    spb = 60 / bpm
    loop = 'Dm9 Bbmaj7 Gm7 A7'.split()
    chs = loop * 8                       # 32 compassos (~85 s)
    n = len(chs)
    T1, T2, T3 = Track(n * 4 * spb), Track(n * 4 * spb), Track(n * 4 * spb)
    gancho = mel('A5:.75 F5:.25 D5:.5 E5:.5 F5:1 r:1 | G5:.5 F5:.5 E5:.5 D5:.5 F5:1 r:1 | '
                 'D5:.75 F5:.25 A5:.5 C6:.5 Bb5:1 A5:.5 G5:.5 | A5:1.5 G5:.5 E5:1 r:1', 4)
    gancho2 = mel('D6:.5 C6:.5 A5:.5 F5:.5 A5:1 r:1 | Bb5:.5 A5:.5 F5:.5 D5:.5 F5:1 G5:1 | '
                  'Bb5:.75 A5:.25 G5:.5 F5:.5 D5:1 F5:1 | E5:1 G5:1 A5:1 r:1', 4)
    for blk in range(8):
        t0 = blk * 16 * spb
        if blk in (1, 2, 5, 6):
            play_mel(T2, 'flute', gancho, spb, t0=t0, vel=.36, legato=.8, rel=.15)
        elif blk in (3, 4):
            play_mel(T2, 'xylophone', gancho2, spb, t0=t0, vel=.34, legato=.5, rel=.2)
            play_mel(T2, 'flute', gancho2, spb, t0=t0, vel=.12, legato=.8, rel=.1, octave=-1)
        elif blk == 7:
            play_mel(T2, 'flute', gancho2, spb, t0=t0, vel=.3, legato=.8, rel=.15)
    for i, c in enumerate(chs):
        t = i * 4 * spb
        b = i * 4
        # camada 1: batida leve, baixo e piano
        hits(T1, kick_hh(), [b, b + 2.5], spb, vel=.7)
        hits(T1, snare_hh(.6), [b + 1, b + 3], spb, vel=.4, wet=True)
        for k in range(0, 16, 2):
            hits(T1, p_shaker(), [b + swing(k)], spb, pan=.25, vel=.3)
        baixo_hh(T1, c, t, spb, .5)
        piano_lofi(T1, c, t, spb)
        # camada 2: batida completa
        beat_boombap(T2, b, spb, cheio=False)
        # camada 3 (capanga perto): batida cheia e cordas cortadas (stabs) no contratempo
        beat_boombap(T3, b, spb, cheio=True)
        for bt in (.5 + .07, 2.5 + .07):
            for m in chord(c, 4)[:3]:
                T3.note('violin', m, t + bt * spb, spb * .2, .14, .05)
        if i % 4 == 3:
            hits(T3, snare_hh(.5), [b + 3.5, b + 3.75], spb, vel=.35)
    return render_stems([T1, T2, T3], .16, 1.2)


# ----------------------------------------------------------------- 1-1 (segurança): hip hop tenso
def gru_seguranca():
    bpm = 86
    spb = 60 / bpm
    loop = 'Em9 Cmaj7 Am7 B7'.split()
    chs = loop * 8
    n = len(chs)
    T1, T2, T3 = Track(n * 4 * spb), Track(n * 4 * spb), Track(n * 4 * spb)
    gancho = mel('B4:.75 G4:.25 E4:.5 F#4:.5 G4:1 r:1 | E5:.5 D5:.5 B4:.5 G4:.5 B4:1 r:1 | '
                 'C5:.75 B4:.25 A4:.5 E4:.5 A4:1 C5:1 | B4:1 D#5:1 F#5:1 r:1', 4)
    for blk in range(8):
        t0 = blk * 16 * spb
        if blk in (1, 2, 5, 6, 7):
            play_mel(T2, 'cello', gancho, spb, t0=t0, vel=.36, legato=.8, rel=.12)
        if blk in (3, 4, 7):
            play_mel(T2, 'xylophone', gancho, spb, t0=t0, vel=.24, legato=.4, rel=.2, octave=1)
    for i, c in enumerate(chs):
        t = i * 4 * spb
        b = i * 4
        hits(T1, kick_hh(), [b, b + 2.5 + .07], spb, vel=.7)
        hits(T1, snare_hh(.6), [b + 1, b + 3], spb, vel=.4, wet=True)
        for k in range(0, 16, 2):
            hits(T1, p_shaker(), [b + swing(k)], spb, pan=.25, vel=.3)
        baixo_hh(T1, c, t, spb, .5, ((0, .5), (1.5, .25), (2.5 + .07, .5), (3.5, .25)))
        piano_lofi(T1, c, t, spb, (0, 2.0 + .07), .15)
        beat_boombap(T2, b, spb, cheio=False)
        beat_boombap(T3, b, spb, cheio=True)
        for bt in (1.5 + .07, 3.5 + .07):
            for m in chord(c, 4)[:3]:
                T3.note('violin', m, t + bt * spb, spb * .2, .13, .05)
    return render_stems([T1, T2, T3], .16, 1.2)


# ----------------------------------------------------------------- luta com o Fiscal Falso (trap)
def fiscal():
    bpm = 150
    spb = 60 / bpm
    chs = 'Dm Dm Bb A Dm Dm Gm A Dm Dm Bb A Gm A Dm Dm'.split()
    T = Track(len(chs) * 4 * spb)
    riff = mel('D5:.5 D5:.5 F5:.5 D5:.5 A5:1 G5:.5 F5:.5 | E5:.5 F5:.5 G5:.5 F5:.5 E5:1 D5:1 | '
               'F5:.5 F5:.5 Bb5:.5 F5:.5 D6:1 C6:.5 Bb5:.5 | A5:1 C#5:1 E5:1 A5:1 | '
               'D5:.5 D5:.5 F5:.5 D5:.5 A5:1 G5:.5 F5:.5 | E5:.5 F5:.5 G5:.5 F5:.5 E5:1 D5:1 | '
               'G5:.5 Bb5:.5 D6:.5 Bb5:.5 G5:1 D5:1 | E5:1 G5:1 A5:1 C#6:1', 4)
    play_mel(T, 'violin', riff, spb, vel=.32, legato=.5, rel=.05)
    play_mel(T, 'piano', riff, spb, t0=8 * 4 * spb, vel=.18, legato=.3, rel=.05, octave=-1)
    play_mel(T, 'violin', riff, spb, t0=8 * 4 * spb, vel=.3, legato=.5, rel=.05)
    for i, c in enumerate(chs):
        t = i * 4 * spb
        b = i * 4
        beat_trap(T, b, spb, rufada=(i % 4 == 3))
        baixo_hh(T, c, t, spb, .55, ((0, .5), (.75, .25), (1.75, .25), (3.25, .5)))
    return T.render(.14, 1.1)


# ----------------------------------------------------------------- mini-chefe: falso segurança (trap)
def seg_luta():
    bpm = 140
    spb = 60 / bpm
    chs = 'Em Em C B7 Em Em Am B7 Em Em C B7 Am B7 Em Em'.split()
    T = Track(len(chs) * 4 * spb)
    riff = mel('E5:.5 E5:.25 G5:.25 r:.5 B5:.5 A5:.5 G5:.5 F#5:1 | E5:.5 E5:.25 G5:.25 r:.5 B5:.5 D6:1 B5:1 | '
               'C6:.5 B5:.5 A5:.5 G5:.5 E5:1 r:1 | D#5:.5 F#5:.5 A5:.5 B5:.5 F#5:2', 4)
    play_mel(T, 'violin', riff, spb, vel=.3, legato=.5, rel=.05)
    play_mel(T, 'xylophone', riff, spb, t0=8 * 4 * spb, vel=.26, legato=.4, rel=.15)
    play_mel(T, 'violin', riff, spb, t0=8 * 4 * spb, vel=.26, legato=.5, rel=.05, octave=-1)
    for i, c in enumerate(chs):
        t = i * 4 * spb
        b = i * 4
        beat_trap(T, b, spb, rufada=(i % 4 == 3))
        baixo_hh(T, c, t, spb, .55, ((0, .5), (.75, .25), (1.75, .25), (3.25, .5)))
        piano_lofi(T, c, t, spb, (0, 2.0), .12)
    return T.render(.14, 1.1)


# ----------------------------------------------------------------- placar: samba curto
def vitoria():
    bpm = 120
    spb = 60 / bpm
    chs = 'D G A D D G A D'.split()
    T = Track(8 * 4 * spb)
    for i, c in enumerate(chs):
        t = i * 4 * spb
        b = i * 4
        ch = chord(c, 4)
        for k, m in enumerate([ch[0], ch[1], ch[2], ch[0] + 12, ch[2], ch[1], ch[0] + 12, ch[2] + 12]):
            T.note('xylophone', m, t + k * spb / 2, spb * .4, .32 if k % 2 == 0 else .24, .3)
        for (bt, v) in [(0, .24), (1, .2), (1.5, .18), (2, .22), (3, .2), (3.5, .18)]:
            strum(T, 'guitar-acoustic', chord(c, 3), t + bt * spb, spb * .3, v, .1, .006)
        T.note('contrabass', chord(c, 2)[0], t, spb * 1.5, .5, .1)
        T.note('contrabass', chord(c, 2)[0] + 7, t + 2 * spb, spb * 1.5, .45, .1)
        hits(T, p_kick(), [b, b + 2], spb, vel=.55)
        hits(T, p_clap(), [b + 1, b + 3], spb, vel=.45, wet=True)
        hits(T, p_shaker(), [b + k * .5 for k in range(8)], spb, pan=.3, vel=.6)
        hits(T, p_snare(.5), [b + 3.5], spb, vel=.25)
    trompete = mel('D5:1 F#5:1 A5:2 | B5:1 A5:1 G5:2 | A5:1 B5:1 C#6:1 E6:1 | D6:4 | '
                   'D5:1 F#5:1 A5:2 | B5:1 D6:1 B5:2 | A5:1 G5:1 E5:1 C#5:1 | D5:4', 4)
    play_mel(T, 'trumpet', trompete, spb, vel=.32, legato=.85, rel=.15)
    return T.render(.24, 1.6)


if __name__ == '__main__':
    so = sys.argv[2:]
    camadas = {'aero_tema': aero_tema, 'gru_saguao': gru_saguao, 'gru_seguranca': gru_seguranca}
    simples = {'fiscal': fiscal, 'vitoria': vitoria, 'seg_luta': seg_luta}
    for nome, f in camadas.items():
        if so and nome not in so:
            continue
        for i, x in enumerate(f()):
            save_ogg('mus_' + nome + ('' if i == 0 else '_%d' % (i + 1)), x)
    for nome, f in simples.items():
        if so and nome not in so:
            continue
        save_ogg('mus_' + nome, f())
