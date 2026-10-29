# Prompt — Paridade com o "Raggler Challenge" (Ragnarok Origin Classic)

> **Para o agente de implementação:** este documento é uma spec/prompt autocontida. O objetivo é fazer o **Cartitas Infinity** ficar o mais próximo possível, em **mecânica e fluxo**, do mini-game "Raggler Challenge" mostrado no vídeo de referência. Leia `CONTEXT.md` (glossário canônico) e `docs/spec.md` (spec atual) antes de qualquer alteração. **Não copie nomes, arte, monstros ou qualquer asset/IP da Ragnarok Origin — apenas as mecânicas genéricas do gênero (match-3 com bandeja limitada) são alvo.** O tema/visual do Cartitas permanece original.

- **Vídeo de referência:** https://www.youtube.com/watch?v=HDFyK7X4NFw — "RAGGLER CHALLENGE GUIDE! Easy Clear + Best Strategy" (I'm DracaryS, ~5 min). **Analisado quadro a quadro** (download em 360p + extração de frames a 5s, 0,4s e 30fps em momentos-chave) — a §1b (visuais/efeitos) vem dessa análise direta.
- **Fontes complementares usadas na pesquisa:** anúncios oficiais do evento (roglobal.com/news/1088 e /1098, Facebook ROO Classic EN) e outros guias em vídeo do mesmo mini-game (BlueBerries, Ginger, King Spade, Lutz Studio).
- **Data da pesquisa:** 2026-08-14.

---

## 1. O jogo de referência (o que foi confirmado no vídeo e nas fontes)

O "Raggler Challenge" é um puzzle de combinar 3 (mesmo gênero de *Sheep a Sheep*), idêntico na base ao Cartitas:

| Mecânica observada | Status da evidência |
|---|---|
| Tocar numa carta a move para uma **bandeja no rodapé**; 3 cartas idênticas na bandeja **são removidas automaticamente** | ✅ Confirmado (regra oficial: *"When 3 identical cards are collected, they'll be cleared automatically. Clear all cards to win!"*) |
| **Vitória:** limpar todas as cartas. **Derrota:** bandeja cheia sem combinação possível | ✅ Confirmado |
| **Capacidade da bandeja: 7 slots** | ⚠️ Inferência forte (padrão do gênero; nunca dito numericamente) — o Cartitas já usa 7, manter |
| **Timer e estrelas:** o relógio **conta para cima** (formato `00:00:00`) e as **3 estrelas do HUD degradam ao vivo** conforme os limiares passam (3★ no início → 2★ → 1★ aos 15:05, ainda jogando). **Nenhuma derrota por timeout foi observada neste vídeo** (versão Classic abr/2026); textos oficiais de outras versões mencionam "tempo limitado" | ✅ Confirmado por frames; ⚠️ timeout varia por versão → `time_limit` opcional por Level (ver T1) |
| **Estrelas por velocidade** (3★ por limpar rápido; na versão Global, 3★ ≤ 7 min); 10 estágios, 30 estrelas, estágios rejogáveis para melhorar nota | ✅ Confirmado |
| **Cada tentativa gera um layout novo** ("Each level has a random selection; it won't always be the same") | ✅ Confirmado |
| **3 poderes consumíveis:** **Remove** (move as **3 primeiras cartas da esquerda** da bandeja para uma área lateral), **Undo** (desfaz a última carta clicada), **Refresh** (reembaralha as cartas restantes do tabuleiro) | ✅ Confirmado |
| Poderes são **consumíveis de estoque finito/persistente** (ganhos fora da partida; podem acabar no meio do run) | ✅ Confirmado |
| Cartas cobertas são **escurecidas mas identificáveis pela fatia visível**; camadas mais profundas podem estar **totalmente ocultas** ("something behind that we can't see") | ✅ Confirmado |
| Retry **ilimitado e grátis**; reiniciar numa abertura ruim é estratégia recomendada | ✅ Confirmado |
| **UI:** bandeja embaixo, botões de poder **à direita**, tabuleiro ao centro; mobile **retrato** | ✅ Confirmado |
| **Endless Mode** após os 10 estágios: fases aleatórias, pontos acumulados, leaderboard | ✅ Confirmado (fase 2 aqui — ver T6) |
| **Painel de poderes à direita** mostra estoque por poder no formato `x/10`; diálogo do Remove: *"Remove 3 Monster Cards to put them aside? Remaining Uses for This Round: 10"* (ícone do item `0/1`) → uso consome item do inventário e há teto de 10 usos por rodada | ✅ Confirmado por frames; ⚠️ interação exata inventário × teto/rodada é inferência |
| **Mascote** no canto esquerdo com balões de fala rotativos (dicas e provocações: *"Hehe, you can't beat me now, can you?"*, *"Use it over the items on the right!"*) | ✅ Confirmado por frames (flavor — adaptar com personagem/tema original) |
| **Tela de resultado:** número grande do estágio, fileira de 3 estrelas (ganhas = douradas, não ganhas = escuras), "Stage Reward" com ícones, botão vermelho "Continue", fala do mascote variando com o desempenho, total de estrelas `26/30` no canto superior direito | ✅ Confirmado por frames |
| **Decks:** dois montes escuros entre tabuleiro e bandeja, topo virado para cima; **o monte some quando esvazia** | ✅ Confirmado por frames |
| Toasts "Obtained: X xN" no centro | ✅ São do MMO em segundo plano, **NÃO fazem parte do mini-game** — não replicar |

