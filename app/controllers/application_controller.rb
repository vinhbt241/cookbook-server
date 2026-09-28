class ApplicationController < ActionController::Base
  # This server is a JSON API: it authenticates via bearer tokens, not cookies,
  # so CSRF protection is irrelevant. null_session empties the session for
  # requests without a valid CSRF token instead of raising.
  protect_from_forgery with: :null_session

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
