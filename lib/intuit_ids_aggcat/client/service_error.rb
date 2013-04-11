module IntuitIdsAggcat

  module Client

    class ServiceError

      attr_reader :challenge_session_id,
                  :challenge_node_id,
                  :response_code,
                  :response_xml,
                  :error_code,
                  :error_type,
                  :error_message,
                  :not_refreshed_reason

      def initialize(options = {})
        options = {} unless options
        @challenge_session_id = options[:challenge_session_id]
        @challenge_node_id = options[:challenge_node_id]
        @response_code = options[:response_code]
        @response_xml = options[:response_xml]
        @error_code = options[:error_code]
        @error_type = options[:error_type]
        @error_message = options[:error_message]
        @not_refreshed_reason = NotRefreshedReason.new(options[:not_refreshed_reason]) unless options[:not_refreshed_reason].nil?
      end

      def password_reset?
        error_code == "109"
      end

      def unavailable?
        error_code == "105"
      end

      def mfa?
        false
      end

      def account_locked?
        error_code == "103"
      end

      def error?
        true
      end
    end

  end

  class NotRefreshedReason < Struct.new(:reason)
    def unavailable?
      reason === 'UNAVAILABLE'
    end
    def credentials_required?
      reason === 'CREDENTIALS_REQUIRED'
    end
    def mfa?
      reason === 'CHALLENGE_RESPONSE_REQUIRED'
    end
  end
end
