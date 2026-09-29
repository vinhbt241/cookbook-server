class OriginalRecipe < ApplicationRecord
  has_many :original_recipe_ingredients, dependent: :destroy, inverse_of: :original_recipe
  has_many :original_cooking_instructions, dependent: :destroy, inverse_of: :original_recipe
end
