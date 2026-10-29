# Guia de Arte — Cartitas Infinity (PT)

Guia para o(a) artista de pixel art produzir e entregar os sprites das cartas e da UI.
A versão didática para enviar ao artista é o PDF [`ART-DELIVERY-PT.pdf`](ART-DELIVERY-PT.pdf) (fonte: `docs/art-delivery/ART-DELIVERY-PT.html`).

## 1. Visão geral

- Jogo 2D em **pixel art**, resolução lógica principal de **640×360** (paisagem 16:9). A janela de desenvolvimento é **1280×720** (2× inteiro) com filtro *nearest* (sem suavização).
- O modo retrato continua disponível em **360×640**, mas não é o layout de referência.
- Formato: **PNG 32 bits (RGBA 8 bits por canal)**, sRGB, sem entrelaçamento.
- Toda arte é desenhada em **1 pixel de arte = 1 pixel lógico** do jogo. O jogo amplia/reduz por código; não entregue versões ampliadas como arquivo de produção.

## 2. Tamanhos (padrão de arte das cartas)

A face da carta é entregue em **alta resolução** e o jogo a reduz na hora certa: **PNG quadrado de 960×960 px** (mínimo 512; prefira múltiplos de 64 — 960 = 64 × 15, o que mantém a moldura em pixel art alinhada). Os arquivos atuais do Pack A têm 480–960 px.

Por quê: a interface é calculada em 640×360 (paisagem) / 360×640 (retrato) **lógicos**, mas desenhada na **resolução física da tela** (`stretch mode = canvas_items`). Uma carta de 40 px lógicos ocupa 80 px reais numa janela 1280×720, 120 px em tela cheia 1080p, e mais em telas maiores. O jogo gera **mipmaps** ao carregar a arte e a desenha com filtro **trilinear** (`UiHelpers.card_texture` + `_make_card_art`), então a placa de vídeo reduz direto do original para o tamanho real — nítido em qualquer resolução, sem reprocessar a arte.

Tamanhos em que a carta aparece (px lógicos; multiplique pela escala da janela para pixels reais):

| Onde | Tamanho exibido |
|------|-----------------|
| Tabuleiro | até 40 (`LevelConfig.MAX_BOARD_CARD_PX`), menor em tabuleiros grandes |
| Clearing Zone | 40 (paisagem) / 36 (retrato) |
| Reserve | 18–40, em grade que cabe na caixa |
| Support Decks | carta do topo dentro do quadrado 64 |

Consequência para a arte: o símbolo precisa ser **legível a ~30 px lógicos** (silhueta forte, contorno escuro, poucos detalhes muito finos).

## 3. Anatomia da carta

O PNG é desenhado **como a face inteira da carta** (sem fundo ou borda extra do jogo). Siga o modelo do Pack A (`assets/cards/card_dog.png`):

- **Moldura** de madeira em pixel art ocupando a borda (no 960 px, cada "pixel" da moldura tem 15 px), com a sombra inferior inclusa.
- **Área interna** clara (branco com filete lilás) e a **ilustração centralizada**, com contorno escuro e respiro de ~15% até a moldura.
- Fundo fora da moldura **transparente**; cantos podem ter pixels totalmente transparentes.
- Mesmo enquadramento e mesma luz em todas as cartas, para o conjunto parecer uma família.
- Cartas bloqueadas são escurecidas pelo jogo; não entregue versões escuras.

## 4. Paleta

Usar uma **paleta limitada compartilhada** (~32 cores). As cores base por tipo estão em `scripts/core/card_type_registry.gd`:

| Tipo | Cor base |
|------|----------|
| cat | `#e07a7a` |
| dog | `#d9a05b` |
| bird | `#e0c95b` |
| fish | `#6bb5e0` |
| flower | `#e08ac9` |
| moon | `#c9b8e0` |
| star | `#f0e060` |
| sun | `#f0b060` |
| leaf | `#6bc98a` |
| heart | `#e06a6a` |
| gem | `#6ac9d9` |
| crystal | `#9a7ae0` |

Cores de interface já usadas: fundo da tela de nível `#c78454`, borda dos painéis `#f3d28d`, texto `#fff1d2`, estrelas `#ffe36e`, moldura do placeholder `#fff2d5`.

