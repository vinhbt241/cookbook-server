module RecipeImport
  # Parses the ISO 8601 duration subset used by schema.org recipes
  # (for example PT30M, PT1H30M, or P1DT2H) into whole minutes.
  module Iso8601Duration
    PATTERN = /\AP(?:(?<days>\d+(?:\.\d+)?)D)?(?:T(?:(?<hours>\d+(?:\.\d+)?)H)?(?:(?<minutes>\d+(?:\.\d+)?)M)?(?:(?<seconds>\d+(?:\.\d+)?)S)?)?\z/i

    module_function

    def to_minutes(value)
      return nil if value.blank?

      match = PATTERN.match(value.to_s.strip)
      return nil unless match

      days = match[:days].to_f
      hours = match[:hours].to_f
      minutes = match[:minutes].to_f
      seconds = match[:seconds].to_f
      return nil if [ days, hours, minutes, seconds ].all?(&:zero?)

      total = (days * 24 * 60) + (hours * 60) + minutes + (seconds / 60.0)
      total.round
    end
  end
end
