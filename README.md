# Encontre-a

Jogo de plataforma 2D em **Godot 4.6** (Android).
Tomé, um mineiro, segue a trilha de lápis de cor deixada pela filha, Isis, que foi levada por
Ademar Vargas, o gerente da mina que ele denunciou por roubo.

Episódios: **1 · O Bosque** (`assets/data/level1.json`) e **2 · As Profundezas da Mina**
(`assets/data/level2.json`, gerado por `tools/gen_level2.py`: boca da mina com elevador e porta de manivela,
vale do moinho com as pás que levam o Tomé para o alto, telhados da vila com varais e fumaça das chaminés,
e o carrinho nos trilhos atrás do Vargas). O Episódio 2 é liberado ao terminar o primeiro.

O Episódio 1 foi portado da versão HTML com a mesma física e as mesmas mecânicas:
- agachar, engatinhar e deslizar;
- escadas, rede e corda;
- cipó, pulo duplo e planar;
- mochila para combinar objetos (gancho + corda, engrenagem + manivela, óleo + pavio);
- caderno de pistas, lápis especiais, desenhos escondidos;
- fogueiras de checagem, placar com estrelas.

Novidades desta versão:
- luz de verdade na lanterna, fogueiras e cogumelos (iluminação 2D do Godot);
- fundos que mudam por trecho (manhã, tarde, pântano com chuva, noite);
- o progresso é salvo no aparelho a cada fogueira;
- tela cheia e controle pelo toque, teclado ou controle (gamepad).

## Como baixar o APK no celular

Cada envio para a branch `main` dispara o GitHub Actions (`.github/workflows/android.yml`), que:
1. baixa o Godot 4.6.2 e os modelos de exportação;
2. roda o teste automático que joga a Fase 1 inteira (`tests/route.gd`);
3. gera o APK e o publica em **Releases** (página de versões do repositório).

No celular: abra a página **Releases**, baixe `encontre-a.apk` e toque nele para instalar.
Talvez seja preciso permitir "instalar apps desconhecidos" para o navegador.

Para publicar na Play Store mais tarde, cadastre a chave de assinatura nos *Secrets* do repositório:
`KEYSTORE_BASE64`, `KEYSTORE_USER` e `KEYSTORE_PASSWORD`. O workflow passa a gerar a versão *release*.

## Abrir e editar

- Abra a pasta no Godot 4.6 (PC ou o editor do Godot para Android).
- Cena principal: `scenes/main.tscn`.
- Dados da fase: `assets/data/level1.json` (posições de chão, plataformas, itens, inimigos, dicas).

## Estrutura

| Pasta/arquivo | O que tem |
|---|---|
| `scripts/game.gd` | simulação: física do Tomé, mecânicas da fase, inimigos, itens, salvamento |
| `scripts/world_static.gd` | cenário fixo, desenhado em pedaços de 1024 px |
| `scripts/world_dyn.gd` | tudo o que se mexe: Tomé, inimigos, escadas, caixas, vilão |
| `scripts/world_glow.gd` | o que brilha acima da escuridão (lápis, objetos, pistas) e a água do brejo |
| `scripts/bg.gd` | fundos em paralaxe por trecho |
| `scripts/main.gd` | telas, HUD, controles de toque, luzes, fluxo do jogo |
| `scripts/spr.gd` | atlas de imagens e funções de desenho |
| `scripts/audio.gd` | sons, música por trecho e chuva |
| `tools/make_audio.py` | gera os sons provisórios (WAV) |
| `tests/route.gd` | teste que joga a fase inteira |
| `tests/shots.gd` | capturas de tela para conferir o visual |

## Testes no computador

```
godot --headless --path . -s tests/route.gd              # fase inteira, sem inimigos
godot --headless --path . -s tests/route2.gd             # Episódio 2 inteiro
godot --headless --path . -s tests/route.gd -- inimigos  # com inimigos (o robô não desvia)
```

Fontes: Lora e Cinzel (SIL Open Font License, em `assets/fonts`).
