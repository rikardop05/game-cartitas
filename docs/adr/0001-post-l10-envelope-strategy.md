# ADR-0001 — Estratégia pós-L10: níveis 11+ config-only dentro do envelope atual

Status: accepted

`DifficultyProfile.LEVELS` define os níveis atuais (1–11), todos dentro dos guardrails de
`LevelConfig` (até 36 board cards, 12 tipos, 4 layers, slots 7×6, envelope retrato
256×195). L10 usa o teto estrutural; L11 é a primeira aplicação config-only desse teto
(recalibração, não crescimento). Decidimos que níveis 11+ continuam
**config-only dentro do envelope atual**, escalando dificuldade pelos parâmetros já
suportados; qualquer expansão estrutural só será permitida mediante um
`BoardEnvelopeProfile`/capability explícito — **nunca** por condicional de número de
nível.

## Context

A progressão é data-driven: cada nível é um JSON com `difficulty` apontando para uma
linha de `DifficultyProfile.LEVELS`. O pipeline (`LayoutGenerator.generate_level` →
`SolvabilityChecker` → `LevelLoader`) nunca retorna nível insolúvel: falha vira erro
(push_error), não fallback. Os guardrails de `LevelConfig.validate()` protegem o
envelope espacial do board no retrato canônico. L10 já usa o teto estrutural (36 cartas,
4 layers, slots 7×6, 12 tipos), então o único espaço de crescimento é a calibragem dos
parâmetros de dificuldade, não a geometria. L11 (adicionado durante a implementação deste
ADR) confirma: frente a L10, é só calibragem (free_ratio 0.30 vs 0.32; overlap 0.7 vs 0.7;
mesmas 36 cartas/7×6/4 layers).

## Decision

**Níveis 11+ = config-only dentro do envelope atual.** A dificuldade adicional deve vir
da combinação dos parâmetros já existentes no `LevelConfig`/JSON:

- **Distribuição de múltiplos trios** — o total por tipo (board + decks) deve ser
  múltiplo de 3 (invariante já validado). Tipos podem carregar 2+ trios (multiplicidade),
  com o excedente vivendo nos decks, pois o board é limitado a 36 cartas.
- **Overlap validado** — overlap por eixo por perfil: `overlap_h ∈ [0.35, 0.60]` e
  `overlap_v ∈ [0.35, 0.55]` (`LevelConfig.OVERLAP_*_MIN/MAX`, efetivos via
  `effective_overlap_h/v`), validados em `LevelConfig.validate()`. A validação de **área**
  (`max_coverage ≤ 0.75`) é separada e feita em `_spatial_validation` +
  `LevelValidator._validate_spatial`. O `[0.25, 0.78]` é apenas o delta interno do tuning,
  não um range de validação.
- **Free ratio** — `free_ratio` por perfil (target) com banda `free_ratio_min/max`
  (validada em `LevelConfig.validate()`); o tuning loop persegue o alvo e reporta
  `free_ratio_ok` em `generation_metrics`. A banda é **soft** (best-score fallback): o
  resultado pode sair dela sem nunca deixar um board insolúvel (ex.: L6 mean 0.34, cauda
  0.22 em 100 seeds).
- **Densidade same-layer** — `MIN_SAME_LAYER_DIST_RATIO = 0.35 × card` (distância mínima
  entre cartas do mesmo layer, enforced em `_spatial_validation.same_layer_ok`).
- **Exposição mínima** — `min_exposure ≥ 0.10` (fração mínima visível de uma carta coberta,
  `_spatial_validation`).
- **Ocupação** — `occupancy_h/v` por perfil (derivam `slot_columns/rows`).
- **Decks** — tamanho e composição por JSON (trios completos; tipos restritos a
  `available_card_types`).
- **Tempo** — `time_thresholds` e `time_limit` por JSON (mantendo `time_limit > two_stars`).
- **Recompensas** — `rewards` por JSON.

**Expansão estrutural** (mais board cards, camadas, slots, tipos ou área) só é permitida
mediante um **`BoardEnvelopeProfile`/capability explícito** que declare o novo envelope e
suas guardrails, seja validado pelo pipeline e reportado em `generation_metrics`
(ex.: `fits_portrait`, `min_card_px_*`). A troca de envelope é decisão de produto —
**nunca** `if difficulty > 10`, `if level_id == 11` ou equivalente no código.

## Considered Options

- **A. Elevar guardrails por nível (ex.: L11 com 48 cartas)** — Rejeitada: introduz
  condicional por número de nível e quebra a validação uniforme; guardrails devem ser
  globais.
- **B. Endless procedural com envelope crescente** — Adiada (T6/fase 2): precisaria do
  mesmo `BoardEnvelopeProfile`; este ADR define a forma para esse uso futuro.
- **C. Envelope dinâmico declarado no JSON do nível** — Aceita como mecanismo único de
  expansão: o nível declara um `board_envelope` (ou referência a um profile de envelope)
  e o pipeline valida contra ele em vez de valores globais.
- **D. Parar em 10 níveis** — Rejeitada: não atende à exigência de progressão contínua.

## Consequences

**Positivas:**
- Conteúdo novo = linha em `DifficultyProfile.LEVELS` + JSON; sem código e sem
  condicionais.
- Guardrails permanecem explícitos e uniformes; `LevelValidator` rejeita violações
  espaciais.
- Métricas tornam overlap/free ratio/ocupação observáveis; falhas nunca são silenciadas.
- Determinismo preservado (seed por perfil, `seed_used`, deck determinístico).

