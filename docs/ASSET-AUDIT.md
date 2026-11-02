# Asset Audit - Claw & Crown / Cartitas Infinity

Date: 2026-11-02
Project: `E:/Cartitas` (Godot 4.7)
Scope: every file under `assets/` (excluding `*.import` and `*.uid` sidecars, which belong to their asset).
This was a read-only audit: no asset was deleted, moved or edited.

## Summary

| Metric | Value |
| --- | --- |
| Asset files audited (no sidecars) | 179 |
| Total asset size | 155.75 MB |
| UNUSED (removed 2026-11-02) | 38 files / **16.74 MB** |
| TEST-ONLY | 0 files |
| DYNAMIC/UNSURE (kept) | 5 groups (see below) |

`MB` here means MiB (1,048,576 bytes), matching Explorer's "size on disk" style used for the per-file KB values.

## Reference corpus searched

Every asset was checked against:

- `scripts/**/*.gd` (36 files)
- `scenes/**/*.tscn` (2 files)
- `tests/**/*.gd` (50 files)
- `levels/**/*.json` (15 files)
- `project.godot`
- `export_presets.cfg`
- all other `*.gd`, `*.tscn`, `*.tres` outside `assets/` (there are **no** `.tres` files in the project)

Searches performed per file:

1. Full filename, e.g. `icon_gear.png`.
2. Filename stem, e.g. `icon_gear`.
3. Literal `res://assets/...` paths and directory constants (`KIT_DIR`, `V2_KIT_DIR`, `HUD_DIR`, `HERO_DIR`, `DEFEAT_DIR`, `LEVEL_BACKGROUND_DIR`).
4. Dynamic path formats:
   - `"res://assets/cards/card_%s.png" % type` (`scripts/ui/ui_helpers.gd:30`)
   - `"res://assets/ui/heroes/%s.png"` / `hero_%s` (`scripts/ui/hero_roster.gd:22`, `scripts/ui/mascot.gd:386`)
   - `"res://assets/ui/heroes/hero_%s.png"` defeat/expression frames (bunny moods)
   - `"%slevel_%02d%s.png"` with `""` / `"_portrait"` (`scripts/ui/ui_helpers.gd:392-400`)
   - `HUD_DIR + name + ".png"` and `STARS_PATH_FORMAT := "stars_%d"` (`scripts/ui/ui_helpers.gd:53`, `scripts/ui/level_screen.gd:140`)
   - `"res://assets/ui/icons/icon_power_%s.png" % p` (`scripts/ui/level_screen.gd:1113`)
   - locale maps: `_pt` / `_en` defeat plates, `config_2`/`Configu`, `Layer 1/2/3`, `Continuar_`, `Iniciar)`, `Opcoes_`, `sair_`
   - per-hero defeat map in `HeroRoster.DEFEAT_ART_BY_HERO` and `DEFEAT_FALLBACK_ART`
   - `.tscn` `ext_resource` entries (`assets/ui/heroes/bunny_rig/bunny_rig.tscn`)

Rules used:

- A file is **USED** if any runtime code path can resolve to it (literal or dynamic), even a fallback.
- A file referenced only by tests is **TEST-ONLY** (listed separately).
- Docs-only mentions do not count as usage for this audit.
- When a classification could not be proven, it went to **DYNAMIC/UNSURE**, never to UNUSED.

### Evidence codes

- **E-LGC** - 0 hits for the filename and for the stem in the corpus; `docs/ART-GUIDE-EN.md:198` documents the folder as archived ("Older art lives in `assets/cards/legacy/` (a folder Godot ignores)"); `assets/cards/legacy/.gdignore` makes Godot skip the whole folder.
- **E-NPC** - 0 hits for `npc_<name>.png` and stem in any non-binary file in the repo. Only Localizer/MascotLines *text* keys (`npc_bear_*`, `npc_whale_*`, `npc_duck_*`) exist; `Mascot` always passes `MascotLines.HERO_CHARACTER` (`scripts/ui/mascot.gd:145,170`), so the NPC host dialogue and images are not reached.
- **E-KIT1** - The v1 file at `assets/ui/kit/<name>` is never resolved. Every basename hit resolves under `assets/ui/kit/v2/` through `V2_KIT_DIR` (`scripts/ui/level_screen.gd:54-57`) or `V2_DIR` (`scripts/ui/main_menu.gd:12`). The v2 file exists and is the one loaded.
- **E-KIT0** - 0 hits for the filename/stem; the functionality that used it now loads v2 art (`Iniciar)`, `Opcoes_`, `sair_`, `Bar_adjust`, `Regulagem_botton`, `icon_accept_v2`, `icon_close_v2`, `slot_48`).
- **E-HUD** - 0 hits anywhere in the repo (all text files searched). The HUD gear uses `V2_KIT_DIR + "Config_Icon.png"` (`scripts/ui/level_screen.gd:58,724`).
- **E-DOC** - 0 hits in code; only `docs/ART-GUIDE-EN.md`, `docs/ART-GUIDE-PT.md` and `docs/spec.md` still mention the old PT pixel-art buttons. The current menu uses the v2 plates (`scripts/ui/main_menu.gd:14-18`), so these docs are stale for this asset.

