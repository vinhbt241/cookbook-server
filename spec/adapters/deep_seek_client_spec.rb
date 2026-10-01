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

  def stub_deep_seek_capture(response_fields = { "name" => "Photo Pancakes" })
    request = double("Faraday request")
    @captured_deep_seek_body = nil
    allow(request).to receive(:body=) { |body| @captured_deep_seek_body = body }

    response = instance_double(Faraday::Response, success?: true, body: JSON.generate(
      "choices" => [ { "message" => { "content" => JSON.generate(response_fields) } } ]
    ))
    connection = instance_double(Faraday::Connection)
    allow(connection).to receive(:post).and_yield(request).and_return(response)
    allow_any_instance_of(described_class).to receive(:connection).and_return(connection)
  end

  def stub_image_download(body:, content_type: "image/jpeg", status: 200)
    response = instance_double(Faraday::Response, success?: status < 400, status: status, body: body,
      headers: { "content-type" => content_type })
    connection = instance_double(Faraday::Connection)
    allow(connection).to receive(:get).and_return(response)
    allow_any_instance_of(described_class).to receive(:image_connection).and_return(connection)
    connection
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
      { "type" => "text", "text" => "Extract the recipe from this image." },
      { "type" => "image_url", "image_url" => { "url" => "data:image/png;base64,cGhvdG8=" } }
    ])
  end

  it "downloads and base64-encodes an external image URL before sending it" do
    stub_deep_seek_capture
    image_connection = stub_image_download(body: "jpeg-bytes")

    described_class.structure_image("https://example.com/recipe.jpg")

    expect(image_connection).to have_received(:get).with("https://example.com/recipe.jpg")

    body = JSON.parse(@captured_deep_seek_body)
    expect(body.dig("messages", 1, "content")).to eq([
      { "type" => "text", "text" => "Extract the recipe from this image." },
      { "type" => "image_url", "image_url" => { "url" => "data:image/jpeg;base64,#{Base64.strict_encode64("jpeg-bytes")}" } }
    ])
  end

  it "rejects a non-URL, non-data-URI image input" do
    expect { described_class.structure_image("not an image") }
      .to raise_error(DeepSeekClient::Error, /data URI or an http\(s\) URL/)
  end

  it "raises an ImageDownloadError when the image download fails" do
    image_connection = stub_image_download(body: "not found", status: 404)

    expect { described_class.structure_image("https://example.com/missing.jpg") }
      .to raise_error(DeepSeekClient::ImageDownloadError, /HTTP 404/)
    expect(image_connection).to have_received(:get).with("https://example.com/missing.jpg")
  end
end
