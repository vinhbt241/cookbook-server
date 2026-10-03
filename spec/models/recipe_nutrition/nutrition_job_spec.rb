require "rails_helper"

RSpec.describe RecipeNutrition::NutritionJob do
  include ActiveJob::TestHelper

  let!(:flour) { create(:ingredient, name: "flour", calories_per_100g: 364, grams_per_unit: { "cup" => 125 }) }

  it "computes and persists calculated nutrition, backfilling ingredient links" do
    recipe = create(:original_recipe, servings: 2)
    ingredient = create(:original_recipe_ingredient, original_recipe: recipe, name: "1 cup flour")

    described_class.perform_now(recipe.id)

    recipe.reload
    expect(recipe.nutrition_status).to eq("computed")
    expect(recipe.calculated_nutritional_information["calories"]).to eq(228)
    expect(recipe.unmatched_ingredients).to eq([])

    ingredient.reload
    expect(ingredient.ingredient).to eq(flour)
    expect(ingredient.quantity).to eq(1.0)
    expect(ingredient.unit).to eq("cup")
  end

  it "is idempotent: skips when nutrition is not pending" do
    recipe = create(:original_recipe, servings: 2, nutrition_status: :computed)
    create(:original_recipe_ingredient, original_recipe: recipe, name: "1 cup flour")

    described_class.perform_now(recipe.id)

    recipe.reload
    expect(recipe.nutrition_status).to eq("computed")
    expect(recipe.calculated_nutritional_information).to be_nil
  end

  it "marks unavailable and never raises on failure" do
    recipe = create(:original_recipe, servings: 2)
    create(:original_recipe_ingredient, original_recipe: recipe, name: "1 cup flour")

    allow(RecipeNutrition::Calculator).to receive(:calculate).and_raise("boom")

    expect { described_class.perform_now(recipe.id) }.not_to raise_error

    recipe.reload
    expect(recipe.nutrition_status).to eq("unavailable")
  end

  it "does nothing when the original recipe is gone" do
    expect { described_class.perform_now(-1) }.not_to raise_error
  end
end
