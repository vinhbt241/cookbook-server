class OriginalRecipe < ApplicationRecord
  has_many :original_recipe_ingredients, dependent: :destroy, inverse_of: :original_recipe
  has_many :original_cooking_instructions, dependent: :destroy, inverse_of: :original_recipe

  enum :nutrition_status, { pending: 0, computed: 1, partial: 2, unavailable: 3 }
end
