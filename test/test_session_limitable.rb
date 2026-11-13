# frozen_string_literal: true

require 'test_helper'

class TestSessionLimitable < ActiveSupport::TestCase
  class ModifiedUser < User
    def skip_session_limitable?
      true
    end
  end

  test 'should have required_fields array' do
    assert_equal [:unique_session_id], Devise::Models::SessionLimitable.required_fields(User)
  end

  test 'check is not skipped by default' do
    user = User.new(email: generate_unique_email, password: 'password1', password_confirmation: 'password1')
    assert_not(user.skip_session_limitable?)
  end

  test 'default check can be overridden by record instance' do
    modified_user = ModifiedUser.new(email: generate_unique_email, password: 'password1', password_confirmation: 'password1')
    assert(modified_user.skip_session_limitable?)
  end

  test 'the sign-out hook condition stays false when session limitable is skipped' do
    modified_user = ModifiedUser.new(
      email: generate_unique_email,
      password: 'password1',
      password_confirmation: 'password1'
    )
    hook_condition = modified_user.devise_modules.include?(:session_limitable) &&
                     !modified_user.skip_session_limitable?
    assert_not(hook_condition)
  end

  class SessionLimitableUser < User
    devise :session_limitable
    include ::Mongoid::Mappings if DEVISE_ORM == :mongoid
  end

  test 'includes Devise::Models::Compatibility' do
    assert_kind_of(Devise::Models::Compatibility, SessionLimitableUser.new)
  end

  test '#update_unique_session_id!(value) updates valid record' do
    user = User.create! password: 'passWord1', password_confirmation: 'passWord1', email: generate_unique_email
    assert user.persisted?
    assert_nil user.unique_session_id
    user.update_unique_session_id!('unique_value')
    user.reload
    assert_equal('unique_value', user.unique_session_id)
  end

  test '#update_unique_session_id!(value) updates invalid record atomically' do
    email = generate_unique_email
    user = User.create! password: 'passWord1', password_confirmation: 'passWord1', email: email
    assert user.persisted?
    user.email = ''
    assert user.invalid?
    assert_nil user.unique_session_id
    user.update_unique_session_id!('unique_value')
    user.reload
    assert_equal(email, user.email)
    assert_equal('unique_value', user.unique_session_id)
  end

  test '#update_unique_session_id!(value) raises an exception on an unpersisted record' do
    user = User.create
    assert_not user.persisted?
    assert_raises(Devise::Models::Compatibility::NotPersistedError) { user.update_unique_session_id!('unique_value') }
  end

  test '#clear_unique_session_id_if_matches! clears the value when the identifier still matches' do
    user = User.create! password: 'passWord1', password_confirmation: 'passWord1', email: generate_unique_email
    user.update_unique_session_id!('unique_value')

    assert(user.clear_unique_session_id_if_matches!('unique_value'))
    assert_nil user.reload.unique_session_id
  end

  test '#clear_unique_session_id_if_matches! keeps a rotated identifier when the identifier does not match' do
    user = User.create! password: 'passWord1', password_confirmation: 'passWord1', email: generate_unique_email
    user.update_unique_session_id!('new_value')

    assert_not(user.clear_unique_session_id_if_matches!('stale_value'))
    assert_equal('new_value', user.reload.unique_session_id)
  end

  test '#clear_unique_session_id_if_matches! raises an exception on an unpersisted record' do
    user = User.create
    assert_not user.persisted?
    assert_raises(Devise::Models::Compatibility::NotPersistedError) do
      user.clear_unique_session_id_if_matches!('unique_value')
    end
  end

  test '#clear_unique_session_id_if_matches! is race-safe against a concurrent identifier rotation' do
    skip 'concurrency check is only meaningful for ActiveRecord' unless DEVISE_ORM == :active_record

    user = User.create! password: 'passWord1', password_confirmation: 'passWord1', email: generate_unique_email
    user.update_unique_session_id!('stale_value')

    barrier = Concurrent::CyclicBarrier.new(2)
    errors = []

    threads = [
      Thread.new do
        barrier.wait
        50.times do
          begin
            User.find(user.id).clear_unique_session_id_if_matches!('stale_value')
          rescue => e
            errors << e
          end
        end
      end,
      Thread.new do
        barrier.wait
        50.times do
          begin
            User.find(user.id).update_unique_session_id!("current_value_#{SecureRandom.hex(4)}")
          rescue => e
            errors << e
          end
        end
      end
    ]
    threads.each(&:join)

    assert_empty errors
    assert_predicate user.reload.unique_session_id, :present?
  end
end
