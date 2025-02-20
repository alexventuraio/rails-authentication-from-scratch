class User < ApplicationRecord
  CONFIRMATION_TOKEN_EXPIRATION_IN_SECONDS = 10.minutes.to_i
  MAILER_FROM_EMAIL = "no-reply@example.com"
  PASSWORD_RESET_TOKEN_EXPIRATION_IN_SECONDS = 10.minutes.to_i
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

  attr_accessor :current_password

  has_secure_password
  has_secure_token :confirmation_token
  has_secure_token :password_reset_token

  before_save :downcase_email
  before_save :downcase_unconfirmed_email

  validates :email, format: { with: VALID_EMAIL_REGEX }, presence: true, uniqueness: true
  validates :unconfirmed_email, format: { with: VALID_EMAIL_REGEX, allow_blank: true }
  validate :unconfirmed_email_must_be_available

  def confirm!
    if self.unconfirmed_email.present?
      self.update(email: self.unconfirmed_email, unconfirmed_email: nil)
    end
    self.update_columns(confirmed_at: Time.current)
  end

  def confirmed?
    self.confirmed_at.present?
  end

  def confirmable_email
    if self.unconfirmed_email.present?
      self.unconfirmed_email
    else
      self.email
    end
  end

  def confirmation_token_has_not_expired?
    return false if self.confirmation_sent_at.nil?
    (Time.current - self.confirmation_sent_at) <= User::CONFIRMATION_TOKEN_EXPIRATION_IN_SECONDS
  end

  def password_reset_token_has_expired?
    return true if self.password_reset_sent_at.nil?
    (Time.current - self.password_reset_sent_at) >= User::PASSWORD_RESET_TOKEN_EXPIRATION_IN_SECONDS
  end  

  def send_confirmation_email!
    self.regenerate_confirmation_token
    self.update_columns(confirmation_sent_at: Time.current)
    UserMailer.confirmation(self).deliver_now
  end

  def send_password_reset_email!
    self.regenerate_password_reset_token
    self.update_columns(password_reset_sent_at: Time.current)
    UserMailer.password_reset(self).deliver_now
  end

  def reconfirming?
    self.unconfirmed_email.present?
  end

  def unconfirmed?
    self.confirmed_at.nil?
  end

  def unconfirmed_or_reconfirming?
    self.unconfirmed? || self.reconfirming?
  end

  private

  def downcase_email
    self.email = self.email.downcase
  end

  def downcase_unconfirmed_email
    return if self.unconfirmed_email.nil?
    self.unconfirmed_email = self.unconfirmed_email.downcase
  end

  def unconfirmed_email_must_be_available
    return if self.unconfirmed_email.nil?
    if User.find_by(email: self.unconfirmed_email.downcase)
      errors.add(:unconfirmed_email, "is already in use.")
    end
  end

end
