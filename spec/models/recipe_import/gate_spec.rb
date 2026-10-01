require "rails_helper"

RSpec.describe RecipeImport::Gate do
  let(:fields) do
    RecipeImport::Extraction.empty_fields.merge(
      "name" => "Pancakes",
      "ingredients" => [ "1 cup flour" ],
      "instructions" => [ "Mix." ],
      "preparation_time" => 10,
      "calories" => nil
    )
  end

  def stub_scores(scores)
    allow(TypeSafeClient).to receive(:evaluate).and_return(scores)
  end

  describe ".apply" do
    it "asks Jev per-field presence for all nine fields" do
      stub_scores(RecipeImport::FIELD_NAMES.index_with { 0.99 })

      described_class.apply(fields: fields, state: "evidence")

      expected_questions = RecipeImport::FIELD_NAMES.index_with do |field|
        { type: "noul", instructions: "does the state contain cooking recipe's #{field}?" }
      end
      expect(TypeSafeClient).to have_received(:evaluate).with(
        state: "evidence", questions: expected_questions
      )
    end

    it "marks a field found when its score meets the threshold" do
      stub_scores(RecipeImport::FIELD_NAMES.index_with { 0.5 })

      result = described_class.apply(fields: fields, state: "evidence")

      expect(result.field_status["name"]).to eq("found")
    end

    it "marks a field not_found when its score is below the threshold" do
      stub_scores(RecipeImport::FIELD_NAMES.index_with { 0.49 })

      result = described_class.apply(fields: fields, state: "evidence")

      expect(result.field_status["name"]).to eq("not_found")
    end

    it "blanks a not_found ingredient/instruction field to an empty array" do
      stub_scores(RecipeImport::FIELD_NAMES.index_with { 0.99 }.merge("ingredients" => 0.1, "instructions" => 0.1))

      result = described_class.apply(fields: fields, state: "evidence")

      expect(result.gated_fields["ingredients"]).to eq([])
      expect(result.gated_fields["instructions"]).to eq([])
    end

    it "blanks a not_found scalar field to nil" do
      stub_scores(RecipeImport::FIELD_NAMES.index_with { 0.99 }.merge("preparation_time" => 0.1))

      result = described_class.apply(fields: fields, state: "evidence")

      expect(result.gated_fields["preparation_time"]).to be_nil
    end

    it "keeps a found field's value" do
      stub_scores(RecipeImport::FIELD_NAMES.index_with { 0.99 })

      result = described_class.apply(fields: fields, state: "evidence")

      expect(result.gated_fields["name"]).to eq("Pancakes")
      expect(result.gated_fields["ingredients"]).to eq([ "1 cup flour" ])
    end
  end
end
