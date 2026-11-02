# Claw & Crown

Jogo de puzzle de cartas (combine 3 iguais) feito em Godot.

**Claw & Crown** é a marca exibida no menu: um logo pintado substitui o título em texto. O nome interno do projeto continua **Cartitas Infinity** (`project.godot`, assembly `CartitasInfinity` e o executável de build).

## Como rodar o jogo

### 1. Instale o Godot (se ainda não tiver)

- Baixe o **Godot 4.7** em https://godotengine.org/download/windows/.
  - O jogo é 100% GDScript e roda na versão padrão.
  - Para usar o addon **Godot-MCP** (`addons/godot_mcp`, integração com agentes de IA como o Claude Code), use a edição **.NET** (`Godot_v4.7-stable_mono_win64.exe`) com o .NET 8 SDK instalado. Na versão padrão o editor avisa que não consegue carregar esse plugin; o jogo e os testes funcionam normalmente.
- Descompacte o arquivo e abra o executável.

### 2. Abra o projeto

1. Na tela inicial do Godot, clique em **Importar**.
2. Selecione a pasta deste projeto (a pasta que contém o arquivo `project.godot`).
3. Clique em **Importar e Editar**.

### 3. Rode o jogo

- Pressione **F5** (ou o botão ▶ **Play** no canto superior direito).

Pronto! O jogo abre no menu. Escolha um level e jogue.

## Como jogar (resumo rápido)

- Clique/tocar nas cartas **disponíveis** (coloridas) para enviá-las à **Clearing Zone**.
- Junte **3 cartas iguais** para removê-las automaticamente. A zona não tem título: as cartas ficam centralizadas dentro da madeira da barra comprida e os slots vazios não mostram placas quadradas.
- Cartas **escuras** estão bloqueadas por outras cartas em cima (quanto mais fundo na pilha, mais escuras).
- Use os dois **decks** (pilhas de cartas embaixo do tabuleiro) quando não houver jogada; as placas quadradas de madeira são a mesa de cada deck, com a carta por cima. Cada tipo aparece no máximo 2 vezes nos decks, então um deck nunca fecha trio sozinho.
- Poderes (painel vertical de madeira, com um ícone por poder e o estoque "xN"):
  - **Hold** — guarda as 3 cartas mais antigas (da esquerda) na **Reserve**, liberando espaço. **Qualquer** carta da Reserve volta para a zona com um toque; com a zona cheia, ela pisca em vermelho e o herói avisa.
  - **Undo** — devolve a última carta ao tabuleiro/deck.
  - **Refresh** — reembaralha o tabuleiro e os decks.
