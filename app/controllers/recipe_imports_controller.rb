class RecipeImportsController < ApplicationController
  include Authenticatable
  before_action :authenticate_confirmed!

  def create
    # The public API contract (docs/designs/apis.md) names these request
    # fields `resource`/`resource_type`; internally the domain term is Source.
    submission = RecipeImport.submit(source_type: params[:resource_type], source: params[:resource])

    if submission.status == "cached"
      render json: {
        status: "cached",
        original_recipe: original_recipe_payload(submission.original_recipe),
        field_status: field_status_payload(submission.original_recipe)
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

    render json: import_payload(record), status: :ok
  end

  private

  def import_payload(record)
    case record.status
    when "processing"
      { status: "processing" }
    when "done", "cached"
      {
        status: record.status,
        original_recipe: original_recipe_payload(record.original_recipe),
        field_status: field_status_payload(record.original_recipe)
      }
    when "failed"
      { status: "failed", error: record.error }
    end
  end

  def original_recipe_payload(recipe)
    {
      name: recipe.name,
      description: recipe.description,
      ingredients: recipe.original_recipe_ingredients.map { |ingredient| ingredient_payload(ingredient) },
      instructions: recipe.original_cooking_instructions.order(:position).map { |instruction| instruction_payload(instruction) },
      preparation_time: recipe.preparation_time,
      cooking_time: recipe.cooking_time,
      servings: recipe.servings,
      calories: recipe.calories,
      nutritional_information: recipe.nutritional_information,
      original_source: recipe.original_source,
      source_identifier: recipe.source_identifier,
      categories: []
    }
  end

  def ingredient_payload(ingredient)
    {
      name: ingredient.name,
      quantity: ingredient.quantity,
      unit: ingredient.unit,
      preparation: ingredient.preparation,
      optional: ingredient.optional,
      notes: ingredient.notes
    }
  end

  def instruction_payload(instruction)
    {
      position: instruction.position,
      content: instruction.content
    }
  end

  def field_status_payload(recipe)
    {
      name: field_status(recipe.name),
      description: field_status(recipe.description),
      ingredients: field_status(recipe.original_recipe_ingredients.any?),
      instructions: field_status(recipe.original_cooking_instructions.any?),
      preparation_time: field_status(recipe.preparation_time),
      cooking_time: field_status(recipe.cooking_time),
      servings: field_status(recipe.servings),
      calories: field_status(recipe.calories),
      nutritional_information: field_status(recipe.nutritional_information)
    }
  end

  def field_status(value)
    value.present? ? "found" : "not_found"
  end

  def authenticate_confirmed!
    return if current_user&.confirmed?

    if current_user
      render json: { error: "confirm your email before importing recipes" }, status: :forbidden
    else
      render json: { error: "unauthorized" }, status: :unauthorized
    end
  end
end
