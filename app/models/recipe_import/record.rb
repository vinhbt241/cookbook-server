module RecipeImport
  # Tracks a single Import while it is processing and, once finished, points at
  # the parsed OriginalRecipe. This is the record the polling endpoint reads.
  class Record < ApplicationRecord
    self.table_name = "recipe_imports"

    MAX_RETRY_ATTEMPTS = 3

    # `no_recipe_found` is intentionally absent: re-parsing the same image
    # bytes cannot produce a recipe, so it must not be retryable.
    RETRYABLE_ERROR_CODES = %w[
      fetch_http_5xx
      fetch_timeout
      fetch_network_error
      deep_seek_error
      jev_error
    ].freeze

    belongs_to :original_recipe, class_name: "OriginalRecipe", optional: true

    enum :status, { processing: 0, done: 1, cached: 2, failed: 3 }

    def retries_remaining
      [ MAX_RETRY_ATTEMPTS - retry_count, 0 ].max
    end

    def retryable_error?
      error_code.present? && RETRYABLE_ERROR_CODES.include?(error_code)
    end

    def retryable?
      retryable_error? && retries_remaining.positive?
    end
  end
end
