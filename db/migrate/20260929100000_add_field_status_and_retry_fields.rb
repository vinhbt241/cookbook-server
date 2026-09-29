class AddFieldStatusAndRetryFields < ActiveRecord::Migration[8.1]
  def change
    add_column :original_recipes, :field_status, :jsonb, default: {}, null: false
    add_column :recipe_imports, :error_code, :string
    add_column :recipe_imports, :retry_count, :integer, default: 0, null: false
  end
end
