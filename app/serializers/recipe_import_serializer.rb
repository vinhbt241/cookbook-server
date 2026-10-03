class RecipeImportSerializer
  def self.submission(submission)
    if submission.cached?
      original_recipe = OriginalRecipeSerializer.new(submission.original_recipe)

      {
        import_id: submission.import_id,
        status: "cached",
        original_recipe: original_recipe.as_json,
        field_status: original_recipe.field_status
      }
    else
      { import_id: submission.import_id, status: "processing" }
    end
  end

  def initialize(record)
    @record = record
  end

  def as_json(_options = nil)
    case record.status
    when "processing"
      { import_id: record.id, status: "processing" }
    when "done", "cached"
      original_recipe = OriginalRecipeSerializer.new(record.original_recipe)

      {
        import_id: record.id,
        status: record.status,
        original_recipe: original_recipe.as_json,
        field_status: original_recipe.field_status
      }
    when "failed"
      {
        import_id: record.id,
        status: "failed",
        error: record.error,
        error_code: record.error_code,
        retryable: record.retryable?,
        retry_count: record.retry_count,
        retries_remaining: record.retries_remaining
      }
    end
  end

  private

  attr_reader :record
end
