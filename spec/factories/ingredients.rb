FactoryBot.define do
  factory :ingredient do
    name { "flour" }
    calories_per_100g { 364 }
    nutritional_information_per_100g do
      { "protein" => 10.3, "carbohydrates" => 76.3, "fat" => 1.0, "fiber" => 2.7, "sugar" => 0.3, "sodium" => 0.002 }
    end
    grams_per_unit { { "cup" => 125, "tbsp" => 8, "tsp" => 2.6 } }
  end
end
