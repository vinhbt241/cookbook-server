module RecipeImport
  # Runs the parse pipeline for a processing Record and persists the resulting
  # OriginalRecipe (with its free-text ingredients and ordered instructions).
  class ParseJob < ApplicationJob
    queue_as :default

    def perform(record_id)
      record = Record.find(record_id)
      parse_result = Parser.parse(
        source_identifier: record.source_identifier,
        source_type: record.source_type,
        source: record.source
      )

      original_recipe = persist_original_recipe(record, parse_result)
      record.update!(status: "done", original_recipe: original_recipe)
    rescue => e
      raise unless record

      record.update!(status: "failed", error: e.message)
    end

    private

    def persist_original_recipe(record, parse_result)
      OriginalRecipe.transaction do
        recipe = OriginalRecipe.find_or_initialize_by(source_identifier: record.source_identifier)

        if recipe.new_record?
          recipe.assign_attributes(
            name: parse_result.name,
            description: parse_result.description,
            preparation_time: parse_result.preparation_time,
            cooking_time: parse_result.cooking_time,
            servings: parse_result.servings,
            calories: parse_result.calories,
            nutritional_information: parse_result.nutritional_information,
            original_source: record.source,
            source_identifier: record.source_identifier,
            parsed_at: Time.current,
            last_checked_at: Time.current
          )
          recipe.save!

          parse_result.ingredients.each do |ingredient|
            recipe.original_recipe_ingredients.create!(ingredient)
          end
          parse_result.instructions.each do |instruction|
            recipe.original_cooking_instructions.create!(instruction)
          end
        end

        recipe
      end
    end
  end
end
