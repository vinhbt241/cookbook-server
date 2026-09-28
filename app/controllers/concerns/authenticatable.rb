# Reads the bearer token from the Authorization header and resolves it to a
# User via Auth.authenticate. Included by controllers that need an
# authenticated user.
module Authenticatable
  extend ActiveSupport::Concern

  private

  def current_user
    @current_user ||= Auth.authenticate(bearer_token)
  end

  def authenticate!
    return if current_user

    render json: { error: "unauthorized" }, status: :unauthorized
  end

  def bearer_token
    header = request.headers["Authorization"].to_s
    header[/\ABearer (.+)\z/, 1]
  end
end
