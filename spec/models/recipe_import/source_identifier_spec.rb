require "rails_helper"

RSpec.describe RecipeImport::SourceIdentifier do
  describe ".for" do
    it "uses the URL as the source_identifier for a web page" do
      url = "https://example.com/recipes/pancakes"

      expect(described_class.for(source_type: "web_page", source: url)).to eq(url)
    end

    it "rejects a non-HTTP web page source" do
      expect {
        described_class.for(source_type: "web_page", source: "not a url")
      }.to raise_error(RecipeImport::InvalidSource, /valid web page URL/i)
    end

    it "rejects an unsupported source type" do
      expect {
        described_class.for(source_type: "youtube", source: "https://youtu.be/abc123")
      }.to raise_error(RecipeImport::InvalidSource, /unsupported source_type/i)
    end
  end
end
