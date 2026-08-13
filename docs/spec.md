# Cartitas Infinity — Especificação

> Documento de spec consolidado. Termos em itálico na primeira ocorrência são os termos canônicos do glossário (`CONTEXT.md`). Este documento substitui qualquer versão anterior das regras.

## Problem Statement

O jogador quer um puzzle de cartas baseado em combinação de três cartas idênticas, no qual deve limpar completamente o tabuleiro de cada *Level* selecionando cartas disponíveis, acumulando-as numa área temporária limitada (a *Clearing Zone*) e formando trios. O desafio não é velocidade de clique, mas **planejamento da ordem das jogadas**, **gerenciamento de espaço limitado** e **uso estratégico de poderes e decks limitados**.

O sistema precisa ser modular e orientado a dados, para que novos níveis, tipos de carta, poderes e regras sejam adicionados sem alterar a lógica principal. A lógica de domínio deve ser testável sem depender da interface visual, e a fonte de verdade deve ser sempre o estado interno do jogo.

## Solution

Um jogo 2D em pixel art (Godot 4.7.1, GDScript), mobile-first em retrato (9:16) com suporte a desktop para desenvolvimento. Cada *Level* é definido por um arquivo JSON (data-driven). O jogador seleciona *Cards* disponíveis do *Board* (ou dos dois *Support Decks*) para a *Clearing Zone*; três cartas do mesmo *Card Type* são removidas automaticamente. Três *Powers* limitados (*Hold*, *Undo*, *Refresh*) ajudam a gerenciar o espaço e a ordem. A vitória ocorre quando não restam cartas ativas; a derrota ocorre quando a Clearing Zone está cheia sem combinação possível.

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
11. Como jogador, quero que a carta que completa um trio seja processada antes da regra de derrota, para não perder injustamente quando a jogada é válida.
12. Como jogador, quero usar os dois *Support Decks*, tocando na carta do topo para enviá-la à Clearing Zone, para ter cartas extras quando o tabuleiro travar.
13. Como jogador, quero ver apenas a carta do topo de cada *Support Deck*, para saber o que virá se eu usá-la.
14. Como jogador, quero que cada *Support Deck* seja finito, para que seja um recurso limitado.
15. Como jogador, quero usar o poder *Hold* para mover as últimas cartas da Clearing Zone para a *Reserve*, para liberar espaço na zona.
16. Como jogador, quero devolver cartas da *Reserve* para a Clearing Zone com um toque, para retomá-las e formar trios.
17. Como jogador, quero que o *Hold* mova no máximo 4 cartas (as últimas adicionadas), para que o poder tenha um efeito definido.
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
- **Engine:** Godot 4.7.1 estável, **GDScript**.
- **Plataforma:** mobile (retrato 9:16) como alvo principal; desktop em janela retrato para desenvolvimento/teste. Touch-first, com suporte a mouse.
- **Resolução:** base lógica 360×640, com upscale inteiro, `texture_filter = nearest`, pixel snap habilitado (padrão de pixel art).
- **Unidades visuais:** carta 32×32 px; UI em grade de 8px; ícones de poderes 16×16.

### Arquitetura e costuras
- **`GameController`** (classe pura, `RefCounted`, sem `Node`): orquestra o fluxo da partida, mantém o `GameState` como fonte de verdade e recebe as ações. É a **costura de teste** única.
- **Módulos internos** (orquestrados pelo `GameController`): `BoardManager`, `ClearingZoneManager`, `DeckManager`, `PowerManager`, `HistoryManager`, `TimerManager`, `ProgressManager`, `SaveManager`.
- **Máquina de estados:** `status ∈ { READY, PLAYING, PAUSED, WON, LOST }`. Ações normais só em `PLAYING`; em `WON`/`LOST` nada é aceito.
- **Separação lógica/apresentação:** a UI lê `GameState` e envia ações; regras nunca dependem de elementos visuais (ex.: nunca `if card.visible`, sempre `card.state`).

