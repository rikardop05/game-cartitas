# ADR-0002 — UI em alta resolução e layout responsivo

Status: accepted

O jogo usa stretch `canvas_items`: a UI é posicionada em unidades de design (360×640 no retrato,
640×360 na paisagem) e o Godot escala o resultado para a janela real. A arte pintada, porém, é
entregue em 1000–2000 px (cartas 882–957 px, painéis até ~2000 px, fundos 1280 px+). Assar um
painel 9-slice no retângulo de design e deixar a GPU ampliá-lo borrava as bordas em janelas 2×.
Este ADR fixa como a UI deve continuar nítida em qualquer tamanho suportado sem abandonar as
unidades de design.

## Context

- O projeto usa `window/stretch/mode="canvas_items"` e, desde 2026-11-02,
  `window/stretch/aspect="expand"`. O viewport lógico cresce além do mínimo de design sem
  mudar a escala dos controles; o layout não pode mais assumir um único par de dimensões.
- A arte é pintada, não pixel art: filtro nearest nos painéis pintados desperdiça a resolução
  entregue, e filtro linear sem mipmaps cintila ao reduzir. Os imports de arte pintada agora
  geram mipmaps (`mipmaps/generate=true`) e o projeto usa `default_texture_filter=3`
  (linear com mipmaps).
- O caminho antigo de 9-slice fazia `alpha_nine_patch`/`trimmed_nine_patch` assarem a textura
  no tamanho de design (ex.: reserva de 148×64, barra da zona de 464×64). Em uma janela 2×
  isso era ampliado pela GPU, borrando cantos e veios pintados. Além disso, `hires_texture`
  decodificava a imagem na CPU para gerar mipmaps em runtime, mesmo quando o import já os
  tinha.
- Os tamanhos mínimos de toque (≥ 32 px de design) e a ausência de sobreposição entre
  controles precisam valer em retrato estreito, tablet e paisagem larga.

## Decision

1. **Manter as unidades de design.** O layout continua expresso em px lógicos de design; a
   escala para a tela real é responsabilidade do stretch e do oversample, nunca de constantes
   duplicadas por resolução.
2. **Nunca assar arte no tamanho de design.** Painéis 9-slice são assados em
   `design_size × ui_oversample()` e desenhados com `scale = 1 / oversample`, via
   `UiHelpers.nine_patch_rect`. O fator vem de `ui_oversample()` (razão entre pixels reais e
   de design, arredondada para meio passo, limitada a 1–4) e o bake é limitado pela resolução
   da fonte, para não inventar nitidez.
3. **Imports com mipmaps.** Toda arte pintada é importada com mipmaps e desenhada com
   `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`. `UiHelpers.hires_texture` prefere o
   `CompressedTexture2D` importado e só gera mipmaps em runtime como fallback para texturas
   geradas ou sem import.
4. **Layout calculado pelo viewport.** `scripts/ui/level_layout.gd` (`LevelLayout.compute`)
   recebe o viewport lógico e devolve retângulos de portrait/landscape para HUD, board,
   poderes, decks, Reserve, zona, mascote e áreas de instrução. `level_screen.gd` consome esses
   retângulos; o menu aplica a mesma ideia com quatro botões e reflow no resize.
5. **Tamanhos suportados:** 360×640, 360×780, 360×800, 480×640, 640×360, 780×360 e 640×480.
   O board é o maior retângulo, os alvos interativos têm pelo menos 32 px e não se sobrepõem.

## Considered Options

- **A. Continuar assando no tamanho de design.** Rejeitada: é a causa direta do blur em 2×;
  aumentar as constantes de design quebraria o layout em telas pequenas.
- **B. Renderizar a UI inteira em um SubViewport 2× e reduzir.** Rejeitada: multiplica o custo
  de memória e fill rate da tela toda, complica input/controles e não resolve o layout
  responsivo.
- **C. Fixar 360×640 com letterbox.** Rejeitada: desperdiça tablet e paisagem, e não atende
  780×360/640×480.
- **D. Redesenhar os painéis como arte vetorial/procedural.** Rejeitada: perde a arte pintada
  entregue e o custo de produção não se justifica para o ganho.

## Consequences

**Positivas:**
- Cantos, veios e ornamentos dos 9-slices ficam nítidos em janelas 2×+ sem mudar o tamanho
  lógico dos controles.
- Um único layout em unidades de design cobre retrato, tablet e paisagem; os testes de layout
  verificam contenção, alvos e sobreposição em todos os tamanhos suportados.
- Os imports com mipmaps tiram da CPU o trabalho de decodificar/gerar mipmaps por textura.

**Negativas / riscos:**
- **Memória:** o bake oversampled ocupa VRAM proporcional ao fator (até 4× por painel,
  limitado pela resolução da fonte). O cache guarda uma entrada por combinação de caminho,
  tamanho de destino e oversample; redimensionar a janela pode criar um segundo bake.
- **Custo de primeira construção:** o resize Lanczos + geração de mipmaps acontece no primeiro
  uso de cada painel/fator; depois o cache serve as próximas telas.
- **Exceção `StyleBoxTexture`:** `kit_stylebox` e as linhas de opções continuam lendo
  `texture`/`margins` em design size, porque `StyleBoxTexture` não oferece o par
  tamanho/scale do `NinePatchRect`. Esses elementos dependem dos mipmaps do import e podem
  ficar um pouco menos nítidos que os painéis desenhados por `nine_patch_rect`.
- O oversample depende da janela: layouts e capturas de QA precisam ser feitos em 2× para
  enxergar o ganho; a suíte `qa_responsive_capture.gd` cobre esse caso.

## Review log

- **2026-11-02 — implementação:** `ui_oversample`/`nine_patch_rect` em `ui_helpers.gd`,
  `level_layout.gd` e o consumo no `level_screen.gd`/`main_menu.gd`; validação por
  `tests/test_level_layout.gd`, `tests/test_asset_references.gd` e capturas de
  `tests/qa_responsive_capture.gd` em `user://qa_shots`.
