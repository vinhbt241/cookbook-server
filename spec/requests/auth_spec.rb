require "rails_helper"

RSpec.describe "Auth", type: :request do
  before do
    ActionMailer::Base.deliveries.clear
  end

  def confirmation_token_from_email
    mail = ActionMailer::Base.deliveries.last
    expect(mail).to be_present
    mail.body.encoded[/auth\/confirm\/([A-Za-z0-9_=-]+)/, 1]
  end

  describe "POST /auth/register" do
    let(:params) { { email: "ada@example.com", name: "Ada", password: "secret123" } }

    it "creates an unconfirmed account and sends a confirmation email" do
      expect {
        post "/auth/register", params: params, as: :json
      }.to change(User, :count).by(1)

      expect(response).to have_http_status(:created)
      user = JSON.parse(response.body)["user"]
      expect(user["email"]).to eq("ada@example.com")
      expect(user["name"]).to eq("Ada")
      expect(user["confirmed"]).to be(false)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ "ada@example.com" ])
      expect(mail.subject).to include("Confirm")
    end

    it "rejects an already-taken email with a clear error" do
      create(:user, email: "ada@example.com")

      post "/auth/register", params: params, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)["error"]).to match(/already been taken/i)
    end

    it "does not echo the password back in the response" do
      post "/auth/register", params: params, as: :json

      expect(response.body).not_to include("secret123")
    end
  end

  describe "GET /auth/confirm/:token" do
    it "marks the account confirmed" do
      post "/auth/register", params: { email: "ada@example.com", name: "Ada", password: "secret123" }, as: :json
      token = confirmation_token_from_email

      get "/auth/confirm/#{token}"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["user"]["confirmed"]).to be(true)
      expect(User.find_by(email: "ada@example.com").confirmed_at).to be_present
    end

    it "rejects an invalid token with a clear error" do
      get "/auth/confirm/not-a-real-token"

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)["error"]).to match(/invalid confirmation token/i)
    end
  end

  describe "POST /auth/login" do
    let!(:user) { create(:user, email: "ada@example.com", password: "secret123") }

    it "returns a session token for correct credentials" do
      post "/auth/login", params: { email: "ada@example.com", password: "secret123" }, as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["token"]).to be_present
      expect(body["user"]["email"]).to eq("ada@example.com")
    end

    it "returns a clear error for a wrong password" do
      post "/auth/login", params: { email: "ada@example.com", password: "wrong" }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to match(/invalid email or password/i)
    end

    it "returns a clear error for an unknown email" do
      post "/auth/login", params: { email: "nobody@example.com", password: "secret123" }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to match(/invalid email or password/i)
    end
  end

  describe "POST /auth/google" do
    let(:google_payload) do
      { "email" => "ada@example.com", "email_verified" => true, "name" => "Ada Lovelace" }
    end

    it "creates a confirmed account and returns a session token on first sign-in" do
      allow(GoogleIdTokenVerifier).to receive(:verify).with("google-id-token").and_return(google_payload)

      expect {
        post "/auth/google", params: { credential: "google-id-token" }, as: :json
      }.to change(User, :count).by(1)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["token"]).to be_present
      expect(body["user"]["email"]).to eq("ada@example.com")
      expect(body["user"]["name"]).to eq("Ada Lovelace")
      expect(body["user"]["confirmed"]).to be(true)

      user = User.find_by(email: "ada@example.com")
      expect(user.confirmed_at).to be_present
      expect(user.password_digest).to be_nil
    end

    it "reuses the existing account for a returning Google sign-in" do
      allow(GoogleIdTokenVerifier).to receive(:verify).and_return(google_payload)

      post "/auth/google", params: { credential: "google-id-token" }, as: :json
      existing_user = User.find_by!(email: "ada@example.com")

      post "/auth/google", params: { credential: "google-id-token" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(User.count).to eq(1)
      body = JSON.parse(response.body)
      expect(body["token"]).to be_present
      expect(body["user"]["id"]).to eq(existing_user.id)
      expect(body["user"]["confirmed"]).to be(true)
    end

    it "rejects an invalid or expired Google ID token with a clear error" do
      allow(GoogleIdTokenVerifier).to receive(:verify).with("bad-token")
        .and_raise(GoogleIdTokenVerifier::InvalidToken, "invalid or expired Google ID token")

      post "/auth/google", params: { credential: "bad-token" }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to match(/invalid or expired/i)
    end

    it "rejects a token whose email is not verified" do
      allow(GoogleIdTokenVerifier).to receive(:verify).with("unverified-token")
        .and_return(google_payload.merge("email_verified" => false))

      post "/auth/google", params: { credential: "unverified-token" }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to match(/invalid Google ID token/i)
    end

    it "returns 500 when Google sign-in is not configured" do
      allow(GoogleIdTokenVerifier).to receive(:verify).with("google-id-token")
        .and_raise(GoogleIdTokenVerifier::ConfigurationError, "Google sign-in is not configured")

      post "/auth/google", params: { credential: "google-id-token" }, as: :json

      expect(response).to have_http_status(:internal_server_error)
      expect(JSON.parse(response.body)["error"]).to match(/not configured/i)
    end
  end

  describe "GET /auth/me" do
    it "returns the authenticated user for a valid token" do
      user = create(:user, email: "ada@example.com", password: "secret123")
      token = Auth.issue_session_token(user)

      get "/auth/me", headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["user"]["email"]).to eq("ada@example.com")
    end

    it "returns 401 without a token" do
      get "/auth/me"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 for an invalid token" do
      get "/auth/me", headers: { "Authorization" => "Bearer bogus-token" }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "the full flow" do
    it "registers, confirms, logs in, and fetches the profile" do
      post "/auth/register", params: { email: "ada@example.com", name: "Ada", password: "secret123" }, as: :json
      expect(response).to have_http_status(:created)

      token = confirmation_token_from_email
      get "/auth/confirm/#{token}"
      expect(JSON.parse(response.body)["user"]["confirmed"]).to be(true)

      post "/auth/login", params: { email: "ada@example.com", password: "secret123" }, as: :json
      session_token = JSON.parse(response.body)["token"]
      expect(session_token).to be_present

      get "/auth/me", headers: { "Authorization" => "Bearer #{session_token}" }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["user"]["email"]).to eq("ada@example.com")
    end
  end
end
