class RecipeImportsController < ApplicationController
  include Authenticatable
  before_action :authenticate_confirmed!

  def create
    # The public API contract (docs/designs/apis.md) names these request
    # fields `resource`/`resource_type`; internally the domain term is Source.
    source = RecipeImport::Source.new(type: params[:resource_type], value: params[:resource])
    submission = RecipeImport.submit(source)

    render json: RecipeImportSerializer.submission(submission),
      status: submission.cached? ? :ok : :accepted
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
