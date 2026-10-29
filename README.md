# Cartitas Infinity

Jogo de puzzle de cartas (combine 3 iguais) feito em Godot.

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
- Junte **3 cartas iguais** para removê-las automaticamente.
- Cartas **escuras** estão bloqueadas por outras cartas em cima (quanto mais fundo na pilha, mais escuras).
- Use os dois **decks** (pilhas de cartas embaixo do tabuleiro) quando não houver jogada.
- Poderes:
  - **Hold** — guarda as 3 cartas mais antigas (da esquerda) na **Reserve**, liberando espaço.
  - **Undo** — devolve a última carta ao tabuleiro/deck.
  - **Refresh** — reembaralha o tabuleiro e os decks.
- Vença limpando **todas** as cartas antes de encher a Clearing Zone. Se a zona encher e você não tiver Hold nem Undo para liberar espaço, o Level termina na hora.
- São **11 Levels** (33★ no total). Cada tentativa gera um tabuleiro novo em camadas, alinhado a uma grade (ainda assim garantidamente solucionável, com os decks e os poderes).
- A recompensa de um Level (ex.: +1 Hold) vem só na **primeira** vitória; rejogar serve para melhorar as estrelas.
- **Endless Mode** (libera ao vencer o último Level, hoje o 11, no topo da lista de Levels): rodadas seguidas com dificuldade crescente, sem tempo limite. Cada carta combinada vale 10 pontos e cada rodada limpa dá um bônus de 100 × rodada. A partida usa um estoque de poderes próprio (2 Hold, 2 Undo, 1 Refresh, +1 poder a cada 3 rodadas) e não gasta o seu inventário. Seu recorde fica salvo.
- O mascote **Ás** diz a instrução no início de cada Level/rodada, dá dicas e reage às jogadas; dá para desligá-lo em **Opções** (a instrução aparece então num balão avulso).
- Alguns Levels têm **tempo limite** opcional (contagem regressiva); sem `time_limit`, o cronômetro só conta para cima e as estrelas degradam conforme o tempo. O cronômetro pausa enquanto a ajuda (?) está aberta ou o jogo está em segundo plano.

## Como rodar os testes (opcional)

Abra o terminal (PowerShell) na pasta do projeto e rode os testes unitários:

```powershell
& "C:\caminho\para\Godot_v4.7-stable_win64_console.exe" --headless --path "E:\Cartitas" --script "res://tests/run_tests.gd"
```

Esse runner inclui `test_level_boards.gd` (tabuleiros gerados de todos os Levels e rodadas do Endless). Troque o caminho pelo executável `_console.exe` do seu Godot. O CI (`.github/workflows/ci.yml`) roda também estes scripts, do mesmo jeito (`--script res://tests/<nome>.gd`):

| Script | O que verifica |
|---|---|
| `smoke_level.gd`, `smoke_main_menu.gd` | as cenas abrem sem erro |
| `smoke_endless.gd` | fluxo do Endless: rodada, pontos, rodada concluída, fim de partida e recorde |
| `smoke_help.gd` | a ajuda (?) cabe na tela nas duas orientações e sempre fecha |
| `regression_board_layout.gd` | posições das cartas de todos os Levels em todas as resoluções (retrato, paisagem e desktop) |
| `probe_generation.gd` | tempo de geração e qualidade dos tabuleiros (validador, solucionável) |
| `repro_hud_bounds.gd` | HUD inteiro dentro da tela em 6 views: campanha e Endless, retrato e paisagem, mais as views com o mascote desligado |
| `repro_board_capture.gd` | tabuleiro da cena igual ao do gerador, em retrato (332×264) e paisagem (466×214) |

## Estrutura do projeto

| Pasta        | O que contém                          |
|--------------|---------------------------------------|
| `scenes/`    | Cenas (menu principal e tela do level) |
| `scripts/core/` | Lógica do jogo (sem UI)            |
| `scripts/ui/`   | Interface e menu                    |
| `levels/`    | Arquivos JSON que definem os níveis   |
| `tests/`     | Testes automatizados                  |
| `docs/`      | Spec, ADRs e guias de arte            |
| `addons/godot_mcp/` | Addon Godot-MCP (C#, só no editor .NET) |
