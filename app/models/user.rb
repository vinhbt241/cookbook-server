class User < ApplicationRecord
  SESSION_TTL = 30.days
  CONFIRMATION_TTL = 24.hours

  has_secure_password

  generates_token_for :email_confirmation, expires_in: CONFIRMATION_TTL
  generates_token_for :session, expires_in: SESSION_TTL

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true

  def confirmed?
    confirmed_at.present?
  end

  def confirm!
    update!(confirmed_at: Time.current) unless confirmed?
  end
end
