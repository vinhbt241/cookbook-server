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
- nutritional_information: object (source-provided only; calculation deferred)
- notes: text
- original_source: string
- source_identifier: string (web page → URL, YouTube → video ID, PDF/image → content hash)
- parsed_at: datetime
- last_checked_at: datetime

Relationships:
- has_many original_recipe_ingredients
- has_many original_cooking_instructions

**OriginalRecipeIngredient** — free text; no canonical `Ingredient` link in MVP
- original_recipe
- name: string (free text, e.g. "2 chicken breasts")
- quantity: decimal
- unit: string
- preparation: string
- optional: boolean
- notes: text

Relationships:
- belongs_to original_recipe

**OriginalCookingInstruction**
- original_recipe
- position: integer
- content: text
- image: attachment
- video: attachment

Relationships:
- belongs_to original_recipe

### Deferred — added with later pipeline stages

**Ingredient** (nutrition stage) — global canonical food reference with `calories_per_100g` and `nutritional_information_per_100g`. When it lands, `OriginalRecipeIngredient` gains a `belongs_to ingredient` link and normalization matches free-text names to canonical rows.

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
