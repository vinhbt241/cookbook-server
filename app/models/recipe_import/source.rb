module RecipeImport
  # The external resource a recipe is imported from, as submitted by a client.
  class Source
    attr_reader :type, :value

    def initialize(type:, value:)
      @type = type.to_s
      @value = value.to_s
    end

    def identifier
      SourceIdentifier.for(source_type: type, source: value)
    end
  end
end
