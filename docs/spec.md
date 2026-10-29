# Cartitas Infinity — Especificação

> Documento de spec consolidado. Termos em itálico na primeira ocorrência são os termos canônicos do glossário (`CONTEXT.md`). Este documento substitui qualquer versão anterior das regras.

## Problem Statement

O jogador quer um puzzle de cartas baseado em combinação de três cartas idênticas, no qual deve limpar completamente o tabuleiro de cada *Level* selecionando cartas disponíveis, acumulando-as numa área temporária limitada (a *Clearing Zone*) e formando trios. O desafio não é velocidade de clique, mas **planejamento da ordem das jogadas**, **gerenciamento de espaço limitado** e **uso estratégico de poderes e decks limitados**.

O sistema precisa ser modular e orientado a dados, para que novos níveis, tipos de carta, poderes e regras sejam adicionados sem alterar a lógica principal. A lógica de domínio deve ser testável sem depender da interface visual, e a fonte de verdade deve ser sempre o estado interno do jogo.

## Solution

Um jogo 2D em pixel art (Godot 4.7, GDScript), mobile-first em retrato (9:16) com suporte a desktop para desenvolvimento. Cada *Level* é definido por um arquivo JSON (data-driven). O jogador seleciona *Cards* disponíveis do *Board* (ou dos dois *Support Decks*) para a *Clearing Zone*; três cartas do mesmo *Card Type* são removidas automaticamente. Três *Powers* limitados (*Hold*, *Undo*, *Refresh*) ajudam a gerenciar o espaço e a ordem. A vitória ocorre quando não restam cartas ativas; a derrota ocorre quando a Clearing Zone está cheia sem combinação possível.

A lógica é separada da apresentação: `GameController` (classe pura, sem `Node`) contém todo o estado e as regras; a UI apenas representa o estado interno e envia ações.

## User Stories