---

## 1b. Visuais e efeitos (análise quadro a quadro do vídeo)

Extraído de frames do próprio vídeo (360p; amostragem a 5s + rajadas a 0,4s e 30fps em momentos-chave):

**Layout da tela de jogo (confirmado visualmente):**
- **Topo:** botão voltar (canto superior esquerdo), título "Stage N" + botão de ajuda "?"; relógio em pill arredondado no centro (`00:00:00`, contando para cima); **3 estrelas logo abaixo do relógio**, douradas quando vivas e escuras quando perdidas (degradam ao vivo; em ~4–5 min no Stage 10 a 3ª estrela aparece **meio dourada** — estado parcial observado, ⚠️ sem confirmação de meio-ponto no resultado).
- **Linha de instrução** fixa: *"Match three identical cards to clear them in the clearing zone below."*
- **Tabuleiro:** cartas brancas de cantos arredondados com arte colorida; **bloqueadas = azul-acinzentadas escuras, silhueta ainda legível**; disponíveis = cor plena. Sobreposição parcial permite "ler" a carta coberta pela fatia visível.
- **Direita:** painel vertical com os 3 poderes — ícone azul + nome + contador `x/10`; entrada do poder fica **realçada** quando selecionada.
- **Decks:** dois montes escuros "estriados" (textura de pilha) entre tabuleiro e bandeja, carta do topo visível; **monte desaparece ao esvaziar**.
- **Bandeja:** barra laranja estampada no rodapé, ocupando a largura central; cartas entram **pela esquerda**, sem divisórias de slot visíveis.
- **Esquerda:** mascote com balão de fala rotativo.

**Efeitos/animações (confirmados frame a frame):**
1. **Voo da carta (seleção):** a carta tocada sai do tabuleiro e **voa face-up, acima de todos os elementos**, direto para o próximo slot livre da bandeja (~0,2–0,3s), assentando no lugar. (Flagrada em t=96,5s: carta a meio caminho entre tabuleiro e bandeja; em t=158s: carta pousando erguida acima da linha da bandeja.)
2. **Combinação (match):** ao pousar a 3ª carta igual, as 3 cartas do trio **viram quadrados dourados brilhantes que explodem em luz dourada** sobre a bandeja (~0,4–0,6s no total: flash → brilho se expande → some) e desaparecem, liberando os slots. (Sequência capturada em t=97,1s→97,5s a 30fps.)
3. **Decaimento de estrelas no HUD:** as estrelas mudam de dourada para escura (com estado intermediário visual) **no momento em que cada limiar de tempo passa** — feedback contínuo, sem modal.
4. **Intro de rodada (Endless):** **burst radial dourado** atrás de um banner com o mascote + frase (*"You think you can beat me alone? You have to go through them first!"*), que desvance para o tabuleiro.
5. **Tela de resultado:** fundo escurecido/desfocado, número grande do estágio, estrelas (douradas/escuras), recompensas em ícones, botão "Continue", fala do mascote conforme desempenho. ⚠️ Transição/animação de preenchimento das estrelas não capturada (aconteceu entre amostras) — assumir reveal sequencial padrão do gênero.
6. **Uso de poder:** modal de confirmação azul ("Confirmation Window") com descrição do efeito, usos restantes na rodada, botões Cancel/Confirm; tela escurecida atrás.
7. **Compactação da bandeja pós-match:** ⚠️ não capturada em frames (matches rápidos); assumir o padrão do gênero: cartas à direita do trio **deslizam para a esquerda** fechando os espaços (inferência).

