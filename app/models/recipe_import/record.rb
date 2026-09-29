module RecipeImport
  # Tracks a single Import while it is processing and, once finished, points at
  # the parsed OriginalRecipe. This is the record the polling endpoint reads.
  class Record < ApplicationRecord
    self.table_name = "recipe_imports"

    belongs_to :original_recipe, class_name: "OriginalRecipe", optional: true

    enum :status, { processing: "processing", done: "done", cached: "cached", failed: "failed" }
  end
end
