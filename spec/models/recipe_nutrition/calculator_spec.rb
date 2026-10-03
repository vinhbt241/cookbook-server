require "rails_helper"

RSpec.describe RecipeNutrition::Calculator do
  let!(:flour) { create(:ingredient, name: "flour", calories_per_100g: 364, grams_per_unit: { "cup" => 125 }) }
  let!(:milk) { create(:ingredient, name: "milk", calories_per_100g: 61, grams_per_unit: { "cup" => 244 }) }
  let!(:egg) { create(:ingredient, name: "egg", calories_per_100g: 143, grams_per_unit: { "piece" => 50 }) }

  def recipe_with(*ingredient_names, servings: 2)
    recipe = create(:original_recipe, servings: servings)
    ingredient_names.each { |name| create(:original_recipe_ingredient, original_recipe: recipe, name: name) }
    recipe
  end

  describe ".calculate" do
    it "computes per-serving calories across matched ingredients" do
      recipe = recipe_with("1 cup flour", "1 cup milk", "2 eggs")

      result = described_class.calculate(recipe)

      # flour 455 + milk 148.84 + eggs 143 = 746.84 → /2 = 373.42 → 373
      expect(result.status).to eq(:computed)
      expect(result.nutritional_information["calories"]).to eq(373)
      expect(result.unmatched_ingredients).to eq([])
      expect(result.assignments.size).to eq(3)
    end

    it "marks unmatched ingredients and returns partial" do
      recipe = recipe_with("1 cup flour", "1 cup unicorn dust")

      result = described_class.calculate(recipe)

      expect(result.status).to eq(:partial)
      expect(result.unmatched_ingredients).to eq([ "1 cup unicorn dust" ])
      expect(result.nutritional_information).not_to be_nil
    end

    it "is unavailable when nothing matches" do
      recipe = recipe_with("1 cup unicorn dust")

      result = described_class.calculate(recipe)

      expect(result.status).to eq(:unavailable)
      expect(result.nutritional_information).to be_nil
      expect(result.unmatched_ingredients).to eq([ "1 cup unicorn dust" ])
    end

    it "is unavailable when servings are missing" do
      recipe = recipe_with("1 cup flour", servings: nil)

      result = described_class.calculate(recipe)

      expect(result.status).to eq(:unavailable)
      expect(result.nutritional_information).to be_nil
    end

    it "is unavailable when there are no ingredients" do
      recipe = create(:original_recipe, servings: 2)

      result = described_class.calculate(recipe)

      expect(result.status).to eq(:unavailable)
      expect(result.nutritional_information).to be_nil
    end

    it "computes per-serving macros" do
      recipe = recipe_with("1 cup flour")

      result = described_class.calculate(recipe)

      # flour protein 10.3g/100g × 125g = 12.875 → /2 = 6.4 (rounded)
      expect(result.nutritional_information["protein"]).to eq(6.4)
      expect(result.nutritional_information["carbohydrates"]).to eq(47.7)
    end
  end
end
