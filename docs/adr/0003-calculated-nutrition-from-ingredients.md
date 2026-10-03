# Calculated nutrition comes from a canonical Ingredient table, never an LLM

A recipe's nutrition is calculated by matching its free-text ingredients to a canonical `Ingredient` table (per-100g nutrition + a curated grams-per-unit map), summing, and dividing by servings. It is an additive async stage that runs after parse completes and never fails the Import; per-serving only, blank when `servings` is unknown.

**Considered options**: estimating nutrition with an LLM (as extraction already does) was rejected because an LLM would invent values where the ingredient list doesn't determine them, violating requirement #4's "leave blank rather than invent" principle. A recurring sweep was rejected in favor of enqueueing once per new `OriginalRecipe`, keeping the stage modular per requirement #8. Whole-recipe totals (when servings are unknown) were rejected to keep the payload single-unit.
