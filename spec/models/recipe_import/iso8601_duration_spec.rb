require "rails_helper"

RSpec.describe RecipeImport::Iso8601Duration do
  describe ".to_minutes" do
    it "parses a minutes-only duration" do
      expect(described_class.to_minutes("PT30M")).to eq(30)
    end

    it "parses hours and minutes into total minutes" do
      expect(described_class.to_minutes("PT1H30M")).to eq(90)
    end

    it "parses days" do
      expect(described_class.to_minutes("P1D")).to eq(1440)
    end

    it "rounds seconds to the nearest minute" do
      expect(described_class.to_minutes("PT90S")).to eq(2)
    end

    it "returns nil for blank or non-ISO values" do
      expect(described_class.to_minutes(nil)).to be_nil
      expect(described_class.to_minutes("")).to be_nil
      expect(described_class.to_minutes("30 minutes")).to be_nil
    end
  end
end
