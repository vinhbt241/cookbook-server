class OriginalCookingInstruction < ApplicationRecord
  belongs_to :original_recipe, inverse_of: :original_cooking_instructions

  validates :content, presence: true
end
