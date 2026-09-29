class OriginalRecipeIngredient < ApplicationRecord
  belongs_to :original_recipe, inverse_of: :original_recipe_ingredients

  validates :name, presence: true
end
