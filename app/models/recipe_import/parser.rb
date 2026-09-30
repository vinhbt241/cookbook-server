module RecipeImport
  # Converts a Source into recipe fields.
  #
  # Pipeline: fetch -> deterministic extraction -> DeepSeek fallback ->
  # Jev per-field gates -> ParseResult. Jev is the sole source of field_status
  # and a field it judges not_found is blanked even if an extractor produced a
  # value.
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
      :instructions,
      :field_status
    )

    JEV_PRESENCE_THRESHOLD = 0.5

    module_function

    def parse(source:)
      page = WebPageFetcher.fetch(source.value)
      extraction = build_extraction(page)
      field_status = evaluate_presence(page, extraction)
      gated_fields = apply_gates(extraction.fields, field_status)

      ParseResult.new(
        name: gated_fields["name"],
        description: gated_fields["description"],
        preparation_time: gated_fields["preparation_time"],
        cooking_time: gated_fields["cooking_time"],
        servings: gated_fields["servings"],
        calories: gated_fields["calories"],
        nutritional_information: gated_fields["nutritional_information"],
        ingredients: normalize_ingredients(gated_fields["ingredients"]),
        instructions: normalize_instructions(gated_fields["instructions"]),
        field_status: field_status
      )
    rescue WebPageFetcher::Error => e
      raise map_fetch_error(e)
    rescue DeepSeekClient::Error => e
      raise PipelineError.new(error_code: "deep_seek_error", message: e.message)
    rescue TypeSafeClient::Error => e
      raise PipelineError.new(error_code: "jev_error", message: e.message)
    end

    def build_extraction(page)
      deterministic = DeterministicExtractor.extract(page.html)
      return deterministic if deterministic.markup_present

      fields = Extraction.empty_fields.merge(DeepSeekClient.structure(page.text))
      Extraction.new(markup_present: false, fields: fields, markup_dump: "")
    end
    private_class_method :build_extraction

    def evaluate_presence(page, extraction)
      state = [ page.text, extraction.markup_dump ].compact_blank.join("\n\nSchema.org markup:\n")
      questions = FIELD_NAMES.index_with { |field_name| { type: "noul", instructions: "does the state contain cooking recipe's #{field_name}?" } }
      scores = TypeSafeClient.evaluate(state: state, questions: questions)

      FIELD_NAMES.index_with do |field|
        score = scores[field]
        score.to_f >= JEV_PRESENCE_THRESHOLD ? "found" : "not_found"
      end
    end
    private_class_method :evaluate_presence

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

    def normalize_ingredients(values)
      Array(values).filter_map do |value|
        name = value.is_a?(Hash) ? value["name"] || value[:name] : value
        name = name.to_s.strip
        { name: name } if name.present?
      end
    end
    private_class_method :normalize_ingredients

    def normalize_instructions(values)
      Array(values).filter_map.with_index(1) do |value, index|
        content = if value.is_a?(Hash)
                    value["text"] || value["content"] || value["name"] ||
                      value[:text] || value[:content] || value[:name]
        else
          value
        end
        content = content.to_s.strip
        { position: index, content: content } if content.present?
      end
    end
    private_class_method :normalize_instructions

    def map_fetch_error(error)
      case error
      when WebPageFetcher::HttpError
        if error.status >= 500
          PipelineError.new(error_code: "fetch_http_5xx", message: error.message)
        else
          PipelineError.new(error_code: "fetch_http_4xx", message: error.message)
        end
      when WebPageFetcher::TimeoutError
        PipelineError.new(error_code: "fetch_timeout", message: error.message)
      when WebPageFetcher::NetworkError
        PipelineError.new(error_code: "fetch_network_error", message: error.message)
      when WebPageFetcher::NonHtmlError
        PipelineError.new(error_code: "fetch_not_html", message: error.message)
      else
        PipelineError.new(error_code: "fetch_error", message: error.message)
      end
    end
    private_class_method :map_fetch_error
  end
end
