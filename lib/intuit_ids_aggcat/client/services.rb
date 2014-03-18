require 'oauth'
require 'rexml/document'
require 'xml/mapping'
require 'intuit_ids_aggcat/client/intuit_xml_mappings'
require_relative 'service_error'
require 'socket'

module IntuitIdsAggcat

  module Client

    class Services

      class << self

        def initialize

        end

        ##
        # Gets all institutions supported by Intuit. If oauth_token_info isn't provided, new tokens are provisioned using "default" user
        # consumer_key and consumer_secret will be retrieved from the Configuration class if not provided
        def get_institutions oauth_token_info = IntuitIdsAggcat::Client::Saml.get_tokens("default"), consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret
          write_to_log(
              "=================================================",
              __method__,
              "================================================="
          )
          response = oauth_get_request "https://financialdatafeed.platform.intuit.com/v1/institutions", oauth_token_info, consumer_key, consumer_secret
          if response.present? && response[:response_code] == "200"
            institutions = Institutions.load_from_xml(response[:response_xml].root)
            institutions.institutions
          else
            IntuitIdsAggcat::Client::ServiceError.new(response)
          end
        end

        ##
        # Gets the institution details for id. If oauth_token_info isn't provided, new tokens are provisioned using "default" user
        # consumer_key and consumer_secret will be retrieved from the Configuration class if not provided
        def get_institution_detail id, oauth_token_info = IntuitIdsAggcat::Client::Saml.get_tokens("default"), consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret
          write_to_log(
              "=================================================",
              __method__,
              "================================================="
          )
          response = oauth_get_request "https://financialdatafeed.platform.intuit.com/v1/institutions/#{id}", oauth_token_info, consumer_key, consumer_secret
          if response.present? && response[:response_code] == "200"
            institutions = InstitutionDetail.load_from_xml(response[:response_xml].root)
            institutions
          else
            IntuitIdsAggcat::Client::ServiceError.new(response)
          end
        end

        ##
        # Get a specific account for a customer from aggregation at Intuit.
        # username and account ID must be provided, if no oauth_token_info is provided, new tokens will be provisioned using username
        def get_account username, account_id, oauth_token_info = IntuitIdsAggcat::Client::Saml.get_tokens(username), consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret
          url = "https://financialdatafeed.platform.intuit.com/v1/accounts/#{account_id}"
          write_to_log(
              "=================================================",
              __method__,
              "=================================================",
              "url",
              url,
              "user_id",
              username
          )
          response = oauth_get_request url, oauth_token_info
          if response.present? && response[:response_code] == "200"
            account = AccountList.load_from_xml(response[:response_xml].root)
          else
            IntuitIdsAggcat::Client::ServiceError.new(response)
          end
        end


        ##
        # Deletes the customer's accounts from aggregation at Intuit.
        # username must be provided, if no oauth_token_info is provided, new tokens will be provisioned using username
        def delete_customer username, oauth_token_info = IntuitIdsAggcat::Client::Saml.get_tokens(username), consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret
          url = "https://financialdatafeed.platform.intuit.com/v1/customers/"
          write_to_log(
              "=================================================",
              __method__,
              "=================================================",
              "url",
              url,
              "user_id",
              username
          )
          oauth_delete_request url, oauth_token_info
        end

        ##
        # Deletes the a specific account for a customer from aggregation at Intuit.
        # username and account ID must be provided, if no oauth_token_info is provided, new tokens will be provisioned using username
        def delete_account username, account_id, oauth_token_info = IntuitIdsAggcat::Client::Saml.get_tokens(username), consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret
          url = "https://financialdatafeed.platform.intuit.com/v1/accounts/#{account_id}"
          write_to_log(
              "=================================================",
              __method__,
              "=================================================",
              "url",
              url,
              "user_id",
              username
          )
          oauth_delete_request url, oauth_token_info
        end

        ##
        # Discovers and adds accounts using credentials
        # institution_id is the ID of the institution, username is the ID for this customer's accounts at Intuit and must be used for future requests,
        # creds_hash is a hash object of key value pairs used for authentication
        # If oauth_token is not provided, new tokens will be provisioned using the username provided
        # Returns a hash produced by parse_account_data with the following keys:
        #    discover_response   : hash including the following keys:
        #                              response_code:        HTTP response code from Intuit
        #                              response_xml :        XML returned by Intuit
        #    accounts            : Ruby hash with accounts if returned by discover call
        #    challenge_type      : text description of the type of challenge requested, if applicable
        #                          "none" | "choice" | "image" | "text"
        #    challenge           : Ruby hash with the detail of the challenge if applicable
        #    challenge_session_id: challenge session ID to pass to challenge_response if this is a challenge
        #    challenge_node_id   : challenge node ID to pass to challenge_response if this is a challenge
        #    description         : text description of the result of the discover request

        def discover_and_add_accounts_with_credentials institution_id, username, creds_hash, oauth_token_info = IntuitIdsAggcat::Client::Saml.get_tokens(username), consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret
          url = "https://financialdatafeed.platform.intuit.com/v1/institutions/#{institution_id}/logins"
          write_to_log(
              "=================================================",
              __method__,
              "=================================================",
              "url",
              url,
              "user_id",
              username
          )
          credentials_array = []
          creds_hash.each do |k, v|
            c = Credential.new
            c.name = k
            c.value = v
            credentials_array.push c
          end
          creds = Credentials.new
          creds.credential = credentials_array
          il = InstitutionLogin.new
          il.credentials = creds
          daa = oauth_post_request url, il.save_to_xml.to_s, oauth_token_info
          parse_account_data daa
        end

        ##
        # Given a username, response text, challenge session ID and challenge node ID, passes the credentials to Intuit to begin aggregation
        def challenge_response institution_id, username, response, challenge_session_id, challenge_node_id, oauth_token_info = IntuitIdsAggcat::Client::Saml.get_tokens(username), consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret
          url = "https://financialdatafeed.platform.intuit.com/v1/institutions/#{institution_id}/logins"
          write_to_log(
              "=================================================",
              __method__,
              "=================================================",
              "url",
              url,
              "user_id",
              username
          )
          if !(response.kind_of?(Array) || response.respond_to?('each'))
            response = [response]
          end

          cr = IntuitIdsAggcat::ChallengeResponses.new
          cr.response = response
          il = IntuitIdsAggcat::InstitutionLogin.new
          il.challenge_responses = cr
          daa = oauth_post_request url, il.save_to_xml.to_s, oauth_token_info, {"challengeSessionId" => challenge_session_id, "challengeNodeId" => challenge_node_id}
          parse_account_data daa
        end

        ##
        # Gets all accounts for a customer
        def get_customer_accounts username, oauth_token_info = IntuitIdsAggcat::Client::Saml.get_tokens(username), consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret
          url = "https://financialdatafeed.platform.intuit.com/v1/accounts/"
          write_to_log(
              "=================================================",
              __method__,
              "=================================================",
              "url",
              url,
              "user_id",
              username
          )
          response = oauth_get_request url, oauth_token_info
          if response.present? && response[:response_code] == "200"
            accounts = AccountList.load_from_xml(response[:response_xml].root)
          else
            IntuitIdsAggcat::Client::ServiceError.new(response)
          end
        end

        ##
        # Get transactions for a specific account and timeframe
        def get_account_transactions username, account_id, start_date, end_date = nil, oauth_token_info = IntuitIdsAggcat::Client::Saml.get_tokens(username), consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret
          txn_start = start_date.strftime("%Y-%m-%d")
          url = "https://financialdatafeed.platform.intuit.com/v1/accounts/#{account_id}/transactions?txnStartDate=#{txn_start}"
          write_to_log(
              "=================================================",
              __method__,
              "=================================================",
              "url",
              url,
              "user_id",
              username
          )
          if !end_date.nil?
            txn_end = end_date.strftime("%Y-%m-%d")
            url = "#{url}&txnEndDate=#{txn_end}"
          end
          response = oauth_get_request url, oauth_token_info
          if response.present?
            xml = REXML::Document.new response[:response_xml].to_s
            if response[:response_xml].to_s.include?("notRefreshedReason='UNAVAILABLE'")
              IntuitIdsAggcat::Client::ServiceError.new(response.merge(:not_refreshed_reason => "UNAVAILABLE"))
            elsif response[:response_xml].to_s.include?("notRefreshedReason='CREDENTIALS_REQUIRED'")
              IntuitIdsAggcat::Client::ServiceError.new(response.merge(:not_refreshed_reason => "CREDENTIALS_REQUIRED"))
            elsif response[:response_xml].to_s.include?("notRefreshedReason='CHALLENGE_RESPONSE_REQUIRED'")
              IntuitIdsAggcat::Client::ServiceError.new(response.merge(:not_refreshed_reason => "CHALLENGE_RESPONSE_REQUIRED"))
            elsif response[:response_code] == "200"
              IntuitIdsAggcat::TransactionList.load_from_xml xml.root
            else
              IntuitIdsAggcat::Client::ServiceError.new(response)
            end
          else
            IntuitIdsAggcat::Client::ServiceError.new
          end
        end

        ##
        # Helper method for parsing discover account response data
        def parse_account_data response
          challenge_type = "none"
          write_to_log(
              "=================================================",
              __method__,
              "=================================================",
              response
          )
          if response.present? && ["200", "201"].include?(response[:response_code])
            accounts = AccountList.load_from_xml(response[:response_xml].root)
          elsif response.present? && response[:response_code] == "401" && response[:challenge_session_id]
            # return challenge
            challenge = Challenges.load_from_xml(response[:response_xml].root)
            challenge.challenge_type = if challenge.save_to_xml.to_s.include?("<choice>")
                                         "choice"
                                       elsif challenge.save_to_xml.to_s.include?("image")
                                         "image"
                                       else
                                         "text"
                                       end
            challenge.challenge_session_id = response[:challenge_session_id]
            challenge.challenge_node_id = response[:challenge_node_id]
            challenge.error_code = response[:error_code]
            challenge.error_type = response[:error_type]
            challenge.error_message = response[:error_message]
            challenge
          else
            IntuitIdsAggcat::Client::ServiceError.new(response)
          end
        end

        ##
        # This call is used to update the account credentials of an added account or explicitly refresh transactions
        # Explicit Refresh: IntuitIdsAggcat::Client::Services.update_institution_login <username>, {}, <institution_login_id>, true
        # Reauthentication: IntuitIdsAggcat::Client::Services.update_institution_login <username>, {<username_label> => <username>, <password_label> => <password>}, <institution_login_id>
        def update_institution_login username, creds_hash, institution_login_id, refresh = false, oauth_token_info = IntuitIdsAggcat::Client::Saml.get_tokens(username), consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret
          url = "https://financialdatafeed.platform.intuit.com/rest-war/v1/logins/#{institution_login_id}"
          url = "#{url}?refresh=true" if refresh == true
          write_to_log(
              "=================================================",
              __method__,
              "=================================================",
              "url",
              url,
              "user_id",
              username
          )
          if !creds_hash.nil? && !creds_hash.empty?
            credentials_array = []
            creds_hash.each do |k, v|
              c = Credential.new
              c.name = k
              c.value = v
              credentials_array.push c
            end
            creds = Credentials.new
            creds.credential = credentials_array
            il = InstitutionLogin.new
            il.credentials = creds
            data = il.save_to_xml.to_s
          else
            data = ""
          end
          daa = oauth_put_request url, data, oauth_token_info
          parse_account_data daa
        end

        ##
        # Given a username, response text, challenge session ID and challenge node ID, passes the credentials to Intuit to begin aggregation
        def update_institution_login_challenge_response institution_login_id, username, response, challenge_session_id, challenge_node_id, oauth_token_info = IntuitIdsAggcat::Client::Saml.get_tokens(username), consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret
          url = "https://financialdatafeed.platform.intuit.com/v1/logins/#{institution_login_id}"
          write_to_log(
              "=================================================",
              __method__,
              "=================================================",
              "url",
              url,
              "user_id",
              username
          )
          if !(response.kind_of?(Array) || response.respond_to?('each'))
            response = [response]
          end

          cr = IntuitIdsAggcat::ChallengeResponses.new
          cr.response = response
          il = IntuitIdsAggcat::InstitutionLogin.new
          il.challenge_responses = cr
          daa = oauth_put_request url, il.save_to_xml.to_s, oauth_token_info, {"challengeSessionId" => challenge_session_id, "challengeNodeId" => challenge_node_id}
          parse_account_data daa
        end

        ##
        # This call updates the type of an account from "Other" to some concrete account type.
        def update_account_type username, account_id, account_type, account_sub_type, oauth_token_info = IntuitIdsAggcat::Client::Saml.get_tokens(username), consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret
          url = "https://financialdatafeed.platform.intuit.com/v1/accounts/#{account_id}"
          write_to_log(
              "=================================================",
              __method__,
              "=================================================",
              "url",
              url,
              "user_id",
              username
          )
          if account_type == "Banking"
            acct_type = IntuitIdsAggcat::BankingAccountType.new
          elsif account_type == "Credit"
            acct_type = IntuitIdsAggcat::CreditAccountType.new
          elsif account_type == "Loan"
            acct_type = IntuitIdsAggcat::LoanType.new
          elsif account_type == "Investment"
            acct_type = IntuitIdsAggcat::InvestmentAccountType.new
          elsif account_type == "Rewards"
            acct_type = IntuitIdsAggcat::RewardsAccountType.new
          end
          acct_type.account_type = account_sub_type
          response = oauth_put_request url, acct_type.save_to_xml.to_s, oauth_token_info
          if response.present? && response[:response_code] == "200"
            200
          else
            IntuitIdsAggcat::Client::ServiceError.new(response)
          end
        end

        ##
        # Helper method to issue post requests
        def oauth_post_request url, body, oauth_token_info, headers = {}, consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret, timeout = 600
          oauth_token = oauth_token_info[:oauth_token]
          oauth_token_secret = oauth_token_info[:oauth_token_secret]

          options = {:request_token_path => 'https://financialdatafeed.platform.intuit.com', :timeout => timeout}
          options = options.merge({:proxy => IntuitIdsAggcat.config.proxy}) if !IntuitIdsAggcat.config.proxy.nil?
          consumer = OAuth::Consumer.new(consumer_key, consumer_secret, options)
          access_token = OAuth::AccessToken.new(consumer, oauth_token, oauth_token_secret)
          dateTime = Time.new
          timestamp = dateTime.to_time.to_i
          write_to_log(
              "timestamp",
              timestamp,
              "url",
              url,
              "oauth_token_info",
              oauth_token_info,
              "consumer_key",
              consumer_key,
              "consumer_secret",
              consumer_secret,
              "consumer",
              consumer,
              "access_token",
              access_token,
              "body",
              body
          )
          response = access_token.post(url, body, {"Content-Type" => 'application/xml', 'Host' => 'financialdatafeed.platform.intuit.com'}.merge(headers))
          response_xml = REXML::Document.new response.body
          write_to_log(
              "=================================================",
              "response",
              "=================================================",
              response
          )
          # handle challenge responses from discoverAndAcccounts flow
          challenge_session_id = challenge_node_id = nil
          if !response["challengeSessionId"].nil?
            challenge_session_id = response["challengeSessionId"]
            challenge_node_id = response["challengeNodeId"]
          end
          {:challenge_session_id => challenge_session_id, :challenge_node_id => challenge_node_id, :response_code => response.code, :response_xml => response_xml}.merge(with_errors(response_xml))
        end

        ##
        # Helper method to issue get requests
        def oauth_get_request url, oauth_token_info, consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret, timeout = 600
          oauth_token = oauth_token_info[:oauth_token]
          oauth_token_secret = oauth_token_info[:oauth_token_secret]

          options = {:request_token_path => 'https://financialdatafeed.platform.intuit.com', :timeout => timeout}
          options = options.merge({:proxy => IntuitIdsAggcat.config.proxy}) if !IntuitIdsAggcat.config.proxy.nil?
          consumer = OAuth::Consumer.new(consumer_key, consumer_secret, options)
          access_token = OAuth::AccessToken.new(consumer, oauth_token, oauth_token_secret)
          dateTime = Time.new
          timestamp = dateTime.to_time.to_i
          write_to_log(
              "timestamp",
              timestamp,
              "url",
              url,
              "oauth_token_info",
              oauth_token_info,
              "consumer_key",
              consumer_key,
              "consumer_secret",
              consumer_secret,
              "consumer",
              consumer,
              "access_token",
              access_token
          )
          begin
            response = access_token.get(url, {"Content-Type" => 'application/xml', 'Host' => 'financialdatafeed.platform.intuit.com'})
            response_xml = REXML::Document.new response.body
            write_to_log(
                "=================================================",
                "response",
                "=================================================",
                response,
                response.body
            )
          rescue REXML::ParseException => msg
            #Rails.logger.error "REXML Parse Exception"
            return nil
          end
          {:response_code => response.code, :response_xml => response_xml}.merge(with_errors(response_xml))
        end

        ##
        # Helper method to issue put requests
        def oauth_put_request url, body, oauth_token_info, headers = {}, consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret, timeout = 600
          oauth_token = oauth_token_info[:oauth_token]
          oauth_token_secret = oauth_token_info[:oauth_token_secret]
          options = {:request_token_path => 'https://financialdatafeed.platform.intuit.com', :timeout => timeout, :http_method => :put}
          options = options.merge({:proxy => IntuitIdsAggcat.config.proxy}) if !IntuitIdsAggcat.config.proxy.nil?
          consumer = OAuth::Consumer.new(consumer_key, consumer_secret, options)
          access_token = OAuth::AccessToken.new(consumer, oauth_token, oauth_token_secret)
          dateTime = Time.new
          timestamp = dateTime.to_time.to_i
          write_to_log(
              "timestamp",
              timestamp,
              "url",
              url,
              "oauth_token_info",
              oauth_token_info,
              "consumer_key",
              consumer_key,
              "consumer_secret",
              consumer_secret,
              "body",
              body
          )
          begin
            response = access_token.put(url, body, {"Content-Type" => 'application/xml', 'Host' => 'financialdatafeed.platform.intuit.com'}.merge(headers))
            write_to_log(
                "=================================================",
                "response",
                "=================================================",
                response,
                response.body
            )
            response_xml = REXML::Document.new response.body
          rescue REXML::ParseException => msg
            #Rails.logger.error "REXML Parse Exception"
            return nil
          end
          # handle challenge responses from discoverAndAcccounts flow
          challenge_session_id = challenge_node_id = nil
          if !response["challengeSessionId"].nil?
            challenge_session_id = response["challengeSessionId"]
            challenge_node_id = response["challengeNodeId"]
          end
          {:challenge_session_id => challenge_session_id, :challenge_node_id => challenge_node_id, :response_code => response.code, :response_xml => response_xml}.merge(with_errors(response_xml))
        end


        ##
        # Helper method to issue delete requests
        def oauth_delete_request url, oauth_token_info, consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret, timeout = 600
          oauth_token = oauth_token_info[:oauth_token]
          oauth_token_secret = oauth_token_info[:oauth_token_secret]

          options = {:request_token_path => 'https://financialdatafeed.platform.intuit.com', :timeout => timeout}
          options = options.merge({:proxy => IntuitIdsAggcat.config.proxy}) if !IntuitIdsAggcat.config.proxy.nil?
          consumer = OAuth::Consumer.new(consumer_key, consumer_secret, options)
          access_token = OAuth::AccessToken.new(consumer, oauth_token, oauth_token_secret)
          dateTime = Time.new
          timestamp = dateTime.to_time.to_i
          write_to_log(
              "timestamp",
              timestamp,
              "url",
              url,
              "oauth_token_info",
              oauth_token_info,
              "consumer_key",
              consumer_key,
              "consumer_secret",
              consumer_secret
          )
          response = access_token.delete(url, {"Content-Type" => 'application/xml', 'Host' => 'financialdatafeed.platform.intuit.com'})
          write_to_log(
              "=================================================",
              "response",
              "=================================================",
              response,
              response.body
          )
          response_xml = REXML::Document.new response.body
          {:response_code => response.code, :response_xml => response_xml}.merge(with_errors(response_xml))
        end

        private

        def with_errors response_xml
          error_hash = {:error_code => nil, :error_type => nil, :error_message => nil}
          if !response_xml.elements["Status/errorInfo"].nil?
            error_hash[:error_code] = response_xml.elements["Status/errorInfo/errorCode"].text
            error_hash[:error_type] = response_xml.elements["Status/errorInfo/errorType"].text
            error_hash[:error_message] = response_xml.elements["Status/errorInfo/errorMessage"].text
          end
          error_hash
        end

        def write_to_log *args
          #yield if block_given? && Socket.gethostname =~ /ryan|ben/i
          data_string = args.join("\n")
          data_string = data_string.gsub(/<v11[^>]*>.+<\/v11[^>]*>/, 'HIDDEN_CHALLENGE_RESPONSES ')
          data_string = data_string.gsub(/<challenge>.+<\/challenge>/, 'HIDDEN_CHALLENGES ')
          #data_string = data_string.gsub(/<credential>.+<\/credential>/, 'HIDDEN_CREDENTIALS ')

          puts data_string if !data_string.blank?
        end
      end
    end
  end
end
