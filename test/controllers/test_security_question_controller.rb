# frozen_string_literal: true

require 'test_helper'

class TestWithSecurityQuestion < ActionDispatch::IntegrationTest
  setup do
    @user = SecurityQuestionUser.create!(
      username: 'hello',
      email: generate_unique_email,
      password: 'A1234567z!',
      security_question_answer: 'Right Answer'
    )
    @user.lock_access!
  end

  test 'When security question is enabled, it is inserted correctly' do
    post(
      '/security_question_users/unlock',
      params: {
        security_question_answer: 'wrong answer',
        security_question_user: {
          email: @user.email
        }
      }
    )

    assert_equal I18n.t('devise.invalid_security_question'), flash[:alert]
    assert_redirected_to new_security_question_user_unlock_path
  end

  test 'When security_question is valid, it runs as normal' do
    post(
      '/security_question_users/unlock',
      params: {
        security_question_answer: @user.security_question_answer,
        security_question_user: {
          email: @user.email
        }
      }
    )

    assert_equal I18n.t('devise.unlocks.send_instructions'), flash[:notice]
    assert_redirected_to new_security_question_user_session_path
  end

  test 'When email is unknown, the response is identical to a wrong answer' do
    post(
      '/security_question_users/unlock',
      params: {
        security_question_answer: 'wrong answer',
        security_question_user: {
          email: generate_unique_email
        }
      }
    )

    assert_equal I18n.t('devise.invalid_security_question'), flash[:alert]
    assert_redirected_to new_security_question_user_unlock_path
  end

  test 'When resource params are missing, the response is identical to a wrong answer' do
    post(
      '/security_question_users/unlock',
      params: {
        security_question_answer: 'wrong answer'
      }
    )

    assert_equal I18n.t('devise.invalid_security_question'), flash[:alert]
    assert_redirected_to new_security_question_user_unlock_path
  end

  test 'When resource params have an unexpected shape, the response is identical to a wrong answer' do
    post(
      '/security_question_users/unlock',
      params: {
        security_question_answer: 'wrong answer',
        security_question_user: 'not a hash'
      }
    )

    assert_equal I18n.t('devise.invalid_security_question'), flash[:alert]
    assert_redirected_to new_security_question_user_unlock_path
  end

  test 'When the answer is nested in the resource params, it is accepted' do
    post(
      '/security_question_users/unlock',
      params: {
        security_question_user: {
          email: @user.email,
          security_question_answer: @user.security_question_answer
        }
      }
    )

    assert_equal I18n.t('devise.unlocks.send_instructions'), flash[:notice]
    assert_redirected_to new_security_question_user_session_path
  end
end

class TestSecurityQuestionThrottling < ActionDispatch::IntegrationTest
  setup do
    @old_max_attempts = Devise.security_question_max_attempts
    Devise.security_question_max_attempts = 2
    @user = SecurityQuestionUser.create!(
      username: 'hello',
      email: generate_unique_email,
      password: 'A1234567z!',
      security_question_answer: 'Right Answer'
    )
    @user.lock_access!
  end

  teardown do
    Devise.security_question_max_attempts = @old_max_attempts
  end

  test 'After too many failed attempts, even the correct answer is rejected with the same response' do
    2.times do
      post_unlock 'wrong answer'

      assert_equal I18n.t('devise.invalid_security_question'), flash[:alert]
      assert_redirected_to new_security_question_user_unlock_path
    end

    post_unlock @user.security_question_answer

    assert_equal I18n.t('devise.invalid_security_question'), flash[:alert]
    assert_redirected_to new_security_question_user_unlock_path
  end

  test 'A successful attempt resets the failed attempt counter' do
    post_unlock 'wrong answer'

    assert_redirected_to new_security_question_user_unlock_path

    post_unlock @user.security_question_answer

    assert_equal I18n.t('devise.unlocks.send_instructions'), flash[:notice]
    assert_redirected_to new_security_question_user_session_path

    # counter was reset, so another failed attempt is allowed again
    post_unlock 'wrong answer'

    assert_equal I18n.t('devise.invalid_security_question'), flash[:alert]
    assert_redirected_to new_security_question_user_unlock_path
  end

  private

  def post_unlock(answer)
    post(
      '/security_question_users/unlock',
      params: {
        security_question_answer: answer,
        security_question_user: {
          email: @user.email
        }
      }
    )
  end
end

class TestWithoutSecurityQuestion < ActionDispatch::IntegrationTest
  setup do
    @user = User.create(
      username: 'hello',
      email: generate_unique_email,
      password: '1234',
      security_question_answer: 'Right Answer'
    )
    @user.lock_access!
  end

  test 'When security question is not enabled it is not inserted' do
    post '/users/unlock', params: { user: { email: @user.email } }

    assert_equal I18n.t('devise.unlocks.send_instructions'), flash[:notice]
    assert_redirected_to new_user_session_path
  end
end