1. Como jogador, quero ver o *Board* de um *Level* carregado a partir de uma configuração, para poder jogar fases diferentes sem recompilar.
2. Como jogador, quero ver as cartas distribuídas em camadas com sobreposição, para entender o que está bloqueado.
3. Como jogador, quero que cartas *Blocked* não sejam selecionáveis, para respeitar as regras de bloqueio.
4. Como jogador, quero selecionar uma carta *AVAILABLE* com um toque, para enviá-la à Clearing Zone.
5. Como jogador, quero ver a carta selecionada sair do tabuleiro e mover-se até a Clearing Zone, para ter feedback da ação.
6. Como jogador, quero que três cartas do mesmo *Card Type* na Clearing Zone sejam removidas automaticamente, para limpar espaço.
7. Como jogador, quero ver uma animação quando um trio é formado, para reconhecer a combinação.
8. Como jogador, quero que cartas bloqueadas sejam desbloqueadas quando a carta que as cobria é removida, para liberar novas jogadas.
9. Como jogador, quero que a Clearing Zone tenha capacidade limitada (7 por padrão), para que o espaço seja um recurso a gerenciar.
10. Como jogador, quero ser avisado (e perder) quando a Clearing Zone está cheia e não consigo formar combinação, para que a derrota seja determinística.
11. Como jogador, quero que uma Clearing Zone cheia rejeite qualquer nova carta, mantendo a capacidade visível como limite absoluto.
12. Como jogador, quero usar os dois *Support Decks*, tocando na carta do topo para enviá-la à Clearing Zone, para ter cartas extras quando o tabuleiro travar.
13. Como jogador, quero ver apenas a carta do topo de cada *Support Deck*, para saber o que virá se eu usá-la.
14. Como jogador, quero que cada *Support Deck* seja finito, para que seja um recurso limitado.
15. Como jogador, quero usar o poder *Hold* para mover as 3 cartas mais antigas (da esquerda) da Clearing Zone para a *Reserve*, para liberar espaço na zona.
16. Como jogador, quero devolver cartas da *Reserve* para a Clearing Zone com um toque, para retomá-las e formar trios.
17. Como jogador, quero que o *Hold* mova exatamente as 3 cartas mais antigas da Clearing Zone, para que o poder tenha um efeito definido.
18. Como jogador, quero que o *Hold* seja rejeitado (sem consumir o poder) se a Clearing Zone estiver vazia, para não desperdiçar recursos.
19. Como jogador, quero usar o poder *Undo* para devolver a última carta da Clearing Zone ao seu *Board* ou *Support Deck*, para corrigir um engano.
20. Como jogador, quero que o *Undo* não desfaça trios já combinados, para manter a regra simples na v1.
21. Como jogador, quero que o *Undo* seja rejeitado (sem consumir o poder) se não houver carta para devolver, para não desperdiçar recursos.
22. Como jogador, quero usar o poder *Refresh* para reembaralhar as posições das cartas restantes do *Board* e a ordem dos dois *Support Decks*, para tentar um novo arranjo.
23. Como jogador, quero que o *Refresh* não altere cartas removidas, nem a Clearing Zone, nem a Reserve, para que o embaralhamento seja previsível.
24. Como jogador, quero que cada poder tenha um estoque limitado e visível, para planejar seu uso.
25. Como jogador, quero que o uso de um poder consuma uma unidade do *Inventory* de forma permanente, para que o recurso seja persistente entre partidas.
26. Como jogador, quero ser impedido de usar um poder sem estoque disponível, para respeitar o limite.
27. Como jogador, quero ver um cronômetro contando o tempo do *Level* (MM:SS), para acompanhar meu desempenho.
28. Como jogador, quero que o cronômetro pare imediatamente ao vencer ou perder, para registrar o tempo final correto.
29. Como jogador, quero receber 1, 2 ou 3 estrelas conforme o tempo final, para ter uma avaliação de desempenho.
30. Como jogador, quero que os limites de tempo das estrelas sejam definidos por *Level*, para balancear cada fase.
31. Como jogador, quero ver uma tela de vitória ao limpar todo o *Board* (tabuleiro, decks, Clearing Zone e Reserve vazios), para saber que venci.
32. Como jogador, quero ver uma tela de derrota ao encher a Clearing Zone sem combinação, para saber que perdi.
33. Como jogador, quero que, ao vencer, o próximo *Level* seja liberado, para progredir.
34. Como jogador, quero receber recompensas ao vencer (ex.: +1 *Hold*), definidas pelo *Level*, para ter incentivo de progresso.
35. Como jogador, quero que meu progresso (níveis concluídos, estrelas, inventário) seja salvo e persista ao fechar o jogo, para não perder avanços.
36. Como jogador, quero jogar em inglês ou português, para usar minha língua preferida.
37. Como jogador, quero que a UI mostre o número do *Level*, o cronômetro, as estrelas, o Board, os dois Support Decks, a Clearing Zone, a Reserve e os três poderes, para ter tudo acessível.
38. Como jogador, quero ver claramente o estado de cada carta (bloqueada, disponível, selecionada), para decidir corretamente.
39. Como jogador, quero feedback visual a cada ação (destaque, movimento, fade), para entender o que aconteceu.
40. Como jogador, quero que os primeiros níveis sejam simples (poucos tipos, pouca sobreposição) e os avançados mais complexos (mais camadas e tipos), para uma progressão de dificuldade justa.
41. Como desenvolvedor, quero definir um *Level* apenas editando um JSON, para criar conteúdo sem tocar no código.
42. Como desenvolvedor, quero validar uma configuração de *Level* (trios possíveis, IDs únicos, capacidade, tempos) antes de publicá-lo, para evitar fases impossíveis.
43. Como desenvolvedor, quero que a lógica do jogo rode sem a UI (headless), para escrever testes automatizados.
44. Como desenvolvedor, quero consultar o estado do jogo e as ações legais programaticamente (`getGameState`, `getLegalActions`), para futuramente treinar um agente de IA.
45. Como artista, quero um documento (PT e EN) explicando como incluir os sprites (resoluções, paleta, nomes de arquivo, caminhos, importação), para entregar a arte no formato certo.
46. Como jogador/testador, quero artes placeholder (símbolos/emoji + cores) já funcionais, para jogar e validar antes da arte final.