- Vença limpando **todas** as cartas antes de encher a Clearing Zone. Se a zona encher e você não tiver Hold nem Undo para liberar espaço, o Level termina na hora.
- São **15 Levels** (45★ no total), com **27 a 198 cartas** no total (tabuleiro+decks). Cada tentativa gera um tabuleiro novo: a base preenche um grid e as camadas de cima ficam espalhadas em posições irregulares (sem fileiras), sempre com cartas livres e garantidamente solucionável com os decks e os poderes.
- A recompensa de um Level (ex.: +1 Hold) vem só na **primeira** vitória; rejogar serve para melhorar as estrelas.
- **Endless Mode** (libera ao vencer o último Level, hoje o 15, no topo da lista de Levels): rodadas seguidas com dificuldade crescente, sem tempo limite. Cada carta combinada vale 10 pontos e cada rodada limpa dá um bônus de 100 × rodada. A partida usa um estoque de poderes próprio (2 Hold, 2 Undo, 1 Refresh, +1 poder a cada 3 rodadas) e não gasta o seu inventário. Seu recorde fica salvo.
- **Herói da fase:** em vez de um mascote único, cada Level tem um retrato de corpo inteiro — **L1** gato, **L2** lobo patrulheiro, **L3** javali, **L4** rato, **L5** coruja, **L6** sapo, **L7** cavaleiro, **L8** coelha, **L9** lobo cavaleiro; **L10/L11** usam o lobo cavaleiro do menu como fallback; **L12** gato mago, **L13** rinoceronte, **L14** sacer, **L15** fecha com o lobo cavaleiro (retrato existente). No Endless, os 9 heróis se revezam a cada rodada. O **L8** troca o retrato conforme o humor (4 expressões: pensando, sequência/feliz, escolha errada/preocupado e derrota/triste); os outros heróis mantêm um retrato e variam só por tinta/deslocamento. A voz é sempre neutra ("hero"), sem nomes próprios.
- O herói diz a instrução no início de cada Level/rodada, dá dicas e reage às jogadas; dá para desligá-lo em **Opções** (a instrução aparece então num balão avulso).
- **Estrelas ao vivo:** no topo, uma placa com 3 estrelas; a estrela "da vez" vai virando **pedra** conforme o tempo passa e, quando o tempo dela acaba, faz um **pluff** e fica de pedra; a primeira estrela fica sempre dourada (vencer vale ao menos 1★). A tela de resultado mostra a mesma placa com as estrelas conquistadas. Os limites seguem o tamanho do Level: **3★ até ~1,5 s por carta** e **2★ até ~2,6 s por carta** (tabuleiro + decks), contados em segundos inteiros como no relógio.
- Os Levels **10, 11, 14 e 15** têm **tempo limite** de **900 s** ou **1080 s** (contagem regressiva; L10/L14 900 s, L11/L15 1080 s); nos demais o cronômetro só conta para cima. O cronômetro pausa enquanto a ajuda (?) está aberta ou o jogo está em segundo plano.
- **Combinação:** ao fechar um trio, as três cartas piscam, somem e cada uma dispara seu próprio **burst + fumaça** pintados; as cartas da zona deslizam/pulam para os slots livres e têm sombra 3D sobre a madeira.
- **Som e música:** menu toca *Beyond the Walls*; campanha e Endless tocam *Castle Eudora*. As duas faixas fazem loop e trocam com crossfade. Volume nas **Opções** (−, barra arrastável, +; o ícone vira "mudo" em zero) e, na tela de jogo, o ícone para silenciar/voltar ao último volume.
- **Configurações na partida:** a **engrenagem** ao lado do som pausa o relógio e abre idioma, orientação da tela, herói/mascote e volume, sem perder a partida.

## Levels e cartas

| Level | Tabuleiro | Decks | Total | 3★ | 2★ | Limite |
|---|---|---|---|---|---|---|
| 1 | 15 | 12 | 27 | 45 s | 75 s | — |
| 2 | 30 | 12 | 42 | 65 s | 110 s | — |
| 3 | 36 | 12 | 48 | 75 s | 125 s | — |
| 4 | 45 | 12 | 57 | 90 s | 150 s | — |
| 5 | 60 | 18 | 78 | 120 s | 205 s | — |
| 6 | 69 | 18 | 87 | 135 s | 230 s | — |
| 7 | 81 | 24 | 105 | 160 s | 275 s | — |
| 8 | 81 | 24 | 105 | 160 s | 275 s | — |
| 9 | 126 | 24 | 150 | 225 s | 390 s | — |
| 10 | 132 | 24 | 156 | 235 s | 410 s | 900 s |
| 11 | 144 | 24 | 168 | 235 s | 440 s | 1080 s |
| 12 | 150 | 24 | 174 | 265 s | 455 s | — |
| 13 | 156 | 27 | 183 | 275 s | 480 s | — |
| 14 | 162 | 30 | 192 | 290 s | 500 s | 900 s |
| 15 | 168 | 30 | 198 | 300 s | 515 s | 1080 s |

Os decks de apoio têm no máximo **2 cartas de cada tipo** (teto de 30 cartas com os 15 tipos); todo tipo do deck também aparece no tabuleiro e o total board+deck por tipo é múltiplo de 3, então um deck nunca fecha trio sozinho. O tabuleiro vai de 15 a 168 cartas (grade até **14×7**, 4 camadas); os Levels 9–11 renderizam **28–29,5 px** e os Levels 12–15 **25,3 px** no retrato (mínimo de 24 px). O probe de geração usa orçamento de **4000 ms** (~1,7 s no total).

