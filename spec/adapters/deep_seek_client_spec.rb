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

  it "parses a vision response into recipe fields" do
    stub_deep_seek_response(JSON.generate({ "name" => "Photo Pancakes", "servings" => 4 }))

    expect(described_class.structure_image("data:image/png;base64,cGhvdG8="))
      .to eq("name" => "Photo Pancakes", "servings" => 4)
  end

  it "sends the image as an image_url content block for vision requests" do
    request = double("Faraday request")
    captured_body = nil
    allow(request).to receive(:body=) { |body| captured_body = body }

    response = instance_double(Faraday::Response, success?: true, body: JSON.generate(
      "choices" => [ { "message" => { "content" => JSON.generate({ "name" => "Photo Pancakes" }) } } ]
    ))
    connection = instance_double(Faraday::Connection)
    allow(connection).to receive(:post).and_yield(request).and_return(response)
    allow_any_instance_of(described_class).to receive(:connection).and_return(connection)

    described_class.structure_image("data:image/png;base64,cGhvdG8=")

    body = JSON.parse(captured_body)
    expect(body.dig("messages", 1, "content")).to eq([
      { "type" => "image_url", "image_url" => { "url" => "data:image/png;base64,cGhvdG8=" } }
    ])
  end
end
