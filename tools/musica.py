"""Músicas do Cadê as milhas?! com instrumentos de verdade (amostras tonejs-instruments, ver musica_base.py).
  corrida: samba-rock animado para as fases (132 bpm, Ré maior)
  titulo:  bossa tranquila de saguão para os menus
  vitoria: festa curta para a tela do resultado

Uso (depois de baixar as amostras como descrito em musica_base.py):
  python3 tools/musica.py /tmp/tj            (todas)
  python3 tools/musica.py /tmp/tj corrida    (só essa)
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import musica_base as mb  # noqa: E402
from musica_base import (Track, mel, chord, play_mel, strum, hits, p_kick, p_snare, p_clap, p_shaker,  # noqa: E402
                         p_rim, p_brush, p_tamb, p_triangle, P, save_ogg, rng)

mb.SRC = sys.argv[1] if len(sys.argv) > 1 else '/tmp/tj'
mb.CH['maj7'] = [0, 4, 7, 11]


def corrida():
    bpm = 132
    spb = 60 / bpm
    chs = 'D Bm G A D Bm Em A G A F#m Bm Em A D D'.split()
    T = Track(16 * 4 * spb)
    melodia = mel('A4:.5 D5:.5 F#5:.5 A5:1 F#5:.5 E5:.5 D5:.5 | B4:.5 D5:.5 F#5:1 E5:.5 D5:.5 B4:1 | '
                  'G4:.5 B4:.5 D5:.5 G5:1 F#5:.5 E5:.5 D5:.5 | E5:1.5 C#5:.5 A4:2 | '
                  'A4:.5 D5:.5 F#5:.5 A5:1 B5:.5 A5:.5 F#5:.5 | D6:1 B5:.5 A5:.5 F#5:1 D5:1 | '
                  'E5:.5 G5:.5 B5:.5 E6:1 D6:.5 B5:.5 G5:.5 | A5:2 r:1 C#5:.5 E5:.5 | '
                  'D6:.5 B5:.5 G5:.5 B5:.5 D6:1 B5:1 | C#6:.5 A5:.5 E5:.5 A5:.5 C#6:1 E6:1 | '
                  'C#6:.5 A5:.5 F#5:.5 A5:.5 C#6:1 A5:1 | B5:1.5 A5:.5 F#5:1 D5:1 | '
                  'G5:.5 F#5:.5 E5:.5 G5:.5 B5:1 A5:1 | E5:.5 F#5:.5 G5:.5 A5:.5 C#6:1 E6:1 | '
                  'D6:1 A5:.5 F#5:.5 D6:1 F#6:1 | D6:2 r:1 A4:.5 C#5:.5', 4)
    # primeira volta: xilofone; a partir do compasso 9, flauta dobrando uma oitava abaixo
    play_mel(T, 'xylophone', melodia, spb, vel=.42, legato=.6, rel=.25)
    play_mel(T, 'flute', [n for n in melodia if n[0] >= 32], spb, vel=.3, legato=.85, rel=.15, octave=-1)
    for i, c in enumerate(chs):
        t = i * 4 * spb
        b = i * 4
        r = chord(c, 2)[0]
        q = r + 7 if r + 7 < P('A2') else r - 5
        # baixo sincopado de samba-rock
        for (bt, m, d, v) in [(0, r, .7, .55), (.75, r, .2, .35), (1.5, q, .4, .45), (2, r + 12, .45, .4),
                              (2.75, r, .2, .35), (3, q, .45, .45), (3.5, r, .4, .4)]:
            T.note('contrabass', m, t + bt * spb, d * spb, v, .06)
        # violão em partido-alto
        acorde = chord(c, 4)
        for (bt, v) in [(0, .26), (.75, .2), (1.5, .24), (2.5, .22), (3, .2), (3.5, .24)]:
            strum(T, 'guitar-nylon', acorde, t + bt * spb, spb * .3, v, .08, .006)
        if i % 4 == 0:
            for m in chord(c, 3):
                T.note('harmonium', m, t, 4 * spb, .07, .5)
        # bateria
        hits(T, p_kick(), [b, b + 1.75, b + 2, b + 3.5], spb, vel=.62)
        hits(T, p_clap(), [b + 1, b + 3], spb, vel=.55, wet=True)
        hits(T, p_rim(), [b, b + .75, b + 1.5, b + 2, b + 2.75, b + 3.5], spb, pan=-.3, vel=.55)
        for k in range(16):
            hits(T, p_shaker(), [b + k * .25], spb, pan=.35, vel=.5 + (.35 if k % 4 == 2 else 0), hum=.002)
        if i % 4 == 3:
            hits(T, p_tamb(), [b + 3, b + 3.25, b + 3.5, b + 3.75], spb, pan=.2, vel=.7)
    return T.render(.18, 1.4)


def titulo():
    bpm = 96
    spb = 60 / bpm
    chs = 'Dmaj7 Bm7 Em7 A7 Dmaj7 Bm7 Em7 A7'.split()
    T = Track(8 * 4 * spb)
    melodia = mel('F#5:1.5 E5:.5 D5:1 C#5:1 | D5:1.5 B4:.5 A4:2 | G4:.5 B4:.5 D5:.5 F#5:1.5 E5:1 | E5:2 C#5:1 r:1 | '
                  'A5:1.5 F#5:.5 E5:1 D5:1 | F#5:1.5 D5:.5 B4:2 | G5:.5 F#5:.5 E5:.5 D5:.5 C#5:1 B4:1 | A4:3 r:1', 4)
    play_mel(T, 'flute', melodia, spb, vel=.36, legato=.95, rel=.3)
    for i, c in enumerate(chs):
        t = i * 4 * spb
        b = i * 4
        r = chord(c, 2)[0]
        T.note('contrabass', r, t, 1.4 * spb, .45, .2)
        T.note('contrabass', r + 7 if r + 7 < P('A2') else r - 5, t + 2 * spb, 1.4 * spb, .4, .2)
        acorde = [m for m in chord(c, 3)]
        for (bt, v) in [(0, .22), (1.5, .2), (2.5, .2), (3.5, .18)]:
            strum(T, 'guitar-nylon', acorde, t + bt * spb, spb * .6, v, .2, .012)
        for k in (0, 2):
            T.note('piano', chord(c, 4)[1], t + (k + .5) * spb, spb * .4, .12, .4)
        hits(T, p_brush(), [b + k * .5 for k in range(8)], spb, vel=.55)
        hits(T, p_rim(), [b + .5, b + 1.5, b + 3], spb, pan=-.2, vel=.35)
    return T.render(.3, 2.0)


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
        if i in (3, 7):
            hits(T, p_triangle(), [b + 3], spb, vel=.8, wet=True)
    trompete = mel('D5:1 F#5:1 A5:2 | B5:1 A5:1 G5:2 | A5:1 B5:1 C#6:1 E6:1 | D6:4 | '
                   'D5:1 F#5:1 A5:2 | B5:1 D6:1 B5:2 | A5:1 G5:1 E5:1 C#5:1 | D5:4', 4)
    play_mel(T, 'trumpet', trompete, spb, vel=.32, legato=.85, rel=.15)
    return T.render(.24, 1.6)


if __name__ == '__main__':
    so = sys.argv[2:]
    for nome, f in (('corrida', corrida), ('titulo', titulo), ('vitoria', vitoria)):
        if so and nome not in so:
            continue
        save_ogg('mus_' + nome, f())
