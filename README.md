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
- Cartas **escuras** estão bloqueadas por outras cartas em cima.
- Use os dois **decks** (em baixo do tabuleiro) quando não houver jogada.
- Poderes:
  - **Hold** — guarda as 3 cartas mais antigas (da esquerda) na **Reserve**, liberando espaço.
  - **Undo** — devolve a última carta ao tabuleiro/deck.
  - **Refresh** — reembaralha o tabuleiro e os decks.
- Vença limpando **todas** as cartas antes de encher a Clearing Zone. Se a zona encher e você não tiver Hold nem Undo para liberar espaço, o Level termina na hora.
- São **11 Levels** (33★ no total). Cada tentativa gera um layout novo (ainda assim garantidamente solucionável).
- A recompensa de um Level (ex.: +1 Hold) vem só na **primeira** vitória; rejogar serve para melhorar as estrelas.
- Alguns Levels têm **tempo limite** opcional (contagem regressiva); sem `time_limit`, o cronômetro só conta para cima e as estrelas degradam conforme o tempo. O cronômetro pausa enquanto a ajuda (?) está aberta ou o jogo está em segundo plano.

## Como rodar os testes (opcional)

Abra o terminal (PowerShell) na pasta do projeto e rode os testes unitários:

```powershell
& "C:\caminho\para\Godot_v4.7-stable_win64_console.exe" --headless --path "E:\Cartitas" --script "res://tests/run_tests.gd"
```

Troque o caminho pelo executável `_console.exe` do seu Godot. O CI (`.github/workflows/ci.yml`) roda também estes scripts, do mesmo jeito (`--script res://tests/<nome>.gd`):

| Script | O que verifica |
|---|---|
| `smoke_level.gd`, `smoke_main_menu.gd` | as cenas abrem sem erro |
| `regression_board_layout.gd` | posições das cartas em todas as resoluções |
| `probe_generation.gd` | tempo de geração dos tabuleiros |
| `repro_hud_bounds.gd` | HUD inteiro dentro da tela em retrato e paisagem |
| `repro_board_capture.gd` | tabuleiro da cena igual ao do gerador |

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
