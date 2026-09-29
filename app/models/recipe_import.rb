# Owns the recipe-import API and the parse pipeline.
#
# Callers submit a Source, look up the global OriginalRecipe cache, and either
# receive the cached recipe or enqueue a parse job through this module and
# nothing else.
module RecipeImport
  class Error < StandardError; end

  # Raised when the submitted source cannot be turned into a source_identifier.
  class InvalidSource < Error; end

  Submission = Data.define(:status, :import_id, :original_recipe)

  module_function

  # Submits a Source for import.
  #
  # On a cache hit, returns a cached Submission with the existing
  # OriginalRecipe. On a miss, creates a processing RecipeImport::Record,
  # enqueues RecipeImport::ParseJob, and returns a processing Submission.
  def submit(source_type:, source:)
    source_identifier = SourceIdentifier.for(source_type:, source:)
    cached = OriginalRecipe.find_by(source_identifier:)

    if cached
      Submission.new(status: "cached", import_id: nil, original_recipe: cached)
    else
      record = Record.create!(
        source_identifier: source_identifier,
        source_type: source_type.to_s,
        source: source.to_s
      )
      ParseJob.perform_later(record.id)
      Submission.new(status: "processing", import_id: record.id, original_recipe: nil)
    end
  end

  def find(import_id)
    Record.find_by(id: import_id)
  end
end
