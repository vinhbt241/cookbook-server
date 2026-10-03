# Owns the recipe-import API and the parse pipeline.
#
# Callers submit a Source, look up the global OriginalRecipe cache, and either
# receive the cached OriginalRecipe or enqueue a parse job through this module
# and nothing else.
module RecipeImport
  class Error < StandardError; end

  # Raised when the submitted source cannot be turned into a source_identifier.
  class InvalidSource < Error; end

  # Raised when a pipeline step fails hard (fetch, DeepSeek, or Jev).
  class PipelineError < Error
    attr_reader :error_code

    def initialize(error_code:, message: nil)
      @error_code = error_code
      super(message || error_code)
    end
  end

  # The nine fields every parse result and field_status map covers.
  FIELD_NAMES = %w[
    name
    description
    ingredients
    instructions
    preparation_time
    cooking_time
    servings
    calories
    nutritional_information
  ].freeze

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
      record = Record.create!(
        source_identifier: source_identifier,
        source_type: source.type,
        source: source.value,
        status: :cached,
        original_recipe: cached
      )
      Submission.new(status: "cached", import_id: record.id, original_recipe: cached)
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

  # Re-runs a failed import in place.
  #
  # A cache hit re-links the record without consuming a retry. Otherwise the
  # record is reset to processing and re-enqueued, consuming one retry.
  def retry(record)
    cached = OriginalRecipe.find_by(source_identifier: record.source_identifier)

    if cached
      record.update!(status: :cached, original_recipe: cached, error: nil, error_code: nil)
      Submission.new(status: "cached", import_id: record.id, original_recipe: cached)
    else
      record.update!(
        status: :processing,
        original_recipe: nil,
        error: nil,
        error_code: nil,
        retry_count: record.retry_count + 1
      )
      ParseJob.perform_later(record.id)
      Submission.new(status: "processing", import_id: record.id, original_recipe: nil)
    end
  end

  def find(import_id)
    Record.find_by(id: import_id)
  end
end
