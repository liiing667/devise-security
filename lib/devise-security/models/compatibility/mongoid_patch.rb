# frozen_string_literal: true

module Devise
  module Models
    module Compatibility
      class NotPersistedError < Mongoid::Errors::MongoidError; end

      module MongoidPatch
        extend ActiveSupport::Concern

        # Will saving this record change the +email+ attribute?
        # @return [Boolean]
        def will_save_change_to_email?
          changed.include? 'email'
        end

        # Will saving this record change the +encrypted_password+ attribute?
        # @return [Boolean]
        def will_save_change_to_encrypted_password?
          changed.include? 'encrypted_password'
        end

        # Updates the document with the value and does not trigger validations or callbacks
        # @param name [Symbol] attribute to update
        # @param value [String] value to set
        def update_attribute_without_validatons_or_callbacks(name, value)
          set(Hash[name, value])
        end

        # Atomically updates the document with the value only when all of the
        # given conditions match, without triggering validations or callbacks.
        # The comparison happens in a single update command so concurrent
        # updates cannot interleave.
        # @param name [Symbol] attribute to update
        # @param value [String] value to set
        # @param conditions [Hash] attributes the document must currently hold
        # @return [Boolean] whether a document was updated
        def update_attribute_if_matches_without_validations_or_callbacks(name, value, conditions)
          result = collection.find(conditions.merge(_id: id)).update_one('$set' => { name => value })
          result.matched_count == 1
        end
      end
    end
  end
end
