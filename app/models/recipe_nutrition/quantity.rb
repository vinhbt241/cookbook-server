module RecipeNutrition
  # Parses a free-text ingredient line into a quantity, a canonical unit, and a
  # clean food name. The parse pipeline stores ingredients as a single free-text
  # `name` (e.g. "2 chicken breasts", "1/2 cup sugar"), so the nutrition stage
  # must split those three things back out before it can match an Ingredient.
  #
  # When no quantity is present (e.g. "salt to taste"), quantity and unit are
  # nil and the caller treats the ingredient as unquantifiable.
  module Quantity
    Parsed = Data.define(:quantity, :unit, :name)

    VOLUME_UNITS = {
      "cup" => "cup", "cups" => "cup",
      "tablespoon" => "tbsp", "tablespoons" => "tbsp", "tbsp" => "tbsp", "tbs" => "tbsp",
      "teaspoon" => "tsp", "teaspoons" => "tsp", "tsp" => "tsp",
      "milliliter" => "ml", "milliliters" => "ml", "millilitre" => "ml", "millilitres" => "ml", "ml" => "ml",
      "liter" => "l", "liters" => "l", "litre" => "l", "litres" => "l", "l" => "l"
    }.freeze

    WEIGHT_UNITS = {
      "gram" => "g", "grams" => "g", "g" => "g",
      "kilogram" => "kg", "kilograms" => "kg", "kg" => "kg",
      "ounce" => "oz", "ounces" => "oz", "oz" => "oz",
      "pound" => "lb", "pounds" => "lb", "lb" => "lb", "lbs" => "lb"
    }.freeze

    COUNT_UNITS = {
      "piece" => "piece", "pieces" => "piece", "pc" => "piece", "pcs" => "piece",
      "clove" => "clove", "cloves" => "clove",
      "slice" => "slice", "slices" => "slice",
      "stalk" => "stalk", "stalks" => "stalk",
      "sprig" => "sprig", "sprigs" => "sprig",
      "can" => "can", "cans" => "can",
      "stick" => "stick", "sticks" => "stick",
      "pinch" => "pinch", "dash" => "dash"
    }.freeze

    ALL_UNITS = VOLUME_UNITS.merge(WEIGHT_UNITS).merge(COUNT_UNITS).freeze

    FRACTIONS = { "½" => 0.5, "¼" => 0.25, "¾" => 0.75, "⅓" => 1.0 / 3.0, "⅔" => 2.0 / 3.0 }.freeze

    # "garlic, minced" -> "garlic"; "salt to taste" -> "salt".
    TAIL_PATTERN = /\b(to taste|for garnish|for serving|to serve|optional)\b.*\z/

    module_function

    def parse(text)
      string = text.to_s.downcase.strip
      return Parsed.new(quantity: nil, unit: nil, name: "") if string.empty?

      string = strip_tail(string)
      quantity, unit, remainder = extract_quantity_and_unit(string)

      if quantity.nil?
        Parsed.new(quantity: nil, unit: nil, name: clean_name(string))
      else
        Parsed.new(quantity: quantity, unit: unit || "piece", name: clean_name(remainder))
      end
    end

    def strip_tail(string)
      string.sub(/,.*\z/m, "").sub(TAIL_PATTERN, "").strip
    end
    private_class_method :strip_tail

    def clean_name(string)
      name = string.to_s.strip
      name.present? ? ActiveSupport::Inflector.singularize(name) : ""
    end
    private_class_method :clean_name

    def extract_quantity_and_unit(string)
      quantity, remainder = extract_number(string)
      return [ nil, nil, string ] if quantity.nil?

      unit, remainder = extract_unit(remainder)
      [ quantity, unit, remainder ]
    end
    private_class_method :extract_quantity_and_unit

    def extract_number(string)
      stripped = string.lstrip

      if (match = stripped.match(/\A(a|an|one)\b/i))
        return [ 1.0, stripped[match.end(0)..] ]
      elsif (match = stripped.match(/\A(\d+)\s+(\d+)\s*\/\s*(\d+)/))
        return [ match[1].to_f + match[2].to_f / match[3].to_f, stripped[match.end(0)..] ]
      elsif (match = stripped.match(/\A(\d+)\s*\/\s*(\d+)/))
        return [ match[1].to_f / match[2].to_f, stripped[match.end(0)..] ]
      elsif (match = stripped.match(/\A(\d+(?:\.\d+)?)/))
        return [ match[1].to_f, stripped[match.end(0)..] ]
      elsif (match = stripped.match(/\A([½¼¾⅓⅔])/))
        return [ FRACTIONS.fetch(match[1]), stripped[match.end(0)..] ]
      end

      [ nil, stripped ]
    end
    private_class_method :extract_number

    def extract_unit(remainder)
      stripped = remainder.lstrip

      [ "fl oz" ].each do |multi|
        if stripped.downcase.start_with?("#{multi} ")
          rest = stripped[multi.length..].lstrip.sub(/\Aof\s+/, "").strip
          return [ ALL_UNITS[multi], rest ]
        end
      end

      word = stripped[/\A([a-z]+)/, 1]
      return [ nil, stripped ] unless word && ALL_UNITS.key?(word)

      rest = stripped[word.length..].lstrip.sub(/\Aof\s+/, "").strip
      [ ALL_UNITS[word], rest ]
    end
    private_class_method :extract_unit
  end
end
