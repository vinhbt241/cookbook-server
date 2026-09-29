class CreateRecipeImportTables < ActiveRecord::Migration[8.1]
  def change
    create_table :original_recipes do |t|
      t.string :name
      t.text :description
      t.integer :preparation_time
      t.integer :cooking_time
      t.integer :servings
      t.integer :calories
      t.jsonb :nutritional_information
      t.text :notes
      t.string :original_source
      t.string :source_identifier, null: false
      t.datetime :parsed_at
      t.datetime :last_checked_at

      t.timestamps
    end
    add_index :original_recipes, :source_identifier, unique: true

    create_table :recipe_imports do |t|
      t.references :original_recipe, foreign_key: true, null: true
      t.string :source_identifier, null: false
      t.string :source_type, null: false
      t.text :source, null: false
      t.string :status, null: false, default: "processing"
      t.text :error

      t.timestamps
    end
    add_index :recipe_imports, :source_identifier

    create_table :original_recipe_ingredients do |t|
      t.references :original_recipe, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :quantity, precision: 10, scale: 3
      t.string :unit
      t.string :preparation
      t.boolean :optional, null: false, default: false
      t.text :notes

      t.timestamps
    end

    create_table :original_cooking_instructions do |t|
      t.references :original_recipe, null: false, foreign_key: true
      t.integer :position, null: false
      t.text :content, null: false

      t.timestamps
    end
    add_index :original_cooking_instructions, [ :original_recipe_id, :position ]
  end
end
