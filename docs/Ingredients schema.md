# Ingredients schema

File: `data/ingredients.json`

A flat object keyed by `ingredient_id`. Each entry defines whether the ingredient needs prep (chopping), cooking, both, or neither, plus the timing knobs for each.

## Shape

```json
{
  "ingredient_id": {
    "label": "Display Name",
    "color": "#RRGGBB",
    "icon": "icon_name",
    "needs_prep": true,
    "prep_taps": 4,
    "prep_verb": "Chop",
    "prepped_label": "Chopped Name",
    "chopped_icon": "icon_name",
    "needs_cook": true,
    "appliance": "appliance_id",
    "cook_time": 6.0,
    "done_grace": 3.0,
    "cooked_label": "Cooked Name",
    "cooked_icon": "icon_name",
    "burnt_icon": "icon_name"
  }
}
```

## Fields

### Common

| Field | Type | Required | Notes |
|---|---|---|---|
| `label` | string | yes | Base display name (raw / not yet prepped or cooked) |
| `color` | string | optional | Hex color used by ReadyBowl swatches and other UI tints. Default `#CCCCCC` |
| `icon` | string | optional | Override the asset filename used for the raw icon. Defaults to the `ingredient_id`. See [[#Icon resolution]] |

### Prep fields (when `needs_prep: true`)

| Field | Type | Required | Notes |
|---|---|---|---|
| `needs_prep` | bool | yes | If false, raw goes straight to appliance or assembly |
| `prep_taps` | int | yes | Number of taps on the cutting board to finish chopping. 3–5 typical |
| `prep_verb` | string | optional | Shown on the cutting board: e.g. `"Chop"`, `"Slice"`. Default `"Chop"` |
| `prepped_label` | string | recommended | Display name after prep. Shown in OrderBubble and assembly rows |
| `chopped_icon` | string | optional | Filename suffix for the prepped sprite. Used by ReadyBowl when count > 0. Defaults to `icon` then `ingredient_id` |

### Cook fields (when `needs_cook: true`)

| Field | Type | Required | Notes |
|---|---|---|---|
| `needs_cook` | bool | yes | If false, this ingredient stops at "prepped" |
| `appliance` | string | yes | Must match an appliance_id in [[Appliances schema]]. The raw button only goes to that appliance |
| `cook_time` | float | yes | Seconds in COOKING state before reaching DONE |
| `done_grace` | float | yes | Seconds the item is READY/collectable before it burns. The cooked sprite gradually chars over this window as a warning, then flips to BURNT. Players have this window to collect |
| `cooked_label` | string | recommended | Display name after cook. Shown in OrderBubble and assembly rows |
| `cooked_icon` | string | optional | Filename suffix for the cooked sprite. Used by CookedItem when count > 0 |
| `burnt_icon` | string | optional | Filename suffix for the **required** burnt sprite (see [[#Cook states & burnt sprite]]). Defaults to `icon` then `ingredient_id` |

## Cook states & burnt sprite

Cooking runs through a simple state machine in [CookingSlot.gd](../scripts/CookingSlot.gd):

```
COOKING ──(cook_time)──▶ DONE ──(done_grace)──▶ BURNT ──(drag to trash)──▶ CLEANING ──▶ EMPTY
   │                       │                       │
 raw sprite          cooked sprite,           burnt sprite +
                     chars as warning          rising smoke
```

There is **no separate "burning" phase** — if the player doesn't collect the item during the `done_grace` window, it burns directly. (The old `burn_time` field is gone; remove it if you see it in old data.)

### Burnt sprite is mandatory

Every `needs_cook: true` ingredient **must** ship a burnt sprite:

```
assets/ingredients/{burnt_icon | icon | ingredient_id}_burnt.png
```

If it's missing, the game asserts (hard error) the moment the item is placed — this keeps the burnt look hand-drawn and consistent rather than relying on a procedural filter. Don't forget to let Godot import the PNG after adding it.

### Visual feedback (code-tunable, not data)

These are tuned in [CookingSlot.gd](../scripts/CookingSlot.gd), not in JSON:

- **Char warning** — during DONE, a darken/desaturate shader ([burn_darken.gdshader](../assets/shaders/burn_darken.gdshader)) ramps `0 → READY_BURN_MAX` across `done_grace`, so the cooked sprite visibly chars as it approaches burning.
- **Smoke** — once BURNT, a `CPUParticles2D` puff rises off the item. Built in `_setup_smoke()`; it's optional and silently skipped if `assets/effects/smoke.png` is absent. Tune density/size/colour there (`amount`, `lifetime`, `scale_amount_*`, the `color_ramp` gradient — first color = darkest, fresh soot).

## State variants

Some ingredients exist as **separate entries** for different recipe contexts:

- `onion_raw` (chop only, no cook) — used in Stir Fry
- `onion_sauteed` (chop + cook on stove) — used in Steak Plate

This is how the prototype currently models "same ingredient, different recipe paths." If you want one onion that's optionally cooked, you'd need to extend the schema (see [[#TODO]]).

## Icon resolution

Sprite paths are computed at runtime:

- **Raw** (RawIngredientButton): `assets/ingredients/{icon | ingredient_id}.png`
- **Prepped** (ReadyBowl, full state): tries `{chopped_icon | icon | ingredient_id}_chopped.png` then `{...}_prepped.png`
- **Cooked** (CookedItem, full state): tries `{cooked_icon | icon | ingredient_id}_cooked.png` then `{...}_toasted.png` then `{...}.png`
- **Burnt** (CookingSlot, BURNT state): `{burnt_icon | icon | ingredient_id}_burnt.png` — **required** for cookable items (see [[#Cook states & burnt sprite]])
- **Empty bowl / cooked slot** falls back to `assets/bowls/empty_bowl.png`

Missing assets render as the empty placeholder — no error. **Exception:** a cookable ingredient with no burnt sprite is a hard error, not a silent fallback.

## Add a new ingredient

1. Pick a unique `ingredient_id` (snake_case).
2. Decide the path:
   - **Raw only** → `needs_prep: false`, `needs_cook: false`. Goes straight from button to assembly.
   - **Prep only** (vegetables) → `needs_prep: true`, `needs_cook: false`. Chop → ReadyBowl → assembly.
   - **Cook only** (patty, bun) → `needs_prep: false`, `needs_cook: true`, set `appliance` + cook timings.
   - **Prep + cook** (sauteed onion) → both true, set all timings.
3. Add the matching sprites under `assets/ingredients/` (optional but recommended) — **except** a `_burnt.png` is **required** for any `needs_cook: true` ingredient (see [[#Cook states & burnt sprite]]).
4. Add the ingredient ID to a level's `prep_ingredients` (if prep-only or prep+cook) — otherwise it won't appear in that level.
5. Reference it from a recipe in [[Recipes schema]].

Example — bacon strip (cook only, on a new "fryer" appliance):

```json
"bacon": {
  "label": "Bacon",
  "color": "#A1473A",
  "needs_prep": false,
  "needs_cook": true,
  "appliance": "fryer",
  "cook_time": 5.0,
  "done_grace": 2.5,
  "cooked_label": "Crispy Bacon"
}
```

Then add the required burnt sprite `assets/ingredients/bacon_burnt.png` (and `bacon_raw.png` / `bacon_cooked.png` if you have them), and let Godot import them.

## Capacity rules

- ReadyBowl caps at 3 (see `CONTAINER_CAPACITY` in [Main.gd](../scripts/Main.gd)). A 4th chop is held on the cutting board in `READY` state until the bowl has space or you trash it.
- CookedItem caps at 3 too. A 4th cook is held on the pan (cooking slot stays in `DONE`) and will burn if you don't free space.

## TODO

- **Single ingredient with optional cook**: today, `onion_raw` and `onion_sauteed` are separate entries. A future schema could let one ingredient have multiple `state` variants and let recipes pick which.
