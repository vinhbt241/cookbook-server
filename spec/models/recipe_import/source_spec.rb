require "rails_helper"

RSpec.describe RecipeImport::Source do
  describe "#identifier" do
    it "uses the source_identifier mapping for the source type" do
      url = "https://example.com/recipes/pancakes"
      source = described_class.new(type: "web_page", value: url)

      expect(source.identifier).to eq(url)
    end
  end

  describe "#value" do
    it "turns an uploaded image into a data URI" do
      upload = instance_double("UploadedFile", read: "photo-bytes", content_type: "image/png")
      source = described_class.new(type: "image", value: upload)

      expect(source.value).to eq("data:image/png;base64,#{Base64.strict_encode64("photo-bytes")}")
    end

    it "turns an uploaded pdf into a data URI" do
      upload = instance_double("UploadedFile", read: "pdf-bytes", content_type: "application/pdf")
      source = described_class.new(type: "pdf", value: upload)

      expect(source.value).to eq("data:application/pdf;base64,#{Base64.strict_encode64("pdf-bytes")}")
    end

    it "keeps an already-normalized image data URI" do
      data_uri = "data:image/png;base64,cGhvdG8="
      source = described_class.new(type: "image", value: data_uri)

      expect(source.value).to eq(data_uri)
    end

    it "stringifies non-image sources" do
      source = described_class.new(type: "web_page", value: :url)

      expect(source.value).to eq("url")
    end
  end
end
