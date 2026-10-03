# Canonical Ingredient reference data for the nutrition stage.
#
# A small hand-curated seed for MVP. Values are per 100g (grams for macros,
# kilocalories for calories) from USDA FoodData Central approximations.
# `grams_per_unit` maps a canonical unit key (see RecipeNutrition::Quantity) to
# the mass in grams of one such unit, and is what turns "1 cup flour" into a
# mass before nutrition is applied.
#
# Idempotent: safe to re-run. A full FoodData Central import is a later stage;
# see docs/designs/data_models.md.

INGREDIENTS = [
  { name: "chicken breast", calories_per_100g: 165,
    macros: { "protein" => 31.0, "carbohydrates" => 0.0, "fat" => 3.6, "fiber" => 0.0, "sugar" => 0.0, "sodium" => 0.074 },
    grams_per_unit: { "piece" => 170 } },
  { name: "flour", calories_per_100g: 364,
    macros: { "protein" => 10.3, "carbohydrates" => 76.3, "fat" => 1.0, "fiber" => 2.7, "sugar" => 0.3, "sodium" => 0.002 },
    grams_per_unit: { "cup" => 125, "tbsp" => 8, "tsp" => 2.6 } },
  { name: "sugar", calories_per_100g: 387,
    macros: { "protein" => 0.0, "carbohydrates" => 100.0, "fat" => 0.0, "fiber" => 0.0, "sugar" => 99.8, "sodium" => 0.0 },
    grams_per_unit: { "cup" => 200, "tbsp" => 12.5, "tsp" => 4.2 } },
  { name: "olive oil", calories_per_100g: 884,
    macros: { "protein" => 0.0, "carbohydrates" => 0.0, "fat" => 100.0, "fiber" => 0.0, "sugar" => 0.0, "sodium" => 0.0 },
    grams_per_unit: { "cup" => 224, "tbsp" => 14, "tsp" => 4.5 } },
  { name: "milk", calories_per_100g: 61,
    macros: { "protein" => 3.2, "carbohydrates" => 4.8, "fat" => 3.3, "fiber" => 0.0, "sugar" => 4.8, "sodium" => 0.044 },
    grams_per_unit: { "cup" => 244, "tbsp" => 15 } },
  { name: "egg", calories_per_100g: 143,
    macros: { "protein" => 12.6, "carbohydrates" => 0.7, "fat" => 9.5, "fiber" => 0.0, "sugar" => 0.4, "sodium" => 0.142 },
    grams_per_unit: { "piece" => 50 } },
  { name: "garlic", calories_per_100g: 149,
    macros: { "protein" => 6.4, "carbohydrates" => 33.1, "fat" => 0.5, "fiber" => 2.1, "sugar" => 1.0, "sodium" => 0.017 },
    grams_per_unit: { "clove" => 3, "piece" => 3 } },
  { name: "butter", calories_per_100g: 717,
    macros: { "protein" => 0.9, "carbohydrates" => 0.1, "fat" => 81.1, "fiber" => 0.0, "sugar" => 0.1, "sodium" => 0.643 },
    grams_per_unit: { "cup" => 227, "stick" => 113, "tbsp" => 14 } },
  { name: "salt", calories_per_100g: 0,
    macros: { "protein" => 0.0, "carbohydrates" => 0.0, "fat" => 0.0, "fiber" => 0.0, "sugar" => 0.0, "sodium" => 38.758 },
    grams_per_unit: { "tsp" => 6, "tbsp" => 18 } },
  { name: "rice", calories_per_100g: 130,
    macros: { "protein" => 2.7, "carbohydrates" => 28.2, "fat" => 0.3, "fiber" => 0.4, "sugar" => 0.1, "sodium" => 0.001 },
    grams_per_unit: { "cup" => 158 } }
].freeze

INGREDIENTS.each do |attributes|
  Ingredient.find_or_create_by!(name: attributes.fetch(:name)) do |ingredient|
    ingredient.calories_per_100g = attributes.fetch(:calories_per_100g)
    ingredient.nutritional_information_per_100g = attributes.fetch(:macros)
    ingredient.grams_per_unit = attributes.fetch(:grams_per_unit)
  end
end