**Negativas / riscos:**
- **Teto prático da dificuldade config-only ≈ L9–L10:** L10 vs L11 são quase
  indistinguíveis estruturalmente (36 cartas, 7×6, 4 layers; overlap 0.7 vs 0.7; free_ratio
  0.22 vs 0.25). Além da banda, diferenciar exige decks/tempo/recompensas — o critério 1
  (progressão perceptível) precisa de métricas de tempo médio/playtesting.
- O envelope atual limita a curva estrutural: 11+ tende a recalibrar L10 (mais overlap,
  menos free ratio), com risco de níveis percebidos como variações em vez de progressão.
- `free_ratio` é soft target (ex.: L6 mean 0.34 com cauda 0.22 fora da banda 0.25–0.45);
  pode divergir do pretendido em perfis agressivos.
- Decks grandes aumentam o tempo de partida sem aumentar dificuldade espacial — usar como
  alavanca secundária.
- Saturação de overlap (cap `OVERLAP_H_MAX = 0.60`/`OVERLAP_V_MAX = 0.55`) e free_ratio
  (mínimo por perfil) define o teto prático da dificuldade config-only.

## Critérios para mudar de envelope

Trocar de envelope (novo `BoardEnvelopeProfile`) quando:

1. A combinação máxima de overlap/free_ratio/occupancy/multiplicidade de trios/decks/
   tempo/recompensas não produzir progressão perceptível entre níveis consecutivos
   (medido por playtesting e métricas de tempo médio/solvabilidade).
2. O produto definir novos limites de UX (ex.: `min_card_px` menor, nova capacidade de
   slots na tela, novo HUD, suporte landscape dedicado).
3. Evidência de playtesting indicar que níveis dentro do envelope atual são todos
   "fáceis" ou "iguais" entre si.

Critérios de aceite para a mudança:

- Novo `BoardEnvelopeProfile` com guardrails próprios; nenhuma condicional por número de
  nível.
- Pipeline valida contra o envelope escolhido e reporta em `generation_metrics`.
- `LevelValidator` espacial passa; todos os perfis do novo envelope são solváveis.
- Testes derivados dos profiles cobrem o novo envelope sem hard-code de contagem.

## Testes derivados dos profiles (recomendação)

> **Estado atual:** já implementado — `test_difficulty_profile` itera `max_level()+3`
> (`test_profile_supports_levels_1_to_max_and_beyond`); `test_progression` deriva todos os
> ranges de `DifficultyProfile.max_level()`; `cfg_count()` retorna `max_level()`.

Substituir asserções hard-coded (contagem 10, faixas fixas) por expectativas derivadas:

1. **Contagem** — derivar de `DifficultyProfile.max_level()`; iterar `range(1, max_level()+1)`;
   assertar `DifficultyProfile.max_level() >= 1` (nunca regride a zero).
2. **Existência/validade** — iterar até `max_level() + k` (k = folga, ex.: 3); assertar
   `for_level(n) != null` para `n <= max_level()` e `== null` para `n > max_level()`.
3. **Esperanças por perfil** — derivar do config: `board_cards() == board_types.size() * count_per_type`;
   `% 3 == 0`; envelope via `fits_portrait()`; `slot_columns/rows` a partir de `occupancy_h/v`.
4. **Monotonicidade** — a tabela de progressão usa comparações relativas (>=) entre níveis
   consecutivos (já parcialmente implementado), nunca valores absolutos.
5. **Contrato de envelope** — manter `test_envelope.test_safe_config_50_loads_no_fallback_all_solvable`
   como contrato de envelope seguro, com `max_attempts` derivado do perfil.
6. **Não-regressão de dificuldade ao adicionar perfil** — assertar monotonicidade entre
   níveis consecutivos: `complexity` crescente, `free_ratio` não-crescente, `overlap`
   não-decrescente. Falha = o novo nível não avança a curva (alerta cedo de "variação de L10").

## BoardEnvelopeProfile (contrato futuro)

O critério "sem condicional por nível" é necessário, mas não suficiente para expansão
(ex.: Endless T6): hoje o pipeline valida contra guardrails globais fixos. Antes de
qualquer expansão, definir o contrato do `BoardEnvelopeProfile`:

- **Campos** — envelope por orientação, `MAX_BOARD_CARDS`, `MAX_LAYERS`, slots máximos,
  `MIN_CARD_SIZE_PX`, `MIN_CARD_SCALE`, `MIN_SAME_LAYER_DIST_RATIO`, banda de free_ratio e
  ranges de overlap por eixo.
- **Validação** — `LevelConfig.validate()` valida contra o envelope **ativo** (instância),
  não contra globais.
- **Métricas** — `generation_metrics` expõe `fits_portrait/landscape`, `min_card_px_*`,
  `scale_limited`, `same_layer_ok`, `min_exposure`.
- **Solvability** — o `SolvabilityChecker` deve escalar com boards maiores (limites de
  passos proporcionais), validado pelo probe de geração.

## Review log

- **2026-08-21 — Beacon (QA):** veredito **ACCEPTED**. As 5 correções do review foram
  incorporadas. Re-validação pós-correções de Pixel: suíte 103 testes/0 falhas;
  `regression_board_layout` OK nas 6 views (edge-clip L1/L2/L3/L5 corrigido, clip=0;
  demais `scale_limited` com warning visível, esperado); `probe_generation` OK 156–162ms;
  smokes OK; `free_ratio` endurecido (`free_ratio_ok=true` nos retornos imediatos; cauda
  fora da banda flagada, nunca insolúvel). Nada bloqueante.