## UNUSED

| Path | Size KB | Evidence |
| --- | ---: | --- |
| `assets/cards/legacy/card_bird.png` | 0.7 | E-LGC |
| `assets/cards/legacy/card_bird_packA.png` | 96.1 | E-LGC |
| `assets/cards/legacy/card_cat.png` | 0.8 | E-LGC |
| `assets/cards/legacy/card_dog.png` | 0.8 | E-LGC |
| `assets/cards/legacy/card_dog_packA.png` | 340.3 | E-LGC |
| `assets/cards/legacy/card_fish_packA.png` | 88.8 | E-LGC |
| `assets/cards/legacy/card_flower.png` | 0.9 | E-LGC |
| `assets/cards/legacy/card_flower_packA.png` | 110.7 | E-LGC |
| `assets/cards/legacy/card_gem.png` | 0.7 | E-LGC |
| `assets/cards/legacy/card_gem_v1.png` | 1,320.4 | E-LGC |
| `assets/cards/legacy/card_gem_v2.png` | 1,496.8 | E-LGC |
| `assets/cards/legacy/card_gem_v3.png` | 585.7 | E-LGC |
| `assets/cards/legacy/card_heart_v1.png` | 1,368.1 | E-LGC |
| `assets/cards/legacy/card_leaf_v1.png` | 1,450.5 | E-LGC |
| `assets/cards/legacy/card_moon.png` | 0.7 | E-LGC |
| `assets/cards/legacy/card_moon_packA.png` | 91.3 | E-LGC |
| `assets/cards/legacy/card_star.png` | 0.9 | E-LGC |
| `assets/cards/legacy/card_star_packA.png` | 116.3 | E-LGC |
| `assets/cards/legacy/card_sun.png` | 0.8 | E-LGC |
| `assets/cards/legacy/card_sun_packA.png` | 95.3 | E-LGC |
| `assets/ui/npc/npc_bear.png` | 1,700.4 | E-NPC |
| `assets/ui/npc/npc_duck.png` | 1,371.8 | E-NPC |
| `assets/ui/npc/npc_whale.png` | 2,172.2 | E-NPC |
| `assets/ui/branding/btn_menu_jogar.png` | 0.7 | E-DOC |
| `assets/ui/branding/btn_menu_opcoes.png` | 0.7 | E-DOC |
| `assets/ui/branding/btn_menu_sair.png` | 0.6 | E-DOC |
| `assets/ui/hud/icon_gear.png` | 209.0 | E-HUD |
| `assets/ui/kit/bar_zone.png` | 628.7 | E-KIT1 (v2 `kit/v2/bar_zone.png` is the used one, `level_screen.gd:56`) |
| `assets/ui/kit/card_available_frame.png` | 1,375.3 | E-KIT1 (v2 counterpart used, `level_screen.gd:57`) |
| `assets/ui/kit/panel_board_frame.png` | 552.8 | E-KIT1 (v2 counterpart used, `level_screen.gd:55`; v1 `panel_board_frame_portrait.png` is a different, used file) |
| `assets/ui/kit/panel_menu_board.png` | 1,959.4 | E-KIT1 (v2 counterpart loaded via `V2_DIR`, `main_menu.gd:12,34`) |
| `assets/ui/kit/btn_options_pt.png` | 0.7 | E-KIT0 |
| `assets/ui/kit/btn_play_pt.png` | 0.7 | E-KIT0 |
| `assets/ui/kit/btn_quit_pt.png` | 0.6 | E-KIT0 |
| `assets/ui/kit/icon_close_red.png` | 0.3 | E-KIT0 (help uses `icon_close_green`; dialogs use `icon_close_v2`) |
| `assets/ui/kit/slider_bar.png` | 0.2 | E-KIT0 (`VolumeRow` uses `v2/Bar_adjust.png`, `volume_row.gd:15`) |
| `assets/ui/kit/slider_handle.png` | 0.2 | E-KIT0 (`VolumeRow` uses `v2/Regulagem_botton.png`, `volume_row.gd:16`) |
| `assets/ui/kit/slot_64.png` | 0.4 | E-KIT0 (only `slot_48` is used, `level_screen.gd:1536`) |

