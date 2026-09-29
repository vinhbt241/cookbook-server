require "rails_helper"

RSpec.describe DeepSeekClient do
  def stub_deep_seek_response(content)
    response = instance_double(Faraday::Response, success?: true, body: JSON.generate(
      "choices" => [ { "message" => { "content" => content } } ]
    ))
    connection = instance_double(Faraday::Connection)
    allow(connection).to receive(:post).and_return(response)
    allow_any_instance_of(described_class).to receive(:connection).and_return(connection)
  end

  it "parses a schema-compliant object" do
    stub_deep_seek_response(JSON.generate({ "name" => "Pancakes", "servings" => 4 }))

    expect(described_class.structure("text")).to eq("name" => "Pancakes", "servings" => 4)
  end

  it "rejects unknown fields" do
    stub_deep_seek_response(JSON.generate({ "made_up" => "no" }))

    expect { described_class.structure("text") }
      .to raise_error(DeepSeekClient::InvalidResponse, /unknown fields/i)
  end

  it "rejects a non-object payload" do
    stub_deep_seek_response(JSON.generate([ "not", "object" ]))

    expect { described_class.structure("text") }
      .to raise_error(DeepSeekClient::InvalidResponse, /non-object/i)
  end

  it "rejects a field with the wrong type" do
    stub_deep_seek_response(JSON.generate({ "name" => 123 }))

    expect { described_class.structure("text") }
      .to raise_error(DeepSeekClient::InvalidResponse, /invalid type for name/i)
  end
end
