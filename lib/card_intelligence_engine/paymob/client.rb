# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "securerandom"

module CardIntelligenceEngine
  module Paymob
    class ConfigurationError < StandardError; end
    class RequestError < StandardError; end

    # Creates Paymob Payment Intentions. Card data is entered only on Paymob-hosted checkout.
    class Client
      API_BASE = "https://accept.paymob.com".freeze
      CHECKOUT_BASE = "https://accept.paymob.com/unifiedcheckout/".freeze

      def initialize(secret_key: ENV["PAYMOB_SECRET_KEY"],
                     public_key: ENV["PAYMOB_PUBLIC_KEY"],
                     integration_id: ENV["PAYMOB_INTEGRATION_ID"],
                     api_base: API_BASE,
                     checkout_base: CHECKOUT_BASE,
                     http: Net::HTTP)
        @secret_key = secret_key
        @public_key = public_key
        @integration_id = integration_id
        @api_base = api_base
        @checkout_base = checkout_base
        @http = http
      end

      # amount_cents is an integer in the smallest currency unit (EGP piasters).
      # billing_data must contain customer contact/address fields required by Paymob.
      def create_checkout(amount_cents:, item_name:, billing_data:, currency: "EGP",
                          notification_url:, redirection_url:, reference: SecureRandom.uuid)
        validate_configuration!
        amount = Integer(amount_cents)
        raise ArgumentError, "amount_cents must be positive" unless amount.positive?
        raise ArgumentError, "item_name is required" if item_name.to_s.strip.empty?
        raise ArgumentError, "billing_data must be a Hash" unless billing_data.is_a?(Hash)
        raise ArgumentError, "billing_data.phone_number is required" if billing_data["phone_number"].to_s.strip.empty?
        raise ArgumentError, "notification_url must be HTTPS" unless https_url?(notification_url)
        raise ArgumentError, "redirection_url must be HTTPS" unless https_url?(redirection_url)

        payload = {
          amount: amount,
          currency: currency,
          payment_methods: [Integer(@integration_id)],
          items: [{ name: item_name.to_s, amount: amount, quantity: 1 }],
          billing_data: billing_data,
          special_reference: reference,
          notification_url: notification_url,
          redirection_url: redirection_url
        }

        response = post_json("/v1/intention/", payload)
        client_secret = response.fetch("client_secret")
        {
          intention_id: response["id"],
          order_id: response["intention_order_id"],
          client_secret: client_secret,
          checkout_url: "#{@checkout_base}?publicKey=#{URI.encode_www_form_component(@public_key)}&clientSecret=#{URI.encode_www_form_component(client_secret)}",
          reference: reference
        }
      rescue KeyError => e
        raise RequestError, "Paymob response missing required field: #{e.message}"
      end

      private

      def validate_configuration!
        missing = []
        missing << "PAYMOB_SECRET_KEY" if @secret_key.to_s.empty?
        missing << "PAYMOB_PUBLIC_KEY" if @public_key.to_s.empty?
        missing << "PAYMOB_INTEGRATION_ID" if @integration_id.to_s.empty?
        raise ConfigurationError, "Missing configuration: #{missing.join(', ')}" unless missing.empty?
        raise ConfigurationError, "Sandbox mode requires a sk_test_ secret key" unless @secret_key.start_with?("sk_test_")
      end

      def https_url?(value)
        uri = URI.parse(value.to_s)
        uri.is_a?(URI::HTTPS) && !uri.host.to_s.empty?
      rescue URI::InvalidURIError
        false
      end

      def post_json(path, payload)
        uri = URI.join(@api_base, path)
        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Token #{@secret_key}"
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(payload)
        response = @http.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) do |connection|
          connection.request(request)
        end
        parsed = JSON.parse(response.body)
        return parsed if response.code.to_i.between?(200, 299)
        raise RequestError, "Paymob returned HTTP #{response.code}: #{parsed.is_a?(Hash) ? parsed.fetch('detail', 'request rejected') : 'request rejected'}"
      rescue JSON::ParserError
        raise RequestError, "Paymob returned an invalid JSON response"
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError => e
        raise RequestError, "Paymob connection failed: #{e.class}"
      end
    end
  end
end
