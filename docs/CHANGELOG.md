# Changelog — Cartitas Infinity

## Rodada de polimento — 2026-10-28 / 29 (branch `feat/connected-board-generation`)

### Jogo
- **Regras:** Undo de carta de deck devolve a carta certa; zona cheia sem Hold/Undo encerra o Level na hora; motivo da derrota (zona cheia × tempo esgotado); estrelas contam segundos inteiros como o relógio; recompensa só na primeira vitória; cronômetro pausa na ajuda e em segundo plano.
- **Tabuleiros:** gerados pelo `BoardPipeline` para todos os Levels e o Endless — base que preenche um grid, camadas de cima espalhadas em grade de 1/4 de carta (sem fileiras), sempre solucionável com decks e poderes; um tabuleiro novo a cada tentativa; bases largas (4×2 no L1 até 9×4 no L11) e mais cartas por Level.
- **Endless Mode:** rodadas de dificuldade crescente, pontuação, estoque de poderes próprio, recorde local; libera após o último Level.
- **Estrelas:** limites recalibrados (≈1,5 s/carta para 3★, ≈2,6 s/carta para 2★); placa de estrelas pintada no HUD, em que a estrela da vez vira pedra com o tempo e faz *pluff* ao acabar; a mesma placa na tela de resultado.
- **Configurações na partida:** engrenagem ao lado do som (idioma, orientação, mascote, volume) sem perder a partida; cronômetro dourado colado ao relógio.
- **Reserve:** qualquer carta volta à zona (antes só a última, o que podia travar uma partida vencível); layout em grade; aviso quando a zona está cheia.
- **Toques instantâneos:** a jogada vale ao apertar; animações não bloqueiam o próximo toque.

### Visual e áudio
- Kit de UI em pixel art (tela de jogo no mockup, menu, lista de Levels, Opções) e fundos pintados com filtro (campo nos Levels 1–3, outono do 4 em diante).
- Mascote original **Ás** com dicas, reações e a instrução no balão.
- Cartas do Pack A (8 tipos) em alta resolução com mipmaps — nítidas em qualquer resolução; padrão de 960 px no guia de arte.
- Volume nas Opções (barra do kit) e ícone de som no HUD.
- Ajuda (?) centralizada e sempre fechável.

### Ferramentas e qualidade
- Addon Godot-MCP (C#) instalado para trabalhar no editor .NET com agentes (não versionado).
- Demo portátil: `export_presets.cfg` gera `build/CartitasInfinity.exe` (arquivo único).
- Testes: 217 testes unitários e 12 scripts de cena no CI (smokes de Endless, toques rápidos, ajuda, Reserve, estrelas e configurações na partida; regressões de layout e de geração). Os testes nunca gravam no save do jogador (usam `Game.save_path` descartável).

### Pendente
- Arte para os tipos leaf, heart, gem e crystal (placeholders).
- `docs/ART-DELIVERY-PT.pdf` ainda descreve o padrão antigo de 48 px.
- O passo de 1/4 de carta não cai em pixel inteiro no Level 11 em retrato (~9,4 px).
