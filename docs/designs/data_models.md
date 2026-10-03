# Data Models

Split by where each model lives. This repo is the **server** (parse + auth + shared cache); the **client** is a separate mobile app (future project) that owns the user's cookbook. See `CONTEXT.md` for terminology and `docs/adr/0001-*.md` for the boundary decision.

## Server (this repo)

### MVP — build now

**User**
- name: string
- email: string
- avatar: attachment
- password_digest: string (email/password accounts only; Google sign-in has none)
- confirmed_at: datetime (import is blocked until confirmed)

Relationships: none in MVP. The server's `OriginalRecipe` cache is globally shared, not user-owned.

**OriginalRecipe** — the globally shared cache, keyed by `source_identifier`
- name: string
- description: text
- preparation_time: integer
- cooking_time: integer
- servings: integer
- calories: integer
- nutritional_information: object (source-provided only)
- calculated_nutritional_information: object (per-serving: calories, protein, carbohydrates, fat, fiber, sugar, sodium — written by the nutrition stage)
- nutrition_status: enum (`pending` | `computed` | `partial` | `unavailable`)
- unmatched_ingredients: array (free-text ingredient names that did not Match)
- notes: text
- original_source: string
- source_identifier: string (web page → URL, PDF/image → content hash)
- field_status: object (per-field `found`/`not_found`, written by the parse pipeline's Jev gate)
- parsed_at: datetime
- last_checked_at: datetime

Relationships:
- has_many original_recipe_ingredients
- has_many original_cooking_instructions

**OriginalRecipeIngredient**
- original_recipe
- ingredient: optional (the canonical Ingredient it Matched, backfilled by the nutrition stage)
- name: string (free text, e.g. "2 chicken breasts")
- quantity: decimal (parsed from free text by the nutrition stage)
- unit: string (canonical unit key, parsed by the nutrition stage)
- preparation: string
- optional: boolean
- notes: text

Relationships:
- belongs_to original_recipe
- optionally belongs_to ingredient

**OriginalCookingInstruction**
- original_recipe
- position: integer
- content: text
- image: attachment
- video: attachment

Relationships:
- belongs_to original_recipe

**Ingredient** (nutrition stage) — global canonical food reference
- name: string (unique, singular lowercase)
- calories_per_100g: decimal
- nutritional_information_per_100g: object (protein, carbohydrates, fat, fiber, sugar, sodium — grams per 100g)
- grams_per_unit: object (canonical unit key → grams, e.g. `{"cup": 125}`)

Seeded with a small curated list for MVP; a FoodData Central import is a later stage.

### Deferred — added with later pipeline stages

**Category** (categorize stage) — global categories tagging `OriginalRecipe` (HABTM). Empty in MVP: nothing populates it until the categorize stage exists.

## Client (mobile app — future project)

**Recipe** — a fork of an `OriginalRecipe`, owned by the user
- user
- original_recipe: optional (provenance only, never a live dependency)
- name, description, preparation_time, cooking_time, servings, calories, nutritional_information, notes, original_source

Relationships:
- belongs_to user
- optionally_belongs_to original_recipe
- has_many recipe_ingredients
- has_many cooking_instructions
- has_and_belongs_to_many categories (user's own custom categories)

**RecipeIngredient** — mirrors `OriginalRecipeIngredient`, owned by the user's Recipe.

**CookingInstruction** — mirrors `OriginalCookingInstruction`, owned by the user's Recipe.

**Category (user custom)** — personal categories for the user's `Recipe`s; distinct from the server's global `Category`.