### Modelo de domínio
- **Card:** `id`, `type`, `position`, `layer`, `state`, `source` (`BOARD | DECK_A | DECK_B`), `location` (`BOARD | CLEARING_ZONE | RESERVE`).
- **Card State:** `HIDDEN`, `AVAILABLE`, `SELECTED`, `MATCHED` (transitório), `REMOVED`.
- **Card Type:** identidade que define a correspondência — duas cartas correspondem se e somente se compartilham o mesmo *Card Type*.
- **Card na Reserve:** permanece `SELECTED` com `location = RESERVE` (enum enxuto, sem novo estado).
- **Blocking:** uma carta é `Blocked` se qualquer carta ativa de camada superior sobrepõe seu retângulo (AABB) em qualquer quantidade. Disponibilidade recalculada após cada remoção.
- **Action:** `SELECT_CARD`, `SELECT_DECK_CARD`, `USE_HOLD`, `USE_UNDO`, `USE_REFRESH`, com estado anterior, para histórico/Undo/análise.

### Regras core
- **Seleção:** apenas cartas `AVAILABLE` podem ser selecionadas; a carta sai do `Board` para a `Clearing Zone` com `state = SELECTED`.
- **Combinação:** após cada inserção, se houver ≥3 cartas do mesmo tipo na zona, remove exatamente as 3 primeiras (`MATCHED` → `REMOVED`), automaticamente. A quarta carta do mesmo tipo permanece para combinação futura.
- **Clearing Zone:** capacidade configurável por *Level* (padrão **7**). A ordem de inserção é preservada (para apresentação e Undo).
- **Vitória:** tabuleiro, os dois *Support Decks*, a *Clearing Zone* e a *Reserve* vazios (estado interno como fonte de verdade).
- **Derrota:** Clearing Zone cheia e a próxima carta não completa um trio. Função `checkDefeat()` extensível.

### Powers
- **Hold** (antes chamado "Remove"): move as últimas até 4 cartas da Clearing Zone para a *Reserve*, liberando espaço. Devolver da Reserve para a zona é ação livre (toque) e ocupa espaço normal da zona. Se a zona estiver vazia, o uso é rejeitado sem consumir o poder.
- **Undo:** devolve a última carta ainda na Clearing Zone à sua origem (`Board` ou `Support Deck`). Não desfaz trios; rejeitado sem carta disponível; não consome poder quando rejeitado.
- **Refresh:** reembaralha as posições das cartas restantes do `Board` e a ordem interna dos dois `Support Decks`. Não altera cartas removidas, nem Clearing Zone, nem Reserve.
- **Estoque:** cada poder tem quantidade; usar consome uma unidade do `Inventory` de forma **permanente** (persistida). Sem estoque, o uso é rejeitado.

### Support Decks
- Dois decks independentes, finitos. Tamanho por *Level*: nível 1 = 3 cartas por deck (6 no total), nível 2 = 6 por deck (12 no total), crescendo de forma balanceada.
- Apenas a carta do topo é visível e tocável; usá-la a envia à Clearing Zone e avança o índice. As cartas usam os mesmos *Card Types* do tabuleiro.

### Progressão e persistência
- **Tipos de carta:** 12 tipos no total. Nível 1 = 3 tipos × 3 cópias = 9 cartas (camada única, sem sobreposição). Níveis seguintes aumentam tipos (até 12) e camadas/sobreposição. Cada tipo sempre em múltiplos de 3.
- **Estrelas:** `t ≤ threeStarsTime → 3★`, `t ≤ twoStarsTime → 2★`, caso contrário `1★`. Limites por *Level*. Sem score numérico, sem bônus de velocidade. Estrelas armazenadas por *Level* para futuras missões/desbloqueios.
- **Desbloqueio:** vencer o *Level* N libera N+1. Recompensas (ex.: `+1 Hold`) definidas no JSON do *Level*.
- **Levels:** arquivos JSON data-driven (tipos, cópias, camadas/posições, decks, capacidade, tempos, recompensas). Valores de fácil edição para testes e balanceamento.
- **Save:** JSON em `user://` via `SaveManager` (níveis concluídos, estrelas por nível, inventário).