Notes:

- `assets/cards/legacy/.gdignore` (0 KB) is not an asset; it only marks the folder as ignored. If the folder is removed, this file goes with it (0 bytes saved). Because the folder is ignored by Godot, deleting the legacy PNGs recovers repository/VCS space but does **not** change the exported PCK.
- The v1 kit files, NPC images, `icon_gear.png` and the branding buttons are imported resources (no `.gdignore`), so they are candidates for real PCK/export size reduction.
- The Localizer/MascotLines `npc_bear_*`, `npc_whale_*`, `npc_duck_*` strings are *text* and are not part of this asset list. Do not delete them based on this audit.

## TEST-ONLY

None.

Every asset that tests mention is also reached by production code:

- `tests/test_audio.gd` -> tracks/SFX from `scripts/core/audio_manager.gd`.
- `tests/test_backgrounds.gd`, `tests/smoke_stars.gd` -> dynamic paths used by `UiHelpers`.
- `tests/smoke_main_menu.gd`, `tests/smoke_settings_overlay.gd`, `tests/test_defeat_screen.gd` -> v2 kit, which production loads.
- `tests/test_mascot_heroes.gd`, `tests/smoke_defeat.gd`, `tests/smoke_bunny_rig.gd` -> hero/defeat/rig assets used by `Mascot`/`HeroRoster`.

## DYNAMIC/UNSURE

These are deliberately **not** in the UNUSED table.

| Path | Why |
| --- | --- |
| `assets/ui/background_castle.png`, `assets/ui/background_castle_portrait.png` | Fallback-only for L8+ (`UiHelpers.background_path`, `ui_helpers.gd:105-106,401-406`). Currently shadowed because `assets/ui/backgrounds/level_07..15` exist, so unreachable for the shipped campaign; keep unless the per-level backdrops are removed. Counted USED (not recoverable in this audit). |
| `assets/ui/kit/panel_powers.png` | Fallback panel only when `assets/ui/kit/panel_powers_board.png` is missing (`level_screen.gd:1065-1069`). Keep while the painted board exists. |
| `assets/ui/kit/icon_accept.png` | Fallback slider handle only when `assets/ui/kit/v2/Regulagem_botton.png` is missing (`volume_row.gd:95-98`). Keep as fallback. |
| `assets/ui/heroes/hero_bunny.png` | Conditional: campaign L8 uses expression frames + `bunny_rig.tscn`, but Endless rounds that draw bunny (round 8, 16, ...) load `hero_bunny` through `hero_%s` (`mascot.gd:380-398`, `hero_roster.gd:8`). Used. |
| `assets/cards/card_*.png` (all 14 types) | Dynamic `card_%s.png`; all 14 `CardTypeRegistry.TYPES` resolve (`cat, mouse, boar, owl, wolf, duck, frog, whale, leaf, heart, gem, cat_mage, rhino, sacer`). Used. |
| `assets/ui/heroes/hero_*.png` (15 files) | Dynamic `hero_%s.png` from `HeroRoster.HEROES`, `CAMPAIGN_OVERRIDES`, `FALLBACK_HERO` and `BUNNY_FRAMES`; every value resolves. Used. |
| `assets/ui/heroes/bunny_rig/Layer 2,3,4,5,6,7,8,10,12,15.png`, `body.png`, `Cross.png` | All are `ext_resource` entries in `bunny_rig.tscn`, loaded by `Mascot.RIG_SCENE` (`mascot.gd:27,417`). Used. |
| `assets/ui/backgrounds/level_07..15.png` and `level_07..15_portrait.png` (18 files) | Dynamic `level_%02d` + `_portrait`; all resolve for levels 7-15 and Endless 999. Used. |
| `assets/ui/hud/stars_1.png`, `stars_2.png`, `stars_3.png`, `icon_stopwatch.png` | `hud_texture("stars_%d")` / `hud_texture("icon_stopwatch")` (`level_screen.gd:140,809,2925,3219`). Used. |
| `assets/ui/icons/icon_power_hold.png`, `icon_power_undo.png`, `icon_power_refresh.png` | Dynamic `icon_power_%s.png` over `PowerManager.POWERS = ["hold", "undo", "refresh"]` (`level_screen.gd:1113`). Used. |
| `assets/ui/defeat/defeat_archer.png`, `defeat_bunny.png`, `defeat_cat.png`, `defeat_sacer.png` plus `defeat_title_{pt,en}.png`, `defeat_retry_{pt,en}.png`, `defeat_quit_{pt,en}.png` | Per-hero map `HeroRoster.DEFEAT_ART_BY_HERO` + fallback, and locale maps in `level_screen.gd:159-162`. Used. |
| `assets/ui/kit/v2/Configu.png`, `config_2.png`, `Layer 1.png`, `Layer 2.png`, `Layer 3.png`, `Continuar_.png`, `Iniciar).png`, `Opcoes_.png`, `sair_.png` | Locale-keyed maps: settings title/options/menu/end-panel plates (`level_screen.gd:60,152-154,1797`; `main_menu.gd:14-18,57-58,65-67,870`). Used. |

