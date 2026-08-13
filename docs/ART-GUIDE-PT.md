# Guia de Arte — Cartitas Infinity (PT)

Guia para o(a) artista de pixel art incluir os sprites das cartas, efeitos e UI no projeto Godot.

## 1. Visão geral

- Jogo 2D em **pixel art**, resolução lógica principal de **640×360** (paisagem 16:9), com janela de desenvolvimento em **1280×720**, upscale inteiro e filtro *nearest* (sem suavização).
- O modo retrato continua disponível em **360×640**, mas não é o layout de referência atual.
- Formato dos arquivos: **PNG**.
- Os tamanhos abaixo são o tamanho do arquivo-fonte da arte. O tamanho renderizado pode mudar conforme a área disponível.
- Unidades de tamanho atuais:
  - **Carta (face e verso): 64×64 px**
  - **Cartas na mesa, Support Decks e Clearing Zone: 48×48 px renderizados**
  - **Cartas na Reserve: 24–48×24–48 px**, reduzidas e empilhadas em duas colunas conforme a quantidade
  - **Ícones de poderes e estrelas: 16×16 px**
  - Grade base da UI: **8 px** (múltiplos de 8 para alinhamento).

## 2. Paleta

Usar uma **paleta limitada compartilhada** (~32 cores) para coesão. As cores de fundo de cada tipo de carta já estão definidas no projeto (arquivo `scripts/core/card_type_registry.gd`) e servem como base:

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

Recomenda-se fornecer um PNG de referência da paleta completa (cartas + UI + fundo) na pasta `assets/`.

## 3. Arquivos necessários

| Arquivo (sugerido) | Tamanho | Descrição |
|--------------------|---------|-----------|
| `assets/cards/card_cat.png` … `card_crystal.png` | 64×64 | 12 faces de carta (um arquivo por tipo) |
| `assets/cards/back.png` | 64×64 | Verso reservado para uso futuro; hoje os Support Decks exibem a face do topo |
| `assets/ui/power_hold.png` | 16×16 | Ícone do poder Hold |
| `assets/ui/power_undo.png` | 16×16 | Ícone do poder Undo |
| `assets/ui/power_refresh.png` | 16×16 | Ícone do poder Refresh |
| `assets/ui/star_filled.png` | 16×16 | Estrela preenchida |
| `assets/ui/star_empty.png` | 16×16 | Estrela vazia |
| `assets/ui/background.png` | 640×360 | Fundo da tela em paisagem; a variante retrato deve ser 360×640 |

**Convenção de nomes:** `card_<tipo>.png` (ex.: `card_cat.png`), tudo em minúsculas. Os 12 tipos são: `cat, dog, bird, fish, flower, moon, star, sun, leaf, heart, gem, crystal`.

> Não use o print de referência (1920×1020) como tamanho de produção. Ele é uma imagem de apresentação; a arte deve ser criada com base na resolução lógica de 640×360.

## 4. Estados visuais da carta

A lógica já controla o estado; a arte/overlay só representa. Em v1, o projeto usa **sobreposições (tint/escurecimento)** aplicadas por código — não é preciso desenhar variações:

- **Bloqueada (HIDDEN):** escurecida/dessaturada (overlay cinza).
- **Disponível (AVAILABLE):** cor plena.
- **Selecionada (SELECTED):** contorno branco (opcional: brilho).
- **Combinação (MATCHED):** animação de escala + fade (feita no código).

## 5. Animações

As animações (voar para a Clearing Zone, combinação, desbloqueio, embaralhar) são **tweens no código**, não arte quadro a quadro. Apenas a arte estática listada acima é necessária.

## 6. Importação no Godot

Ao colocar um PNG na pasta `assets/`, configurar no painel *Import*:

- **Filter:** Nearest
- **Mipmaps:** desligados
- **Compress:** Lossless (para pixel art)

O projeto já configura o filtro padrão como *nearest*; verificar apenas os novos arquivos.

## 7. Substituindo os placeholders

Hoje o jogo usa **placeholders** (cor de fundo + emoji por tipo), definidos em `scripts/core/card_type_registry.gd`. Para trocar por arte real:

1. Crie os PNGs nos caminhos da tabela acima.
2. O carregamento opcional já procura `assets/cards/card_<tipo>.png`; sem o arquivo, o placeholder continua sendo usado.
3. As artes de poderes, estrelas, verso e fundo ainda são referências para a próxima integração visual; atualmente a interface usa texto, emoji e cor de fundo para esses elementos.

Nenhuma regra de jogo depende da arte; a arte é puramente apresentação.
