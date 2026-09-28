require "rails_helper"

RSpec.describe User, type: :model do
  describe "passwords" do
    it "stores a hash, never the plaintext" do
      user = create(:user, password: "secret123")

      expect(user.password_digest).to be_present
      expect(user.password_digest).not_to eq("secret123")
      expect(user.password_digest).not_to include("secret123")
    end

    it "authenticates with the correct password only" do
      user = create(:user, password: "secret123")

      expect(user.authenticate("secret123")).to eq(user)
      expect(user.authenticate("wrong")).to be(false)
    end
  end

  describe "confirmation" do
    it "is unconfirmed by default and can be confirmed" do
      user = create(:user, password: "secret123")

      expect(user.confirmed?).to be(false)

      user.confirm!
      expect(user.confirmed?).to be(true)
      expect(user.confirmed_at).to be_present
    end
  end
end
