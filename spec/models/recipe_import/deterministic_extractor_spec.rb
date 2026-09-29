require "rails_helper"

RSpec.describe RecipeImport::DeterministicExtractor do
  def fixture(name)
    Rails.root.join("spec/fixtures/recipes/#{name}.html").read
  end

  describe ".extract" do
    it "extracts a JSON-LD schema.org Recipe" do
      extraction = described_class.extract(fixture("json_ld"))

      expect(extraction.markup_present).to be(true)
      expect(extraction.fields).to include(
        "name" => "Fluffy Pancakes",
        "description" => "Easy fluffy pancakes.",
        "preparation_time" => 10,
        "cooking_time" => 20,
        "servings" => 4,
        "calories" => 350
      )
      expect(extraction.fields["ingredients"]).to eq([ "2 cups flour", "1 cup milk", "2 eggs" ])
      expect(extraction.fields["instructions"]).to eq([ "Mix flour and milk.", "Cook on a hot griddle." ])
      expect(extraction.fields["nutritional_information"]).to include("calories" => "350 calories")
      expect(extraction.markup_dump).to include("Fluffy Pancakes")
    end

    it "finds a Recipe nested inside a JSON-LD @graph" do
      html = <<~HTML
        <script type="application/ld+json">
        {
          "@context": "https://schema.org",
          "@graph": [
            { "@type": "WebPage", "name": "Pancakes page" },
            {
              "@type": "Recipe",
              "name": "Graph Pancakes",
              "recipeIngredient": ["1 cup flour"],
              "recipeInstructions": ["Mix and cook."]
            }
          ]
        }
        </script>
      HTML

      extraction = described_class.extract(html)

      expect(extraction.markup_present).to be(true)
      expect(extraction.fields["name"]).to eq("Graph Pancakes")
      expect(extraction.fields["ingredients"]).to eq([ "1 cup flour" ])
    end

    it "extracts a schema.org Recipe from microdata" do
      extraction = described_class.extract(fixture("microdata"))

      expect(extraction.markup_present).to be(true)
      expect(extraction.fields).to include(
        "name" => "Microdata Pancakes",
        "description" => "A microdata pancake recipe.",
        "preparation_time" => 5,
        "cooking_time" => 15,
        "servings" => 2,
        "calories" => 200
      )
      expect(extraction.fields["ingredients"]).to eq([ "1 cup flour", "1 egg" ])
      expect(extraction.fields["instructions"]).to eq([ "Mix everything.", "Cook until golden." ])
    end

    it "does not treat meta-only pages as markup" do
      extraction = described_class.extract(fixture("meta_only"))

      expect(extraction.markup_present).to be(false)
    end
  end
end
