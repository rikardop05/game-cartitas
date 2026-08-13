# Cartitas Infinity

Jogo de puzzle de cartas (combine 3 iguais) feito em Godot.

## Como rodar o jogo

### 1. Instale o Godot (se ainda não tiver)

- Baixe o **Godot 4.7 ou superior** (versão padrão, sem .NET) em:
  https://godotengine.org/download/windows/
- Descompacte o arquivo e abra o executável `Godot_v4.x-stable_win64.exe`.

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
  - **Hold** — guarda as últimas cartas na **Reserve**, liberando espaço.
  - **Undo** — devolve a última carta ao tabuleiro/deck.
  - **Refresh** — reembaralha o tabuleiro e os decks.
- Vença limpando **todas** as cartas antes de encher a Clearing Zone.

## Como rodar os testes (opcional)

Abra o terminal (PowerShell) na pasta do projeto e rode:

```powershell
& "F:\caminho\para\Godot_console.exe" --headless --path "E:\Cartitas" --script "res://tests/run_tests.gd"
```

Troque o caminho pelo executável `Godot_v4.x-stable_win64_console.exe` do seu Godot.

## Estrutura do projeto

| Pasta        | O que contém                          |
|--------------|---------------------------------------|
| `scenes/`    | Cenas (menu principal e tela do level) |
| `scripts/core/` | Lógica do jogo (sem UI)            |
| `scripts/ui/`   | Interface e menu                    |
| `levels/`    | Arquivos JSON que definem os níveis   |
| `tests/`     | Testes automatizados                  |
| `docs/`      | Spec e guias de arte                  |