### Localização
- UI em inglês e português (pt-BR). Documentação em EN e PT.

## Testing Decisions

- **O que testar:** comportamento externo apenas — chamar a API do `GameController` e verificar o `GameState` resultante. Nunca testar detalhes internos nem Nodes de UI.
- **Costura:** `GameController` (classe pura). Todos os testes rodam headless, sem cena nem janela.
- **Framework:** GUT (Godot Unit Test) — a confirmar; alternativa GdUnit4.
- **Módulos cobertos:** regras core, poderes, decks, bloqueio, vitória/derrota, timer, progressão.
- **Casos obrigatórios (do documento original, §46):**
  - Combinação: 3 iguais → removidas; 2 iguais → permanecem.
  - Bloqueio: carta coberta → indisponível; carta superior removida → inferior disponível.
  - Clearing Zone: capacidade respeitada; trio libera espaço.
  - Derrota: zona cheia sem combinação → derrota; carta que completa trio não gera derrota.
  - Vitória: última carta removida (com decks, zona e reserva vazios) → vitória.
  - Undo: seleção → estado A; undo → estado anterior.
  - Hold: move até 4 para a Reserve; zona vazia rejeita sem consumir; devolver à zona funciona.
  - Refresh: mesmas cartas, novas posições; ordem dos decks alterada; removidas/zona/reserva intactas.
  - Poderes: uso reduz estoque; uso sem estoque é rejeitado.
  - Timer: início, parada, tempo final correto.
  - Progressão: nível concluído → recompensa → próximo nível liberado.
  - Determinismo: embaralhamento aceita `seed` para reproduzir casos.

## Out of Scope

Para esta spec (v1):

- Score numérico e bônus por velocidade.
- Missões/quests, skins, temas, moedas, vidas, itens.
- Agente de IA de tomada de decisão (apenas a API `getGameState`/`getLegalActions` é prevista).
- Editor visual de níveis (níveis são JSON).
- Derrotas por tempo ou por "sem movimentos" além da Clearing Zone cheia.
- Rollback de trios e de uso de poder no Undo (a arquitetura permite estender depois).
- Som/música (apenas espaço reservado).
- Multiplayer/online.

## Further Notes

- **Arte:** sprite sheet (atlas) padrão de pixel art, paleta limitada compartilhada (~32 cores). Lista de arte: 12 faces de carta, 1 verso, ícones dos 3 poderes, estrelas (cheia/vazia), área da Reserve, slots da Clearing Zone, ícone dos 2 decks, fundo. Animações via tweens no código (sem arte quadro-a-quadro). Estados visuais: bloqueada = escurecida, disponível = cor plena, selecionada = contorno, match = fade.
- **Documento do artista:** `docs/ART-GUIDE-PT.md` e `docs/ART-GUIDE-EN.md` (resoluções, paleta, nomenclatura de arquivos, caminhos, importação nearest/sem mipmaps).
- **Placeholders:** artes provisórias geradas (símbolos/emoji + cor de fundo por tipo), substituíveis pelos arquivos finais sem mudar código.
- **Critérios de aceitação da v1:** o jogo deve carregar um Level de JSON, apresentar cartas, impedir seleção de bloqueadas, permitir seleção de disponíveis, enviar à Clearing Zone, remover trios, liberar espaço, desbloquear cartas, limitar capacidade, usar os dois decks, os três poderes (Hold/Undo/Refresh) com estoque, cronômetro, detectar vitória/derrota, registrar tempo, atribuir estrelas, conceder recompensas, salvar progresso e liberar o próximo nível — tudo funcional com arte placeholder.
- **Filosofia:** a partida é uma sequência de estados; cada ação produz um novo estado, habilitando Undo, replay, debug, testes e futura IA.
