require "rails_helper"

RSpec.describe RecipeImport::Source do
  describe "#identifier" do
    it "uses the source_identifier mapping for the source type" do
      url = "https://example.com/recipes/pancakes"
      source = described_class.new(type: "web_page", value: url)

      expect(source.identifier).to eq(url)
    end
  end
end
