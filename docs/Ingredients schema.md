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
    "burn_time": 3.0,
    "cooked_label": "Cooked Name",
    "cooked_icon": "icon_name"
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
| `done_grace` | float | yes | Seconds in DONE state before BURNING starts. Players have this window to collect |
| `burn_time` | float | yes | Seconds in BURNING before BURNT state. After BURNT, must drag to trash |
| `cooked_label` | string | recommended | Display name after cook. Shown in OrderBubble and assembly rows |
| `cooked_icon` | string | optional | Filename suffix for the cooked sprite. Used by CookedItem when count > 0 |

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
- **Empty bowl / cooked slot** falls back to `assets/bowls/empty_bowl.png`

Missing assets render as the empty placeholder — no error.

## Add a new ingredient

1. Pick a unique `ingredient_id` (snake_case).
2. Decide the path:
   - **Raw only** → `needs_prep: false`, `needs_cook: false`. Goes straight from button to assembly.
   - **Prep only** (vegetables) → `needs_prep: true`, `needs_cook: false`. Chop → ReadyBowl → assembly.
   - **Cook only** (patty, bun) → `needs_prep: false`, `needs_cook: true`, set `appliance` + cook timings.
   - **Prep + cook** (sauteed onion) → both true, set all timings.
3. Add the matching sprites under `assets/ingredients/` (optional but recommended).
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
  "burn_time": 3.0,
  "cooked_label": "Crispy Bacon"
}
```

## Capacity rules

- ReadyBowl caps at 3 (see `CONTAINER_CAPACITY` in [Main.gd](../scripts/Main.gd)). A 4th chop is held on the cutting board in `READY` state until the bowl has space or you trash it.
- CookedItem caps at 3 too. A 4th cook is held on the pan (cooking slot stays in `DONE`) and will burn if you don't free space.

## TODO

- **Single ingredient with optional cook**: today, `onion_raw` and `onion_sauteed` are separate entries. A future schema could let one ingredient have multiple `state` variants and let recipes pick which.
