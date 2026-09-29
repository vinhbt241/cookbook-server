module RecipeImport
  # The dependency seam for converting a Source into recipe fields.
  #
  # This is a stub for the async-contract ticket. The real deterministic +
  # DeepSeek + Jev pipeline replaces it in the web-page parsing ticket.
  module Parser
    ParseResult = Data.define(
      :name,
      :description,
      :preparation_time,
      :cooking_time,
      :servings,
      :calories,
      :nutritional_information,
      :ingredients,
      :instructions
    )

    module_function

    def parse(source:)
      ParseResult.new(
        name: "Stub Recipe",
        description: nil,
        preparation_time: nil,
        cooking_time: nil,
        servings: nil,
        calories: nil,
        nutritional_information: nil,
        ingredients: [
          { name: "2 cups all-purpose flour" },
          { name: "1 cup water" }
        ],
        instructions: [
          { position: 1, content: "Mix the ingredients together." },
          { position: 2, content: "Cook until done." }
        ]
      )
    end
  end
end
