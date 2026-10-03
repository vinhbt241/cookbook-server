class OriginalRecipeIngredient < ApplicationRecord
  belongs_to :original_recipe, inverse_of: :original_recipe_ingredients
  belongs_to :ingredient, optional: true

  validates :name, presence: true
end
