# frozen_string_literal: true

require 'test_helper'

class TestSecurityQuestionable < ActiveSupport::TestCase
  test 'should have required_fields array' do
    assert_equal(
      [:security_question_id, :security_question_answer],
      Devise::Models::SecurityQuestionable.required_fields(User)
    )
  end

  test 'valid_security_question_answer? accepts the stored answer' do
    user = SecurityQuestionUser.new(security_question_answer: 'Right Answer')

    assert user.valid_security_question_answer?('Right Answer')
  end

  test 'valid_security_question_answer? rejects a wrong answer' do
    user = SecurityQuestionUser.new(security_question_answer: 'Right Answer')

    assert_not user.valid_security_question_answer?('wrong answer')
  end

  test 'valid_security_question_answer? never matches a blank stored answer' do
    user = SecurityQuestionUser.new(security_question_answer: nil)

    assert_not user.valid_security_question_answer?(nil)
    assert_not user.valid_security_question_answer?('')
  end
end
