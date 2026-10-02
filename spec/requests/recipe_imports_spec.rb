require "rails_helper"
require "digest"

RSpec.describe "RecipeImports", type: :request do
  include ActiveJob::TestHelper

  let(:url) { "https://example.com/recipes/pancakes" }

  let(:all_found_scores) do
    RecipeImport::FIELD_NAMES.index_with { 0.99 }
  end

  let(:all_found_status) do
    RecipeImport::FIELD_NAMES.index_with { "found" }
  end

  def fixture_html(name)
    Rails.root.join("spec/fixtures/recipes/#{name}.html").read
  end

  def stub_fetch(name, text:)
    html = fixture_html(name)
    allow(WebPageFetcher).to receive(:fetch).and_return(
      WebPageFetcher::Page.new(html: html, text: text, content_type: "text/html")
    )
  end

  def auth_headers(user)
    { "Authorization" => "Bearer #{Auth.issue_session_token(user)}" }
  end

  def upload_recipe_image
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/recipe_photo.png"),
      "image/png"
    )
  end

  def recipe_image_content_hash
    Digest::SHA256.hexdigest(File.binread(Rails.root.join("spec/fixtures/files/recipe_photo.png")))
  end

  def upload_recipe_pdf
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/recipe.pdf"),
      "application/pdf"
    )
  end

  def recipe_pdf_content_hash
    Digest::SHA256.hexdigest(File.binread(Rails.root.join("spec/fixtures/files/recipe.pdf")))
  end

  before do
    allow(TypeSafeClient).to receive(:evaluate).and_return(all_found_scores)
    allow(DeepSeekClient).to receive(:structure).and_raise("DeepSeek should not be called")
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

  describe "POST /recipe-imports with an image upload" do
    it "returns 202 with an import_id and processing status for an image upload" do
      user = create(:user, confirmed_at: Time.current)

      post "/recipe-imports", params: { resource_type: "image", resource: upload_recipe_image },
        headers: auth_headers(user)

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      expect(body["import_id"]).to be_present
      expect(body["status"]).to eq("processing")
    end

    it "structures the image through DeepSeek vision and blanks fields Jev judges not_found" do
      user = create(:user, confirmed_at: Time.current)
      allow(DeepSeekClient).to receive(:structure_image).and_return(
        "name" => "Photo Pancakes",
        "ingredients" => [ "1 cup flour", "1 cup milk", "2 eggs" ],
        "instructions" => [ "Mix everything.", "Cook until golden." ],
        "preparation_time" => 5,
        "cooking_time" => 15,
        "servings" => 2
      )
      allow(TypeSafeClient).to receive(:evaluate).and_return(
        all_found_scores.merge("calories" => 0.1, "nutritional_information" => 0.1)
      )

      post "/recipe-imports", params: { resource_type: "image", resource: upload_recipe_image },
        headers: auth_headers(user)
      import_id = JSON.parse(response.body)["import_id"]

      perform_enqueued_jobs

      expect(DeepSeekClient).to have_received(:structure_image).once

      get "/recipe-imports/#{import_id}", headers: auth_headers(user)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("done")

      original_recipe = body["original_recipe"]
      expect(original_recipe["name"]).to eq("Photo Pancakes")
      expect(original_recipe["ingredients"].map { |ingredient| ingredient["name"] })
        .to eq([ "1 cup flour", "1 cup milk", "2 eggs" ])
      expect(original_recipe["instructions"].map { |instruction| instruction["content"] })
        .to eq([ "Mix everything.", "Cook until golden." ])
      expect(original_recipe["preparation_time"]).to eq(5)
      expect(original_recipe["cooking_time"]).to eq(15)
      expect(original_recipe["servings"]).to eq(2)
      expect(original_recipe["calories"]).to be_nil
      expect(body["field_status"]).to include(
        "name" => "found",
        "calories" => "not_found",
        "nutritional_information" => "not_found"
      )
    end

    it "uses the image content hash as source_identifier and re-imports the same file from cache" do
      user = create(:user, confirmed_at: Time.current)
      allow(DeepSeekClient).to receive(:structure_image).and_return("name" => "Photo Pancakes")

      post "/recipe-imports", params: { resource_type: "image", resource: upload_recipe_image },
        headers: auth_headers(user)
      expect(response).to have_http_status(:accepted)

      perform_enqueued_jobs

      original_recipe = OriginalRecipe.last
      expect(original_recipe.source_identifier).to eq(recipe_image_content_hash)
      expect(original_recipe.original_source).to eq(recipe_image_content_hash)
      expect(DeepSeekClient).to have_received(:structure_image).once

      post "/recipe-imports", params: { resource_type: "image", resource: upload_recipe_image },
        headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("cached")
      expect(body["original_recipe"]["source_identifier"]).to eq(recipe_image_content_hash)

      expect(OriginalRecipe.count).to eq(1)
      expect(DeepSeekClient).to have_received(:structure_image).once
    end

    it "rejects an image upload that is not an image" do
      user = create(:user, confirmed_at: Time.current)
      upload = Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/recipes/no_markup_text.html"),
        "text/html"
      )

      post "/recipe-imports", params: { resource_type: "image", resource: upload },
        headers: auth_headers(user)

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)["error"]).to match(/image file/i)
    end

    it "rejects an image larger than the size limit" do
      user = create(:user, confirmed_at: Time.current)
      stub_const("RecipeImport::SourceIdentifier::MAX_IMAGE_BYTES", 10)

      post "/recipe-imports", params: { resource_type: "image", resource: upload_recipe_image },
        headers: auth_headers(user)

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)["error"]).to match(/too large/i)
    end

    it "marks the import failed with no_recipe_found when the image yields no recipe" do
      user = create(:user, confirmed_at: Time.current)
      allow(DeepSeekClient).to receive(:structure_image).and_return(
        "name" => nil, "ingredients" => [], "instructions" => []
      )
      allow(TypeSafeClient).to receive(:evaluate).and_return(
        RecipeImport::FIELD_NAMES.index_with { 0.1 }
      )

      post "/recipe-imports", params: { resource_type: "image", resource: upload_recipe_image },
        headers: auth_headers(user)
      import_id = JSON.parse(response.body)["import_id"]

      perform_enqueued_jobs

      get "/recipe-imports/#{import_id}", headers: auth_headers(user)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("failed")
      expect(body["error_code"]).to eq("no_recipe_found")
      expect(body["retryable"]).to be(false)
    end
  end

  describe "POST /recipe-imports with a PDF upload" do
    let(:pdf_text) { "Fluffy Pancakes need flour, milk, and eggs." }

    it "returns 202 with an import_id and processing status for a PDF upload" do
      user = create(:user, confirmed_at: Time.current)

      post "/recipe-imports", params: { resource_type: "pdf", resource: upload_recipe_pdf },
        headers: auth_headers(user)

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      expect(body["import_id"]).to be_present
      expect(body["status"]).to eq("processing")
    end

    it "rejects a PDF upload that is not a PDF" do
      user = create(:user, confirmed_at: Time.current)
      upload = Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/recipes/no_markup_text.html"),
        "text/html"
      )

      post "/recipe-imports", params: { resource_type: "pdf", resource: upload },
        headers: auth_headers(user)

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)["error"]).to match(/PDF file/i)
    end

    it "extracts a PDF text layer directly and structures it through DeepSeek without OCR" do
      user = create(:user, confirmed_at: Time.current)
      allow(PdfExtractor).to receive(:extract_text).and_return(pdf_text)
      allow(PdfExtractor).to receive(:ocr).and_return("")
      allow(DeepSeekClient).to receive(:structure_pdf).and_return(
        "name" => "PDF Pancakes",
        "description" => "Fluffy pancakes from a PDF.",
        "ingredients" => [ "1 cup flour", "1 cup milk", "2 eggs" ],
        "instructions" => [ "Mix everything.", "Cook until golden." ],
        "preparation_time" => 5,
        "cooking_time" => 15,
        "servings" => 2
      )

      post "/recipe-imports", params: { resource_type: "pdf", resource: upload_recipe_pdf },
        headers: auth_headers(user)
      import_id = JSON.parse(response.body)["import_id"]

      perform_enqueued_jobs

      expect(PdfExtractor).to have_received(:extract_text).once
      expect(PdfExtractor).not_to have_received(:ocr)
      expect(DeepSeekClient).to have_received(:structure_pdf).once.with(pdf_text)

      get "/recipe-imports/#{import_id}", headers: auth_headers(user)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("done")

      original_recipe = body["original_recipe"]
      expect(original_recipe["name"]).to eq("PDF Pancakes")
      expect(original_recipe["description"]).to eq("Fluffy pancakes from a PDF.")
      expect(original_recipe["ingredients"].map { |ingredient| ingredient["name"] })
        .to eq([ "1 cup flour", "1 cup milk", "2 eggs" ])
      expect(original_recipe["instructions"].map { |instruction| instruction["content"] })
        .to eq([ "Mix everything.", "Cook until golden." ])
      expect(original_recipe["preparation_time"]).to eq(5)
      expect(original_recipe["cooking_time"]).to eq(15)
      expect(original_recipe["servings"]).to eq(2)
    end

    it "falls back to OCR for a scanned PDF with no text layer" do
      user = create(:user, confirmed_at: Time.current)
      ocr_text = "Scanned Pancakes: mix flour, milk, and eggs, then cook."
      allow(PdfExtractor).to receive(:extract_text).and_return("")
      allow(PdfExtractor).to receive(:ocr).and_return(ocr_text)
      allow(DeepSeekClient).to receive(:structure_pdf).and_return(
        "name" => "Scanned Pancakes",
        "ingredients" => [ "1 cup flour", "1 cup milk", "2 eggs" ],
        "instructions" => [ "Mix everything.", "Cook until golden." ]
      )

      post "/recipe-imports", params: { resource_type: "pdf", resource: upload_recipe_pdf },
        headers: auth_headers(user)
      import_id = JSON.parse(response.body)["import_id"]

      perform_enqueued_jobs

      expect(PdfExtractor).to have_received(:extract_text).once
      expect(PdfExtractor).to have_received(:ocr).once
      expect(DeepSeekClient).to have_received(:structure_pdf).once.with(ocr_text)

      get "/recipe-imports/#{import_id}", headers: auth_headers(user)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("done")
      expect(body["original_recipe"]["name"]).to eq("Scanned Pancakes")
    end

    it "blanks fields Jev judges not_found for a PDF" do
      user = create(:user, confirmed_at: Time.current)
      allow(PdfExtractor).to receive(:extract_text).and_return(pdf_text)
      allow(DeepSeekClient).to receive(:structure_pdf).and_return(
        "name" => "PDF Pancakes",
        "calories" => 350
      )
      allow(TypeSafeClient).to receive(:evaluate).and_return(
        all_found_scores.merge("calories" => 0.1, "description" => 0.1)
      )

      post "/recipe-imports", params: { resource_type: "pdf", resource: upload_recipe_pdf },
        headers: auth_headers(user)
      import_id = JSON.parse(response.body)["import_id"]

      perform_enqueued_jobs

      get "/recipe-imports/#{import_id}", headers: auth_headers(user)
      body = JSON.parse(response.body)
      original_recipe = body["original_recipe"]

      expect(original_recipe["name"]).to eq("PDF Pancakes")
      expect(original_recipe["calories"]).to be_nil
      expect(original_recipe["description"]).to be_nil
      expect(body["field_status"]).to include(
        "name" => "found",
        "calories" => "not_found",
        "description" => "not_found"
      )
    end

    it "uses the PDF content hash as source_identifier and re-imports the same file from cache" do
      user = create(:user, confirmed_at: Time.current)
      allow(PdfExtractor).to receive(:extract_text).and_return(pdf_text)
      allow(DeepSeekClient).to receive(:structure_pdf).and_return("name" => "PDF Pancakes")

      post "/recipe-imports", params: { resource_type: "pdf", resource: upload_recipe_pdf },
        headers: auth_headers(user)
      expect(response).to have_http_status(:accepted)

      perform_enqueued_jobs

      original_recipe = OriginalRecipe.last
      expect(original_recipe.source_identifier).to eq(recipe_pdf_content_hash)
      expect(original_recipe.original_source).to eq(recipe_pdf_content_hash)
      expect(DeepSeekClient).to have_received(:structure_pdf).once

      post "/recipe-imports", params: { resource_type: "pdf", resource: upload_recipe_pdf },
        headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("cached")
      expect(body["original_recipe"]["source_identifier"]).to eq(recipe_pdf_content_hash)

      expect(OriginalRecipe.count).to eq(1)
      expect(DeepSeekClient).to have_received(:structure_pdf).once
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

  describe "the deterministic markup path" do
    it "extracts JSON-LD Recipe markup without calling DeepSeek" do
      user = create(:user, confirmed_at: Time.current)
      stub_fetch("json_ld", text: "Fluffy Pancakes body text")

      post "/recipe-imports", params: { resource_type: "web_page", resource: url }, as: :json,
        headers: auth_headers(user)
      import_id = JSON.parse(response.body)["import_id"]

      perform_enqueued_jobs

      expect(DeepSeekClient).not_to have_received(:structure)

      get "/recipe-imports/#{import_id}", headers: auth_headers(user)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("done")

      original_recipe = body["original_recipe"]
      expect(original_recipe["name"]).to eq("Fluffy Pancakes")
      expect(original_recipe["description"]).to eq("Easy fluffy pancakes.")
      expect(original_recipe["ingredients"].map { |ingredient| ingredient["name"] })
        .to eq([ "2 cups flour", "1 cup milk", "2 eggs" ])
      expect(original_recipe["instructions"].map { |instruction| instruction["content"] })
        .to eq([ "Mix flour and milk.", "Cook on a hot griddle." ])
      expect(original_recipe["preparation_time"]).to eq(10)
      expect(original_recipe["cooking_time"]).to eq(20)
      expect(original_recipe["servings"]).to eq(4)

      expect(body["field_status"]).to include(
        "name" => "found",
        "ingredients" => "found",
        "instructions" => "found",
        "preparation_time" => "found",
        "cooking_time" => "found",
        "servings" => "found"
      )
    end
  end

  describe "the DeepSeek fallback path" do
    it "structures a page without markup through the DeepSeek adapter" do
      user = create(:user, confirmed_at: Time.current)
      stub_fetch("meta_only", text: "Meta Only Pancakes need flour, milk, and eggs.")

      allow(DeepSeekClient).to receive(:structure).and_return(
        "name" => "Meta Only Pancakes",
        "description" => "A pancake recipe only present in meta tags.",
        "ingredients" => [ "1 cup flour", "1 cup milk", "2 eggs" ],
        "instructions" => [ "Mix everything.", "Cook until golden." ],
        "preparation_time" => 5,
        "cooking_time" => 15,
        "servings" => 2
      )
      allow(TypeSafeClient).to receive(:evaluate).and_return(
        all_found_scores.merge("calories" => 0.1, "nutritional_information" => 0.1)
      )

      post "/recipe-imports", params: { resource_type: "web_page", resource: url }, as: :json,
        headers: auth_headers(user)
      import_id = JSON.parse(response.body)["import_id"]

      perform_enqueued_jobs

      expect(DeepSeekClient).to have_received(:structure).once

      get "/recipe-imports/#{import_id}", headers: auth_headers(user)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("done")

      original_recipe = body["original_recipe"]
      expect(original_recipe["name"]).to eq("Meta Only Pancakes")
      expect(original_recipe["ingredients"].map { |ingredient| ingredient["name"] })
        .to eq([ "1 cup flour", "1 cup milk", "2 eggs" ])
      expect(original_recipe["instructions"].map { |instruction| instruction["content"] })
        .to eq([ "Mix everything.", "Cook until golden." ])
      expect(original_recipe["preparation_time"]).to eq(5)
      expect(original_recipe["cooking_time"]).to eq(15)
      expect(original_recipe["servings"]).to eq(2)
      expect(body["field_status"]).to include(
        "name" => "found",
        "calories" => "not_found",
        "nutritional_information" => "not_found"
      )
    end
  end

  describe "never-invent behavior" do
    it "blanks a field Jev judges not_found even when the extractor produced a value" do
      user = create(:user, confirmed_at: Time.current)
      stub_fetch("json_ld", text: "Fluffy Pancakes body text")
      allow(TypeSafeClient).to receive(:evaluate).and_return(
        all_found_scores.merge("ingredients" => 0.1, "preparation_time" => 0.1)
      )

      post "/recipe-imports", params: { resource_type: "web_page", resource: url }, as: :json,
        headers: auth_headers(user)
      import_id = JSON.parse(response.body)["import_id"]

      perform_enqueued_jobs

      get "/recipe-imports/#{import_id}", headers: auth_headers(user)
      body = JSON.parse(response.body)
      original_recipe = body["original_recipe"]

      expect(original_recipe["ingredients"]).to eq([])
      expect(original_recipe["preparation_time"]).to be_nil
      expect(body["field_status"]).to include(
        "ingredients" => "not_found",
        "preparation_time" => "not_found",
        "name" => "found"
      )
    end
  end

  describe "the not-a-recipe path" do
    it "finishes as done with every field not_found" do
      user = create(:user, confirmed_at: Time.current)
      stub_fetch("no_markup_text", text: "Welcome to my blog about cats.")
      allow(DeepSeekClient).to receive(:structure).and_return({})
      allow(TypeSafeClient).to receive(:evaluate).and_return(
        RecipeImport::FIELD_NAMES.index_with { 0.1 }
      )

      post "/recipe-imports", params: { resource_type: "web_page", resource: url }, as: :json,
        headers: auth_headers(user)
      import_id = JSON.parse(response.body)["import_id"]

      perform_enqueued_jobs

      get "/recipe-imports/#{import_id}", headers: auth_headers(user)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("done")
      expect(body["original_recipe"]["name"]).to be_nil
      expect(body["original_recipe"]["ingredients"]).to eq([])
      expect(body["original_recipe"]["instructions"]).to eq([])
      expect(body["field_status"]).to eq(RecipeImport::FIELD_NAMES.index_with { "not_found" })
    end
  end

  describe "the cache-hit path" do
    it "reuses the cached OriginalRecipe without re-running the pipeline" do
      user = create(:user, confirmed_at: Time.current)
      stub_fetch("json_ld", text: "Fluffy Pancakes body text")

      post "/recipe-imports", params: { resource_type: "web_page", resource: url }, as: :json,
        headers: auth_headers(user)
      expect(response).to have_http_status(:accepted)

      perform_enqueued_jobs
      expect(WebPageFetcher).to have_received(:fetch).once
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
      expect(WebPageFetcher).to have_received(:fetch).once
    end
  end

  describe "POST /recipe-imports/:id/retry" do
    it "rejects unauthenticated requests" do
      record = RecipeImport::Record.create!(
        source_identifier: url,
        source_type: "web_page",
        source: url,
        status: :failed,
        error: "boom",
        error_code: "fetch_http_4xx"
      )

      post "/recipe-imports/#{record.id}/retry"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 404 for an unknown import" do
      user = create(:user, confirmed_at: Time.current)

      post "/recipe-imports/999999/retry", headers: auth_headers(user)

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["error"]).to match(/not found/i)
    end

    it "returns 409 when the import is not failed" do
      user = create(:user, confirmed_at: Time.current)
      record = RecipeImport::Record.create!(
        source_identifier: url,
        source_type: "web_page",
        source: url,
        status: :processing
      )

      post "/recipe-imports/#{record.id}/retry", headers: auth_headers(user)

      expect(response).to have_http_status(:conflict)
      expect(JSON.parse(response.body)["error"]).to eq("import is not failed")
    end

    it "returns 409 when the retry limit is reached" do
      user = create(:user, confirmed_at: Time.current)
      record = RecipeImport::Record.create!(
        source_identifier: url,
        source_type: "web_page",
        source: url,
        status: :failed,
        error: "boom",
        error_code: "deep_seek_error",
        retry_count: 3
      )

      post "/recipe-imports/#{record.id}/retry", headers: auth_headers(user)

      expect(response).to have_http_status(:conflict)
      expect(JSON.parse(response.body)["error"]).to eq("retry limit reached")
    end

    it "re-enqueues a failed import and consumes a retry" do
      user = create(:user, confirmed_at: Time.current)
      stub_fetch("json_ld", text: "Fluffy Pancakes body text")
      record = RecipeImport::Record.create!(
        source_identifier: url,
        source_type: "web_page",
        source: url,
        status: :failed,
        error: "boom",
        error_code: "fetch_http_5xx",
        retry_count: 0
      )

      post "/recipe-imports/#{record.id}/retry", headers: auth_headers(user)

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      expect(body["import_id"]).to eq(record.id)
      expect(body["status"]).to eq("processing")
      expect(record.reload.retry_count).to eq(1)

      perform_enqueued_jobs

      expect(record.reload.status).to eq("done")
      expect(record.retry_count).to eq(1)
    end

    it "re-links a cache hit without consuming a retry" do
      user = create(:user, confirmed_at: Time.current)
      original_recipe = OriginalRecipe.create!(
        source_identifier: url,
        name: "Cached Pancakes",
        field_status: all_found_status,
        parsed_at: Time.current,
        last_checked_at: Time.current
      )
      record = RecipeImport::Record.create!(
        source_identifier: url,
        source_type: "web_page",
        source: url,
        status: :failed,
        error: "boom",
        error_code: "fetch_http_4xx",
        retry_count: 1
      )

      post "/recipe-imports/#{record.id}/retry", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("cached")
      expect(body["original_recipe"]["name"]).to eq("Cached Pancakes")

      record.reload
      expect(record.status).to eq("cached")
      expect(record.original_recipe).to eq(original_recipe)
      expect(record.retry_count).to eq(1)
    end
  end

  describe "failed poll response" do
    it "exposes retry metadata derived from error_code and retry_count" do
      user = create(:user, confirmed_at: Time.current)
      record = RecipeImport::Record.create!(
        source_identifier: url,
        source_type: "web_page",
        source: url,
        status: :failed,
        error: "fetch failed with HTTP 404",
        error_code: "fetch_http_4xx",
        retry_count: 1
      )

      get "/recipe-imports/#{record.id}", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to include(
        "status" => "failed",
        "error_code" => "fetch_http_4xx",
        "retryable" => false,
        "retry_count" => 1,
        "retries_remaining" => 2
      )
    end

    it "marks provider errors retryable until retries are exhausted" do
      user = create(:user, confirmed_at: Time.current)
      record = RecipeImport::Record.create!(
        source_identifier: url,
        source_type: "web_page",
        source: url,
        status: :failed,
        error: "TypeSafe API error: HTTP 529",
        error_code: "jev_error",
        retry_count: 2
      )

      get "/recipe-imports/#{record.id}", headers: auth_headers(user)

      body = JSON.parse(response.body)
      expect(body["retryable"]).to be(true)
      expect(body["retries_remaining"]).to eq(1)
    end
  end
end
