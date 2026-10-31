# Guia de Arte — Cartitas Infinity (PT)

Guia para o(a) artista de pixel art produzir e entregar os sprites das cartas e da UI.
A versão didática para enviar ao artista é o PDF [`ART-DELIVERY-PT.pdf`](ART-DELIVERY-PT.pdf) (fonte: `docs/art-delivery/ART-DELIVERY-PT.html`).

## 1. Visão geral

- Jogo 2D em **pixel art**, resolução lógica principal de **640×360** (paisagem 16:9). A janela de desenvolvimento é **1280×720** (2× inteiro) com filtro *nearest* (sem suavização).
- O modo retrato continua disponível em **360×640**, mas não é o layout de referência.
- Formato: **PNG 32 bits (RGBA 8 bits por canal)**, sRGB, sem entrelaçamento.
- Toda arte é desenhada em **1 pixel de arte = 1 pixel lógico** do jogo. O jogo amplia/reduz por código; não entregue versões ampliadas como arquivo de produção.

## 2. Tamanhos (padrão de arte das cartas)

A face da carta é entregue em **alta resolução** e o jogo a reduz na hora certa: **PNG quadrado** (mínimo 512; prefira múltiplos de 64). O conjunto atual tem **882–957 px** — cada carta é recortada no limite duro da moldura e mantida no tamanho nativo quadrado (ex.: 957 px vindo de fonte 960; 882 px quando a fonte é menor), sem upscale artificial para um número fixo.

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

O PNG é desenhado **como a face inteira da carta** (sem fundo ou borda extra do jogo). Siga o modelo atual (`assets/cards/card_mouse.png`):

- **Moldura** de metal escuro pintada, com rebites e um ornamento entalhado em cada canto, ocupando a borda.
- **Área interna** de pergaminho e a **ilustração centralizada**, com contorno escuro e respiro de ~10% até a moldura.
- Fundo fora da moldura **transparente**, com silhueta limpa: sem halo branco, sem sombra projetada, sem glow e sem respingos. O jogo propaga a cor da borda para os pixels transparentes; um fundo branco apareceria como um filete claro.
- **A moldura toca as quatro bordas do canvas**: recorte no limite duro do alpha (alpha ≥ 240) e entregue um quadrado sem margem transparente. Não faça upscale de uma fonte menor só para chegar a 960.
- Mesmo enquadramento e mesma luz em todas as cartas, para o conjunto parecer uma família.
- Cartas bloqueadas são escurecidas pelo jogo; não entregue versões escuras.

## 3b. Arte pintada do HUD

Placas e ícones pintados (estrelas, cronômetro, engrenagem) ficam em `assets/ui/hud/` e seguem o mesmo padrão das cartas: PNG com fundo transparente em alta resolução (ícones ≥ 512 px; placas de estrelas ~1024 px de largura, uma imagem por estado `stars_1/2/3.png`), desenhados com mipmaps e filtro trilinear.

## 3c. Heróis pintados

Os heróis de fase ficam em `assets/ui/heroes/` como `hero_<id>.png`: corpo inteiro pintado, fundo transparente, sem halo branco e sem sombra projetada, recortados na silhueta, em alta resolução (770–1220 px de largura × 1260–1520 px de altura). Desenhados com mipmaps e filtro trilinear.

Mapa de fases (usado pela tela de nível):

| Fase | Arquivo |
|------|---------|
| 1 | `hero_cat.png` |
| 2 | `hero_wolf_ranger.png` |
| 3 | `hero_boar.png` |
| 4 | `hero_mouse.png` |
| 5 | `hero_owl.png` |
| 6 | `hero_frog.png` |
| 7 | `hero_knight.png` |
| 8 | `hero_bunny.png` |
| 9 | `hero_wolf_knight.png` |
| 10 / 11 | fallback (`hero_menu_wolf.png` segue como herói do menu) |

A fase 8 (coelha) tem ainda quatro expressões, com o mesmo tamanho e enquadramento de `hero_bunny.png`:

| Arquivo | Uso |
|---------|-----|
| `hero_bunny_thinking.png` | pensando / esperando |
| `hero_bunny_sequence.png` | mostrando a sequência |
| `hero_bunny_bad_choice.png` | escolha errada |
| `hero_bunny_defeat.png` | derrota |

O herói do menu é `assets/ui/heroes/hero_menu_wolf.png` (lobo cavaleiro de costas). O logo do jogo fica em `assets/ui/branding/logo_claw_and_crown.png` (transparente, 1748×866).

## 3d. FX de combinação

Os efeitos de combinação ficam em `assets/ui/fx/`: `match_burst.png` (explosão azul, ao fechar um trio) e `match_smoke.png` (nuvens de fumaça azul + gotas). Ambos são PNG RGBA com fundo transparente e mantêm o brilho suave (não corte o alpha, só a borda vazia).

## 3e. Fundos de fase

Fundos pintados full-bleed, um conjunto por faixa de fases. Sem alpha e sem recorte: a arte já cobre o quadro inteiro e é desenhada esticada na tela com filtro linear.

| Fases | Conjunto | Paisagem | Retrato |
|-------|----------|----------|---------|
| 1–3 | campo (meadow) | `assets/ui/background.png` (640×360) | `assets/ui/background_portrait.png` (360×640) |
| 4–7 | cidade de outono | `assets/ui/background_autumn.png` (1672×941) | reaproveita a arte de paisagem |
| 8–11 | castelo | `assets/ui/background_castle.png` (1280×720) | `assets/ui/background_castle_portrait.png` (532×720) |

