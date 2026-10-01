require "base64"
require "digest"

module RecipeImport
  # Turns a submitted Source into the global cache key used by OriginalRecipe.
  module SourceIdentifier
    SUPPORTED_TYPES = %w[web_page image].freeze

    module_function

    def for(source_type:, source:)
      type = source_type.to_s
      raise RecipeImport::InvalidSource, "unsupported source_type" unless SUPPORTED_TYPES.include?(type)

      case type
      when "web_page"
        web_page_identifier(source)
      when "image"
        image_identifier(source)
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

    def image_identifier(source)
      data_uri = source.to_s
      raise RecipeImport::InvalidSource, "source must be an image file" if data_uri.blank?

      header, payload = data_uri.split(",", 2)
      media_type = header.to_s.split(";", 2).first
      unless media_type.to_s.start_with?("data:image/") && payload.present?
        raise RecipeImport::InvalidSource, "source must be an image file"
      end

      bytes = Base64.decode64(payload)
      raise RecipeImport::InvalidSource, "source must be a non-empty image" if bytes.empty?

      Digest::SHA256.hexdigest(bytes)
    end
    private_class_method :image_identifier
  end
end
