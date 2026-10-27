# Guia de Arte — Cartitas Infinity (PT)

Guia para o(a) artista de pixel art produzir e entregar os sprites das cartas e da UI.
A versão didática para enviar ao artista é o PDF [`ART-DELIVERY-PT.pdf`](ART-DELIVERY-PT.pdf) (fonte: `docs/art-delivery/ART-DELIVERY-PT.html`).

## 1. Visão geral

- Jogo 2D em **pixel art**, resolução lógica principal de **640×360** (paisagem 16:9). A janela de desenvolvimento é **1280×720** (2× inteiro) com filtro *nearest* (sem suavização).
- O modo retrato continua disponível em **360×640**, mas não é o layout de referência.
- Formato: **PNG 32 bits (RGBA 8 bits por canal)**, sRGB, sem entrelaçamento.
- Toda arte é desenhada em **1 pixel de arte = 1 pixel lógico** do jogo. O jogo amplia/reduz por código; não entregue versões ampliadas como arquivo de produção.

## 2. Tamanhos

O tamanho exibido da carta é `Card.DISPLAY_SIZE` = **48×48 px lógicos** (`scripts/core/card.gd`). Por isso a face da carta é desenhada em **48×48**: no tamanho padrão do tabuleiro ela aparece exatamente em 2× na janela 1280×720, sem pixels deformados.

Tamanhos em que a mesma imagem aparece hoje (o código redimensiona o PNG para caber):

| Onde | Tamanho exibido (px lógicos) | Origem no código |
|------|------------------------------|------------------|
| Tabuleiro (padrão) | 48×48 | `LevelConfig.DEFAULT_CARD_SIZE` |
| Tabuleiro (ajuste ao espaço) | 41–120 (escala 0,85–2,5) | `BoardLayout.compute`, `MIN_CARD_SCALE` |
| Support Decks | ~38×38 (48 × 0,8) | `LevelConfig.RESERVE_CARD_SCALE` |
| Clearing Zone — paisagem | 31×31 | `LANDSCAPE_ZONE_CARD_SIZE` |
| Clearing Zone — retrato | 48×48 | `CARD_DISPLAY_SIZE` |
| Reserve — paisagem | 28–30, duas colunas | `LANDSCAPE_RESERVE_CARD_SIZE` |
| Reserve — retrato | 28–38, duas colunas | `_reserve_card_size()` |

Consequência para a arte: o símbolo precisa ser **legível a ~30 px** (silhueta forte, poucos detalhes finos de 1 px), porque nas áreas pequenas a imagem é reduzida.

## 3. Anatomia da carta

O PNG da carta é desenhado **por cima da carta inteira** (um `TextureRect` do tamanho da carta, em `_make_card_art` de `scripts/ui/level_screen.gd`). A moldura e a cor de fundo do placeholder só aparecem onde o PNG for transparente. Portanto:

- Entregue a **face completa**: moldura + fundo + símbolo, dentro de 48×48.
- Os cantos podem ser arredondados com pixels **totalmente transparentes** (o placeholder usa raio ~5 px).
- Use a cor base do tipo (tabela abaixo) como cor dominante do fundo ou do símbolo, para o jogador reconhecer o tipo.
- Alpha só **0 ou 255** (sem semitransparência nem anti-aliasing nas bordas).

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
| `assets/cards/card_<tipo>.png` | 48×48 | 12 faces de carta, uma por tipo |

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

Ao entrar no projeto, cada PNG em `assets/` deve ter no painel *Import*:

- **Filter:** Nearest (o padrão do projeto já é nearest — `default_texture_filter=0`)
- **Mipmaps:** desligados
- **Compress:** Lossless

Nenhuma regra de jogo depende da arte; a arte é puramente apresentação.
