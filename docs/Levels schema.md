# Levels schema

File: `data/levels.json`

A JSON **array** (not object) — order in the array is the play order. Each entry defines a "shift": which ingredients/recipes/appliances are available and the spawning/timing parameters.

## Shape

```json
[
  {
    "id": 1,
    "name": "Shift 1 - First Day",
    "screen_mode": "single",
    "prep_ingredients": ["lettuce", "tomato"],
    "appliances": ["grill", "toaster"],
    "recipes": ["classic_burger"],
    "max_simultaneous_orders": 1,
    "total_orders": 3,
    "spawn_interval": 6.0,
    "initial_delay": 1.5,
    "prep_time": 5.0,
    "time_target_seconds": 20,
    "show_swipe_tutorial": true
  }
]
```

## Fields

### Identity

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | int | yes | Shown on the stage select. Should be unique and ascending |
| `name` | string | yes | Display name (e.g. `"Shift 2 - Getting Started"`) |

### Layout

| Field | Type | Required | Notes |
|---|---|---|---|
| `screen_mode` | string | optional | Legacy field from the swipe-page system. Currently ignored — was `"single"` or `"dual"`. Safe to leave or remove |
| `show_swipe_tutorial` | bool | optional | Legacy — used to trigger the swipe tutorial overlay. The Tutorial node still exists; flag is read but the swipe UI was removed |

### Content

| Field | Type | Required | Notes |
|---|---|---|---|
| `prep_ingredients` | string[] | yes | Ingredient IDs (see [[Ingredients schema]]) shown in the prep crates. Capped at `MAX_PREP_SLOTS = 5` in code |
| `appliances` | string[] | yes | Appliance IDs (see [[Appliances schema]]). Capped at 4 (`ApplianceSlot1..4`). Order = visual order in the cook area |
| `recipes` | string[] | yes | Recipe IDs (see [[Recipes schema]]) that can spawn this level. Each new order picks uniformly at random |

### Timing & difficulty

| Field | Type | Required | Notes |
|---|---|---|---|
| `max_simultaneous_orders` | int | yes | How many active orders can be on screen at once. Customers queue at the window slots |
| `total_orders` | int | yes | Number of orders that will spawn this shift before the level ends |
| `spawn_interval` | float | yes | Seconds between order spawns once active count < max |
| `initial_delay` | float | optional | Subtracted from `spawn_interval` for the first order. Effectively how long until the first customer appears |
| `prep_time` | float | optional | Seconds of "PREP" overlay before orders start. 0 to skip |
| `time_target_seconds` | int | yes | Star threshold — finish the shift in this many seconds for the "Under time" star. Doesn't affect failure, just rating |

## Add a new level

1. Append a new object to the end of the array.
2. `id` = previous max + 1.
3. Pick ingredients, appliances, and recipes that are *consistent*: every component of every recipe must be reachable with the given ingredients + appliances.
4. Difficulty knobs:
   - **Slower**: more `spawn_interval`, fewer `total_orders`, smaller `max_simultaneous_orders`.
   - **Harder**: more concurrent recipes, recipes with longer chains, tighter `time_target_seconds`.

Example — a salad-themed shift:

```json
{
  "id": 6,
  "name": "Shift 6 - Greens",
  "prep_ingredients": ["lettuce", "tomato", "peppers"],
  "appliances": [],
  "recipes": ["salad_bowl"],
  "max_simultaneous_orders": 2,
  "total_orders": 5,
  "spawn_interval": 4.5,
  "initial_delay": 1.0,
  "prep_time": 3.0,
  "time_target_seconds": 30
}
```

## Star scoring

Stars are awarded per shift in [Main.gd:_on_level_completed](../scripts/Main.gd):
- ⭐ **No burnt items** — never let a cooking slot reach BURNT.
- ⭐ **No angry customers** — no order expired AND no wrong-order penalty triggered (see [[#Wrong order penalty]]).
- ⭐ **Under time** — `_stage_elapsed <= time_target_seconds`.

You need to complete at least one order to earn any stars.

## Wrong order penalty

Clicking a customer with a non-empty assembly that doesn't match their recipe currently:
- Deducts `WRONG_ORDER_COIN_PENALTY` (5) coins.
- Sets `_stage_angry = true` (loses the angry-customer star).
- Subtracts `WRONG_ORDER_TIME_PENALTY` (10s) from the order's timer.
- Clears the assembly.

The customer keeps waiting — they don't leave. See [[#TODO]] if you want this to fail the order instead.

## TODO

- Replace the legacy `screen_mode` and `show_swipe_tutorial` fields, or remove from the data file entirely.
- Per-level spawn weighting on `recipes` (today: uniform random).
- Per-level overrides on penalty constants (today: `WRONG_ORDER_*` constants in Main.gd are global).