## Implementation Decisions

### Engine e apresentação
- **Engine:** Godot 4.7 estável, **GDScript**. O jogo roda na edição padrão; o addon de editor Godot-MCP (`addons/godot_mcp`, C#) exige a edição .NET.
- **Plataforma:** mobile-first em retrato (9:16) como layout de referência; paisagem 16:9 continua disponível. Touch-first, com suporte a mouse.
- **Resolução:** base lógica principal 640×360, janela de desenvolvimento 1280×720, com modo retrato 360×640, upscale inteiro e `texture_filter = nearest`. A área do tabuleiro é de **332×264** px em retrato e **466×214** px em paisagem (`LevelConfig.PORTRAIT_BOARD_ENVELOPE` / `LANDSCAPE_BOARD_ENVELOPE`).
- **Unidades visuais:** arte de carta em alta resolução (PNG quadrado de 960 px, moldura inclusa), desenhada com mipmaps e filtro trilinear no tamanho físico da tela; cartas do tabuleiro com no máximo 40 px lógicos (`LevelConfig.MAX_BOARD_CARD_PX`); Clearing Zone 40 / 36 px (paisagem / retrato); Reserve em grade que cabe na caixa (18–40 px); Support Decks dentro dos quadrados de 64 px do kit; kit de UI em pixel art na escala lógica 1:1.
- **Tela do Level:** segue o mockup do kit de UI (ver "Arte de UI e fundos"): seta verde, título e ajuda (?) no topo esquerdo; placas do relógio e das estrelas ao vivo no topo (no Endless, a pontuação); botão de som no topo direito; janela do tabuleiro com o fundo escurecido dentro; poderes e deck B à direita, deck A à esquerda com o mascote Ás acima; Reserve e barra da Clearing Zone no rodapé. Em retrato, a mesma linguagem empilhada. A instrução **não cobre o tabuleiro**: o Ás a diz no balão por ~4 s (com o mascote desligado, um balão avulso). Cartas bloqueadas escurecem progressivamente com a profundidade (cartas com arte usam uma tabela um pouco mais clara para continuarem reconhecíveis); cartas de layers superiores têm uma sombra suave. **Estrelas ao vivo:** placa pintada com 3 estrelas (`assets/ui/hud/stars_<n>.png`); a estrela em jogo vira pedra gradualmente ao longo da sua janela de tempo (transição entre o estado atual e o seguinte) e faz um *pluff* de fumaça quando o limite passa, ficando de pedra; a primeira estrela nunca vira pedra. O relógio tem um cronômetro dourado colado à placa. Uma engrenagem ao lado do som pausa o jogo e abre as configurações (idioma, orientação, mascote, volume), aplicadas na hora sem reiniciar o Level.

### Arquitetura e costuras
- **`GameController`** (classe pura, `RefCounted`, sem `Node`): orquestra o fluxo da partida, mantém o `GameState` como fonte de verdade e recebe as ações. É a **costura de replay/integração** (estados, Undo e replay headless de witnesses) — não é a única costura do sistema: os seams do Board são testados diretamente, sem passar por ele.
- **Seams core do Board** (integrados à produção: `LevelLoader.resolve` — Levels da campanha e rodadas do Endless — gera o tabuleiro com `BoardPipeline` via `LevelBoardGenerator`, e `BoardManager` joga o tabuleiro gerado; são o pipeline de geração e o runtime do tabuleiro):
  - **`BoardPipeline`** (`BoardSpec` → `BoardBuildResult`): módulo **puro e testável** (sem `Node`, sem dependência de `GameController`). A base (layer 0) é conectada/compacta e preenche um grid de cartas inteiras; os layers superiores são **espalhados**: cada carta fica numa posição da grade de 1/4 de carta dentro da área da base, apoiada em pelo menos duas cartas do layer de baixo (limiar de 10%), sem cobrir mais de 75% de nenhuma e sem sobreposição dentro do mesmo layer. A escolha é gulosa e semeada, penalizando cartas lado a lado na mesma linha/coluna, alinhamentos, deslocamentos repetidos e regiões já ocupadas; uma parcela de cada layer grande fica descoberta para nunca faltar carta livre. Tabuleiros com fileiras, pouca variedade ou regiões vazias são rejeitados. Falhas estruturadas via `error_code` (`SPEC_INVALID`, `BUDGET_EXHAUSTED`, `COMPACTNESS_REJECTED`, `UPPER_LAYER_REJECTED`).
  - **`LevelBoardGenerator`**: ponte entre o perfil e o pipeline. Mapeia cada linha de `DifficultyProfile` (`LevelConfig.build_spec()`) para um `BoardSpec`, tenta seeds `seed + tentativa`, prefere tabuleiros dentro da banda `free_ratio_min/max` e só devolve tabuleiros **solucionáveis com os Support Decks e os poderes** (`SolvabilityChecker`); a divisão dos decks e a seed dos símbolos derivam da mesma seed da tentativa. Preenche `generation_metrics` (ver `docs/LEVEL-CONFIG-SCHEMA.md`). O antigo `LayoutGenerator` ficou legado, só para JSONs com `layout` manual.
  - **`BoardManager`**: runtime do tabuleiro (`is_blocked`, `recalculate_availability`, `shuffle_positions`); aplica apenas guards de state/location/layer e delega a decisão geométrica a `BoardSpatialRules`.
  - **`BoardSpatialRules`**: única implementação da regra de bloqueio. `coverage()` retorna o valor cru de AABB (`intersection_area/card_area`), sem rounding; `at_or_above_threshold()` faz comparação escalar direta com 0.10; `blocks()` compara áreas por cross-multiplication e canonicaliza o limite geométrico somente por meio ULP de área derivado da magnitude/expoente float32 das coordenadas relevantes e do overlap ortogonal, sem promover o próximo offset representável abaixo do corte. Compartilhado por geração, métricas, `LevelValidator`, solver e runtime para que `blocked` do resultado, a contagem de cartas livres, a busca de witness e a disponibilidade em jogo sempre concordem.
  - **`BoardSolvabilitySolver`**: seam core **puro e testável** (sem `Node` e sem dependência de `GameController`) que busca deterministicamente uma sequência legal para limpar o Board respeitando bloqueio e capacidade da Clearing Zone; expõe resultado estruturado com witness e esgotamento de budget.
  - **`BoardSpec`**: config tipada/validável (`card_count`, `card_size`, `board_width/height` — a maior área que a base pode ocupar —, `layers` exato, `layer_ratio`, `geometry_seed` com alias legado `seed`, e `symbol_seed`/`card_types` opcionais); `validate()` rejeita layers impossíveis (layers > card_count ou card_count insuficiente para pirâmide estritamente decrescente), `layer_ratio` fora de (0, 1), malha pequena demais para a base e configurações inválidas de símbolos.
- **Módulos internos** (orquestrados pelo `GameController`): `ClearingZoneManager`, `DeckManager`, `PowerManager`, `TimerManager`, `ProgressManager`, `SaveManager`. O histórico de ações fica em `GameController.action_history`.
- **Máquina de estados:** `status ∈ { READY, PLAYING, PAUSED, WON, LOST }`. Ações normais só em `PLAYING`; em `WON`/`LOST` nada é aceito.
- **Separação lógica/apresentação:** a UI lê `GameState` e envia ações; regras nunca dependem de elementos visuais (ex.: nunca `if card.visible`, sempre `card.state`).

### Modelo de domínio
- **Card:** `id`, `type`, `position`, `layer`, `state`, `source` (`BOARD | DECK_A | DECK_B`), `location` (`BOARD | CLEARING_ZONE | RESERVE`).
- **Card State:** `HIDDEN`, `AVAILABLE`, `SELECTED`, `MATCHED` (transitório), `REMOVED`.
- **Card Type:** identidade que define a correspondência — duas cartas correspondem se e somente se compartilham o mesmo *Card Type*.
- **Card na Reserve:** permanece `SELECTED` com `location = RESERVE` (enum enxuto, sem novo estado).
- **Blocking:** uma carta é `Blocked` se qualquer carta ativa de camada superior cobre pelo menos 10% da área do seu retângulo visual (AABB de 48×48). Cartas do mesmo layer não se bloqueiam. A regra é local à área da carta, não global à mesa. Disponibilidade recalculada após cada remoção. A implementação geométrica (interseção, threshold e canonicalização por meio ULP de área) vive exclusivamente em `BoardSpatialRules`, compartilhada por `BoardPipeline` (campo `blocked` de cada card), `LevelBoardGenerator` (métricas), `LevelValidator` (`free_card_count`) e `BoardManager`. Os tabuleiros gerados não têm cartas do mesmo layer sobrepostas (o `LevelValidator` rejeita sobreposição no mesmo layer), e uma única carta do layer *imediatamente* acima não pode esconder mais de 75% de uma carta (limite do `LevelValidator`; layers com dois ou mais de distância podem se alinhar exatamente, como numa pirâmide).
- **Action:** `SELECT_CARD`, `SELECT_DECK_CARD`, `USE_HOLD`, `USE_UNDO`, `USE_REFRESH`, com estado anterior, para histórico/Undo/análise.

### Regras core
- **Seleção:** apenas cartas `AVAILABLE` podem ser selecionadas; a carta sai do `Board` para a `Clearing Zone` com `state = SELECTED`.
- **Combinação:** após cada inserção, se houver ≥3 cartas do mesmo tipo na zona, remove exatamente as 3 primeiras (`MATCHED` → `REMOVED`), automaticamente. A quarta carta do mesmo tipo permanece para combinação futura.
- **Clearing Zone:** capacidade configurável por *Level* (padrão **7**). A ordem de inserção é preservada (para apresentação e Undo).
- **Vitória:** tabuleiro, os dois *Support Decks*, a *Clearing Zone* e a *Reserve* vazios (estado interno como fonte de verdade).
- **Derrota:** Clearing Zone cheia rejeita qualquer nova carta e encerra o Level. Além disso, se a zona encher e o jogador não tiver *Hold* nem *Undo* em estoque (nada mais pode liberar um slot), o Level termina na hora, sem esperar um toque condenado. O motivo fica em `loss_reason` (`ZONE_FULL` ou `TIMEOUT`) para a UI. Função `checkDefeat()` extensível.
- **Time limit (opcional):** um Level pode declarar `time_limit` (segundos); ausente = sem limite (comportamento padrão). Quando presente, a UI mostra contagem regressiva e, ao exceder o limite durante `PLAYING`, o Level é perdido (`check_timeout()`). As estrelas continuam baseadas no tempo decorrido; JSONs devem garantir `time_limit > two_stars`.
- **Pausa:** o cronômetro pausa (`GameController.pause()`) enquanto a ajuda está aberta e quando o app perde o foco ou vai para segundo plano.

### Powers
- **Hold** (antes chamado "Remove"): move as 3 cartas mais antigas (as mais à esquerda) da Clearing Zone para a *Reserve*, liberando espaço. Devolver da Reserve para a zona é ação livre (toque em **qualquer** carta da Reserve, na ordem que o jogador quiser) e ocupa espaço normal da zona; com a zona cheia o toque é recusado com aviso visual. Se a zona estiver vazia, o uso é rejeitado sem consumir o poder.
- **Undo:** devolve a última carta ainda na Clearing Zone à sua origem (`Board` ou `Support Deck`). Não desfaz trios; rejeitado sem carta disponível; não consome poder quando rejeitado.
- **Refresh:** reembaralha as posições das cartas restantes do `Board` e a ordem interna dos dois `Support Decks`. Não altera cartas removidas, nem Clearing Zone, nem Reserve.
- **Estoque:** cada poder tem quantidade; usar consome uma unidade do `Inventory` de forma **permanente** (persistida). Sem estoque, o uso é rejeitado.

### Support Decks
- Dois decks independentes, finitos. Tamanho por *Level*: nível 1 = 3 cartas por deck (6 no total), nível 2 = 6 por deck (12 no total), crescendo de forma balanceada.
- Apenas a carta do topo é visível e tocável; usá-la a envia à Clearing Zone e avança o índice. As cartas usam os mesmos *Card Types* do tabuleiro.

### Progressão e persistência
- **Tipos de carta:** 12 tipos no total. O Level 1 usa poucos tipos (9 cartas no tabuleiro) e só 2 camadas, com poucas cartas cobertas (perfil em `DifficultyProfile`: base `columns × rows` em cartas, `layers`, `layer_ratio`, banda de `free_ratio`). Níveis seguintes aumentam tipos (até 12), camadas (até 4) e a proporção de cartas bloqueadas. Cada tipo sempre em múltiplos de 3.
- **Estrelas:** `t ≤ threeStarsTime → 3★`, `t ≤ twoStarsTime → 2★`, caso contrário `1★`, com `t` em segundos inteiros (o mesmo valor do relógio MM:SS exibido). Limites por *Level*, proporcionais às cartas a limpar (tabuleiro + decks): cerca de **1,5 s por carta para 3★** e **2,6 s por carta para 2★**, arredondados para múltiplos de 5 s (`test_star_thresholds.gd`); o `time_limit` dos Levels 10–11 fica acima do limite de 2★. Sem score numérico, sem bônus de velocidade. Estrelas armazenadas por *Level* para futuras missões/desbloqueios.
- **Desbloqueio:** vencer o *Level* N libera N+1. Recompensas (ex.: `+1 Hold`) definidas no JSON do *Level* são concedidas **só na primeira vitória**; replays melhoram as estrelas mas não dão poderes de novo.
- **Levels:** arquivos JSON data-driven (tipos, cópias, camadas/posições, decks, capacidade, tempos, `time_limit` opcional, recompensas). Valores de fácil edição para testes e balanceamento. O jogo traz 11 Levels (33★). Cada JSON aponta para uma linha de `DifficultyProfile` (`difficulty`), mapeada para um `BoardSpec` (ver `docs/LEVEL-CONFIG-SCHEMA.md`). O layout é gerado a cada tentativa: `randomize_per_attempt` (default `true`) sorteia uma seed base mantendo a garantia de solução via `SolvabilityChecker`; com `randomize_per_attempt: false` vale a seed fixa do perfil. Testes usam `LevelLoader.deterministic = true` para reproduzir a seed do perfil em todos os Levels.
- **Save:** JSON em `user://` via `SaveManager` (níveis concluídos, estrelas por nível, inventário, recorde do Endless, configurações).

### Endless Mode
- **Desbloqueio:** vencer o último Level da campanha (hoje o 11; `ProgressManager.endless_unlock_level()` deriva dos arquivos `levels/`, então um Level novo move a exigência junto); a entrada fica no topo da lista de Levels e mostra o recorde.
- **Rodadas:** uma partida (`EndlessRun`) é uma sequência de rodadas; cada rodada é um Level normal gerado por `DifficultyProfile` com seed nova (dificuldade = rodada + 2, limitada ao último perfil), Support Decks de 6 a 15 cartas, Clearing Zone 7 e **sem** `time_limit`. Vencer a rodada leva à próxima; a partida termina na primeira derrota.
- **Pontuação:** 10 pontos por carta combinada (30 por trio) + bônus de 100 × rodada ao limpar uma rodada. O melhor resultado (`endless_best`, `endless_best_rounds`) é salvo localmente; não há leaderboard online.
- **Poderes:** estoque próprio da partida (2 Hold, 2 Undo, 1 Refresh; +1 poder a cada 3 rodadas, em rodízio). O *Inventory* persistente não é usado nem alterado, e as recompensas da campanha não se aplicam.
- **Saída:** voltar ao menu ou fechar o jogo no meio da partida encerra a partida e registra a pontuação.

### Arte de UI e fundos
- Kit de UI em pixel art em `assets/ui/kit/` (janelas, barras, painel de poderes, quadrados de deck, placas, botões do menu e ícones), desenhado na escala lógica 1:1 (paisagem 640×360, retrato 360×640, filtro *nearest*). A tela de jogo segue o mockup: seta verde, placas de relógio e estrelas no topo, botão de som, janela do tabuleiro (464×208 / 352×192) com o fundo escurecido dentro, poderes e deck B à direita, deck A à esquerda, Reserve e barra da Clearing Zone no rodapé.
- Fundos pintados com filtro (desfoque, escurecimento, tom quente, vinheta): campo nos Levels 1–3 e no menu, cidade de outono do Level 4 em diante e no Endless (`UiHelpers.AUTUMN_FROM_LEVEL`).
- HUD pintado em alta resolução (`assets/ui/hud/`: placas de estrelas, cronômetro, engrenagem), com mipmaps e filtro trilinear como as cartas.
- Cartas: 8 tipos com arte (Pack A) e 4 (leaf, heart, gem, crystal) ainda com placeholder; padrão de entrega em `docs/ART-GUIDE-PT.md`.
- Som: em Opções, controle de volume do kit (−, barra com alça arrastável, +, ícone que vira "mudo" em zero), salvo em `settings.volume`; no HUD só o ícone, que silencia ou volta ao último volume.

### Mascote
- Personagem original **Ás** (*Ace* em inglês), uma carta de baralho viva desenhada em código (sem arte externa e sem nada da IP de referência), com humores neutro/feliz/preocupado/triste.
- Balão com a instrução de como jogar (~4 s no início do Level/rodada), dicas rotativas e reações (início de Level/rodada, trio formado, Clearing Zone quase cheia, poder usado, vitória por estrelas, derrota). Nunca intercepta toques. Pode ser desligado em Opções (`settings.mascot`).

### Localização
- UI em inglês e português (pt-BR). Documentação em EN e PT.

## Testing Decisions

- **O que testar:** comportamento externo apenas — chamar a API pública dos seams (`GameController`, `BoardPipeline`, `LevelBoardGenerator`/`LevelLoader`, `BoardManager`, `BoardSpatialRules`, `BoardSolvabilitySolver`) e verificar os estados/resultados. Nunca testar detalhes internos nem Nodes de UI.
- **Costura:** os seams do Board (`BoardPipeline`/`BoardManager`/`BoardSpatialRules`/`BoardSolvabilitySolver`) são testados **diretamente e headless**, sem cena nem janela; `GameController` continua sendo a costura de replay/integração para regras core. Não há uma única costura obrigatória — cada seam é testável pela sua interface.
- **Framework:** runner próprio (`tests/run_tests.gd` + `tests/assert.gd`), sem dependências; scripts de smoke/regressão de cena rodam com `--script` no CI.
- **Módulos cobertos:** regras core, poderes, decks, bloqueio, vitória/derrota, timer, progressão e os tabuleiros gerados de todos os Levels e rodadas do Endless (`tests/test_level_boards.gd`, com invariantes compartilhados em `tests/board_checks.gd`: alinhamento à malha, sem sobreposição no mesmo layer, solucionável com decks e poderes, bloqueio pela regra única). `tests/repro_hud_bounds.gd` audita 6 views (campanha e Endless, paisagem e retrato, mais as views com o mascote desligado).
- **Casos obrigatórios (do documento original, §46):**
  - Combinação: 3 iguais → removidas; 2 iguais → permanecem.
  - Bloqueio: carta coberta → indisponível; carta superior removida → inferior disponível.
  - Clearing Zone: capacidade respeitada; zona cheia rejeita a oitava carta.
  - Derrota: zona cheia → derrota, inclusive quando a nova carta formaria um trio; zona cheia sem Hold/Undo → derrota imediata.
  - Vitória: última carta removida (com decks, zona e reserva vazios) → vitória.
  - Undo: seleção → estado A; undo → estado anterior.
  - Hold: move as 3 cartas mais antigas para a Reserve; zona vazia rejeita sem consumir; devolver à zona funciona.
  - Refresh: mesmas cartas, novas posições; ordem dos decks alterada; removidas/zona/reserva intactas.
  - Poderes: uso reduz estoque; uso sem estoque é rejeitado.
  - Timer: início, parada, tempo final correto; com `time_limit`, timeout derrota; sem `time_limit`, nunca perde por tempo.
  - Progressão: nível concluído → recompensa → próximo nível liberado.
  - Determinismo: embaralhamento aceita `seed` para reproduzir casos; `randomize_per_attempt: false` mantém layout fixo.

## Out of Scope

Para esta spec (v1):

- Score numérico e bônus por velocidade na campanha (o Endless Mode tem pontuação própria).
- Missões/quests, skins, temas, moedas, vidas, itens.
- Agente de IA de tomada de decisão (apenas a API `getGameState`/`getLegalActions` é prevista).
- Editor visual de níveis (níveis são JSON).
- Derrotas por "sem movimentos" além da Clearing Zone cheia (derrota por tempo é opcional via `time_limit`, desligada por padrão).
- Rollback de trios e de uso de poder no Undo (a arquitetura permite estender depois).
- Som/música (apenas espaço reservado).
- Multiplayer/online, incluindo leaderboard online do Endless.

## Further Notes

- **Arte:** sprite sheet (atlas) padrão de pixel art, paleta limitada compartilhada (~32 cores). Lista de arte: 12 faces de carta, 1 verso, ícones dos 3 poderes, estrelas (cheia/vazia), área da Reserve, slots da Clearing Zone, ícone dos 2 decks, fundo. Animações via tweens no código (sem arte quadro-a-quadro). Estados visuais: bloqueada = escurecida, disponível = cor plena, selecionada = contorno, match = fade.
- **Documento do artista:** `docs/ART-GUIDE-PT.md` e `docs/ART-GUIDE-EN.md` (resoluções, paleta, nomenclatura de arquivos, caminhos, importação nearest/sem mipmaps).
- **Placeholders:** artes provisórias geradas (símbolos/emoji + cor de fundo por tipo), substituíveis pelos arquivos finais sem mudar código.
- **Critérios de aceitação da v1:** o jogo deve carregar um Level de JSON, apresentar cartas, impedir seleção de bloqueadas, permitir seleção de disponíveis, enviar à Clearing Zone, remover trios, liberar espaço, desbloquear cartas, limitar capacidade, usar os dois decks, os três poderes (Hold/Undo/Refresh) com estoque, cronômetro, detectar vitória/derrota, registrar tempo, atribuir estrelas, conceder recompensas, salvar progresso e liberar o próximo nível — tudo funcional com arte placeholder.
- **Filosofia:** a partida é uma sequência de estados; cada ação produz um novo estado, habilitando Undo, replay, debug, testes e futura IA.
