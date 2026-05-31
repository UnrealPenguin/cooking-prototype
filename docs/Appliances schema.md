# Appliances schema

File: `data/appliances.json`

A flat object keyed by `appliance_id`. Each entry defines a cooking station — its visual label, color, how many items it can cook simultaneously, and the cleaning time after a burn.

## Shape

```json
{
  "appliance_id": {
    "label": "Display Name",
    "slots": 1,
    "color": "#5D4037",
    "cleaning_time": 2.0
  }
}
```

## Fields

| Field | Type | Required | Notes |
|---|---|---|---|
| `label` | string | yes | Uppercased and shown as the appliance's title at runtime (e.g. `"GRILL"`) |
| `slots` | int | yes | Number of `CookingSlot`s inside this appliance. Each slot holds one item being cooked. Currently all appliances use 1 |
| `color` | string | yes | Hex color tinting the appliance's BG ColorRect at runtime |
| `cleaning_time` | float | yes | Seconds in `CLEANING` state after a burnt item is trashed — slot is unusable during this window |

## How it's used

- Each ingredient with `needs_cook: true` references an appliance via its `appliance` field (see [[Ingredients schema]]).
- A level's `appliances` array (see [[Levels schema]]) decides which appliances spawn in the kitchen for that shift.
- `Main.gd:_build_cook_section` instances one `Appliance` per entry in the level's array and adds it to the matching `ApplianceSlot1..4` in [Main.tscn](../scenes/Main.tscn).

## Add a new appliance

1. Pick a unique `appliance_id` (snake_case).
2. Set `slots`. Keep at 1 to match current visuals (the prototype's slot art assumes 1).
3. Pick a `color` that pairs with the label.
4. Set `cleaning_time` (2.0s default, longer for "heavier" appliances).
5. Add the appliance ID to the `appliances` array on at least one level in [[Levels schema]].
6. Reference it from an ingredient's `appliance` field so something can be cooked on it.

Example — fryer for bacon / fries:

```json
"fryer": {
  "label": "Fryer",
  "slots": 1,
  "color": "#FF9800",
  "cleaning_time": 3.0
}
```

## State machine (CookingSlot)

Each slot transitions through:

`EMPTY → COOKING → DONE → BURNING → BURNT → CLEANING → EMPTY`

- **EMPTY** — accepts a raw drop.
- **COOKING** — counts up to `cook_time` (from the ingredient).
- **DONE** — ready to collect for `done_grace` seconds. Tap to add to the cooked tray (blocked if tray full).
- **BURNING** — `burn_time` seconds before BURNT. Still collectable.
- **BURNT** — can't collect. Drag to trash to start CLEANING.
- **CLEANING** — `cleaning_time` (from the appliance). Then back to EMPTY.

## Capacity quirk

If the cooked tray for that ingredient is at 3 when the slot reaches `DONE`, tap-to-collect is blocked. The slot keeps counting toward BURNING — you have until the burn timer runs out to free a cooked slot in the bowl (drag to assembly, or place on another appliance) and then tap to collect. See [[Ingredients schema#Capacity rules]].
