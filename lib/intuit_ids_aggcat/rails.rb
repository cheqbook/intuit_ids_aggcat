require 'yaml'

module IntuitIdsAggcat

  if Object.const_defined?(:Rails) and Rails.const_defined?(:Railtie)

    # @private
    class Railtie < Rails::Railtie

      # configure our plugin on boot. other extension points such
      # as configuration, rake tasks, etc, are also available
      initializer "intuit_ids_aggcat.initialize" do |app|
        IntuitIdsAggcat::Rails.setup
      end
    end

  end

  # A handful of useful Rails integration methods.
  #
  # If you require this gem inside a Rails application (via config.gem
  # for rails 2 and bundler for rails 3) then {setup} is called
  # automatically.
  module Rails

    # Adds extra functionality to Rails.
    #
    # Normailly this method is invoked automatically when you require this
    # gem in a Rails Application:
    #
    # Rails 3+ (RAILS_ROOT/Gemfile)
    #
    #   gem 'intuit_ids_aggcat'
    #

    # @return [nil]
    def self.setup
      load_yaml_config
      log_to_rails_logger
      nil
    end

    # Loads Intuit IDS AggCat configuration options from +RAILS_ROOT/config/intuit_ids_aggcat.yml+.
    #
    # This configuration file is optional.  You can omit this file and instead
    # use ruby to configure the gem inside a configuration initialization script
    # (e.g. RAILS_ROOT/config/intializers/intuit_ids_aggcat.rb).
    #
    # If you have a yaml configuration file it should be formatted like the
    # standard +database.yml+ file in a Rails application.  This means there
    # should be one section for Rails environment:
    #
    #   development:
    #     certificate_path: path to private key
    #     issuer_id: SAML issuer ID provided by intuit
    #     oauth_consumer_key: OAuth consumer key
    #     oauth_consumer_secret: OAuth consumer secret
    #
    #   production:
    #     certificate_path: path to private key
    #     issuer_id: SAML issuer ID provided by intuit
    #     oauth_consumer_key: OAuth consumer key
    #     oauth_consumer_secret: OAuth consumer secret

    def self.load_yaml_config

      path = Pathname.new("#{rails_root}/config/intuit_ids_aggcat.yml")

      if File.exists?(path)
        cfg = YAML::load(ERB.new(File.read(path)).result)
        unless cfg[rails_env]
          raise "config/intuit_ids_aggcat.yml is missing a section for `#{rails_env}`"
        end
        IntuitIdsAggcat.config(cfg[rails_env])
      end

    end


    # Configures gem to log to the Rails default logger.
    # @return [nil]
    def self.log_to_rails_logger
     # AWS.config(:logger => rails_logger)
      nil
    end

    # @private
    protected
    def self.rails_env
      ::Rails.respond_to?(:env) ? ::Rails.env : RAILS_ENV
    end

    # @private
    protected
    def self.rails_root
      ::Rails.respond_to?(:root) ? ::Rails.root.to_s : RAILS_ROOT
    end

    # @private
    protected
    def self.rails_logger
      ::Rails.respond_to?(:logger) ? ::Rails.logger : ::RAILS_DEFAULT_LOGGER
    end

  end
end