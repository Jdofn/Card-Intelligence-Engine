# frozen_string_literal: true

require "net/http"
require "uri"

module CardIntelligenceEngine
  # Reads the user-supplied 2020 Gist as a last-resort metadata source.
  # It is intentionally metadata-only and never receives full card data.
  class LegacyGistProvider
    SOURCE_URL = "https://gist.githubusercontent.com/mahmoudimus/4bdf559c943d4c69640a748e1b94aa3d/raw/bin_db.sql"
    DATASET_DATE = "2020-06-30"
    CACHE_TTL = 86_400

    def initialize(http: Net::HTTP, clock: -> { Time.now })
      @http = http
      @clock = clock
      @cached_at = nil
      @categories = {}
      @records = []
    end

    def lookup(bin)
      return nil unless bin.to_s.match?(/\A\d{6}\z/)

      refresh_if_needed
      row = @records.find { |record| matches?(record.fetch(:code), bin) }
      return nil unless row

      category = @categories[row.fetch(:category_id)]
      description = row.fetch(:description)
      {
        "bin" => bin,
        "brand" => brand_for(category, description),
        "type" => type_for(description),
        "legacy_description" => description,
        "legacy_category" => category,
        "source" => "legacy_gist_2020",
        "dataset_date" => DATASET_DATE,
        "source_url" => SOURCE_URL
      }.compact
    rescue StandardError
      # This historical, optional source must never take down primary lookup.
      nil
    end

    private

    def refresh_if_needed
      return if @cached_at && (@clock.call - @cached_at) < CACHE_TTL

      uri = URI(SOURCE_URL)
      response = @http.start(uri.host, uri.port, use_ssl: true,
                             open_timeout: 3, read_timeout: 5) do |connection|
        connection.get(uri.request_uri)
      end
      raise "legacy source unavailable" unless response.is_a?(Net::HTTPSuccess)

      sql = response.body
      categories = {}
      sql.scan(/\((\d+),\s*'((?:''|[^'])*)'\)/).each do |id, name|
        categories[id.to_i] = name.gsub("''", "'")
      end
      records = []
      sql.scan(/\(\d+,\s*'((?:''|[^'])*)',\s*'((?:''|[^'])*)',\s*(\d+)\)/).each do |code, description, category_id|
        records << {
          code: code.gsub("''", "'"),
          description: description.gsub("''", "'"),
          category_id: category_id.to_i
        }
      end
      raise "legacy source contained no BIN records" if records.empty?

      @categories = categories
      @records = records
      @cached_at = @clock.call
    end

    def matches?(pattern, bin)
      value = pattern.to_s.strip
      return false if value.empty?

      if value.match?(/\A\d+\z/)
        return bin.start_with?(value) || value.start_with?(bin)
      end

      if value.include?("*")
        regex = Regexp.escape(value).gsub("\\*", "\\d")
        return !!Regexp.new("\\A#{regex}\\z").match(bin)
      end

      range = value.match(/\A(\d+)\s*(?:-|to)\s*(\d+)\z/i)
      return false unless range

      first, last = range.captures
      width = first.length
      last = first[0, width - last.length] + last if last.length < width
      return false unless first.length == last.length && first.match?(/\A\d+\z/) && last.match?(/\A\d+\z/)

      number = bin.to_i
      number.between?(first.to_i, last.to_i)
    end

    def brand_for(category, description)
      text = "#{category} #{description}".upcase
      %w[VISA MASTERCARD AMERICAN\ EXPRESS DISCOVER JCB MAESTRO UNIONPAY DINERS].find do |brand|
        text.include?(brand)
      end&.then { |brand| brand == "AMERICAN EXPRESS" ? "AMEX" : brand }
    end

    def type_for(description)
      text = description.downcase
      return "prepaid" if text.include?("prepaid")
      return "debit" if text.include?("debit")
      return "credit" if text.include?("credit")

      nil
    end
  end
end
