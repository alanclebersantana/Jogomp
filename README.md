# Milhas Plus – Cadê as milhas?!

Jogo de corrida contra o embarque para Android (celular em pé), feito em Godot 4.6.

O Barão das Milhas Falsas roubou as milhas dos clientes e espalhou pelos aeroportos. O robô **Milis**
corre sozinho pelo aeroporto: cada fase é um voo na última chamada, e é preciso chegar ao portão antes de
ele fechar, pegando as milhas pelo caminho.

## Como se joga
- **Toque**: pula. Segurar o toque pula mais alto.
- **Toque no ar**: pulo duplo.
- **Segurar no ar** (depois de achar as asas de avião): plana. Os ventiladores do chão levam para cima.
- **Parede comum**: o Milis bate e vira para o outro lado.
- **Parede verde**: ele sobe correndo; um toque salta para a parede do outro lado.
- **Tropeçou** (passageiro, carrinho, mala, laser, capanga, buraco): volta ao último totem de check-in e
  o relógio do embarque continua correndo.
- Pule na cabeça dos capangas do Barão, das malas e das malas voadoras para quicar.

## Fases prontas
Guarulhos (milhas LATAM): 1-1 Saguão de Check-in e 1-2 Raio-X e Portas. As outras 6 fases e o chefe
(Motoboy Turbo) vêm depois; depois Maringá, Brasília, Salvador e Rio, onde está o Barão.

## Pastas
- `scripts/` — o jogo (`jogo.gd`: corrida, obstáculos e desenho; `main.gd`: telas; `fase.gd`: leitura das fases).
- `assets/fases/` — as fases em texto, geradas por `tools/fases.py` (a legenda das letras está lá).
- `assets/art/` — a arte, recortada das folhas do Gemini (`art_src/gemini`) por `tools/arte.py`; alguns
  objetos são desenhados em código por `tools/desenhos.py`.
- `assets/audio/` — efeitos e músicas (`tools/musica.py`, com instrumentos gravados).
- `tests/rota.gd` — um robô joga as fases do começo ao fim (roda no GitHub antes de gerar o APK).
- `tests/foto.gd` — tira prints das telas e de pontos das fases.

## APK
A cada envio para `main`, o GitHub gera dois APKs na página de versões (Releases): o normal e o de teste
(todas as fases liberadas, instala ao lado do normal). A chave de assinatura é fixa (`tools/chave_debug.jks`),
então as versões novas instalam por cima das antigas.
