# A canonical, globally-shared food reference. The foundation for per-recipe
# nutrition calculation: each Ingredient carries nutrition data per 100g and a
# curated map of how much a common unit (cup, tbsp, piece, …) weighs in grams.
class Ingredient < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :calories_per_100g, presence: true, numericality: { greater_than_or_equal_to: 0 }

  def grams_per(unit)
    grams_per_unit[unit.to_s]&.to_f
  end
end
