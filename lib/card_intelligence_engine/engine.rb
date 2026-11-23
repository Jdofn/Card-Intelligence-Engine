# frozen_string_literal: true

require_relative "errors"
require_relative "local_provider"
require_relative "bincodes_provider"

module CardIntelligenceEngine
  class Engine
    def initialize(local_provider: LocalProvider.new, remote_provider: BincodesProvider.new)
      @local_provider = local_provider
      @remote_provider = remote_provider
    end

    # Accepts only a BIN/IIN prefix (6-8 digits), never a full card number.
    def lookup(value)
      bin = value.to_s
      raise InvalidBIN, "BIN/IIN must contain 6 to 8 digits only" unless bin.match?(/\A\d{6,8}\z/)

      local = @local_provider.lookup(bin[0, 6])
      return local if local

      remote = @remote_provider.lookup(bin)
      return remote if remote

      raise NotFound, "No metadata found for supplied BIN/IIN"
    end
  end
end