Atenção: `heart` (`#e06a6a`) e `cat` (`#e07a7a`) são quase iguais — diferencie pelo símbolo e silhueta, não pela cor.

Entregue um `palette/palette.png` com todas as cores usadas (um quadrado 8×8 por cor).

## 5. Arquivos

### Fase 1 — obrigatório (já é carregado pelo jogo)

| Arquivo | Tamanho | Descrição |
|---------|---------|-----------|
| `assets/cards/card_<tipo>.png` | 960×960 (mín. 512, quadrado) | 12 faces de carta, uma por tipo (moldura inclusa) |

`UiHelpers.card_texture()` procura `res://assets/cards/card_<tipo>.png`; sem o arquivo, o jogo usa o placeholder (cor + emoji). Os 12 tipos: `cat, dog, bird, fish, flower, moon, star, sun, leaf, heart, gem, crystal`.

### Fase 2 — opcional (ainda não integrado no código; hoje a UI usa texto/emoji)

| Arquivo | Tamanho | Descrição |
|---------|---------|-----------|
| `assets/cards/back.png` | 48×48 | Verso (reservado para uso futuro) |
| `assets/ui/power_hold.png` | 16×16 | Ícone do poder Hold (move 3 cartas da Clearing Zone para a Reserve) |
| `assets/ui/power_undo.png` | 16×16 | Ícone do poder Undo (devolve a última carta da Clearing Zone) |
| `assets/ui/power_refresh.png` | 16×16 | Ícone do poder Refresh (reembaralha o tabuleiro e os Support Decks) |
| `assets/ui/star_filled.png` | 16×16 | Estrela preenchida (HUD) |
| `assets/ui/star_empty.png` | 16×16 | Estrela vazia (HUD) |
| `assets/ui/background.png` | 640×360 | Fundo da tela, paisagem |
| `assets/ui/background_portrait.png` | 360×640 | Fundo da tela, retrato |

O fundo fica atrás de painéis semitransparentes escuros e das cartas: use contraste baixo e evite detalhes no centro.

**Nomes:** tudo minúsculo, sem espaços nem acentos, exatamente como nas tabelas.

> Não use o print de referência (1920×1020) como tamanho de produção. É uma imagem de apresentação.

## 6. Estados visuais

A lógica controla o estado; a arte não precisa de variações.

- **Disponível (AVAILABLE):** cor plena.
- **Bloqueada (HIDDEN):** o código multiplica a carta por cinza 62% (`modulate = Color(0.62, 0.62, 0.62)`). A arte precisa continuar legível escurecida — evite detalhes que dependam de tons escuros.
- **Selecionada / combinação:** a carta voa para a Clearing Zone e, ao formar trio, some com escala + fade. Tudo em tween; não há contorno nem quadro desenhado.

## 7. Animações

Voo para a Clearing Zone, combinação, desbloqueio e embaralhar são **tweens no código**. Só é necessária arte estática.

## 8. Entrega

Um único `.zip` cuja raiz espelha o projeto (pode ser descompactado direto na raiz do repositório):

```
cartitas_arte_v01_AAAA-MM-DD.zip
├── assets/
│   ├── cards/   card_cat.png … card_crystal.png (12)  [+ back.png]
│   └── ui/      (fase 2, se entregue)
├── palette/     palette.png
├── source/      arquivos editáveis (.aseprite, .psd, …)
├── preview/     (opcional) mesmas artes ampliadas 4× — só para conferência
└── LEIAME.txt   versão, data, lista do que mudou, observações
```

## 9. Importação no Godot (feito por quem integra)

- **Cartas** (`assets/cards/`): basta copiar o PNG com o nome `card_<tipo>.png`. O jogo gera os mipmaps e usa filtro trilinear sozinho; não precisa mexer no painel *Import*. Artes antigas ficam em `assets/cards/legacy/` (pasta ignorada pelo Godot).
- **Kit de UI e ícones em pixel art** (`assets/ui/kit/`): Filter **Nearest** (padrão do projeto), Mipmaps **desligados**, Compress **Lossless**, desenhados em 1× ou múltiplos inteiros.
- **Fundos pintados** (`assets/ui/`): o jogo aplica filtro linear e o shader de suavização.

Nenhuma regra de jogo depende da arte; a arte é puramente apresentação.
