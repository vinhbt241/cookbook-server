class RecipeImportsController < ApplicationController
  include Authenticatable
  before_action :authenticate_confirmed!

  def create
    # The public API contract (docs/designs/apis.md) names these request
    # fields `resource`/`resource_type`; internally the domain term is Source.
    submission = RecipeImport.submit(source_type: params[:resource_type], source: params[:resource])

    if submission.status == "cached"
      serializer = OriginalRecipeSerializer.new(submission.original_recipe)

      render json: {
        status: "cached",
        original_recipe: serializer.as_json,
        field_status: serializer.field_status
      }, status: :ok
    else
      render json: { import_id: submission.import_id, status: "processing" }, status: :accepted
    end
  rescue RecipeImport::InvalidSource => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  def show
    record = RecipeImport.find(params[:id])
    return render json: { error: "import not found" }, status: :not_found unless record

    render json: RecipeImportSerializer.new(record).as_json, status: :ok
  end

  private

  def authenticate_confirmed!
    return if current_user&.confirmed?

    if current_user
      render json: { error: "confirm your email before importing recipes" }, status: :forbidden
    else
      render json: { error: "unauthorized" }, status: :unauthorized
    end
  end
end