## Total recoverable

**16.74 MB** (17,552,640 bytes) by removing the 38 UNUSED files.

Breakdown:

- `assets/cards/legacy/`: 20 files, 7.00 MB (ignored by Godot; saves repo only).
- `assets/ui/npc/`: 3 files, 5.12 MB.
- v1 `assets/ui/kit/` duplicates and leftovers: 11 files, 4.41 MB.
- `assets/ui/hud/icon_gear.png`: 1 file, 0.20 MB.
- `assets/ui/branding/btn_menu_*.png`: 3 files, ~0.002 MB.

## Removed on 2026-11-02

Phase C1 executed this cleanup after orchestrator verification. Exactly the 38 files listed in the UNUSED table above were deleted (16.74 MB / 17,552,640 bytes), together with their `.import` sidecars. There were no `.uid` sidecars for these files. The `assets/cards/legacy/` folder was removed whole, including its `.gdignore`.

Groups removed:

- `assets/cards/legacy/` - 20 PNGs (7.00 MB).
- `assets/ui/npc/` - `npc_bear.png`, `npc_duck.png`, `npc_whale.png` (5.12 MB).
- `assets/ui/branding/` - `btn_menu_jogar.png`, `btn_menu_opcoes.png`, `btn_menu_sair.png` (~0.002 MB).
- `assets/ui/hud/icon_gear.png` (0.20 MB).
- v1 `assets/ui/kit/` - `bar_zone.png`, `card_available_frame.png`, `panel_board_frame.png`, `panel_menu_board.png`, `btn_options_pt.png`, `btn_play_pt.png`, `btn_quit_pt.png`, `icon_close_red.png`, `slider_bar.png`, `slider_handle.png`, `slot_64.png` (4.41 MB).

Not removed: everything in `assets/ui/kit/v2/`, the DYNAMIC/UNSURE items (castle backgrounds, `kit/panel_powers.png`, `kit/icon_accept.png`, `hero_bunny.png`), and the NPC dialogue text in `scripts/ui/localizer.gd` / `scripts/ui/mascot_lines.gd`.

Validation after removal:

- New suite `tests/test_asset_references.gd` (4 tests, 0 failed) checks every concrete `res://assets/...` literal in `scripts/**/*.gd` and `scenes/**/*.tscn` with `ResourceLoader.exists()`, plus the dynamic card/hero/star/power families. It was run standalone and is **not** registered in `tests/run_tests.gd`.
- `Godot_v4.7-stable_win64_console.exe --path E:/Cartitas --headless --import` completed with no missing asset dependency errors. The only error line is the pre-existing addon loader message `No loader found for resource: res://addons/godot_mcp/Editor/GodotMcpPlugin.cs`, unrelated to the assets.
- `docs/ART-GUIDE-EN.md`, `docs/ART-GUIDE-PT.md` and `docs/spec.md` were updated to point at the v2 art and to mark the removed files.
