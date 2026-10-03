module RecipeNutrition
  # Resolves a clean food name (already quantity/unit-free) to a canonical
  # Ingredient. Matching is exact and conservative: normalize case/whitespace
  # and singularize, then look up the canonical row by name. Unmatched names
  # return nil and contribute nothing, per the no-invention principle.
  module Matcher
    module_function

    def match(name)
      normalized = ActiveSupport::Inflector.singularize(name.to_s.downcase.squish)
      return nil if normalized.blank?

      Ingredient.find_by(name: normalized)
    end
  end
end