## Cartas

São **15 tipos** (`CardTypeRegistry`): `cat`, `mouse`, `boar`, `owl`, `wolf`, `duck`, `frog`, `whale`, `leaf`, `heart`, `gem`, `crystal`, `cat_mage`, `rhino`, `sacer`.

- Oito personagens têm **arte nova**: gato, rato, javali, coruja, lobo, pato, sapo e baleia.
- `leaf`, `heart` e `gem` também ganharam arte nova (elfa/arqueira, coelha paladina e coelha cavaleira).
- **Novos em L12–L15:** `cat_mage` (gato mago), `rhino` (rinoceronte) e `sacer` (sacer), todos com arte.
- `crystal` ainda usa o **placeholder** (cor + emoji) e será substituído pela arte final; os outros **14 tipos** têm face pintada.
- Cada face é recortada no limite duro da moldura e entregue num quadrado nativo de **882–957 px**, sem margem transparente; o jogo aplica mipmaps e filtro trilinear.

## Visual

- **Fundos pintados:** o menu em **paisagem** usa `background_menu.png` (cidade); o menu em **retrato** mantém o fundo retrato atual. Nos Levels, campo nos **1–3**, cidade de outono nos **4–6** e **cenas próprias por Level de 7 a 15** (`assets/ui/backgrounds/level_NN.png` + `_portrait`); o **Endless usa a cena do L15**. O castelo antigo fica como fallback se um arquivo faltar.
- **Filtro dos fundos:** mais leve para manter a definição — menu com blur **0,30** e brilho **0,90**; gameplay com blur **0,60** e brilho **0,82** (saturação 0,95/0,90, tint 0,05/0,08 e vinheta 0,25/0,35).
- **Tamanhos de carta:** tabuleiro até **46 px** (lógico); Clearing Zone **46 px** em paisagem e **42 px** em retrato; Support Decks **42 px**; Reserve em grade que encolhe de **34 px** (paisagem) / **42 px** (retrato) até um mínimo de **18 px**, conforme a quantidade de cartas guardadas.
- **Janela do tabuleiro** com moldura de madeira pintada; no retrato usa o **frame vertical novo** (`panel_board_frame_portrait.png`), assado no tamanho exato (furo 327×185, board 323×181), enquanto a paisagem mantém o frame atual. O posicionamento do board foi corrigido para nunca recortar cartas (L14/L15 com `clip=0`).
- **Tela do Level (retrato):** poderes no **topo-esquerdo**; **herói grande no topo-centro** (na camada atrás do HUD e do tabuleiro); barra da Clearing Zone logo abaixo; **tabuleiro na metade inferior**; **deck A, Reserve e deck B na mesma linha**; rodapé com **engrenagem, som, placa de estrelas** (ou pontuação no Endless) **e logo Claw & Crown**. O **HUD ocupa a altura toda** da tela no retrato. Em **paisagem**, a barra de HUD continua com **48 px** e **sem logo**.
- **Clearing Zone e decks:** a barra comprida (`bar_zone.png`) é esticada por 9-slice e as cartas ficam dentro do vão de madeira, centradas; as placas quadradas (`card_available_frame.png`) viraram a mesa dos dois Support Decks, com a pilha de cartas por cima.
- **Menu:** logo **Claw & Crown** (topo-esquerda em paisagem, topo-centro em retrato), lobo cavaleiro de corpo inteiro (esquerda/centro em paisagem, canto inferior direito em retrato), placa de madeira com os três botões e o total de estrelas sob o logo (paisagem) ou sob a placa (retrato), e **parallax** em três camadas. Em **PT** os botões usam a arte pronta (`btn_menu_jogar/opcoes/sair`); em **EN** usam a placa vazia com o texto localizado.
- **Reserve:** campo de **pedra** pintado (`panel_reserve_field`), sem header/contador, alinhado à barra da Clearing Zone em paisagem e com as cartas centradas no vão.
- **Poderes:** painel vertical de madeira (`panel_powers_board`, 751×1453 px) usado sem rotação nas duas orientações, com ícone e estoque de cada poder.

