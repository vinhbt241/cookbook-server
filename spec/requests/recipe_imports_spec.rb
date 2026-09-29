require "rails_helper"

RSpec.describe "RecipeImports", type: :request do
  include ActiveJob::TestHelper

  let(:url) { "https://example.com/recipes/pancakes" }

  let(:parse_result) do
    RecipeImport::Parser::ParseResult.new(
      name: "Parsed Pancakes",
      description: nil,
      preparation_time: 10,
      cooking_time: 20,
      servings: 4,
      calories: nil,
      nutritional_information: nil,
      ingredients: [ { name: "1 cup flour" } ],
      instructions: [ { position: 1, content: "Mix everything together." } ]
    )
  end

  before do
    allow(RecipeImport::Parser).to receive(:parse).and_return(parse_result)
  end

  def auth_headers(user)
    { "Authorization" => "Bearer #{Auth.issue_session_token(user)}" }
  end

  describe "POST /recipe-imports" do
    it "rejects unauthenticated requests" do
      post "/recipe-imports", params: { resource_type: "web_page", resource: url }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to eq("unauthorized")
    end

    it "rejects unconfirmed accounts" do
      user = create(:user, confirmed_at: nil)

      post "/recipe-imports", params: { resource_type: "web_page", resource: url }, as: :json,
        headers: auth_headers(user)

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)["error"]).to match(/confirm/i)
    end

    it "returns 202 with an import_id and processing status for a web page URL" do
      user = create(:user, confirmed_at: Time.current)

      post "/recipe-imports", params: { resource_type: "web_page", resource: url }, as: :json,
        headers: auth_headers(user)

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      expect(body["import_id"]).to be_present
      expect(body["status"]).to eq("processing")
    end

    it "rejects an invalid web page URL" do
      user = create(:user, confirmed_at: Time.current)

      post "/recipe-imports", params: { resource_type: "web_page", resource: "not a url" }, as: :json,
        headers: auth_headers(user)

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)["error"]).to match(/valid web page URL/i)
    end
  end

  describe "GET /recipe-imports/:id" do
    it "requires a confirmed account" do
      user = create(:user, confirmed_at: Time.current)
      post "/recipe-imports", params: { resource_type: "web_page", resource: url }, as: :json,
        headers: auth_headers(user)
      import_id = JSON.parse(response.body)["import_id"]

      get "/recipe-imports/#{import_id}"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 404 for an unknown import" do
      user = create(:user, confirmed_at: Time.current)

      get "/recipe-imports/999999", headers: auth_headers(user)

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["error"]).to match(/not found/i)
    end
  end

  describe "the submit → poll → done cycle" do
    it "reports processing, then done, with the parsed OriginalRecipe and field_status" do
      user = create(:user, confirmed_at: Time.current)

      post "/recipe-imports", params: { resource_type: "web_page", resource: url }, as: :json,
        headers: auth_headers(user)
      expect(response).to have_http_status(:accepted)
      import_id = JSON.parse(response.body)["import_id"]

      get "/recipe-imports/#{import_id}", headers: auth_headers(user)
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["status"]).to eq("processing")

      perform_enqueued_jobs

      expect(OriginalRecipe.count).to eq(1)
      expect(OriginalRecipeIngredient.count).to eq(1)
      expect(OriginalCookingInstruction.count).to eq(1)

      get "/recipe-imports/#{import_id}", headers: auth_headers(user)
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["status"]).to eq("done")

      original_recipe = body["original_recipe"]
      expect(original_recipe["name"]).to eq("Parsed Pancakes")
      expect(original_recipe["source_identifier"]).to eq(url)
      expect(original_recipe["ingredients"].first["name"]).to eq("1 cup flour")
      expect(original_recipe["instructions"].first["content"]).to eq("Mix everything together.")

      expect(body["field_status"]).to include(
        "name" => "found",
        "ingredients" => "found",
        "instructions" => "found",
        "preparation_time" => "found",
        "cooking_time" => "found",
        "servings" => "found",
        "description" => "not_found",
        "calories" => "not_found",
        "nutritional_information" => "not_found"
      )
    end
  end

  describe "the cache-hit path" do
    it "reuses the cached OriginalRecipe without re-running the pipeline" do
      user = create(:user, confirmed_at: Time.current)

      post "/recipe-imports", params: { resource_type: "web_page", resource: url }, as: :json,
        headers: auth_headers(user)
      expect(response).to have_http_status(:accepted)

      perform_enqueued_jobs
      expect(RecipeImport::Parser).to have_received(:parse).once
      original_recipe_id = OriginalRecipe.last.id

      post "/recipe-imports", params: { resource_type: "web_page", resource: url }, as: :json,
        headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("cached")
      expect(body["original_recipe"]["source_identifier"]).to eq(url)
      expect(body["field_status"]["name"]).to eq("found")

      expect(OriginalRecipe.count).to eq(1)
      expect(OriginalRecipe.last.id).to eq(original_recipe_id)
      expect(RecipeImport::Parser).to have_received(:parse).once
    end
  end
end
