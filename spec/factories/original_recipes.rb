FactoryBot.define do
  factory :original_recipe do
    sequence(:source_identifier) { |n| "recipe-#{n}" }
    name { "Pancakes" }
    servings { 2 }
  end

  factory :original_recipe_ingredient do
    original_recipe
    name { "1 cup flour" }
  end
end
