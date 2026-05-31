# Cooking Prototype — Documentation

Welcome to the project vault. This is the landing page — start here.

## Data schemas

The game is data-driven. Most gameplay tweaks happen by editing JSON in [data/](../data/).

- [[Recipes schema]] — orders the player must fulfill (`data/recipes.json`)
- [[Ingredients schema]] — every ingredient and its prep/cook config (`data/ingredients.json`)
- [[Appliances schema]] — cooking stations (`data/appliances.json`)
- [[Levels schema]] — shifts / progression (`data/levels.json`)

## Conventions

- IDs are `snake_case` strings (e.g. `classic_burger`, `onion_sauteed`).
- Colors are CSS-style hex strings: `"#RRGGBB"`.
- Times are seconds (floats).
- Fields marked **required** must exist; **optional** ones fall back to a default.

## How to add a new …

- [[Recipes schema#Add a new recipe]]
- [[Ingredients schema#Add a new ingredient]]
- [[Appliances schema#Add a new appliance]]
- [[Levels schema#Add a new level]]
