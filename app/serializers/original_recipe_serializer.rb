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
      calculated_nutritional_information: original_recipe.calculated_nutritional_information,
      nutrition_status: original_recipe.nutrition_status,
      unmatched_ingredients: original_recipe.unmatched_ingredients,
      original_source: original_recipe.original_source,
      source_identifier: original_recipe.source_identifier,
      categories: []
    }
  end

  def field_status
    original_recipe.field_status.presence || {}
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
end
