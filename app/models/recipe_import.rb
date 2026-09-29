# Owns the recipe-import API and the parse pipeline.
#
# Callers submit a Source, look up the global OriginalRecipe cache, and either
# receive the cached OriginalRecipe or enqueue a parse job through this module
# and nothing else.
module RecipeImport
  class Error < StandardError; end

  # Raised when the submitted source cannot be turned into a source_identifier.
  class InvalidSource < Error; end

  Submission = Data.define(:status, :import_id, :original_recipe) do
    def cached?
      status == "cached"
    end
  end

  module_function

  # Submits a Source for import.
  #
  # On a cache hit, records a cached RecipeImport::Record and returns a cached
  # Submission with the existing OriginalRecipe. On a miss, records a
  # processing RecipeImport::Record, enqueues RecipeImport::ParseJob, and
  # returns a processing Submission.
  def submit(source)
    source_identifier = source.identifier
    cached = OriginalRecipe.find_by(source_identifier:)

    if cached
      Record.create!(
        source_identifier: source_identifier,
        source_type: source.type,
        source: source.value,
        status: :cached,
        original_recipe: cached
      )
      Submission.new(status: "cached", import_id: nil, original_recipe: cached)
    else
      record = Record.create!(
        source_identifier: source_identifier,
        source_type: source.type,
        source: source.value
      )
      ParseJob.perform_later(record.id)
      Submission.new(status: "processing", import_id: record.id, original_recipe: nil)
    end
  end

  def find(import_id)
    Record.find_by(id: import_id)
  end
end
