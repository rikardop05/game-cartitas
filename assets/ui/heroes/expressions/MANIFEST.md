# Hero expression sets (from Miro)

Source: Miro board `uXjVEUSSdkE=`, section "Expressions" (downloaded 2026-11-02, original-resolution PNGs).
Layout: `<hero_id>/<expression>.png`. Expressions follow the board columns left to right:
`thinking` (Normal Thinking), `sequence` (Sequence), `bad_choice` (Bad Choice), `defeat` (Defeat).
The column position on the board decides the expression. Some Miro filenames disagree with it
(R2's column-1 image is named `4_Defeat.png`, R7's column-3 image is named `Layer 15.png` and its
column-4 image `3_Bad_Choice.png`). The pictures match their columns, so the filenames were ignored.

These files have not been imported into Godot yet: there are no `.import` files.

Hero ids follow the game's files (`assets/ui/heroes/hero_<id>.png`, `HeroRoster`). **Note:** in the game,
`sacer` is the blonde cat priestess (see `hero_sacer.png` and `defeat_sacer.png`) and `cat_mage` is the pink-haired
cat girl with red scarf and daggers (see `hero_cat_mage.png`). The folders follow the game files.

Sizes are W x H in pixels. Alpha bbox = (left, top, right, bottom) of pixels with alpha > 8. The plain
non-zero-alpha bbox covers the whole canvas for every file except bunny/thinking (33,0,1010,1536) and bunny/bad_choice (0,0,1010,1528).

| Panel (board) | hero_id | thinking | sequence | bad_choice | defeat |
|---|---|---|---|---|---|
| R1 (x -9383, y ~6550) | bunny | 1024x1536, bbox 48,9,989,1527 | 1024x1536, 14,5,1021,1522 | 1024x1536, 38,6,1002,1525 | 1024x1536, 5,9,1020,1516 |
| R2 (y ~8770) | sacer | 395x907, 0,1,394,906 | 394x905, 0,1,394,904 | 373x905, 0,0,371,904 | 398x900, 0,0,397,899 |
| R3 (y ~11030) | cat | 387x618, 1,5,365,616 | 382x622, 0,6,366,616 | 377x619, 9,6,375,617 | 405x624, 14,6,403,618 |
| R4 (y ~13145) | wolf_ranger | 363x640, 9,3,351,639 | 343x640, 4,3,341,639 | 362x640, 2,2,359,639 | 390x640, 5,3,388,639 |
| R5 (y ~15460) | cat_mage | 358x614, 9,4,356,610 | 461x798, 0,1,461,797 | 328x610, 0,4,319,606 | 385x613, 0,3,382,608 |
| R6 (y ~17586) | frog | 466x627, 2,11,460,623 | 558x670, 8,2,554,666 | 491x665, 3,26,488,661 | 515x615, 5,2,513,611 |
| R7 (y ~19853, panel y 18924) | rhino | 533x708, 9,5,513,700 | 580x708, 15,6,544,700 | 532x708, 25,6,529,701 | 532x707, 25,9,504,699 |
| L1 (x -17425, y ~6573) | wolf_knight | 536x724, 3,19,470,713 | 639x724, 16,9,600,713 | 608x721, 59,16,545,710 | 519x724, 24,38,510,713 |
| L2 (y ~8727) | owl | 355x588, 6,2,347,581 | 381x598, 11,10,379,588 | 372x590, 11,2,370,580 | 414x585, 5,3,414,581 |
| L3 (y ~10908) | mouse | 402x630, 6,49,393,590 | 376x540, 17,0,376,540 | 404x623, 27,41,376,585 | 424x640, 10,58,402,601 |
| L4 (y ~13055) | knight | 335x628, 6,9,321,625 | 411x623, 69,4,400,620 | 397x629, 63,10,380,625 | 396x623, 45,4,372,619 |
| L5 (y ~15333) | boar | 500x693, 9,3,486,686 | 584x715, 66,5,567,695 | 524x717, 7,11,487,699 | 585x724, 35,21,573,704 |
| L6 (y ~17581) | whale (NPC whale captain) | 483x700, 3,9,477,698 | 601x715, 27,2,599,704 | 508x690, 7,2,489,689 | 525x700, 5,2,520,698 |
| L7 (y ~19955, panel y 18924) | duck (NPC pelican detective) | 473x723, 4,10,451,713 | 657x713, 83,2,586,703 | 528x714, 13,2,472,704 | 535x700, 40,2,522,698 |

All files are RGBA PNGs. The bunny files are 1024x1536 with max alpha 254 and a faint low-alpha haze
around the figure. All other files have alpha up to 255.

## Notes per set
- **bunny (R1)**: this is the art already in the game (`hero_bunny_{thinking,sequence,bad_choice,defeat}.png`).
  The in-game files are tighter crops of these 1024x1536 board originals (about 940-1012 x 1506-1518). The existing files were not changed.
- **R7 / L7** (rhino, duck) are in the panels at y 18924, which were not in the original id list. Image ids:
  R7 = 3458764689178042286 / ...287 / ...284 / ...289. L7 = 3458764689173053683 / ...684 / ...685 / ...682.
- **whale** and **duck** are NPC/board types (`difficulty_profile.gd` board_types), not playable heroes in `HeroRoster`.

## Extras (not copied into the project)
Kept in the scratch dir only: `miro_expr/raw/X_extra1.png`, `X_extra2.png`.
- 3458764689190441340 (`Victory.png`, 1420x516): "VICTORY" title banner on a stone plaque with a blue/gold shield crest.
- 3458764689190441342 (`Vitoria.png`, 1421x513): the same banner with the Portuguese text "VITORIA".

## Unidentified panels
None. Every panel in the section matched a game id.

## Heroes without an expression set
- `menu_wolf`, the `HeroRoster` fallback/default hero. It has no panel on the board.
All 9 `HEROES` (cat, wolf_ranger, boar, mouse, owl, frog, knight, bunny, wolf_knight) and the campaign
overrides (cat_mage, rhino, sacer) have a full 4-expression set.
