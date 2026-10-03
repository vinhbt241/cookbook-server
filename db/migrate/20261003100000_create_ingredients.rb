class CreateIngredients < ActiveRecord::Migration[8.1]
  def change
    create_table :ingredients do |t|
      t.string :name, null: false
      t.decimal :calories_per_100g, precision: 8, scale: 2, null: false
      t.jsonb :nutritional_information_per_100g, default: {}, null: false
      t.jsonb :grams_per_unit, default: {}, null: false

      t.timestamps
    end
    add_index :ingredients, :name, unique: true
  end
end
