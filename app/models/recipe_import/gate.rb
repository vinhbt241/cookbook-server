module RecipeImport
  # Decides which recipe fields are present and blanks the absent ones.
  #
  # The single caller of TypeSafeClient. Takes candidate fields and the
  # evidence text assembled by the Parser, asks Jev per-field presence, and
  # returns blanked fields plus field_status. Jev is the sole source of
  # field_status; a field it judges not_found is blanked even if an extractor
  # produced a value.
  module Gate
    Result = Data.define(:gated_fields, :field_status)

    JEV_PRESENCE_THRESHOLD = 0.5

    module_function

    def apply(fields:, state:)
      field_status = evaluate_presence(state)
      gated_fields = apply_gates(fields, field_status)

      Result.new(gated_fields: gated_fields, field_status: field_status)
    end

    def evaluate_presence(state)
      scores = TypeSafeClient.evaluate(state: state, questions: questions)
      FIELD_NAMES.index_with do |field|
        score = scores[field]
        score.to_f >= JEV_PRESENCE_THRESHOLD ? "found" : "not_found"
      end
    end
    private_class_method :evaluate_presence

    def questions
      FIELD_NAMES.index_with { |field_name| { type: "noul", instructions: "does the state contain cooking recipe's #{field_name}?" } }
    end
    private_class_method :questions

    def apply_gates(fields, field_status)
      fields.each_with_object({}) do |(field, value), gated|
        gated[field] = field_status[field] == "not_found" ? blank_for(field) : value
      end
    end
    private_class_method :apply_gates

    def blank_for(field)
      field.in?(%w[ingredients instructions]) ? [] : nil
    end
    private_class_method :blank_for
  end
end
