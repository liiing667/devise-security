# frozen_string_literal: true

require 'test_helper'

class TestSessionLimitableWorkflow < ActionDispatch::IntegrationTest
  include IntegrationHelpers

  setup do
    @user = User.create!(password: 'passWord1',
                         password_confirmation: 'passWord1',
                         email: generate_unique_email)
    @user.confirm
  end

  test 'failed login' do
    assert_nil @user.unique_session_id

    open_session do |session|
      failed_sign_in(@user, session)
      session.assert_response(:success)
      assert_equal devise_invalid_login_message, session.flash[:alert]
      assert_nil @user.reload.unique_session_id
    end
  end

  test 'successful login' do
    assert_nil @user.unique_session_id

    open_session do |session|
      sign_in(@user, session)
      session.assert_redirected_to '/'
      session.get widgets_path
      session.assert_response(:success)
      assert_equal('success', session.response.body)
      assert_not_nil @user.reload.unique_session_id
    end
  end

  test 'session is logged out when another session is created' do
    first_session = open_session
    second_session = open_session
    unique_session_id = nil

    first_session.tap do |session|
      sign_in(@user, session)
      session.assert_redirected_to '/'
      session.get widgets_path
      session.assert_response(:success)
      assert_equal('success', session.response.body)
      unique_session_id = @user.reload.unique_session_id
      assert_not_nil unique_session_id
    end

    second_session.tap do |session|
      sign_in(@user, session)
      session.assert_redirected_to '/'
      session.get widgets_path
      session.assert_response(:success)
      assert_equal('success', session.response.body)
      assert_not_equal unique_session_id, @user.reload.unique_session_id
    end

    first_session.tap do |session|
      session.get widgets_path
      session.assert_redirected_to new_user_session_path
      assert_equal session.flash[:alert], I18n.t('devise.failure.session_limited')
    end
  end

  test 'session is cleared when user logs out' do
    assert_nil @user.unique_session_id

    open_session do |session|
      sign_in(@user, session)
      session.assert_redirected_to '/'
      session.get widgets_path
      session.assert_response(:success)
      assert_equal('success', session.response.body)
      assert_not_nil @user.reload.unique_session_id

      sign_out(session)
      session.assert_redirected_to '/'
      assert_nil @user.reload.unique_session_id
    end
  end

  test 'logging out an older session does not clear the unique session id of a newer session' do
    first_session = open_session
    second_session = open_session
    newer_unique_session_id = nil

    first_session.tap do |session|
      sign_in(@user, session)
      session.assert_redirected_to '/'
      assert_not_nil @user.reload.unique_session_id
    end

    second_session.tap do |session|
      sign_in(@user, session)
      session.assert_redirected_to '/'
      newer_unique_session_id = @user.reload.unique_session_id
      assert_not_nil newer_unique_session_id
    end

    # The first session is already stale at this point. Its sign-out must not
    # touch the identifier owned by the second session.
    first_session.tap do |session|
      sign_out(session)
      session.assert_redirected_to '/'
    end

    assert_equal newer_unique_session_id, @user.reload.unique_session_id

    second_session.tap do |session|
      session.get widgets_path
      session.assert_response(:success)
      assert_equal('success', session.response.body)
    end
  end

  test 'only the current session can clear the unique session id on sign out' do
    first_session = open_session
    second_session = open_session
    newer_unique_session_id = nil

    first_session.tap do |session|
      sign_in(@user, session)
      session.assert_redirected_to '/'
    end

    second_session.tap do |session|
      sign_in(@user, session)
      session.assert_redirected_to '/'
      newer_unique_session_id = @user.reload.unique_session_id
    end

    # The stale first session cannot clear the identifier, but the second
    # session holding the current identifier can still sign out cleanly.
    sign_out(first_session)
    assert_equal newer_unique_session_id, @user.reload.unique_session_id

    sign_out(second_session)
    assert_nil @user.reload.unique_session_id
  end

  test 'an outdated record cannot revive a stale session after a new login' do
    first_session = open_session
    second_session = open_session

    first_session.tap do |session|
      sign_in(@user, session)
      session.assert_redirected_to '/'
      session.get widgets_path
      session.assert_response(:success)
    end

    second_session.tap do |session|
      sign_in(@user, session)
      session.assert_redirected_to '/'
      session.get widgets_path
      session.assert_response(:success)
    end

    # Reusing the first (stale) session keeps rejecting it even after the
    # second session signs out: it can never be revived.
    first_session.get widgets_path
    first_session.assert_redirected_to new_user_session_path
    assert_equal first_session.flash[:alert], I18n.t('devise.failure.session_limited')

    sign_out(second_session)
    assert_nil @user.reload.unique_session_id

    first_session.get widgets_path
    first_session.assert_redirected_to new_user_session_path
  end
end
