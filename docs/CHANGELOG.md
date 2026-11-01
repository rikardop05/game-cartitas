# Changelog — Cartitas Infinity

## Levels 12–15, cenários, heróis e frame — 2026-11-01

### Jogo
- **15 Levels e 15 tipos:** L12 174 cartas (150 board + 24 deck), L13 183 (156+27), L14 192 (162+30) e L15 198 (168+30). Novos tipos `cat_mage`, `rhino` e `sacer`; 14 tipos com arte e `crystal` ainda em placeholder.
- **Decks:** 24 em L12, 27 em L13 e 30 em L14–L15; teto de **30 = 2 por tipo**. A regra (≤2 por tipo, tipo no board, board+deck múltiplo de 3) continua valendo.
- **Estrelas e limites:** L12 265/455, L13 275/480, L14 290/500 e L15 300/515 (1,5 s/2,6 s por carta); `time_limit` 900 s em L10/L14 e 1080 s em L11/L15.
- **Guardrails:** `MAX_COLUMNS 14`, `MAX_ROWS 7`, `MAX_BOARD_CARDS 168`, `MAX_LAYERS 5` (aberto; os níveis usam 4) e `MIN_CARD_SIZE_PX 24`. L12–L15 renderizam **25,3 px** no retrato (27,6 px na paisagem).
- **Geração:** 15 Levels solucionáveis (60/60 seeds em cada) e probe em **~1,7 s** (budget 4000 ms).

### Visual e assets
- **Fundos:** cenas próprias por Level de **7 a 15** (`assets/ui/backgrounds/level_NN.png` + `_portrait`); campo em L1–3, outono em L4–6 e **Endless usa a cena do L15**. O castelo antigo fica como fallback.
- **Heróis:** L12 `cat_mage`, L13 `rhino`, L14 `sacer` e L15 `wolf_knight` (retrato existente). Os três retratos novos são só de campanha; o Endless mantém o ciclo dos 9 heróis originais.
- **Frame do retrato:** novo `panel_board_frame_portrait.png` (1166×1184) assado no tamanho exato da janela: furo **327×185**, board **323×181**; a paisagem mantém o frame atual.
- **Board clip:** o offset passou a ser recalculado pelo bbox final (posição escalada + tamanho da carta) e limitado ao container; L14/L15 com `clip=0` em retrato, paisagem e desktops.

### Ferramentas e qualidade
- Suíte completa: **256 testes, 0 falhas**.
- `repro_board_capture` OK (portrait board 323×181, landscape 448×193), `repro_hud_bounds` GREEN nas 6 views, `regression_board_layout` OK em L1–L15 × 6 views.
- `probe_generation` OK nos 15 Levels (1,6–1,7 s; budget 4000 ms).

## Rodada de cartas e decks (Nexus) — 2026-10-30 (checkpoint anterior)

### Jogo
- **Totais por Level (tabuleiro+decks):** L1 27, L2 42, L3 48, L4 57, L5 78, L6 87, L7 105, L8 105, L9 150, L10 156, L11 168.
- **Decks de apoio:** 12 cartas em L1–L4, 18 em L5–L6 e 24 em L7–L11; teto de **24 = 2 por tipo**. Todo tipo do deck aparece no tabuleiro e board+deck por tipo é múltiplo de 3, então o deck nunca fecha trio sozinho.
- **Estrelas:** limites recalculados a **1,5 s/carta (3★)** e **2,6 s/carta (2★)** sobre o novo total; `time_limit` de **900 s no L10** e **1080 s no L11**.
- **Guardrails:** `MAX_COLUMNS 13`, `MAX_ROWS 7`, `MAX_BOARD_CARDS 144`, `MIN_CARD_SIZE_PX 24` (e `MAX_BOARD_CARD_PX 46`). L9–L11 renderizam **28,0–29,5 px** no retrato, acima do mínimo.
- **Geração:** orçamento do probe passou a **4000 ms**; os 11 Levels geram em 1 tentativa cada (~3,3–3,5 s no total, L11 ~1,0 s).

### Ferramentas e qualidade
- Suíte completa: **255 testes, 0 falhas** (Nexus).
- `test_difficulty_profile` cobre a regra do deck (≤2 por tipo, tipos no board, board+deck múltiplo de 3); `test_star_thresholds` recalcula os limites; `test_progression` valida 60 seeds por Level.

## Layout do retrato da tela do Level — 2026-10-30 (spec da Luna; checkpoint anterior)

### Jogo
- **Retrato:** o HUD passa a ocupar a altura toda da tela. Os **poderes** ficam no topo-esquerdo; o **herói grande** no topo-centro (atrás do HUD e do tabuleiro); a **barra da Clearing Zone** logo abaixo; o **tabuleiro na metade inferior**; **deck A, Reserve e deck B na mesma linha**; e o **rodapé** com engrenagem, som, placa de estrelas (ou pontuação no Endless) e o **logo Claw & Crown**.
- **Paisagem:** a barra de HUD continua com **48 px** e **sem logo**, com o layout do mockup.
- **Herói:** caixa 2:3 de **96×144** lógicos, desenhada a **1,6× em paisagem** e **1,8× em retrato**; no retrato fica grande no topo-centro, atrás do HUD/tabuleiro.
- **Tabuleiro (retrato):** janela de **339×196** com furo **329×184** e tabuleiro de ~325×180; a constante de validação `PORTRAIT_BOARD_ENVELOPE` segue **336×177**.
- **Qualidade:** suíte **251/251**; `repro_hud_bounds.gd` cobre o novo retrato (HUD 360×640, topo/rodapé, logo no rodapé e ausência de logo em paisagem).