---

## 2. Estado atual do Cartitas (gap analysis)

Verificado no código em 2026-08-14:

| # | Feature do vídeo | Estado atual no Cartitas | Gap |
|---|---|---|---|
| 1 | Match-3 automático na bandeja | ✅ `ClearingZoneManager.resolve_matches` remove as 3 primeiras do tipo | Nenhum |
| 2 | Bandeja com 7 slots, derrota ao encher | ✅ `clearing_capacity: 7`, `_lose()` em `_would_overflow` | Nenhum |
| 3 | Bloqueio por sobreposição de camadas; bloqueada escurecida porém identificável | ✅ `BoardManager.is_blocked` (AABB), UI escurece (`modulate 0.42`) e desabilita | Nenhum |
| 4 | **Timer para cima + estrelas ao vivo que degradam**; timeout como opção por versão | ⚠️ `TimerManager` conta para cima ✅; `_update_live_stars` já degrada estrelas no HUD ✅; **não há derrota por tempo** (no vídeo não foi observada — partida ativa aos 15:05; oficial de outras versões menciona) | Manter como está; `time_limit` **opcional** por Level (T1) |
| 5 | **Layout aleatório a cada tentativa** | ⚠️ Parcial: `LevelLoader.resolve` usa `layout.seed` **fixa** do JSON (tabuleiro idêntico em toda tentativa); só os decks são embaralhados por tentativa | **Implementar** |
| 6 | **10 estágios + tela de seleção com estrelas, rejogáveis** | ⚠️ Menu com estrelas existe (`main_menu.gd`), mas só há **3 níveis** (`levels/level_1..3.json`) | **Criar conteúdo** |
| 7 | Poder **Remove/Hold**: tira as **3 primeiras da esquerda** da bandeja | ⚠️ `use_hold()` move as **últimas até 4** (`HOLD_COUNT = 4`, `zone.take_last`) para a Reserve (retornável — equivalente à "área lateral" do vídeo, manter a Reserve) | **Alinhar: 3 primeiras** (decisão documentada, ver tarefa T4) |
| 8 | Undo e Refresh | ✅ `use_undo` / `use_refresh` equivalentes | Nenhum |
| 9 | Estoque de poderes persistente | ✅ `PowerManager` + `SaveManager`/`ProgressManager` | Nenhum |
| 10 | UI retrato, bandeja embaixo, **poderes à direita com contador `x/10`**, relógio em pill no topo + 3 estrelas ao vivo | ⚠️ Layout atual é **paisagem** 640×360 como referência (retrato existe como modo); poderes existem mas sem o padrão "coluna direita com `x/10`" | **Ajustar UI (T5)** |
| 11 | Endless Mode com pontos/leaderboard | ❌ Não existe | **Fase 2 (opcional)** |
| 12 | Recompensas diárias/caixas de itens (estrutura de evento do RO) | ❌ Não existe | **Fora de escopo** (ver §4) |
| 13 | **Efeito de voo da carta** até a bandeja (~0,2–0,3s, face-up, acima de tudo) | ✅ Já existe equivalente: `_animate_card_to_zone` (ghost com tween 0,3s + reveal + impacto "✦") — `level_screen.gd` L606–637 | Nenhum (polir em T7 se quiser) |
| 14 | **Efeito de match: flash dourado** — trio vira quadrados dourados que explodem em luz e somem (~0,4–0,6s) | ❌ Hoje o match não tem VFX próprio visível (remoção direta; só o impacto "✦" genérico na chegada) | **Implementar (T7)** |
| 15 | **Compactação da bandeja** pós-match com deslize para a esquerda | ⚠️ A zona re-renderiza (rebuild) sem animação de deslize | **Implementar (T7)** |
| 16 | **Decaimento de estrelas ao vivo no HUD** | ✅ `_update_live_stars` existe (`level_screen.gd` L751+) | Nenhum |
| 17 | **Decks desaparecem ao esvaziar** | ⚠️ Verificar comportamento atual do container dos decks ao esvaziar | **Ajustar (T7)** |
| 18 | **Tela de resultado** com nº do estágio, estrelas, recompensas, Continue, fala de mascote, total `x/30` | ⚠️ `_show_end` tem título/estrelas/tempo/botões; falta: número grande, recompensas visíveis, total de estrelas, mascote | **Polir (T7)** |
| 19 | **Mascote com dicas rotativas** | ❌ Não existe | **Opcional (T7)** — com personagem/tema original |

