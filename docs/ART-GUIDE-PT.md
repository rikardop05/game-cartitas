# Guia de Arte — Cartitas Infinity (PT)

Guia para o(a) artista de pixel art incluir os sprites das cartas, efeitos e UI no projeto Godot.

## 1. Visão geral

- Jogo 2D em **pixel art**, resolução lógica base de **360×640** (retrato 9:16), com upscale inteiro e filtro *nearest* (sem suavização).
- Formato dos arquivos: **PNG**.
- Unidades de tamanho:
  - **Carta (face e verso): 32×32 px**
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
| `assets/cards/card_cat.png` … `card_crystal.png` | 32×32 | 12 faces de carta (um arquivo por tipo) |
| `assets/cards/back.png` | 32×32 | Verso da carta (para o topo dos Support Decks) |
| `assets/ui/power_hold.png` | 16×16 | Ícone do poder Hold |
| `assets/ui/power_undo.png` | 16×16 | Ícone do poder Undo |
| `assets/ui/power_refresh.png` | 16×16 | Ícone do poder Refresh |
| `assets/ui/star_filled.png` | 16×16 | Estrela preenchida |
| `assets/ui/star_empty.png` | 16×16 | Estrela vazia |
| `assets/ui/background.png` | 360×640 | Fundo da tela |

**Convenção de nomes:** `card_<tipo>.png` (ex.: `card_cat.png`), tudo em minúsculas. Os 12 tipos são: `cat, dog, bird, fish, flower, moon, star, sun, leaf, heart, gem, crystal`.

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

Nenhuma regra de jogo depende da arte; a arte é puramente apresentação.
