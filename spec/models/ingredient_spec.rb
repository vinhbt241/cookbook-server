require "rails_helper"

RSpec.describe Ingredient, type: :model do
  subject { build(:ingredient) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_uniqueness_of(:name) }
  it { is_expected.to validate_presence_of(:calories_per_100g) }
  it { is_expected.to validate_numericality_of(:calories_per_100g).is_greater_than_or_equal_to(0) }

  describe "#grams_per" do
    it "returns the grams for a canonical unit" do
      ingredient = build(:ingredient, grams_per_unit: { "cup" => 125 })

      expect(ingredient.grams_per("cup")).to eq(125.0)
    end

    it "returns nil for an unknown unit" do
      ingredient = build(:ingredient, grams_per_unit: { "cup" => 125 })

      expect(ingredient.grams_per("clove")).to be_nil
    end
  end
end