---

## 3. Tarefas (ordem de execução)

Regras globais para todas as tarefas:

- Rode a suíte headless antes e depois: `& "<Godot_console.exe>" --headless --path "E:\Cartitas" --script "res://tests/run_tests.gd"` (ver `README.md`). **Nenhum teste existente pode quebrar** (exceto quando a tarefa mudar comportamento documentado — aí atualize o teste e o doc na mesma entrega).
- Lógica nova vai em classes puras em `scripts/core/` (a costura de teste é o `GameController`); UI em `scripts/ui/` só reflete estado.
- Strings novas de UI em **EN e PT** no `Localizer` (`scripts/ui/localizer.gd`).
- Níveis novos são **JSON data-driven** em `levels/` e devem passar pelo `SolvabilityChecker`/`LevelValidator` existentes.
- Ao mudar comportamento documentado, atualize `docs/spec.md`, `CONTEXT.md` e `README.md` na mesma entrega.

### T1 — `time_limit` opcional por Level (derrota por timeout) — PRIORIDADE MÉDIA

**Evidência revista:** neste vídeo (Classic abr/2026) o relógio **conta para cima** e a partida segue ativa aos 15:05 com 1★ — **sem derrota por timeout observada**. Textos oficiais de outras versões mencionam "tempo limitado". Portanto: implementar como **opção por Level, desligada por padrão** (o comportamento default continua igual ao do vídeo: timer progressivo + estrelas que degradam).

- Adicionar `time_limit` (segundos, opcional) ao JSON do Level. Ausente = sem limite (comportamento atual preservado — igual ao vídeo).
- `GameController`: expor verificação de timeout dirigida por chamada (ex.: `check_timeout()` ou checagem dentro de `get_game_state()`/`tick()`), que aplica `_lose()` quando `timer.elapsed_seconds() > time_limit` durante `PLAYING`. **Não** introduzir `_process`/Node no core — a UI chama a verificação no seu `_process` existente (onde já atualiza o relógio, `level_screen.gd` linha ~50).
- UI: quando o Level tem `time_limit`, o relógio vira **contagem regressiva** (restante), com destaque visual nos últimos segundos; sem limite, mantém cronômetro progressivo (default).
- Estrelas continuam baseadas no tempo decorrido (`calculate_stars` inalterado); quando `time_limit` existir, garantir `time_limit > two_stars` nos JSONs.
- **Testes:** timeout → `Status.LOST` e timer parado; antes do limite → segue `PLAYING`; vitória antes do limite → `WON` com estrelas corretas; Level sem `time_limit` nunca perde por tempo. Usar `timer.set_elapsed_seconds()` (já existe) para casos determinísticos.
- **Critério de aceite:** Level com `time_limit: 10` em teste headless perde ao avançar o relógio além de 10s; Level sem `time_limit` nunca perde por tempo.

### T2 — Layout aleatório por tentativa

No vídeo, cada tentativa (inclusive retry do mesmo estágio) gera arranjo novo.

