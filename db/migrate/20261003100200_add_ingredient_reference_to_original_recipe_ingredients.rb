class AddIngredientReferenceToOriginalRecipeIngredients < ActiveRecord::Migration[8.1]
  def change
    add_reference :original_recipe_ingredients, :ingredient, foreign_key: true, null: true
  end
end
