require "base64"

module RecipeImport
  # The external resource a recipe is imported from, as submitted by a client.
  class Source
    attr_reader :type, :value

    def initialize(type:, value:)
      @type = type.to_s
      @value = normalize_value(value)
    end

    def identifier
      SourceIdentifier.for(source_type: type, source: value)
    end

    private

    def normalize_value(value)
      return value.to_s unless file?

      return value if value.is_a?(String) && value.start_with?("data:")

      if value.respond_to?(:read)
        content_type = value.content_type.to_s.presence || "application/octet-stream"
        "data:#{content_type};base64,#{Base64.strict_encode64(value.read.to_s)}"
      else
        value.to_s
      end
    end

    def file?
      type.in?(%w[image pdf])
    end
  end
end
