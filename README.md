# Milhas Plus - Última Chamada!

Jogo de corrida 2D para celular em pé, em **Godot 4.6** (Android), no mesmo estilo de arte do Encontre-a.
O mascote da Milhas Plus está atrasado para o voo: ele corre sozinho pelos aeroportos, recolhe milhas,
foge do guarda e precisa chegar ao avião antes de o portão fechar.

**Episódio 1 · Brasil:** Guarulhos (pronto), Maringá, Brasília, Salvador e Rio de Janeiro (em breve).
**Episódio 2 · Mundo:** aeroportos de fora (em breve).

## Controles

| Gesto | Teclado | Controle | O que faz |
|---|---|---|---|
| Toque ou arrastar para cima | ↑ / W / Espaço | A | Pular |
| Segurar (depois do pulo) | segurar ↑ | segurar A | Planar (a mochila abre asas) |
| Arrastar para baixo | ↓ / S | B | Rolar no chão · descer rápido no ar |
| Arrastar para a frente ou toque duplo | → / D / Shift | X / RB | Acelerar |
| Arrastar para os lados (no trem) | ← → | direcional | Trocar de faixa |

## Fase 1 · Guarulhos (SP)

Calçada com garoa e táxis, check-in com mezanino, buraco que leva às esteiras de bagagem (com mola para voltar),
raio-x e detector de metal (passe rolando ou o alarme dispara), piso molhado, o trem entre terminais em visão
de trás (3 faixas, vagões com rampa e trem vindo), área de embarque com pastel e caldo de cana, e o finger até o avião.
Ao fundo: MASP, Ponte Estaiada e os prédios da Paulista. Milhas da fase: LATAM.

Estrelas: chegar a tempo · juntar a meta de milhas · achar a mala dourada.

## Como baixar o APK no celular

Cada envio para a branch `main` dispara o GitHub Actions (`.github/workflows/android.yml`), que:
1. baixa o Godot 4.6.2 e os modelos de exportação;
2. roda o teste automático em que um robô joga a fase inteira (`tests/route.gd`);
3. gera dois APKs e publica em **Releases**:
   - `ultima-chamada.apk`: o jogo normal;
   - `ultima-chamada-teste.apk`: versão de teste com todas as fases liberadas (instala ao lado do normal).

Para publicar na Play Store, cadastre a chave nos *Secrets*: `KEYSTORE_BASE64`, `KEYSTORE_USER` e `KEYSTORE_PASSWORD`.

## Estrutura

| Pasta/arquivo | O que tem |
|---|---|
| `assets/data/guarulhos.json` | a fase: chão, obstáculos, milhas, dicas, trecho de trás (gerado por `tools/gerar_guarulhos.py`) |
| `scripts/sim.gd` | física e regras (mascote, guarda, obstáculos, tempo), sem desenho |
| `scripts/regras.gd` | números do jogo: velocidade, pulo, planar, guarda |
| `scripts/main.gd` | desenho da visão lateral e da visão de trás, HUD, telas, controles e sons |
| `tools/make_mascote.py` | desenha o mascote (de lado, de costas, expressões dos olhos de LED) |
| `tools/make_pessoas.py` | guarda, passageiros, comissária, atendente |
| `tools/make_objetos.py` | malas, balcões, raio-x, placas, milhas, avião e o que aparece no trem |
| `tools/make_fundos.py` | céu de São Paulo, paredes do terminal, subsolo, finger e a vista do trem |
| `tests/route.gd` | o robô joga a fase do começo ao fim |

A arte é desenhada em código (`pip install pycairo` e rode os scripts de `tools/`). Para trocar por arte
feita no Gemini, gere a imagem com o mesmo tamanho e o mesmo nome de arquivo em `assets/`.

Para tirar prints da fase: `godot --path . -- --fotos=3,100,300 --pasta=/tmp`.