Mantenha contraste baixo e evite detalhe no centro: painéis escuros semitransparentes e as cartas ficam por cima.

## 3f. Painéis pintados (kit de UI)

Os painéis esticáveis ficam em `assets/ui/kit/`. Todos estão recortados na silhueta (margens transparentes removidas, sem sombra externa) e são desenhados como `NinePatchRect`, então a margem do 9-slice precisa preservar os cantos entalhados:

| Arquivo | Tamanho | Uso | Margem 9-slice |
|---------|---------|-----|----------------|
| `bar_zone.png` | 2162×314 | Barra da Clearing Zone (área útil x 56–2105, y 44–257) | 72 px (pontas) |
| `panel_powers_board.png` | 751×1453 | Board vertical dos poderes (área útil x 78–690, y 76–1368) | 96 px |
| `panel_reserve_field.png` | 1829×741 | Campo da Reserve — o miolo de pedra faz parte da arte (as cartas vão por cima) | 192 px |
| `card_available_frame.png` | 1160×1077 | Moldura de carta disponível (área útil x 75–1086, y 72–1004) | 96 px |

## 3g. Assets do menu

| Arquivo | Tamanho | Observação |
|---------|---------|------------|
| `assets/ui/background_menu.png` | 640×360 | Fundo do menu, só paisagem (sem versão retrato) |
| `assets/ui/branding/btn_menu_jogar.png` | 64×32 | Botão "JOGAR" em pixel art |
| `assets/ui/branding/btn_menu_opcoes.png` | 64×32 | Botão "OPÇÕES" em pixel art |
| `assets/ui/branding/btn_menu_sair.png` | 64×32 | Botão "SAIR" em pixel art |

Os botões são pixel art: desenhe em 1× ou múltiplos inteiros com filtro Nearest, mipmaps desligados e compressão lossless (já é o padrão de importação do projeto). O logo do jogo (`assets/ui/branding/logo_claw_and_crown.png`) fica separado dos botões.

## 4. Paleta

Usar uma **paleta limitada compartilhada** (~32 cores). As cores base por tipo estão em `scripts/core/card_type_registry.gd`:

| Tipo | Cor base |
|------|----------|
| mouse | `#b8a46a` |
| cat | `#c9564f` |
| boar | `#b0713c` |
| owl | `#7a6bc9` |
| wolf | `#8fa3b8` |
| duck | `#d9a441` |
| frog | `#7fae4a` |
| whale | `#4f7fc9` |
| leaf | `#6bc98a` |
| heart | `#e06a6a` |
| gem | `#6ac9d9` |
| crystal | `#9a7ae0` |

Cores de interface já usadas: fundo da tela de nível `#c78454`, borda dos painéis `#f3d28d`, texto `#fff1d2`, estrelas `#ffe36e`, moldura do placeholder `#fff2d5`.

Temas das cartas (arte atual): `mouse` estudioso encapuzado com livro; `cat` arqueira encapuzada de capa vermelha; `boar` brutamontes com maça; `owl` mago com cajado; `wolf` cavaleiro de armadura; `duck` pistoleiro de chapéu; `frog` patrulheiro de capa de folhas; `whale` capitão pirata; `leaf` patrulheira verde (arqueira); `heart` coelha paladina dourada; `gem` coelha cavaleira azul (armadura prateada, cachecol e capa azuis); `crystal` ainda no placeholder. `heart` e `gem` são personagens diferentes — nunca reaproveite uma pela outra. `heart` (`#e06a6a`) e `cat` são vermelhos próximos: diferencie pela silhueta e pelo símbolo, não pela cor.

Entregue um `palette/palette.png` com todas as cores usadas (um quadrado 8×8 por cor).

## 5. Arquivos

### Fase 1 — obrigatório (já é carregado pelo jogo)

| Arquivo | Tamanho | Descrição |
|---------|---------|-----------|
| `assets/cards/card_<tipo>.png` | quadrado nativo (mín. 512) | 12 faces de carta, uma por tipo (moldura inclusa, recortada no limite duro) |

`UiHelpers.card_texture()` procura `res://assets/cards/card_<tipo>.png`; sem o arquivo, o jogo usa o placeholder (cor + emoji). Os 12 tipos: `mouse, cat, boar, owl, wolf, duck, frog, whale, leaf, heart, gem, crystal`. Onze têm arte pintada; `crystal` ainda usa o placeholder.

### Fase 2 — opcional (ainda não integrado no código; hoje a UI usa texto/emoji)

| Arquivo | Tamanho | Descrição |
|---------|---------|-----------|
| `assets/cards/back.png` | 48×48 | Verso (reservado para uso futuro) |
| `assets/ui/power_hold.png` | 16×16 | Ícone do poder Hold (move 3 cartas da Clearing Zone para a Reserve) |
| `assets/ui/power_undo.png` | 16×16 | Ícone do poder Undo (devolve a última carta da Clearing Zone) |
| `assets/ui/power_refresh.png` | 16×16 | Ícone do poder Refresh (reembaralha o tabuleiro e os Support Decks) |
| `assets/ui/star_filled.png` | 16×16 | Estrela preenchida (HUD) |
| `assets/ui/star_empty.png` | 16×16 | Estrela vazia (HUD) |

Os fundos de fase estão na seção 3e.

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
│   ├── cards/   card_mouse.png … card_crystal.png (12; crystal pode seguir como placeholder)  [+ back.png]
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
