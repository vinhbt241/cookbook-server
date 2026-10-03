require "rails_helper"

RSpec.describe "Recipe import nutrition", type: :request do
  include ActiveJob::TestHelper

  def auth_headers(user)
    { "Authorization" => "Bearer #{Auth.issue_session_token(user)}" }
  end

  def upload_recipe_image
    Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/recipe_photo.png"), "image/png")
  end

  before do
    allow(TypeSafeClient).to receive(:evaluate).and_return(RecipeImport::FIELD_NAMES.index_with { 0.99 })
  end

  it "computes calculated nutrition after parse and exposes it on the original_recipe" do
    user = create(:user, confirmed_at: Time.current)
    create(:ingredient, name: "flour", calories_per_100g: 364, grams_per_unit: { "cup" => 125 })
    create(:ingredient, name: "milk", calories_per_100g: 61, grams_per_unit: { "cup" => 244 })
    create(:ingredient, name: "egg", calories_per_100g: 143, grams_per_unit: { "piece" => 50 })

    allow(DeepSeekClient).to receive(:structure_image).and_return(
      "name" => "Pancakes",
      "ingredients" => [ "1 cup flour", "1 cup milk", "2 eggs" ],
      "instructions" => [ "Mix and cook." ],
      "servings" => 2
    )

    import_id = nil
    perform_enqueued_jobs do
      post "/recipe-imports", params: { source_type: "image", source: upload_recipe_image },
        headers: auth_headers(user)
      import_id = JSON.parse(response.body)["import_id"]
    end

    get "/recipe-imports/#{import_id}", headers: auth_headers(user)
    original_recipe = JSON.parse(response.body)["original_recipe"]

    expect(original_recipe["nutrition_status"]).to eq("computed")
    expect(original_recipe["calculated_nutritional_information"]["calories"]).to eq(373)
    expect(original_recipe["unmatched_ingredients"]).to eq([])
  end
end
