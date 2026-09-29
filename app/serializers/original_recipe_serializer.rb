class OriginalRecipeSerializer
  def initialize(original_recipe)
    @original_recipe = original_recipe
  end

  def as_json(_options = nil)
    {
      name: original_recipe.name,
      description: original_recipe.description,
      ingredients: ingredients,
      instructions: instructions,
      preparation_time: original_recipe.preparation_time,
      cooking_time: original_recipe.cooking_time,
      servings: original_recipe.servings,
      calories: original_recipe.calories,
      nutritional_information: original_recipe.nutritional_information,
      original_source: original_recipe.original_source,
      source_identifier: original_recipe.source_identifier,
      categories: []
    }
  end

  def field_status
    {
      name: found?(original_recipe.name),
      description: found?(original_recipe.description),
      ingredients: found?(original_recipe.original_recipe_ingredients.any?),
      instructions: found?(original_recipe.original_cooking_instructions.any?),
      preparation_time: found?(original_recipe.preparation_time),
      cooking_time: found?(original_recipe.cooking_time),
      servings: found?(original_recipe.servings),
      calories: found?(original_recipe.calories),
      nutritional_information: found?(original_recipe.nutritional_information)
    }
  end

  private

  attr_reader :original_recipe

  def ingredients
    original_recipe.original_recipe_ingredients.map do |ingredient|
      {
        name: ingredient.name,
        quantity: ingredient.quantity,
        unit: ingredient.unit,
        preparation: ingredient.preparation,
        optional: ingredient.optional,
        notes: ingredient.notes
      }
    end
  end

  def instructions
    original_recipe.original_cooking_instructions.order(:position).map do |instruction|
      {
        position: instruction.position,
        content: instruction.content
      }
    end
  end

  def found?(value)
    value.present? ? "found" : "not_found"
  end
end
