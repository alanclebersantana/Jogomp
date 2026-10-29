# Animações extras do Tomé (opcionais)

Coloque aqui folhas de sprites PNG com fundo transparente. Se um arquivo existir, o jogo passa a usá-lo
automaticamente no lugar da pose antiga (veja `scripts/spr.gd` → `ANIM_NAMES`).

| arquivo     | quadros sugeridos | quando aparece                      |
|-------------|-------------------|-------------------------------------|
| idle.png    | 8                 | parado (respirando, lanterna balança)|
| walk.png    | 10–12             | andando                             |
| run.png     | 8                 | correndo                            |
| jump.png    | 4                 | subindo no pulo (do impulso ao ápice)|
| fall.png    | 4                 | caindo (do ápice até cair rápido)   |
| land.png    | 3                 | aterrissando                        |

Regras: todos os quadros **quadrados** e do mesmo tamanho (ex.: 256×256), lado a lado numa linha só,
o Tomé virado para a **direita**, pés tocando a base do quadro, centralizado. O prompt para gerar está em
`docs/ANIMACOES.md`.
