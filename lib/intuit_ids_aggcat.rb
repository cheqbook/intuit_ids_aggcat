require "intuit_ids_aggcat/version"
require "intuit_ids_aggcat/core"

module IntuitIdsAggcat
  class << self

    # @private
    @@config = nil
    @@client = nil

    def config options = {}
      @@config ||= Core::Configuration.new
      @@config = @@config.with(options) unless options.empty?
      @@config
    end

    def client
      @@client ||= Client::Services.new
      @@client
    end

  end
end
