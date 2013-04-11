require 'set'
require 'uri'

module IntuitIdsAggcat
  module Core

    # A configuration object for the Intuit interface.
    #
    # == Configuring Credentials
    #
    # In order to do anything with the AggCat services you will need to assign credentials.
    # The simplest method is to assing your credentials into the default
    # configuration:
    #
    #   AWS.config(:access_key_id => 'KEY', :secret_access_key => 'SECRET')
    #
    # You can also export them into your environment and they will be picked up
    # automatically:
    #
    #   export AWS_ACCESS_KEY_ID='YOUR_KEY_ID_HERE'
    #   export AWS_SECRET_ACCESS_KEY='YOUR_SECRET_KEY_HERE'
    #

    class Configuration

      # Creates a new Configuration object.
      def initialize options = {}

        @created = options.delete(:__created__) || {}
        options.each_pair do |opt_name, value|
          opt_name = opt_name.to_sym
          if self.class.accepted_options.include?(opt_name)
            supplied[opt_name] = value
          end
        end

      end

      # @return [Hash] Returns a hash with your configured credentials.
      def credentials
        credentials = {}
        [:saml_idp_id, :user_id].each do |opt|
          if value = credential_provider.send(opt)
            credentials[opt] = value
          end
        end
        credentials
      end

      def with options = {}

        # symbolize option keys
        options = options.inject({}) {|h,kv| h[kv.first.to_sym] = kv.last; h }

        values = supplied.merge(options)

        if supplied == values
          self # nothing changed
        else
          self.class.new(values.merge(:__created__ => @created.dup))
        end

      end

      # @return [Hash] Returns a hash of all configuration values.
      def to_h
        self.class.accepted_options.inject({}) do |h,k|
          h.merge(k => send(k))
        end
      end
      alias_method :to_hash, :to_h

      # @return [Boolean] Returns true if the two configuration objects have
      #   the same values.
      def eql? other
        other.is_a?(self.class) and self.supplied == other.supplied
      end
      alias_method :==, :eql?

      # @private
      def inspect
        "<#{self.class.name}>"
      end

      protected

      def supplied
        @supplied ||= {}
      end

      class << self

        # @private
        def accepted_options
          @options ||= Set.new
        end

        # @private
        def add_option name, default_value = nil, options = {}, &transform

          accepted_options << name

          define_method(name) do |&default_override|

            value =
              if supplied.has_key?(name)
                supplied[name]
              elsif default_override
                default_override.call
              else
                default_value
              end

            transform ? transform.call(self, value) : value

          end

          alias_method("#{name}?", name) if options[:boolean]

        end

      end

      add_option :certificate_path
      add_option :certificate_string
      add_option :certificate_password
      add_option :issuer_id
      add_option :oauth_consumer_key
      add_option :oauth_consumer_secret
      add_option :oauth_token_info
      add_option :proxy

    end
  end
end