## Como rodar os testes (opcional)

Abra o terminal (PowerShell) na pasta do projeto e rode os testes unitários:

```powershell
& "C:\caminho\para\Godot_v4.7-stable_win64_console.exe" --headless --path "E:\Cartitas" --script "res://tests/run_tests.gd"
```

O runner roda 256 testes unitários, incluindo `test_level_boards.gd` e `test_board_scatter.gd` (tabuleiros gerados de todos os Levels e rodadas do Endless, incluindo o espalhamento das camadas de cima), `test_card_art.gd` (arte das cartas em alta resolução com mipmaps), `test_star_thresholds.gd` (limites de estrelas por carta), `test_audio.gd` (faixas e mixagem), `test_backgrounds.gd` (fundos por Level/orientação), `test_mascot_heroes.gd` (heróis por fase e expressões do L8) e `test_mascot_lines.gd`. Troque o caminho pelo executável `_console.exe` do seu Godot. O CI (`.github/workflows/ci.yml`) roda também estes scripts, do mesmo jeito (`--script res://tests/<nome>.gd`); o `smoke_mascot_heroes.gd` por enquanto é local:

| Script | O que verifica |
|---|---|
| `smoke_level.gd`, `smoke_main_menu.gd` | as cenas abrem sem erro |
| `smoke_endless.gd` | fluxo do Endless: rodada, pontos, rodada concluída, fim de partida e recorde |
| `smoke_rapid_taps.gd` | toques rápidos seguidos nunca se perdem; animações sobrepostas terminam com a zona correta |
| `smoke_help.gd` | a ajuda (?) cabe na tela nas duas orientações e sempre fecha |
| `smoke_reserve.gd` | toda carta da Reserve volta à zona com clique real; a jogada sem saída relatada é vencível |
| `smoke_stars.gd` | a estrela da vez vira pedra, faz pluff no tempo certo e a placa passa de 3★ a 1★; a primeira estrela fica dourada |
| `smoke_settings.gd` | a engrenagem pausa o jogo e muda idioma, orientação, mascote e volume sem perder a partida |
| `smoke_mascot_heroes.gd` | herói por fase, expressões do L8 e fala neutra no balão |
| `smoke_bunny_rig.gd` | rig novo da coelha: cena carrega, Idle de 4 s toca, polígonos válidos e o L8 alterna rig (idle) ↔ expressões pintadas |
| `regression_board_layout.gd` | posições das cartas de todos os Levels em todas as resoluções (retrato, paisagem e desktop) |
| `probe_generation.gd` | tempo de geração e qualidade dos tabuleiros (validador, solucionável; orçamento 4000 ms) |
| `repro_hud_bounds.gd` | HUD inteiro dentro da tela em 6 views: campanha e Endless, retrato e paisagem, mais as views com o mascote desligado; no retrato confere o HUD de tela cheia, o rodapé e o logo |
| `repro_board_capture.gd` | tabuleiro da cena igual ao do gerador, em retrato (336×177) e paisagem (448×193) |

## Estrutura do projeto

| Pasta        | O que contém                          |
|--------------|---------------------------------------|
| `scenes/`    | Cenas (menu principal e tela do level) |
| `scripts/core/` | Lógica do jogo (sem UI); inclui `audio_manager.gd` |
| `scripts/ui/`   | Interface, menu, heróis (`hero_roster.gd`) |
| `levels/`    | Arquivos JSON que definem os níveis   |
| `assets/`    | Cartas (`cards/`, 882–957 px nativos), heróis (`ui/heroes/`), logo e botões PT (`ui/branding/`), FX (`ui/fx/`), ícones, kit de UI, fundos e músicas (`audio/music/`) |
| `tests/`     | Testes automatizados                  |
| `docs/`      | Spec, ADRs, guias de arte e `CHANGELOG.md` |
| `addons/godot_mcp/` | Addon Godot-MCP (C#, só no editor .NET) |
