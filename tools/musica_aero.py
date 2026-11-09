"""Músicas próprias do Cadê as milhas?! (ritmos brasileiros por cidade), com instrumentos gravados
(mesmo motor de tools/make_music.py). Guarulhos: samba-rock e MPB.

  aero_tema     bossa do saguão para os menus (3 camadas)
  gru_saguao    samba-rock do terminal (3 camadas: violão e baixo / bateria / melodia e metais)
  gru_seguranca samba-funk tenso da área de segurança (3 camadas)
  fiscal        batucada da luta com o Fiscal Falso
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


# ----------------------------------------------------------------- 1-1: samba-rock do terminal
def gru_saguao():
    bpm = 130
    spb = 60 / bpm
    chs = ('D Bm G A D Bm Em A G A F#m Bm Em A D D '
           'G Gm D Bm Em A D D7 G Gm F#m B7 Em A D D').split()
    n = len(chs)
    T1, T2, T3 = Track(n * 4 * spb), Track(n * 4 * spb), Track(n * 4 * spb)
    a = mel('A4:.5 D5:.5 F#5:.5 A5:1 F#5:.5 E5:.5 D5:.5 | B4:.5 D5:.5 F#5:1 E5:.5 D5:.5 B4:1 | '
            'G4:.5 B4:.5 D5:.5 G5:1 F#5:.5 E5:.5 D5:.5 | E5:1.5 C#5:.5 A4:2 | '
            'A4:.5 D5:.5 F#5:.5 A5:1 B5:.5 A5:.5 F#5:.5 | D6:1 B5:.5 A5:.5 F#5:1 D5:1 | '
            'E5:.5 G5:.5 B5:.5 E6:1 D6:.5 B5:.5 G5:.5 | A5:2 r:1 C#5:.5 E5:.5 | '
            'D6:.5 B5:.5 G5:.5 B5:.5 D6:1 B5:1 | C#6:.5 A5:.5 E5:.5 A5:.5 C#6:1 E6:1 | '
            'C#6:.5 A5:.5 F#5:.5 A5:.5 C#6:1 A5:1 | B5:1.5 A5:.5 F#5:1 D5:1 | '
            'G5:.5 F#5:.5 E5:.5 G5:.5 B5:1 A5:1 | E5:.5 F#5:.5 G5:.5 A5:.5 C#6:1 E6:1 | '
            'D6:1 A5:.5 F#5:.5 D6:1 F#6:1 | D6:2 r:2', 4)
    bb = mel('B5:1 A5:.5 G5:.5 D5:1 B4:1 | Bb5:1 A5:.5 G5:.5 D5:2 | F#5:.5 E5:.5 D5:.5 A4:.5 D5:1 F#5:1 | B5:2 A5:1 F#5:1 | '
             'G5:.5 F#5:.5 E5:.5 B4:.5 E5:1 G5:1 | A5:1 G5:.5 F#5:.5 E5:1 C#5:1 | D5:.5 F#5:.5 A5:.5 D6:.5 C#6:1 A5:1 | C6:2 r:1 A5:.5 C6:.5 | '
             'B5:1 D6:.5 B5:.5 G5:1 D5:1 | Bb5:1 D6:.5 Bb5:.5 G5:2 | A5:.5 G#5:.5 F#5:.5 C#5:.5 F#5:1 A5:1 | D#6:1 C#6:.5 B5:.5 A5:1 F#5:1 | '
             'G5:.5 B5:.5 E6:.5 B5:.5 G5:1 E5:1 | C#6:1 B5:.5 A5:.5 G5:1 E5:1 | F#5:1 A5:.5 D6:.5 F#6:1 D6:1 | D6:2 r:1 A4:.5 C#5:.5', 4)
    # a melodia fica na camada 2 (que toca sempre): a música já começa animada
    play_mel(T2, 'xylophone', a, spb, vel=.4, legato=.6, rel=.25)
    play_mel(T2, 'flute', a, spb, vel=.18, legato=.85, rel=.15, octave=-1)
    play_mel(T2, 'flute', bb, spb, t0=16 * 4 * spb, vel=.34, legato=.9, rel=.2)
    play_mel(T2, 'clarinet', bb, spb, t0=16 * 4 * spb, vel=.16, legato=.9, rel=.2, octave=-1)
    # camada 3 (capanga por perto): metais dobrando a melodia uma oitava abaixo
    play_mel(T3, 'trumpet', a, spb, vel=.2, legato=.7, rel=.1, octave=-1)
    play_mel(T3, 'trumpet', bb, spb, t0=16 * 4 * spb, vel=.22, legato=.7, rel=.1, octave=-1)
    for i, c in enumerate(chs):
        t = i * 4 * spb
        b = i * 4
        r = chord(c, 2)[0]
        q = baixo_quinta(r)
        for (bt, m, d, v) in [(0, r, .7, .55), (.75, r, .2, .35), (1.5, q, .4, .45), (2, r + 12, .45, .4),
                              (2.75, r, .2, .35), (3, q, .45, .45), (3.5, r, .4, .4)]:
            T1.note('contrabass', m, t + bt * spb, d * spb, v, .06)
        for (bt, v) in [(0, .26), (.75, .2), (1.5, .24), (2.5, .22), (3, .2), (3.5, .24)]:
            strum(T1, 'guitar-nylon', chord(c, 4), t + bt * spb, spb * .3, v, .08, .006)
        hits(T1, p_shaker(), [b + k * .5 for k in range(8)], spb, pan=.35, vel=.45)
        # pulso já na base: bumbo nos tempos e palma no contratempo
        hits(T1, p_kick(), [b, b + 2, b + 2.75], spb, vel=.5)
        hits(T1, p_clap(), [b + 1, b + 3], spb, vel=.35, wet=True)
        # camada 2: bateria e surdo
        hits(T2, p_kick(), [b, b + 1.75, b + 2, b + 3.5], spb, vel=.6)
        hits(T2, p_clap(), [b + 1, b + 3], spb, vel=.5, wet=True)
        hits(T2, surdo(), [b + 1], spb, vel=.55)
        hits(T2, p_rim(), [b, b + .75, b + 1.5, b + 2, b + 2.75, b + 3.5], spb, pan=-.3, vel=.5)
        for k in range(16):
            hits(T2, p_shaker(), [b + k * .25], spb, pan=.35, vel=.35 + (.3 if k % 4 == 2 else 0), hum=.002)
        if i % 4 == 0:
            for m in chord(c, 3):
                T2.note('harmonium', m, t, 4 * spb, .06, .5)
        # camada 3: agogô, pandeiro e metais na parte B
        hits(T3, p_block(880), [b + .5, b + 2.5], spb, pan=.4, vel=.5)
        hits(T3, p_block(1180), [b + 1, b + 1.5, b + 3], spb, pan=.4, vel=.45)
        if i % 4 == 3:
            hits(T3, p_tamb(), [b + 3, b + 3.25, b + 3.5, b + 3.75], spb, pan=.2, vel=.7)
        # metais em ataques curtos (todo compasso) e virada de caixa a cada 4
        for bt in (1.5, 3.5):
            for m in chord(c, 4):
                T3.note('trumpet', m, t + bt * spb, spb * .3, .13, .08)
        if i % 4 == 3:
            hits(T3, p_snare(.6), [b + 2 + k * .25 for k in range(8)], spb, vel=.4, hum=.002)
    return render_stems([T1, T2, T3], .2, 1.5)


# ----------------------------------------------------------------- 1-1 (segurança): samba-funk tenso
def gru_seguranca():
    bpm = 122
    spb = 60 / bpm
    parte = 'Em7 A7 Em7 A7 Cmaj7 B7 Em7 Em7 Am7 D7 Gmaj7 Cmaj7 F#m7b5 B7 Em7 B7'.split()
    chs = parte * 2
    n = len(chs)
    T1, T2, T3 = Track(n * 4 * spb), Track(n * 4 * spb), Track(n * 4 * spb)
    m = mel('E5:.75 G5:.25 B5:1 A5:.5 G5:.5 E5:1 | C#5:.5 E5:.5 G5:1 F#5:1 E5:1 | E5:.75 G5:.25 B5:1 D6:1 B5:1 | A5:2 G5:1 E5:1 | '
            'E5:.5 G5:.5 B5:1 C6:1 B5:1 | A5:.5 F#5:.5 D#5:1 F#5:1 B4:1 | G5:1.5 F#5:.5 E5:2 | r:2 B4:.5 D5:.5 E5:.5 G5:.5 | '
            'C6:1 B5:.5 A5:.5 E5:1 G5:1 | F#5:1 A5:.5 C6:.5 A5:2 | B5:.5 A5:.5 G5:.5 F#5:.5 D5:2 | E5:1 G5:1 B5:1 C6:1 | '
            'A5:1 C6:.5 A5:.5 F#5:1 E5:1 | D#5:1 F#5:1 A5:1 B5:1 | G5:.5 F#5:.5 E5:1 B4:1 E5:1 | F#5:2 D#5:1 B4:1', 4)
    play_mel(T2, 'clarinet', m, spb, vel=.34, legato=.8, rel=.12, octave=-1)
    play_mel(T2, 'xylophone', m[::2], spb, t0=16 * 4 * spb, vel=.18, legato=.4, rel=.2)
    play_mel(T3, 'trumpet', m, spb, vel=.26, legato=.75, rel=.1, octave=-1)
    play_mel(T3, 'french-horn', m, spb, t0=16 * 4 * spb, vel=.2, legato=.8, rel=.1, octave=-1)
    for i, c in enumerate(chs):
        t = i * 4 * spb
        b = i * 4
        r = chord(c, 2)[0]
        for (bt, mm_, d, v) in [(0, r, .6, .55), (1.5, r + 12, .3, .4), (2, r, .4, .45), (2.75, baixo_quinta(r), .25, .4), (3.5, r + 10, .4, .4)]:
            T1.note('contrabass', mm_, t + bt * spb, d * spb, v, .05)
        for (bt, v) in [(.5, .14), (1.5, .12), (2.5, .14), (3.25, .12)]:
            for mm_ in chord(c, 4):
                T1.note('piano', mm_, t + bt * spb, spb * .25, v, .1)
        hits(T1, p_kick(), [b, b + 2.5], spb, vel=.5)
        hits(T1, p_shaker(), [b + k * .25 for k in range(16)], spb, pan=.3, vel=.3, hum=.002)
        hits(T2, p_kick(), [b, b + 1.75, b + 2.5], spb, vel=.62)
        hits(T2, p_snare(), [b + 1, b + 3], spb, vel=.48, wet=True)
        hits(T2, p_shaker(), [b + k * .5 for k in range(8)], spb, pan=.3, vel=.55)
        hits(T2, p_rim(), [b + .75, b + 2.25, b + 3.75], spb, pan=-.3, vel=.35)
        if i % 8 == 7:
            for k in range(4):
                T3.raw(p_timp(P('E2') + [7, 5, 3, 0][k]) * .5, t + (2 + k * .5) * spb)
    return render_stems([T1, T2, T3], .2, 1.6)


# ----------------------------------------------------------------- luta com o Fiscal Falso: batucada
def fiscal():
    bpm = 138
    spb = 60 / bpm
    chs = 'Dm Dm Bb A Dm Dm Gm A Dm Dm Bb A Gm A Dm Dm'.split()
    T = Track(len(chs) * 4 * spb)
    riff = mel('D5:.5 D5:.5 F5:.5 D5:.5 A5:1 G5:.5 F5:.5 | E5:.5 F5:.5 G5:.5 F5:.5 E5:1 D5:1 | '
               'F5:.5 F5:.5 Bb5:.5 F5:.5 D6:1 C6:.5 Bb5:.5 | A5:1 C#5:1 E5:1 A5:1 | '
               'D5:.5 D5:.5 F5:.5 D5:.5 A5:1 G5:.5 F5:.5 | E5:.5 F5:.5 G5:.5 F5:.5 E5:1 D5:1 | '
               'G5:.5 Bb5:.5 D6:.5 Bb5:.5 G5:1 D5:1 | E5:1 G5:1 A5:1 C#6:1', 4)
    play_mel(T, 'trumpet', riff, spb, vel=.4, legato=.7, rel=.08)
    play_mel(T, 'french-horn', riff, spb, vel=.22, legato=.8, rel=.1, octave=-1)
    play_mel(T, 'trumpet', riff, spb, t0=8 * 4 * spb, vel=.36, legato=.7, rel=.08, octave=1)
    play_mel(T, 'french-horn', riff, spb, t0=8 * 4 * spb, vel=.22, legato=.8, rel=.1)
    for i, c in enumerate(chs):
        t = i * 4 * spb
        b = i * 4
        r = chord(c, 2)[0]
        for k in range(4):
            T.note('contrabass', r if k % 2 == 0 else baixo_quinta(r), t + k * spb, spb * .5, .55, .05)
        hits(T, surdo(), [b + 1, b + 3], spb, vel=.8)
        hits(T, surdo(.6), [b + 2.5], spb, vel=.5)
        for k in range(16):
            hits(T, p_snare(.5), [b + k * .25], spb, vel=.28 + (.3 if k % 4 in (0, 3) else 0), hum=.002)
        hits(T, p_rim(), [b + .5, b + 1.25, b + 2, b + 2.75, b + 3.5], spb, pan=-.35, vel=.6)
        hits(T, p_block(900), [b, b + 1.5, b + 3], spb, pan=.4, vel=.55)
        hits(T, p_block(1250), [b + .5, b + 2, b + 2.5], spb, pan=.4, vel=.5)
        hits(T, p_kick(), [b, b + 2], spb, vel=.6)
        if i % 4 == 3:
            hits(T, p_tamb(), [b + 3, b + 3.25, b + 3.5, b + 3.75], spb, pan=.2, vel=.8)
    return T.render(.16, 1.3)


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
        hits(T, surdo(), [b + 1], spb, vel=.45)
    trompete = mel('D5:1 F#5:1 A5:2 | B5:1 A5:1 G5:2 | A5:1 B5:1 C#6:1 E6:1 | D6:4 | '
                   'D5:1 F#5:1 A5:2 | B5:1 D6:1 B5:2 | A5:1 G5:1 E5:1 C#5:1 | D5:4', 4)
    play_mel(T, 'trumpet', trompete, spb, vel=.32, legato=.85, rel=.15)
    return T.render(.24, 1.6)


if __name__ == '__main__':
    so = sys.argv[2:]
    camadas = {'aero_tema': aero_tema, 'gru_saguao': gru_saguao, 'gru_seguranca': gru_seguranca}
    simples = {'fiscal': fiscal, 'vitoria': vitoria}
    for nome, f in camadas.items():
        if so and nome not in so:
            continue
        for i, x in enumerate(f()):
            save_ogg('mus_' + nome + ('' if i == 0 else '_%d' % (i + 1)), x)
    for nome, f in simples.items():
        if so and nome not in so:
            continue
        save_ogg('mus_' + nome, f())
