module RecipeImport
  # Turns a submitted Source into the global cache key used by OriginalRecipe.
  module SourceIdentifier
    SUPPORTED_TYPES = %w[web_page].freeze

    module_function

    def for(source_type:, source:)
      type = source_type.to_s
      raise RecipeImport::InvalidSource, "unsupported source_type" unless SUPPORTED_TYPES.include?(type)

      case type
      when "web_page"
        web_page_identifier(source)
      end
    end

    def web_page_identifier(source)
      value = source.to_s
      raise RecipeImport::InvalidSource, "source must be a valid web page URL" if value.blank?

      uri = URI.parse(value)
      unless uri.is_a?(URI::HTTP) && uri.host.present?
        raise RecipeImport::InvalidSource, "source must be a valid web page URL"
      end

      value
    rescue URI::InvalidURIError
      raise RecipeImport::InvalidSource, "source must be a valid web page URL"
    end
    private_class_method :web_page_identifier
  end
end
