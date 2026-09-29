# Asks Jev (TypeSafe System One) per-field presence questions.
#
# This is the adapter seam for Jev gating. The parse pipeline talks to this
# class and never reaches Faraday or the TypeSafe API directly.
class TypeSafeClient
  ENDPOINT = "https://api.typesafe.ai/v1/systemone"
  MODEL = "jev-latest"
  TIMEOUT = 30

  class Error < StandardError; end
  class ApiError < Error; end
  class TimeoutError < Error; end
  class InvalidResponse < Error; end

  def self.evaluate(state:, questions:)
    new.evaluate(state:, questions:)
  end

  # questions is a hash keyed by field name; values are TypeSafe question
  # objects. Returns a hash keyed by the same field names with noul scores.
  def evaluate(state:, questions:)
    response = connection.post(ENDPOINT) do |request|
      request.body = { state: state, model: MODEL, questions: questions }.to_json
    end

    raise ApiError, "TypeSafe API error: HTTP #{response.status}" unless response.success?

    body = JSON.parse(response.body)
    answers = body["answers"]
    raise InvalidResponse, "TypeSafe returned no answers" unless answers.is_a?(Hash)

    questions.keys.to_h do |question_id|
      answer = answers[question_id.to_s]
      unless answer.is_a?(Hash) && answer["type"] == "noul" && answer["noul"].is_a?(Numeric)
        raise InvalidResponse, "TypeSafe returned an invalid answer for #{question_id}"
      end

      [ question_id.to_s, answer["noul"].to_f ]
    end
  rescue Faraday::TimeoutError => e
    raise TimeoutError, e.message
  rescue JSON::ParserError => e
    raise InvalidResponse, "TypeSafe returned malformed JSON: #{e.message}"
  end

  private

  def connection
    @connection ||= Faraday.new do |conn|
      conn.options.timeout = TIMEOUT
      conn.options.open_timeout = TIMEOUT
      conn.headers["Content-Type"] = "application/json"
      conn.headers["Authorization"] = "Bearer #{api_key}"
      conn.adapter Faraday.default_adapter
    end
  end

  def api_key
    Rails.application.credentials.typesafe_api_key.presence ||
      raise(Error, "typesafe_api_key is not configured")
  end
end