- `LevelLoader.resolve`: quando `layout.randomize_per_attempt` for `true` (default `true` para níveis novos; níveis 1–3 existentes podem migrar), sortear a seed base a cada carregamento em vez de usar `layout.seed` fixa, **mantendo o loop de até 60 tentativas do `SolvabilityChecker`** (ou seja: seed aleatória, mas layout garantidamente solucionável).
- Preservar caminho determinístico: se `layout.seed` estiver presente **e** `randomize_per_attempt` for `false`, comportamento atual (testes e smoke dependem de reprodutibilidade — verificar `tests/` antes de mudar defaults).
- **Testes:** duas cargas consecutivas do mesmo Level com randomização produzem layouts diferentes (posições/camadas), ambos solucionáveis; com seed fixa, layouts idênticos.
- **Critério de aceite:** retry do mesmo Level no jogo mostra tabuleiro diferente e solucionável.

### T3 — Expandir para 10 Levels com curva de dificuldade

O vídeo tem 10 estágios (30★). Hoje há 3.

- Criar `levels/level_4.json` … `level_10.json` com progressão: mais tipos (até os 12 registrados), mais camadas/sobreposição, decks maiores, `time_limit` e `time_thresholds` coerentes (3★ exigente mas possível; o vídeo sugere que os estágios 8–10 são o salto de dificuldade onde os poderes passam a ser necessários).
- Cada Level deve declarar `rewards` (seguindo o padrão atual, ex.: `+1 hold`) e, opcionalmente, `time_limit` (T1 — desligado por padrão).
- Menu (`main_menu.gd`): exibir **total de estrelas** (ex.: `★ 12/30`) além das estrelas por Level.
- Validar todos os JSONs com o `LevelValidator`/`SolvabilityChecker` existentes (adicionar caso de teste que carrega e valida os 10).
- **Critério de aceite:** menu lista 10 Levels desbloqueáveis em sequência, todos solucionáveis, total de estrelas agregado visível.

### T4 — Alinhar o Hold ao "Remove" do vídeo (3 primeiras cartas) — DECISÃO DOCUMENTADA

No vídeo, o poder tira as **3 primeiras cartas da esquerda** da bandeja. Hoje `use_hold()` tira as **últimas até 4** (`HOLD_COUNT = 4`, `zone.take_last(HOLD_COUNT)`).

- Mudar para mover as **3 cartas mais antigas** (esquerda) da Clearing Zone para a Reserve. Manter: Reserve retornável por toque (equivalente à área lateral do vídeo), rejeição sem consumo com zona vazia, nome canônico **Hold** (o glossário proíbe "Remove").
- **Atenção:** isso altera semântica documentada em `CONTEXT.md` ("moves the last few cards") e em `docs/spec.md` (US 15/17, seção Powers). Atualizar ambos + `README.md` na mesma entrega, junto com os testes de Hold (`tests/test_game_controller.gd`, `tests/test_integration.gd`).
- Se o mantenedor preferir manter o comportamento atual, esta tarefa pode ser descartada — é a única divergência deliberada de design do projeto em relação ao vídeo.
- **Detalhes observados no vídeo (decisões de design a registrar):**
  - O painel de poderes mostra estoque como `x/10` e o modal do Remove diz *"Remaining Uses for This Round: 10"* → aparentemente há **teto de 10 usos por rodada** além do custo de inventário. Registrar como config opcional por Level (ex.: `power_round_cap`, default desligado) **ou** não implementar — decidir com o mantenedor.
  - O vídeo mostra **modal de confirmação** antes de aplicar o poder (Cancel/Confirm). Recomendação: **não** adotar modal (atrito em jogo de ritmo rápido) — registrar a divergência como deliberada, a menos que o mantenedor queira paridade literal.
- **Critério de aceite:** com zona `[A, B, C, D, E]`, `use_hold()` move `[A, B, C]` para a Reserve e deixa `[D, E]`; docs e testes atualizados.

### T5 — Paridade de UI: retrato, bandeja embaixo, poderes à direita

Layout confirmado pelos frames do vídeo (ver §1b para o detalhe completo):

