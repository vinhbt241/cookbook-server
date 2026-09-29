class User < ApplicationRecord
  SESSION_TTL = 30.days
  CONFIRMATION_TTL = 24.hours

  has_secure_password(validations: false)

  # Google sign-in creates accounts without a password. Set this when the
  # account comes from a verified Google ID token.
  attr_accessor :skip_password_validation

  generates_token_for :email_confirmation, expires_in: CONFIRMATION_TTL
  generates_token_for :session, expires_in: SESSION_TTL

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, on: :create, unless: :skip_password_validation
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates_confirmation_of :password, allow_nil: true

  validate :password_length_within_bcrypt_limit

  def confirmed?
    confirmed_at.present?
  end

  def confirm!
    update!(confirmed_at: Time.current) unless confirmed?
  end

  private

  def password_length_within_bcrypt_limit
    return if password.blank?
    return if password.bytesize <= ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED

    errors.add(:password, :password_too_long)
  end
end
