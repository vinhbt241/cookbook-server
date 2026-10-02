require "rails_helper"

RSpec.describe RecipeImport::ImageDimensions do
  describe ".of" do
    it "reads a PNG's dimensions" do
      bytes = Base64.decode64(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
      )

      expect(described_class.of(bytes)).to eq([ 1, 1 ])
    end

    it "reads a GIF's dimensions" do
      bytes = "GIF89a".b + [ 2, 3 ].pack("v2")

      expect(described_class.of(bytes)).to eq([ 2, 3 ])
    end

    it "reads a JPEG's dimensions" do
      bytes = Base64.decode64(
        "/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AVN//2Q=="
      )

      expect(described_class.of(bytes)).to eq([ 1, 1 ])
    end

    it "reads a lossy WebP's dimensions" do
      bytes = Base64.decode64("UklGRiYAAABXRUJQVlA4IBoAAAAwAQCdASoBAAEAAUAmJaQAA3AA/vuUAAA=")

      expect(described_class.of(bytes)).to eq([ 1, 1 ])
    end

    it "reads a lossless WebP's dimensions" do
      bytes = Base64.decode64("UklGRhwAAABXRUJQVlA4TA8AAAAvAkAAAAcQ/Y/+ByKi/wEA")

      expect(described_class.of(bytes)).to eq([ 3, 2 ])
    end

    it "reads an extended WebP's dimensions" do
      bytes = Base64.decode64(
        "UklGRmIAAABXRUJQVlA4WAoAAAAQAAAAAwAABAAAQUxQSAoAAAABB1DAiAhERP8DVlA4IDIAAADQAQCdASoEAAUAAUAmJaACdLoB+AADsAD+6SIf+8+fufP3Pn/Rn/+U/fI4/kcf/KBAAA=="
      )

      expect(described_class.of(bytes)).to eq([ 4, 5 ])
    end

    it "returns nil for an unrecognised format" do
      expect(described_class.of("not an image")).to be_nil
    end

    it "returns nil for a truncated image header" do
      expect(described_class.of("GIF89a".b)).to be_nil
    end
  end
end
