# frozen_string_literal: true

module DeviseSecurity::Patches
  module ControllerSecurityQuestion
    extend ActiveSupport::Concern

    included do
      prepend_before_action :check_security_question, only: [:create]
    end

    private

    # Enumeration-safe entry point: every failure (unknown email, wrong
    # answer, malformed parameters, throttled attempts) results in the same
    # redirect and the same localized flash message, so the response cannot
    # be used to tell existing accounts apart from unknown ones.
    def check_security_question
      return if security_question_request_valid?

      register_security_question_attempt
      flash[:alert] = t('devise.invalid_security_question') if is_navigational_format?
      respond_with({}, location: url_for(action: :new))
    end

    def security_question_request_valid?
      return false if security_question_attempts_exceeded?

      resource = find_security_question_resource
      return false unless resource

      if valid_security_question_answer?(resource, security_question_answer_param)
        reset_security_question_attempts
        true
      else
        false
      end
    end

    def find_security_question_resource
      email = security_question_email_param
      return if email.blank?

      # only find via email, not login
      resource_class.find_or_initialize_with_error_by(:email, email, :not_found)
    end

    # Accept both the classic Devise form shape (nested resource params with a
    # top-level answer field) and flat params, and never raise on unexpected
    # shapes such as a missing or scalar resource param.
    def security_question_email_param
      scoped = security_question_scoped_params
      email = scoped[:email] if scoped
      email.presence || params[:email]
    end

    def security_question_answer_param
      scoped = security_question_scoped_params
      answer = scoped[:security_question_answer] if scoped
      answer.presence || params[:security_question_answer]
    end

    def security_question_scoped_params
      scoped = params[resource_name]
      scoped if scoped.is_a?(ActionController::Parameters) || scoped.is_a?(Hash)
    end

    def security_question_attempts_exceeded?
      max_attempts = Devise.security_question_max_attempts.to_i
      max_attempts.positive? && security_question_attempts >= max_attempts
    end

    def security_question_attempts
      session[security_question_attempts_key].to_i
    end

    def register_security_question_attempt
      session[security_question_attempts_key] = security_question_attempts + 1
    end

    def reset_security_question_attempts
      session.delete(security_question_attempts_key)
    end

    # Attempts are tracked per resource scope and shared across the recover,
    # unlock and confirmation controllers, so repeated attempts accumulate no
    # matter which recovery form is used.
    def security_question_attempts_key
      @security_question_attempts_key ||= "security_question_attempts.#{resource_name}"
    end
  end
end
