# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module CardIntelligenceEngine
  class BincodesProvider
    DEFAULT_ENDPOINT = "https://api.bincodes.com".freeze

    def initialize(api_key: ENV["BINCODES_API_KEY"], endpoint: DEFAULT_ENDPOINT, timeout: 5)
      @api_key = api_key
      @endpoint = endpoint
      @timeout = timeout
    end

    def lookup(bin)
      return nil if @api_key.nil? || @api_key.empty?

      uri = URI("#{@endpoint}/bin/json/#{URI.encode_www_form_component(@api_key)}/#{bin}/")
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                 open_timeout: @timeout, read_timeout: @timeout) do |http|
        http.get(uri.request_uri)
      end
      raise ProviderError, "Bincodes provider returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      payload = JSON.parse(response.body)
      return nil if payload.key?("error")

      {
        "bin" => payload["bin"] || bin,
        "brand" => payload["card"],
        "issuer" => payload["bank"],
        "type" => payload["type"],
        "category" => payload["level"],
        "country" => payload["country"],
        "country_code" => payload["countrycode"],
        "source" => "bincodes"
      }.compact
    rescue JSON::ParserError, SocketError, IOError, SystemCallError, Timeout::Error => e
      raise ProviderError, "Bincodes lookup failed: #{e.class}"
    end
  end
end
