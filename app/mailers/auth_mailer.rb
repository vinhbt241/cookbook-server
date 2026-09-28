class AuthMailer < ApplicationMailer
  def confirmation(user, token)
    @user = user
    @confirmation_url = auth_confirm_url(token: token)
    mail(to: user.email, subject: "Confirm your email")
  end
end
