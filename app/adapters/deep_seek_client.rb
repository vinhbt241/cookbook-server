# Structures recipe text with DeepSeek's OpenAI-compatible chat endpoint.
#
# This is the adapter seam for the DeepSeek fallback. The parse pipeline talks
# to this class and never reaches Faraday or the DeepSeek API directly.
class DeepSeekClient
  BASE_URL = "https://api.deepseek.com"
  CHAT_PATH = "/chat/completions"
  MODEL = "deepseek-flash"
  TIMEOUT = 30

  FIELD_NAMES = RecipeImport::FIELD_NAMES

  FIELD_TYPES = {
    "name" => [ String, NilClass ],
    "description" => [ String, NilClass ],
    "ingredients" => [ Array, NilClass ],
    "instructions" => [ Array, NilClass ],
    "preparation_time" => [ Integer, NilClass ],
    "cooking_time" => [ Integer, NilClass ],
    "servings" => [ Integer, NilClass ],
    "calories" => [ Integer, NilClass ],
    "nutritional_information" => [ Hash, NilClass ]
  }.freeze

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You extract recipe data from the plain text of a web page.
    Return a JSON object with only these keys. Use null or omit a key when the
    value is absent. Never invent values.
    - name: string
    - description: string
    - ingredients: array of strings
    - instructions: array of strings, in cooking order
    - preparation_time: integer minutes
    - cooking_time: integer minutes
    - servings: integer
    - calories: integer
    - nutritional_information: object
  PROMPT

  VISION_SYSTEM_PROMPT = <<~PROMPT.freeze
    You extract recipe data from a photo of a recipe.
    Return a JSON object with only these keys. Use null or omit a key when the
    value is absent. Never invent values.
    - name: string
    - description: string
    - ingredients: array of strings
    - instructions: array of strings, in cooking order
    - preparation_time: integer minutes
    - cooking_time: integer minutes
    - servings: integer
    - calories: integer
    - nutritional_information: object
  PROMPT

  class Error < StandardError; end
  class ApiError < Error; end
  class TimeoutError < Error; end
  class InvalidResponse < Error; end

  def self.structure(text)
    new.structure(text)
  end

  def self.structure_image(data_uri)
    new.structure_image(data_uri)
  end

  def structure(text)
    parse_structure_response do
      post_structure_request([
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: text.to_s }
      ])
    end
  end

  def structure_image(data_uri)
    parse_structure_response do
      post_structure_request([
        { role: "system", content: VISION_SYSTEM_PROMPT },
        { role: "user", content: [
          { type: "text", text: "Extract the recipe from this image." },
          { type: "image_url", image_url: { url: data_uri } }
        ] }
      ])
    end
  end

  private

  def post_structure_request(messages)
    connection.post(CHAT_PATH) do |request|
      request.body = {
        model: MODEL,
        response_format: { type: "json_object" },
        messages: messages
      }.to_json
    end
  end

  def parse_structure_response
    response = yield

    raise ApiError, "DeepSeek API error: HTTP #{response.status}" unless response.success?

    body = JSON.parse(response.body)
    content = body.dig("choices", 0, "message", "content")
    raise InvalidResponse, "DeepSeek returned no content" if content.blank?

    fields = JSON.parse(content)
    validate_fields!(fields)
  rescue Faraday::TimeoutError => e
    raise TimeoutError, e.message
  rescue JSON::ParserError => e
    raise InvalidResponse, "DeepSeek returned malformed JSON: #{e.message}"
  end

  def connection
    @connection ||= Faraday.new(url: BASE_URL) do |conn|
      conn.options.timeout = TIMEOUT
      conn.options.open_timeout = TIMEOUT
      conn.headers["Content-Type"] = "application/json"
      conn.headers["Authorization"] = "Bearer #{api_key}"
      conn.adapter Faraday.default_adapter
    end
  end

  def api_key
    Rails.application.credentials.deep_seek_api_key.presence ||
      raise(Error, "deep_seek_api_key is not configured")
  end

  def validate_fields!(fields)
    raise InvalidResponse, "DeepSeek returned a non-object response" unless fields.is_a?(Hash)

    fields = fields.stringify_keys
    unknown = fields.keys - FIELD_NAMES
    unless unknown.empty?
      raise InvalidResponse, "DeepSeek returned unknown fields: #{unknown.join(', ')}"
    end

    fields.each do |key, value|
      unless FIELD_TYPES.fetch(key).any? { |type| value.is_a?(type) }
        raise InvalidResponse, "DeepSeek returned an invalid type for #{key}: #{value.class}"
      end
    end

    validate_string_array!(fields["ingredients"], "ingredients")
    validate_string_array!(fields["instructions"], "instructions")

    fields
  end

  def validate_string_array!(value, field)
    return unless value.is_a?(Array)
    return if value.all? { |entry| entry.is_a?(String) }

    raise InvalidResponse, "DeepSeek returned a non-string entry in #{field}"
  end
end
