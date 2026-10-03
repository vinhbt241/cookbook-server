module RecipeNutrition
  # Computes per-serving nutrition for an OriginalRecipe from its ingredients.
  #
  # Each ingredient line is parsed (quantity + unit + food), matched to a
  # canonical Ingredient, and converted to grams via the Ingredient's curated
  # grams_per_unit map. Nutrition is summed across matched ingredients and
  # divided by the recipe's servings. Ingredients that cannot be quantified or
  # matched contribute nothing and are reported as unmatched.
  module Calculator
    MACROS = %w[protein carbohydrates fat fiber sugar sodium].freeze

    Result = Data.define(:status, :nutritional_information, :unmatched_ingredients, :assignments)

    module_function

    def calculate(original_recipe)
      records = original_recipe.original_recipe_ingredients.to_a
      return unavailable([]) if records.empty?

      servings = original_recipe.servings.to_f
      return unavailable([]) unless servings.positive?

      totals = { "calories" => 0.0 }.merge(MACROS.index_with { 0.0 })
      unmatched = []
      assignments = []
      matched = 0

      records.each do |record|
        contribution = contribution_for(Quantity.parse(record.name))

        if contribution
          matched += 1
          assignments << {
            record: record,
            ingredient: contribution.fetch(:ingredient),
            quantity: contribution.fetch(:quantity),
            unit: contribution.fetch(:unit)
          }
          grams = contribution.fetch(:grams)
          totals["calories"] += grams / 100.0 * contribution.fetch(:ingredient).calories_per_100g.to_f
          MACROS.each do |macro|
            totals[macro] += grams / 100.0 * per_100g(contribution.fetch(:ingredient), macro)
          end
        else
          unmatched << record.name
        end
      end

      return unavailable(unmatched) if matched.zero?

      status = unmatched.empty? ? :computed : :partial
      Result.new(
        status: status,
        nutritional_information: per_serving(totals, servings),
        unmatched_ingredients: unmatched,
        assignments: assignments
      )
    end

    def contribution_for(parsed)
      return nil if parsed.quantity.nil?

      ingredient = Matcher.match(parsed.name)
      return nil unless ingredient

      grams_per_unit = ingredient.grams_per(parsed.unit)
      return nil unless grams_per_unit

      {
        ingredient: ingredient,
        quantity: parsed.quantity,
        unit: parsed.unit,
        grams: parsed.quantity * grams_per_unit
      }
    end
    private_class_method :contribution_for

    def per_100g(ingredient, macro)
      ingredient.nutritional_information_per_100g[macro].to_f
    end
    private_class_method :per_100g

    def per_serving(totals, servings)
      {
        "calories" => (totals["calories"] / servings).round,
        "protein" => round_macro(totals["protein"] / servings),
        "carbohydrates" => round_macro(totals["carbohydrates"] / servings),
        "fat" => round_macro(totals["fat"] / servings),
        "fiber" => round_macro(totals["fiber"] / servings),
        "sugar" => round_macro(totals["sugar"] / servings),
        "sodium" => round_macro(totals["sodium"] / servings)
      }
    end
    private_class_method :per_serving

    def round_macro(value)
      value.round(1)
    end
    private_class_method :round_macro

    def unavailable(unmatched)
      Result.new(status: :unavailable, nutritional_information: nil, unmatched_ingredients: unmatched, assignments: [])
    end
    private_class_method :unavailable
  end
end
