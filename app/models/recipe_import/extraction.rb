module RecipeImport
  # The normalized output of an extraction step, before Jev gating.
  #
  # fields is a hash keyed by the 9 recipe field names. ingredients and
  # instructions are kept as arrays of free-text strings at this stage; the
  # parser turns them into the persistence shapes after gating.
  Extraction = Data.define(:markup_present, :fields, :markup_dump) do
    def self.empty_fields
      {
        "name" => nil,
        "description" => nil,
        "ingredients" => [],
        "instructions" => [],
        "preparation_time" => nil,
        "cooking_time" => nil,
        "servings" => nil,
        "calories" => nil,
        "nutritional_information" => nil
      }
    end
  end
end
