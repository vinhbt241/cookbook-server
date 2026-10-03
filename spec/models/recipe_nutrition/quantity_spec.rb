require "rails_helper"

RSpec.describe RecipeNutrition::Quantity do
  describe ".parse" do
    def parsed(text)
      described_class.parse(text)
    end

    it "parses a count implied by the food noun" do
      result = parsed("2 chicken breasts")

      expect(result.quantity).to eq(2.0)
      expect(result.unit).to eq("piece")
      expect(result.name).to eq("chicken breast")
    end

    it "parses a volume unit" do
      result = parsed("1 cup flour")

      expect(result.quantity).to eq(1.0)
      expect(result.unit).to eq("cup")
      expect(result.name).to eq("flour")
    end

    it "parses a simple fraction" do
      result = parsed("1/2 cup sugar")

      expect(result.quantity).to be_within(0.001).of(0.5)
      expect(result.unit).to eq("cup")
      expect(result.name).to eq("sugar")
    end

    it "parses a mixed fraction" do
      result = parsed("1 1/2 cups flour")

      expect(result.quantity).to be_within(0.001).of(1.5)
      expect(result.unit).to eq("cup")
      expect(result.name).to eq("flour")
    end

    it "parses a decimal quantity" do
      result = parsed("1.5 cups flour")

      expect(result.quantity).to eq(1.5)
      expect(result.unit).to eq("cup")
      expect(result.name).to eq("flour")
    end

    it "parses a count noun with no explicit unit" do
      result = parsed("2 eggs")

      expect(result.quantity).to eq(2.0)
      expect(result.unit).to eq("piece")
      expect(result.name).to eq("egg")
    end

    it "parses a unit abbreviation" do
      result = parsed("1 tbsp olive oil")

      expect(result.quantity).to eq(1.0)
      expect(result.unit).to eq("tbsp")
      expect(result.name).to eq("olive oil")
    end

    it "strips preparation after a comma and parses a count unit" do
      result = parsed("2 cloves garlic, minced")

      expect(result.quantity).to eq(2.0)
      expect(result.unit).to eq("clove")
      expect(result.name).to eq("garlic")
    end

    it "parses a weight unit" do
      result = parsed("8 oz chicken")

      expect(result.quantity).to eq(8.0)
      expect(result.unit).to eq("oz")
      expect(result.name).to eq("chicken")
    end

    it "parses 'a' as one with an 'of' unit phrase" do
      result = parsed("a pinch of salt")

      expect(result.quantity).to eq(1.0)
      expect(result.unit).to eq("pinch")
      expect(result.name).to eq("salt")
    end

    it "returns no quantity for an unquantified line" do
      result = parsed("salt to taste")

      expect(result.quantity).to be_nil
      expect(result.unit).to be_nil
      expect(result.name).to eq("salt")
    end
  end
end