## Rodada de UI, heróis e áudio — 2026-10-30 (branch `feat/connected-board-generation`)

### Jogo
- **Herói por fase:** o mascote único Ás deu lugar a um retrato de corpo inteiro por Level — L1 `cat`, L2 `wolf_ranger`, L3 `boar`, L4 `mouse`, L5 `owl`, L6 `frog`, L7 `knight`, L8 `bunny`, L9 `wolf_knight`; L10/L11 usam o lobo cavaleiro do menu como fallback. No Endless os nove heróis se revezam por rodada. A voz é neutra ("hero"), sem nomes próprios.
- **Expressões do L8:** a coelha troca de retrato conforme o humor — pensando (idle), sequência (feliz/trio/vitória), escolha errada (preocupado/zona quase cheia) e derrota (triste).
- **Clearing Zone:** removido o título; a barra comprida (`bar_zone.png`) é esticada por 9-slice, as cartas ficam centradas dentro do vão de madeira e os slots vazios não desenham placa quadrada.
- **Decks:** as placas quadradas (`card_available_frame.png`) agora são a mesa dos dois Support Decks, com a pilha de cartas por cima.
- **Reserve:** campo de pedra (`panel_reserve_field.png`) sem header/contador, alinhado à barra da Clearing Zone em paisagem, com as cartas centradas e grade que se adapta à lotação (até 34/42 px, mínimo 18 px).
- **Combinação:** cada carta do trio dispara seu próprio burst + fumaça pintados; as cartas na zona recebem sombra 3D sobre a madeira. A camada de FX não bloqueia toques.
- **Menu:** em paisagem usa `background_menu.png` (cidade), com logo no topo-esquerda, herói à esquerda/centro e placa com os botões à direita; em retrato mantém o fundo retrato atual, com logo no topo-centro e herói no canto inferior direito. Botões em PT usam a arte pronta; em EN usam a placa vazia com texto localizado. Parallax de três camadas.
- **Escala das cartas:** tabuleiro até 46 px (antes 40), Clearing Zone 46/42 px (paisagem/retrato), Support Decks 42 px.

### Visual e assets
- **12 tipos de carta:** oito personagens com arte nova (`cat`, `mouse`, `boar`, `owl`, `wolf`, `duck`, `frog`, `whale`) e `leaf`, `heart` e `gem` também com arte nova; `crystal` segue em placeholder. Removidos os tipos antigos (`bird`, `dog`, `fish`, `flower`, `moon`, `star`, `sun`).
- **Cartas normalizadas:** faces recortadas no limite duro da moldura, quadrados nativos de **882–957 px** e sem margem transparente.
- **Heróis:** 9 retratos + 4 expressões do L8 + o lobo do menu em `assets/ui/heroes/`.
- **Fundos:** castelo nos Levels 8–11 e no Endless, com recorte dedicado para retrato (`background_castle.png` / `background_castle_portrait.png`); campo nos Levels 1–3, outono nos 4–7 e cidade no menu em paisagem (`background_menu.png`). Filtro mais leve (menu blur 0,30/brilho 0,90; gameplay 0,60/0,82).
- **Kit:** moldura de madeira do tabuleiro (`panel_board_frame`), barra comprida da zona (`bar_zone`), campo de pedra da Reserve (`panel_reserve_field`), painel vertical de poderes (`panel_powers_board`, 751×1453, sem rotação), placas quadradas como mesa dos decks (`card_available_frame`) e ícones de poder (`assets/ui/icons/`).
- **FX:** `match_burst.png` e `match_smoke.png`, um par por carta combinada.
- **Marca:** `logo_claw_and_crown.png`, `background_menu.png` e os botões `btn_menu_jogar/opcoes/sair`.
- **HUD/som:** ícones de som e engrenagem repintados em alta resolução.

### Áudio
- Duas faixas em `assets/audio/music/`: **Beyond the Walls** (menu) e **Castle Eudora** (campanha e Endless), em loop e com crossfade de 0,8 s entre cenas.
- Autoload `Audio` com buses Music/SFX, headroom de −2 dB por faixa e limiter no Master; volume/mute das Opções e do HUD aplicados à música na hora, guardando o último volume.

### Ferramentas e qualidade
- Novos testes unitários: `test_audio.gd`, `test_backgrounds.gd`, `test_mascot_heroes.gd` e a atualização de `test_mascot_lines.gd`; suíte **250/250** neste checkpoint (**251** após o layout do retrato).
- Smokes atualizados: `smoke_main_menu.gd` cobre menu PT/EN (arte pronta × texto), logo/herói, layout da placa e parallax; `smoke_mascot_heroes.gd` cobre herói por fase, expressões do L8 e fala neutra. Utilitário `qa_visual_capture.gd` para captura visual.
- `probe_generation.gd` confirma os 11 Levels dentro do envelope e do orçamento (naquela rodada: 553 ms de geração no total, limite 1500 ms).

### Pendente
- Arte final de `crystal` (ainda placeholder).
- L10/L11 sem herói próprio (usam `hero_menu_wolf`).

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