- Tornar **retrato (9:16)** o layout de referência do Level (o vídeo é mobile retrato); manter paisagem funcionando como alternativa.
- **Topo:** botão voltar à esquerda, título "Level N" + ajuda "?", relógio em pill centralizada, **3 estrelas logo abaixo do relógio** (já existe `_update_live_stars` — só reposicionar/estilizar).
- **Direita:** coluna vertical com os 3 poderes (ícone + nome + **contador de estoque `x/N`**); entrada realçada quando o poder está "armado"/selecionado.
- **Centro:** tabuleiro; **decks como montes escuros** entre tabuleiro e bandeja com a carta do topo visível.
- **Rodapé:** Clearing Zone em barra destacada, cartas entrando pela esquerda; Reserve próxima (manter — é a "área lateral" do vídeo).
- Linha de instrução curta no topo (localizada EN/PT), equivalente a *"Match three identical cards..."*.
- Cartas bloqueadas continuam escurecidas e identificáveis (já está assim); garantir que carta **totalmente coberta** não seja nem parcialmente clicável (hitbox) — apenas pela carta que a cobre.
- **Critério de aceite:** em 360×640, todos os elementos (tabuleiro, decks, zona, reserve, poderes à direita, relógio) são visíveis sem sobreposição; paisagem continua jogável.

### T6 — (FASE 2, OPCIONAL) Endless Mode

Somente após T1–T5 estáveis. Desbloqueado ao vencer o Level 10: gera layouts aleatórios com dificuldade crescente (mais tipos/camadas a cada rodada), acumula **pontos** por carta removida/rodada concluída, persiste **melhor pontuação local** em `user://` via `SaveManager` (leaderboard local apenas — nada online). Entrada visível no menu após completar os 10 Levels. No vídeo, o Endless tem **intro própria** (burst radial dourado + banner) — reutilizar o VFX de T7.

### T7 — Paridade de efeitos visuais (VFX) — com base na análise quadro a quadro (§1b)

Tudo em `scripts/ui/` (apresentação apenas — **nenhuma regra muda**; o `GameController` não deve saber que os efeitos existem). Implementar com tweens/animações em código, seguindo o padrão já existente (`_animate_card_to_zone`, `_play_card_impact`).

1. **Flash dourado de match (o efeito-assinatura do vídeo):** quando `matched_ids` voltar no resultado de `select_card`/`use_deck`/`return_from_reserve`, as 3 cartas do trio na Clearing Zone **viram retângulos dourados brilhantes** (ex.: modulate para dourado `#ffd54a` + escala 1,0→~1,2), **irradiam luz** (glow/burst radial ou partículas douradas simples) e **desvanecem** — total ~0,4–0,6s — antes de sumir. Sincronizar com a remoção visual: o trio some **depois** do flash, não instantaneamente.
2. **Compactação da bandeja:** após o match, as cartas à direita do trio **deslizam para a esquerda** (tween de `position`, ~0,15–0,2s) fechando os espaços, em vez de rebuild instantâneo. O mesmo deslize vale para carta devolvida ao tabuleiro pelo Undo.
3. **Voo da carta (já existe — polir):** `_animate_card_to_zone` já voa a carta com tween cúbico 0,3s + micro-rotação + impacto "✦". Alinhar ao vídeo: trajetória direta tabuleiro→slot, sem desvio; manter o impacto sutil no pouso. Sem mudança de regra.
4. **Decaimento de estrelas:** ao cruzar um limiar de tempo, a estrela perdida faz uma micro-animação (escala pulsa e esmaece de dourada para escura) — hoje muda seco via `_update_live_stars`.
5. **Decks:** monte **desaparece com fade/scale-out** quando esvazia (e reaparece no restart), em vez de ficar visível vazio.
6. **Tela de resultado:** fundo escurecido (já existe) + **número grande do Level**, **reveal sequencial das estrelas** (cada estrela ganha "pipa" com scale-bounce + brilho, ~0,3s entre elas), lista visual das **recompensas** do Level (ícone + quantidade, hoje só aplicadas silenciosamente), **total de estrelas agregado** (`x/30`), botões. Fala do mascote é opcional (item 8).
7. **Intro de rodada (opcional, usado no Endless do vídeo):** overlay com **burst radial dourado** + título do Level que desvance (~0,8s) ao iniciar a partida.
8. **(Opcional, flavor) Mascote com dicas:** personagem **original** do Cartitas (não o Raggler) num canto, com balão rotativo de dicas ("Use o poder à direita!", "Não encha a bandeja!"). Só se o mantenedor quiser; localizar EN/PT.
- **Testes:** VFX é apresentação — não exige teste headless; verificar manualmente (F5) que: match mostra flash dourado antes de sumir; bandeja compacta com deslize; decks somem ao esvaziar; resultado revela estrelas em sequência.
- **Critério de aceite:** os 4 efeitos centrais (1, 2, 4, 6) visíveis e fiéis às descrições da §1b; nenhum teste headless quebrado; `GameController` intacto.

