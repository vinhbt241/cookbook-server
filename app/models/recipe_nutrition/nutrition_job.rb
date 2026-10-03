module RecipeNutrition
  # Computes calculated nutrition for a newly persisted OriginalRecipe and
  # backfills each ingredient's canonical Ingredient link, quantity, and unit.
  #
  # Additive and best-effort: a failure here never fails the Import. The job is
  # idempotent — it only runs while nutrition_status is pending.
  class NutritionJob < ApplicationJob
    queue_as :default

    def perform(original_recipe_id)
      original_recipe = OriginalRecipe.find_by(id: original_recipe_id)
      return unless original_recipe
      return unless original_recipe.pending?

      result = Calculator.calculate(original_recipe)

      OriginalRecipe.transaction do
        apply_assignments(result.assignments)
        original_recipe.update!(
          calculated_nutritional_information: result.nutritional_information,
          nutrition_status: result.status,
          unmatched_ingredients: result.unmatched_ingredients
        )
      end
    rescue => e
      Rails.logger.error("[RecipeNutrition] failed for original_recipe #{original_recipe_id}: #{e.message}")
      original_recipe&.update_column(:nutrition_status, OriginalRecipe.nutrition_statuses[:unavailable])
    end

    private

    def apply_assignments(assignments)
      assignments.each do |assignment|
        assignment.fetch(:record).update!(
          ingredient: assignment.fetch(:ingredient),
          quantity: assignment.fetch(:quantity),
          unit: assignment.fetch(:unit)
        )
      end
    end
  end
end
