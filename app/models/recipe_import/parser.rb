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

    module_function

    def parse(source:)
      case source.type
      when "web_page"
        parse_web_page(source)
      when "image"
        parse_image(source)
      when "pdf"
        parse_pdf(source)
      else
        raise PipelineError.new(error_code: "unsupported_source_type", message: "unsupported source_type")
      end
    rescue WebPageFetcher::Error => e
      raise map_fetch_error(e)
    rescue PdfExtractor::Error => e
      raise PipelineError.new(error_code: e.error_code, message: e.message)
    rescue DeepSeekClient::Error => e
      raise PipelineError.new(error_code: "deep_seek_error", message: e.message)
    rescue TypeSafeClient::Error => e
      raise PipelineError.new(error_code: "jev_error", message: e.message)
    end

    def parse_web_page(source)
      page = WebPageFetcher.fetch(source.value)
      extraction = build_extraction(page)
      state = [ page.text, extraction.markup_dump ].compact_blank.join("\n\nSchema.org markup:\n")
      result = Gate.apply(fields: extraction.fields, state: state)

      build_result(result.gated_fields, result.field_status)
    end
    private_class_method :parse_web_page

    def parse_image(source)
      extraction = build_image_extraction(source.value)
      result = Gate.apply(fields: extraction.fields, state: image_state(extraction.fields))

      if recipe_absent?(result.gated_fields)
        raise PipelineError.new(error_code: "no_recipe_found",
          message: "couldn't read a recipe from this image")
      end

      build_result(result.gated_fields, result.field_status)
    end
    private_class_method :parse_image

    def parse_pdf(source)
      text = PdfExtractor.extract_text(source.value)
      text = PdfExtractor.ocr(source.value) if text.blank?

      fields = Extraction.empty_fields.merge(DeepSeekClient.structure_pdf(text))
      extraction = Extraction.new(markup_present: false, fields: fields, markup_dump: "")
      result = Gate.apply(fields: extraction.fields, state: text)

      build_result(result.gated_fields, result.field_status)
    end
    private_class_method :parse_pdf

    def build_image_extraction(data_uri)
      fields = Extraction.empty_fields.merge(DeepSeekClient.structure_image(data_uri))
      Extraction.new(markup_present: false, fields: fields, markup_dump: "")
    end
    private_class_method :build_image_extraction

    # Builds the evidence text Jev gates against. For images this is derived
    # from DeepSeek's own output (Jev cannot see pixels), so the image gate is
    # a consistency check on DeepSeek's JSON, not a source-presence check.
    def image_state(fields)
      state = fields.each_with_object([]) do |(field, value), lines|
        next if value.blank?

        lines << "#{field}: #{format_field_value(value)}"
      end.join("\n")
      state = "No recipe fields were extracted from the image." if state.blank?

      state
    end
    private_class_method :image_state

    def format_field_value(value)
      value.is_a?(Array) ? value.join(", ") : value.to_s
    end
    private_class_method :format_field_value

    # TODO(web_page/pdf): adopt this same no_recipe_found outcome when those
    # source types are refactored; currently scoped to images only.
    def recipe_absent?(fields)
      fields["name"].blank? &&
        Array(fields["ingredients"]).empty? &&
        Array(fields["instructions"]).empty?
    end
    private_class_method :recipe_absent?

    def build_result(fields, field_status)
      ParseResult.new(
        name: fields["name"],
        description: fields["description"],
        preparation_time: fields["preparation_time"],
        cooking_time: fields["cooking_time"],
        servings: fields["servings"],
        calories: fields["calories"],
        nutritional_information: fields["nutritional_information"],
        ingredients: normalize_ingredients(fields["ingredients"]),
        instructions: normalize_instructions(fields["instructions"]),
        field_status: field_status
      )
    end
    private_class_method :build_result

    def build_extraction(page)
      deterministic = DeterministicExtractor.extract(page.html)
      return deterministic if deterministic.markup_present

      fields = Extraction.empty_fields.merge(DeepSeekClient.structure(page.text))
      Extraction.new(markup_present: false, fields: fields, markup_dump: "")
    end
    private_class_method :build_extraction

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
