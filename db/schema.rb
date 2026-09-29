# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_29_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "original_cooking_instructions", force: :cascade do |t|
    t.bigint "original_recipe_id", null: false
    t.integer "position", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["original_recipe_id", "position"], name: "idx_on_original_recipe_id_position_136e837daf"
    t.index ["original_recipe_id"], name: "index_original_cooking_instructions_on_original_recipe_id"
  end

  create_table "original_recipe_ingredients", force: :cascade do |t|
    t.bigint "original_recipe_id", null: false
    t.string "name", null: false
    t.decimal "quantity", precision: 10, scale: 3
    t.string "unit"
    t.string "preparation"
    t.boolean "optional", default: false, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["original_recipe_id"], name: "index_original_recipe_ingredients_on_original_recipe_id"
  end

  create_table "original_recipes", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.integer "preparation_time"
    t.integer "cooking_time"
    t.integer "servings"
    t.integer "calories"
    t.jsonb "nutritional_information"
    t.text "notes"
    t.string "original_source"
    t.string "source_identifier", null: false
    t.datetime "parsed_at"
    t.datetime "last_checked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_identifier"], name: "index_original_recipes_on_source_identifier", unique: true
  end

  create_table "recipe_imports", force: :cascade do |t|
    t.bigint "original_recipe_id"
    t.string "source_identifier", null: false
    t.string "source_type", null: false
    t.text "source", null: false
    t.integer "status", default: 0, null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["original_recipe_id"], name: "index_recipe_imports_on_original_recipe_id"
    t.index ["source_identifier"], name: "index_recipe_imports_on_source_identifier"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "original_cooking_instructions", "original_recipes"
  add_foreign_key "original_recipe_ingredients", "original_recipes"
  add_foreign_key "recipe_imports", "original_recipes"
end
