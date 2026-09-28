require "googleauth"

# Verifies Google-issued ID tokens (the `credential` from Google Sign-In) and
# returns the decoded payload. This is the only part of Auth that talks to
# Google, so the rest of authentication stays deterministic and offline-testable.
module GoogleIdTokenVerifier
  class InvalidToken < StandardError; end

  module_function

  def verify(id_token)
    audience = Rails.application.credentials.google_client_id.presence
    raise InvalidToken, "Google sign-in is not configured" unless audience

    Google::Auth::IDTokens.verify_oidc(id_token, aud: audience)
  rescue Google::Auth::IDTokens::VerificationError, Google::Auth::IDTokens::KeySourceError
    raise InvalidToken, "invalid or expired Google ID token"
  end
end
