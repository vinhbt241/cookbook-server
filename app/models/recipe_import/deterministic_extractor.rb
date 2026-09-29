module RecipeImport
  # Extracts schema.org Recipe markup from an HTML document.
  #
  # Markup is considered present when a schema.org Recipe appears in JSON-LD
  # (including @graph and nested @type arrays) or in microdata. Meta tags are
  # never a trigger on their own; they only supplement name/description once
  # markup is found.
  module DeterministicExtractor
    module_function

    def extract(html)
      doc = Nokogiri::HTML(html)

      json_ld = extract_json_ld(doc)
      if json_ld
        fields = supplement_from_meta(normalize_json_ld(json_ld), doc)
        return Extraction.new(
          markup_present: true,
          fields: fields,
          markup_dump: JSON.generate(json_ld)
        )
      end

      microdata, nutrition = extract_microdata(doc)
      if microdata
        fields = supplement_from_meta(normalize_microdata(microdata, nutrition), doc)
        return Extraction.new(
          markup_present: true,
          fields: fields,
          markup_dump: dump_microdata(microdata, nutrition)
        )
      end

      Extraction.new(markup_present: false, fields: Extraction.empty_fields, markup_dump: "")
    end

    def extract_json_ld(doc)
      doc.css('script[type="application/ld+json"]').each do |script|
        text = script.text.to_s.strip
        next if text.blank?

        recipe = find_recipe(JSON.parse(text))
        return recipe if recipe
      rescue JSON::ParserError
        next
      end
      nil
    end
    private_class_method :extract_json_ld

    def find_recipe(node)
      case node
      when Hash
        return node if recipe_type?(node["@type"])

        node.each_value do |value|
          recipe = find_recipe(value)
          return recipe if recipe
        end
      when Array
        node.each do |value|
          recipe = find_recipe(value)
          return recipe if recipe
        end
      end
      nil
    end
    private_class_method :find_recipe

    def recipe_type?(type)
      case type
      when String
        type == "Recipe" || type.end_with?("/Recipe")
      when Array
        type.any? { |entry| recipe_type?(entry) }
      else
        false
      end
    end
    private_class_method :recipe_type?

    def normalize_json_ld(recipe)
      fields = Extraction.empty_fields
      fields["name"] = string_value(recipe["name"])
      fields["description"] = string_value(recipe["description"])
      fields["ingredients"] = string_array(recipe["recipeIngredient"])
      fields["instructions"] = normalize_instructions(recipe["recipeInstructions"])
      fields["preparation_time"] = Iso8601Duration.to_minutes(string_value(recipe["prepTime"]))
      fields["cooking_time"] = Iso8601Duration.to_minutes(string_value(recipe["cookTime"]))
      fields["servings"] = parse_servings(recipe["recipeYield"])
      fields["calories"], fields["nutritional_information"] = extract_nutrition(recipe)
      fields
    end
    private_class_method :normalize_json_ld

    def extract_microdata(doc)
      recipe_node = doc.at_css('[itemtype*="schema.org/Recipe"]')
      return nil unless recipe_node

      properties = scoped_properties(recipe_node)
      nutrition_node = recipe_node.at_css('[itemtype*="schema.org/NutritionInformation"]')
      nutrition = nutrition_node ? scoped_properties(nutrition_node) : nil
      [ properties, nutrition ]
    end
    private_class_method :extract_microdata

    def scoped_properties(scope)
      scope.css("[itemprop]").each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |node, properties|
        next if nested_itemprop?(scope, node)

        properties[node["itemprop"].to_s.strip] << microdata_value(node)
      end
    end
    private_class_method :scoped_properties

    def nested_itemprop?(scope, node)
      node.ancestors.each do |ancestor|
        break if ancestor == scope

        return true if ancestor["itemprop"].present?
      end
      false
    end
    private_class_method :nested_itemprop?

    def microdata_value(node)
      node["content"].presence || node["datetime"].presence || node.text.strip
    end
    private_class_method :microdata_value

    def normalize_microdata(properties, nutrition)
      fields = Extraction.empty_fields
      fields["name"] = first(properties["name"])
      fields["description"] = first(properties["description"])
      fields["ingredients"] = Array(properties["recipeIngredient"]).map(&:strip).select(&:present?)
      fields["instructions"] = Array(properties["recipeInstructions"]).map(&:strip).select(&:present?)
      fields["preparation_time"] = Iso8601Duration.to_minutes(first(properties["prepTime"]))
      fields["cooking_time"] = Iso8601Duration.to_minutes(first(properties["cookTime"]))
      fields["servings"] = parse_servings(first(properties["recipeYield"]))
      fields["calories"] = numeric_value(first(properties["calories"]))

      if nutrition
        nutritional_information = nutrition.transform_values { |values| values.first }
        fields["nutritional_information"] = nutritional_information
        fields["calories"] ||= numeric_value(nutritional_information["calories"])
      end

      fields
    end
    private_class_method :normalize_microdata

    def dump_microdata(properties, nutrition)
      lines = [ "itemtype: https://schema.org/Recipe" ]
      properties.each do |name, values|
        values.each { |value| lines << "#{name}: #{value}" }
      end
      if nutrition
        lines << "nutrition:"
        nutrition.each { |name, values| lines << "  #{name}: #{values.first}" }
      end
      lines.join("\n")
    end
    private_class_method :dump_microdata

    def supplement_from_meta(fields, doc)
      if fields["name"].blank?
        fields["name"] = doc.at_css('meta[property="og:title"]')&.[]("content")&.strip
      end
      if fields["description"].blank?
        meta = doc.at_css('meta[name="description"]') || doc.at_css('meta[property="og:description"]')
        fields["description"] = meta&.[]("content")&.strip
      end
      fields
    end
    private_class_method :supplement_from_meta

    def normalize_instructions(value)
      Array(value).filter_map do |item|
        case item
        when String
          item.strip.presence
        when Hash
          (item["text"].presence || item["name"].presence)&.strip
        end
      end
    end
    private_class_method :normalize_instructions

    def string_value(value)
      value = value.first if value.is_a?(Array)
      value.to_s.strip.presence
    end
    private_class_method :string_value

    def string_array(value)
      Array(value).filter_map do |item|
        item = item["name"] if item.is_a?(Hash) && item["name"].present?
        item.to_s.strip.presence
      end
    end
    private_class_method :string_array

    def parse_servings(value)
      text = Array(value).first.to_s
      text[/\d+/]&.to_i
    end
    private_class_method :parse_servings

    def extract_nutrition(recipe)
      nutrition = recipe["nutrition"]
      calories = nil
      nutritional_information = nil

      if nutrition.is_a?(Hash)
        calories = numeric_value(nutrition["calories"])
        nutritional_information = nutrition
      end
      calories ||= numeric_value(recipe["calories"])

      [ calories, nutritional_information ]
    end
    private_class_method :extract_nutrition

    def numeric_value(value)
      value = value.first if value.is_a?(Array)
      value = value["calories"] if value.is_a?(Hash) && value["calories"].present?
      value.to_s[/\d+/]&.to_i
    end
    private_class_method :numeric_value

    def first(values)
      Array(values).first
    end
    private_class_method :first
  end
end
