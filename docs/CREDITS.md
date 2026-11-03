# Credits

## Card juice (Phase I) — MIT-licensed sources

- **"2D Perspective" shader by Hei** — https://godotshaders.com/shader/2d-perspective/ (MIT).
  Base of `scripts/ui/card_juice.gdshader` (the perspective vertex/fragment pair, with the `rect_size`
  uniform fix for a `TextureRect` whose size differs from its texture).
- **MrEliptik/godot_ui_components, scene `balatro`** — https://github.com/MrEliptik/godot_ui_components
  (MIT, © 2024 Victor Meunier). Reference for the tilt-from-pointer, hover scale and tween-back-to-rest feel
  implemented in `scripts/ui/level_screen.gd`.
- Video reference: "I recreated Balatro's effects in Godot" — https://www.youtube.com/watch?v=Alwy-TH0WzE

The inner-window mask (shine/foil at 30% on the card art, 100% on the metal frame) is ours, not from
those sources: `inner_rect` / `inner_strength` / `inner_feather` in the shader, values measured on the
baked frame of `assets/cards/card_*.png`.