---

## 4. Fora de escopo (não implementar)

- Estrutura de evento do jogo original: caixas diárias de itens, quests diárias, loja de tokens, recompensas de account (molduras, títulos).
- **Chrome do MMO visto nos frames:** toasts "Obtained: X xN", ticker de drops no rodapé, chat de guilda, menu lateral "Special Event", janela de Quest List — tudo isso é do Ragnarok Origin, **não** do mini-game.
- Leaderboard online / multiplayer.
- Qualquer arte, nome, monstro ou texto da IP Ragnarok Origin (inclusive o mascote Raggler — se adotado o flavor de mascote, criar personagem original).
- Mudança de tema/visual do Cartitas (placeholders atuais seguem valendo).

## 5. Verificação final (Definition of Done)

1. Suíte headless 100% verde, incluindo testes novos de T1–T4.
2. `LevelValidator`/`SolvabilityChecker` aprovam os 10 JSONs.
3. Jogo rodando (F5): fluxo completo menu → Level → vitória com estrelas → próximo Level liberado; retry com layout novo; derrota por bandeja cheia; e, num Level de teste com `time_limit`, contagem regressiva + derrota por timeout.
4. **Verificação visual (F5):** flash dourado no match, bandeja compactando com deslize, estrelas degradando ao vivo, decks sumindo ao esvaziar, tela de resultado com reveal sequencial de estrelas + recompensas + total `x/30` — tudo conforme §1b e T7.
5. `CONTEXT.md`, `docs/spec.md`, `README.md` e este documento consistentes com o comportamento final.

---

## 6. Status de implementação (sessão 2026-08-14)

- **T1** (time_limit opcional por Level) — implementado: `GameController.time_limit` + `check_timeout()`, UI com contagem regressiva e destaque nos segundos finais; testes cobrindo timeout/vitória/sem-limite.
- **T2** (layout aleatório por tentativa) — implementado: `layout.randomize_per_attempt` (default `true`) sorteia seed base mantendo o loop de solvabilidade; `randomize_per_attempt: false` + `seed` preserva determinismo.
- **T3** (10 Levels + total de estrelas) — implementado: `level_4..10.json`, todos solucionáveis; menu mostra total agregado `★ X/30`.
- **T4** (Hold move as 3 mais antigas) — implementado: `take_first(3)`; docs e testes atualizados. Sem modal de confirmação e sem `power_round_cap` (divergências deliberadas, já registradas).
- **T5** (paridade de UI) — implementado: retrato como layout de referência, poderes em coluna à direita com ícone + nome + contador `x/N`, HUD com relógio em pill + 3 estrelas abaixo, linha de instrução, botão de ajuda "?".
- **T6** (Endless Mode) — NÃO implementado (fase 2).
- **T7** (VFX) — itens 1 a 7 implementados (flash dourado de match, compactação com deslize, voo existente polido, decaimento animado das estrelas, decks com fade-out ao esvaziar, tela de resultado com reveal sequencial + recompensas + total `x/30`, intro de rodada). Item 8 (mascote) NÃO implementado.
- **Revisão de polimento (2026-10-28):** T2 tinha regredido quando os Levels passaram a usar `DifficultyProfile` (seed fixa por perfil); restaurado com `randomize_per_attempt` (default `true`) no caminho por perfil. Recompensas agora só na primeira vitória. Zona cheia sem Hold/Undo encerra o Level na hora; derrota por tempo mostra "Tempo esgotado!". T6 (Endless) e T7.8 (mascote) continuam pendentes.
- **T6 e T7.8 (2026-10-28):** implementados. Endless Mode com rodadas de dificuldade crescente, pontuação, estoque de poderes próprio, recorde local e entrada no menu após o último Level (decisão do mantenedor: o 11, não o 10 do texto original) (`EndlessRun`, `smoke_endless.gd`). Mascote original **Ás**, desenhado em código, com dicas e reações localizadas e opção de desligar. A intro de rodada reaproveita o burst dourado de T7.7.
