class AddNutritionFieldsToOriginalRecipes < ActiveRecord::Migration[8.1]
  def change
    add_column :original_recipes, :calculated_nutritional_information, :jsonb
    add_column :original_recipes, :nutrition_status, :integer, default: 0, null: false
    add_column :original_recipes, :unmatched_ingredients, :jsonb, default: [], null: false
  end
end
