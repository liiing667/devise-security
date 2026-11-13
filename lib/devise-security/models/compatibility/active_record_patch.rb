# frozen_string_literal: true

module Devise
  module Models
    module Compatibility
      class NotPersistedError < ActiveRecord::ActiveRecordError; end

      module ActiveRecordPatch
        extend ActiveSupport::Concern

        unless defined?(ActiveRecord) && ActiveRecord.gem_version >= Gem::Version.new("5.1.x")
          # When the record was saved, was the +encrypted_password+ changed?
          # @return [Boolean]
          def saved_change_to_encrypted_password?
            encrypted_password_changed?
          end

          # The encrypted password that existed before the record was saved
          # @return [String]
          # @return [nil] if an +encrypted_password+ had not been set
          def encrypted_password_before_last_save
            previous_changes['encrypted_password'].try(:first)
          end

          # When the record is saved, will the +encrypted_password+ be changed?
          # @return [Boolean]
          def will_save_change_to_encrypted_password?
            changed_attributes['encrypted_password'].present?
          end
        end

        # Updates the record with the value and does not trigger validations or callbacks
        # @param name [Symbol] attribute to update
        # @param value [String] value to set
        def update_attribute_without_validatons_or_callbacks(name, value)
          update_column(name, value)
        end

        # Atomically updates the record with the value only when all of the
        # given conditions match, without triggering validations or callbacks.
        # The comparison happens in a single UPDATE statement so concurrent
        # updates cannot interleave.
        # @param name [Symbol] attribute to update
        # @param value [String] value to set
        # @param conditions [Hash] attributes the row must currently hold
        # @return [Boolean] whether a row was updated
        def update_attribute_if_matches_without_validations_or_callbacks(name, value, conditions)
          self.class.unscoped.where(conditions.merge(self.class.primary_key => id))
                    .update_all(name => value) == 1
        end
      end
    end
  end
end
