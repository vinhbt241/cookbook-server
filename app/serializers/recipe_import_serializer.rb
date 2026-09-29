class RecipeImportSerializer
  def initialize(record)
    @record = record
  end

  def as_json(_options = nil)
    case record.status
    when "processing"
      { status: "processing" }
    when "done", "cached"
      original_recipe = OriginalRecipeSerializer.new(record.original_recipe)

      {
        status: record.status,
        original_recipe: original_recipe.as_json,
        field_status: original_recipe.field_status
      }
    when "failed"
      { status: "failed", error: record.error }
    end
  end

  private

  attr_reader :record
end
