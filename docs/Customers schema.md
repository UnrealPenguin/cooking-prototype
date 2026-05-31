# Customers schema

File: `data/customers.json`

A flat object keyed by `animal_id`. Each entry defines an animal type — its display name, all sprite variations, which recipes it can order, and how frequently it appears relative to other compatible animals.

## Shape

```json
{
  "animal_id": {
    "label": "Display Name",
    "frequency": 1,
    "sprites": ["filename1.png", "filename2.png"],
    "recipes": ["recipe_id_1", "recipe_id_2"]
  }
}
```

## Fields

| Field | Type | Required | Notes |
|---|---|---|---|
| `label` | string | recommended | Display name (currently unused in UI; reserved for tooltips / debug) |
| `frequency` | int | optional | Weight in the weighted random pick. Default `1`. See [[#Weighting]] |
| `sprites` | string[] | yes | Asset filenames inside `assets/customers/`. At least one. A random sprite is picked per spawn |
| `recipes` | string[] | yes | Recipe IDs (see [[Recipes schema]]) this animal is willing to order. An animal only spawns for a recipe that's in this list |

### `sprites`
- Filenames only (e.g. `"cat_with_flower.png"`), no `res://` prefix or folder path — paths are resolved against `assets/customers/` at runtime.
- A spawned customer gets one uniformly-random sprite from the list. Add more entries for visual variety.
- The PNG must exist; missing files mean the customer will render blank.

### `recipes`
- Each entry must be a key in [[Recipes schema]].
- An animal that doesn't list a recipe will **never** spawn as the customer for that recipe.
- If **no** animal lists a given recipe, that order is **skipped** at spawn time (with a `push_warning`). This is intentional: it's a data inconsistency you need to fix.

## Weighting

The spawn picker is a two-stage filter — recipe first, then customers compatible with it.

### Stage 1 — pick a recipe

In [Main.gd:_spawn_order](../scripts/Main.gd):

```gdscript
var pool: Array = GameManager.current_level.get("recipes", [])
var recipe_id: String = pool[randi() % pool.size()]
```

Uniform random over the level's `recipes` array. No weighting at this stage. See [[Levels schema]] for what controls this pool.

### Stage 2 — pick a customer compatible with that recipe

In [Main.gd:_pick_customer_sprite_for_recipe](../scripts/Main.gd):

```gdscript
# 1. Collect candidates + weights
for animal_id in DataLoader.customers:
    var animal = DataLoader.customers[animal_id]
    if not (recipe_id in animal.recipes):
        continue            # skip animals that can't order this dish
    if animal.sprites.is_empty():
        continue            # skip animals with no sprite to render
    candidates.append(animal)
    weights.append(animal.frequency)

# 2. Weighted random
var total = sum(weights)
var roll = randi() % total
# subtract weights in order until roll goes negative → that's the pick

# 3. Pick a sprite within the chosen animal
var sprite_filename = picked.sprites[randi() % picked.sprites.size()]
return "res://assets/customers/%s" % sprite_filename
```

So `frequency` is **relative**, not absolute. If three animals can order a recipe with weights `1`, `1`, `3`, the third appears `3 / 5 = 60%` of the time.

### Worked example

With the current `customers.json`, the candidates per recipe are:

| recipe_id | candidates | weights |
|---|---|---|
| `basic_burger` | cat | 1 |
| `classic_burger` | cat, corgi, raccoon | 1, 1, 1 |
| `steak_plate` | corgi, fox | 1, 1 |
| `stir_fry` | fox, raccoon | 1, 1 |

For `classic_burger`: `total = 3`, `roll ∈ {0, 1, 2}` → 33% each.

If you bumped `cat.frequency = 3`, the row becomes:

| recipe_id | candidates | weights | distribution |
|---|---|---|---|
| `classic_burger` | cat, corgi, raccoon | 3, 1, 1 | cat 60%, corgi 20%, raccoon 20% |

### Tips for level difficulty

- Bump `frequency` on animals that order **harder** dishes to make a level feel tougher.
- Bump `frequency` on animals that order **easier** dishes (or that you've added more sprite variations for) early on, so the player sees variety without facing the hardest customers immediately.

### Sprite no-repeat rule

After the animal is chosen, the picker excludes that animal's **last-used sprite** when picking the new one:

```gdscript
var last_sprite = _last_sprite_by_animal.get(picked_id, "")
var pool = sprites
if sprites.size() > 1 and last_sprite != "":
    pool = sprites.filter(func(s): return s != last_sprite)
var filename = pool[randi() % pool.size()]
_last_sprite_by_animal[picked_id] = filename
```

Behavior:

- **2+ sprites for an animal** → the same sprite can't appear twice in a row for that animal. Other animals are unaffected.
- **1 sprite for an animal** → the rule is bypassed; the only sprite repeats. (You can't enforce no-repeat with only 1 option.)
- **Tracked per-animal**: cat's last sprite doesn't affect raccoon's pick.
- The dict (`_last_sprite_by_animal`) persists across orders within a session — it isn't reset on level start. Harmless in practice.

So the minimum to make this rule meaningful for an animal is **2 sprite variations**. Adding more (3+) makes the result feel less alternating.

### Skip case

If no animal in `customers.json` lists the chosen recipe, the picker returns `""`. In `_spawn_order`:

```gdscript
if sprite_path == "":
    push_warning("No customer can order recipe '%s' …")
    return   # no card, no customer, _orders_spawned not incremented
```

Result: the order is silently skipped — no card, no customer, and the level's `total_orders` budget isn't consumed. You'll see the warning in Godot's Output panel.

## Add a new customer

1. Pick a unique `animal_id` (snake_case).
2. Drop the sprite PNGs into `assets/customers/` (any aspect ratio; size 174×174 matches existing).
3. Pick the recipes this animal will order — every entry must exist in [[Recipes schema]] and be reachable from at least one level's `recipes` array (otherwise the animal will never spawn).
4. Set `frequency` if you want them more / less common than others (default 1).

Example — squirrel that only orders salads, twice as common as other compatible animals:

```json
"squirrel": {
  "label": "Squirrel",
  "frequency": 2,
  "sprites": ["squirrel_default.png", "squirrel_acorn.png"],
  "recipes": ["salad_bowl"]
}
```

## Add a new sprite variation to an existing animal

Just append the filename to the animal's `sprites` array — no code change needed. The picker will start including it next spawn.

```json
"cat": {
  "sprites": ["cat.png", "cat_with_flower.png", "cat_chef_hat.png"]
}
```

## How it's loaded

- `DataLoader.customers` is a Dictionary populated at game start from this file.
- `DataLoader.get_customer(id)` returns the dict or `{}` if missing.
- `Main.gd:_pick_customer_sprite_for_recipe(recipe_id)` does the weighted pick and returns a `res://...` sprite path (or `""` if no animal qualifies).
- `Main.gd:_spawn_order` calls the picker first; if it returns `""`, the order is **skipped entirely** — no card, no customer, no order-budget consumption.
- `Customer.gd:setup(sprite_path)` loads the chosen sprite into the customer's `TextureRect`.

## Known limits

- **Sprite resolution is flat** — there's no per-recipe sprite (e.g. a hungrier-looking cat when ordering a steak). Workaround: split into separate animal IDs with overlapping `recipes`.
- **Level-scoped frequencies are global** — `frequency` applies everywhere. If you want per-level weighting, you'd need a `customer_weights` override on the level entry.
- **No customer state across spawns** — there's no memory; the same sprite can appear back-to-back.

## Related

- [[Recipes schema]] — what `recipes` references.
- [[Levels schema]] — the `recipes` array on a level filters which orders spawn, which in turn filters which animals can appear in that shift.
