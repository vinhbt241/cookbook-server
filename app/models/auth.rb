# Owns identity, email confirmation, and session tokens.
#
# The single entry point for authentication concerns: callers register users,
# confirm emails, log in, and authenticate bearer tokens through this module
# and nothing else.
module Auth
  class Error < StandardError; end

  # Raised when registering with an email that is already taken.
  class EmailTaken < Error; end

  # Raised when logging in with an unknown email or wrong password.
  class InvalidCredentials < Error; end

  # Raised when a Google ID token is invalid or expired.
  class InvalidGoogleToken < Error; end

  # Raised when a required auth provider is not configured.
  class ConfigurationError < Error; end

  # Raised when a confirmation token is invalid or expired.
  class InvalidToken < Error; end

  # Raised when a registration fails model validation for a reason other than
  # a taken email (e.g. invalid email or too-short password).
  class ValidationError < Error
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      super("Validation failed")
    end
  end

  module_function

  # Creates an unconfirmed account and sends a confirmation email.
  #
  # Returns the persisted, unconfirmed User.
  # Raises EmailTaken when the email already exists, or ValidationError for
  # other validation failures.
  def register(email:, name:, password:)
    user = User.new(email:, name:, password:)
    return deliver_confirmation(user) if user.save

    if user.errors.of_kind?(:email, :taken)
      raise EmailTaken, "email has already been taken"
    end

    raise ValidationError, user.errors
  end

  # Marks the account confirmed, given the token from its confirmation email.
  #
  # Returns the confirmed User. Raises InvalidToken when the token is invalid
  # or expired.
  def confirm(token)
    user = User.find_by_token_for(:email_confirmation, token)
    raise InvalidToken, "invalid confirmation token" unless user

    user.confirm!
    user
  end

  # Authenticates an email/password pair.
  #
  # Returns a bearer session token. Raises InvalidCredentials when the email
  # is unknown or the password is wrong.
  def login(email:, password:)
    user = User.find_by(email: email.to_s.strip.downcase)
    raise InvalidCredentials, "invalid email or password" unless user&.authenticate(password)

    issue_session_token(user)
  end

  # Signs in with a Google ID token.
  #
  # Verifies the token, creates a confirmed account on first sign-in, and
  # reuses it on later sign-ins. Returns the confirmed User. Raises
  # InvalidGoogleToken when the token cannot be verified.
  def google(credential:)
    payload = GoogleIdTokenVerifier.verify(credential)
    email = payload["email"].to_s.strip.downcase
    unless payload["email_verified"] && email.present?
      raise InvalidGoogleToken, "invalid Google ID token"
    end

    user = User.find_by(email: email)
    if user
      user.confirm! unless user.confirmed?
    else
      user = User.new(
        email: email,
        name: payload["name"].presence || email,
        confirmed_at: Time.current
      )
      user.skip_password_validation = true
      user.save!
    end

    user
  rescue GoogleIdTokenVerifier::InvalidToken => e
    raise InvalidGoogleToken, e.message
  rescue GoogleIdTokenVerifier::ConfigurationError => e
    raise ConfigurationError, e.message
  end

  # Issues a bearer session token for the given user.
  def issue_session_token(user)
    user.generate_token_for(:session)
  end

  # Resolves a bearer session token to a User, or nil when invalid/expired.
  def authenticate(token)
    User.find_by_token_for(:session, token)
  end

  def deliver_confirmation(user)
    AuthMailer.confirmation(user, user.generate_token_for(:email_confirmation)).deliver_now
    user
  end
  private_class_method :deliver_confirmation
end
