# Recipes schema

File: `data/recipes.json`

A flat object keyed by `recipe_id`. Each recipe defines a dish a customer can order and what the player must assemble to serve it.

## Shape

```json
{
  "recipe_id": {
    "label": "Display Name",
    "color": "#FFC107",
    "components": [
      { "ingredient": "ingredient_id", "state": "prepped" | "cooked" }
    ],
    "timer": 60.0,
    "base_coins": 20
  }
}
```

## Fields

| Field | Type | Required | Notes |
|---|---|---|---|
| `label` | string | yes | Shown to player in order bubble / OrderCard |
| `color` | string | optional | Hex color used to tint OrderCard background and bubble accent. Default `#FFC107`. See [[Index#Conventions]] |
| `components` | array of `{ingredient, state}` | yes | The ingredients the player must drop into the assembly to serve. Order doesn't matter. Each entry must be unique in the current build (one of each — duplicates not supported yet, see [[#Known limits]]) |
| `timer` | float | yes | Seconds the customer waits. Drives the timer bar under the customer |
| `base_coins` | int | yes | Max coins on perfect serve. Reduced if served late: 100% if >66% time left, 60% at 33–66%, 30% under 33%, 0% expired |

### `components[].ingredient`
String matching a key in [[Ingredients schema]]. Must be a real ingredient ID.

### `components[].state`
- `"prepped"` — the player must drop the prepped (chopped/sliced) version. Requires `needs_prep: true` on the ingredient.
- `"cooked"` — the player must drop the cooked version. Requires `needs_cook: true` on the ingredient.

## Add a new recipe

1. Pick a unique `recipe_id` (snake_case).
2. List the components — each `ingredient_id` must already exist in [[Ingredients schema]].
3. Set `timer` (60s is comfortable for ~4-ingredient recipes).
4. Set `base_coins` (rough: 5 per ingredient or per cook step).
5. Add the `recipe_id` to a level's `recipes` array in [[Levels schema]] so it can spawn.

Example — salad bowl that reuses existing prep ingredients:

```json
"salad_bowl": {
  "label": "Garden Salad",
  "color": "#7CB342",
  "components": [
    { "ingredient": "lettuce", "state": "prepped" },
    { "ingredient": "tomato", "state": "prepped" }
  ],
  "timer": 35.0,
  "base_coins": 8
}
```

## Known limits

- **No duplicates of same component**: assembly currently caps at 1 of each `(ingredient, state)` pair. A recipe like 2× patty + 1× bun will fail the match check. Tracked under [[Index#TODO]].
- **No alternates**: you can't express "either lettuce OR coleslaw". Make two separate recipes if needed.
- **Order doesn't matter** for serving — the match is a multiset comparison.

## How it's loaded

- `DataLoader.recipes` is a Dictionary populated at game start from this file.
- `DataLoader.get_recipe(id)` returns the dict or `{}` if missing.
- `Main.gd:_spawn_order` randomly picks from a level's `recipes` array.
- `Main.gd:_assembly_matches_recipe(recipe)` does the multiset check on serve.
