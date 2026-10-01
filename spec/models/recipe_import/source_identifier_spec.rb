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

    it "uses the SHA-256 content hash as the source_identifier for an image" do
      data_uri = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="

      expect(described_class.for(source_type: "image", source: data_uri))
        .to eq("431ced6916a2a21a156e38701afe55bbd7f88969fbbfc56d7fe099d47f265460")
    end

    it "rejects a non-image data URI" do
      expect {
        described_class.for(source_type: "image", source: "data:text/plain;base64,aGVsbG8=")
      }.to raise_error(RecipeImport::InvalidSource, /image file/i)
    end

    it "rejects an empty image source" do
      expect {
        described_class.for(source_type: "image", source: nil)
      }.to raise_error(RecipeImport::InvalidSource, /image file/i)
    end

    it "rejects an unsupported source type" do
      expect {
        described_class.for(source_type: "youtube", source: "https://youtu.be/abc123")
      }.to raise_error(RecipeImport::InvalidSource, /unsupported source_type/i)
    end
  end
end
