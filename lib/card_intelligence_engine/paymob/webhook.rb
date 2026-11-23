# frozen_string_literal: true

require "openssl"

module CardIntelligenceEngine
  module Paymob
    # Verifies the documented Transaction Processed Callback HMAC.
    # The callback is only trusted after this check succeeds.
    class Webhook
      TRANSACTION_FIELDS = %w[
        amount_cents created_at currency error_occured has_parent_transaction id
        integration_id is_3d_secure is_auth is_capture is_refunded is_standalone_payment
        is_voided order.id owner pending source_data.pan source_data.sub_type
        source_data.type success
      ].freeze

      def initialize(hmac_secret: ENV["PAYMOB_HMAC_SECRET"])
        @hmac_secret = hmac_secret
      end

      def verify_transaction!(payload, supplied_hmac:)
        raise ConfigurationError, "PAYMOB_HMAC_SECRET is missing" if @hmac_secret.to_s.empty?
        raise ArgumentError, "callback payload must be a Hash" unless payload.is_a?(Hash)
        obj = payload.fetch("obj")
        values = TRANSACTION_FIELDS.map { |field| fetch_path(obj, field) }
        expected = OpenSSL::HMAC.hexdigest("SHA512", @hmac_secret, values.join)
        return true if secure_compare(expected, supplied_hmac.to_s.downcase)
        raise RequestError, "Paymob callback HMAC verification failed"
      rescue KeyError
        raise RequestError, "Paymob callback is missing required HMAC fields"
      end

      # Return only non-sensitive transaction facts. Never persist the raw callback.
      def safe_transaction_summary(payload)
        obj = payload.fetch("obj")
        {
          event_type: payload["type"],
          transaction_id: obj["id"],
          order_id: obj.dig("order", "id"),
          amount_cents: obj["amount_cents"],
          currency: obj["currency"],
          success: obj["success"] == true,
          pending: obj["pending"] == true,
          error_occurred: obj["error_occured"] == true
        }
      end

      private

      def fetch_path(hash, path)
        path.split(".").reduce(hash) { |value, key| value.fetch(key) }
      end

      def secure_compare(left, right)
        return false unless left.bytesize == right.bytesize
        OpenSSL.fixed_length_secure_compare(left, right)
      end
    end
  end
end
