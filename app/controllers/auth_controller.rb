class AuthController < ApplicationController
  include Authenticatable
  before_action :authenticate!, only: :me

  def register
    user = Auth.register(email: params[:email], name: params[:name], password: params[:password])
    render json: { user: user_payload(user) }, status: :created
  rescue Auth::EmailTaken => e
    render json: { error: e.message }, status: :unprocessable_content
  rescue Auth::ValidationError => e
    render json: { errors: e.errors.to_hash }, status: :unprocessable_content
  end

  def confirm
    user = Auth.confirm(params[:token])
    render json: { user: user_payload(user) }, status: :ok
  rescue Auth::InvalidToken => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  def login
    token = Auth.login(email: params[:email], password: params[:password])
    user = Auth.authenticate(token)
    render json: { token:, user: user_payload(user) }, status: :ok
  rescue Auth::InvalidCredentials => e
    render json: { error: e.message }, status: :unauthorized
  end

  def me
    render json: { user: user_payload(current_user) }, status: :ok
  end

  private

  def user_payload(user)
    {
      id: user.id,
      email: user.email,
      name: user.name,
      confirmed: user.confirmed?
    }
  end
end
