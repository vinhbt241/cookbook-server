require "rails_helper"

RSpec.describe RecipeNutrition::Matcher do
  describe ".match" do
    it "matches a pluralized name to the canonical Ingredient" do
      chicken = create(:ingredient, name: "chicken breast")

      expect(described_class.match("chicken breasts")).to eq(chicken)
    end

    it "matches a clean name exactly" do
      flour = create(:ingredient, name: "flour")

      expect(described_class.match("flour")).to eq(flour)
    end

    it "normalizes case and whitespace" do
      butter = create(:ingredient, name: "butter")

      expect(described_class.match("  BUTTER  ")).to eq(butter)
    end

    it "returns nil for an unknown name" do
      expect(described_class.match("unicorn")).to be_nil
    end
  end
end
