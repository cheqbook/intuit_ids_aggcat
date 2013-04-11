require 'openssl'
require 'nokogiri'
require 'base64'
require 'securerandom'
require 'active_support'
require 'net/https'
require 'cgi'
require 'uri'

module IntuitIdsAggcat

  module Client

    class Saml
      @token_timeout = 600
      class << self

        def get_saml_assertion_xml issuer_id, username = "default", private_key_path, private_key_string, private_key_password, instant
          id = "_#{SecureRandom.uuid.gsub!(/-/, '')}"
          time_format = "%Y-%m-%dT%T.%LZ"
          before = instant - 5*60
          after = instant + @token_timeout
          saml_assertion_xml = <<-EOF_XML
<?xml version="1.0" encoding="UTF-8"?><saml2:Assertion xmlns:saml2="urn:oasis:names:tc:SAML:2.0:assertion" ID="#{id}" IssueInstant="#{instant.utc.strftime(time_format)}" Version="2.0"><saml2:Issuer>#{issuer_id}</saml2:Issuer><ds:Signature xmlns:ds="http://www.w3.org/2000/09/xmldsig#"><ds:SignedInfo><ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/><ds:SignatureMethod Algorithm="http://www.w3.org/2000/09/xmldsig#rsa-sha1"/><ds:Reference URI="##{id}"><ds:Transforms><ds:Transform Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature"/><ds:Transform Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/></ds:Transforms><ds:DigestMethod Algorithm="http://www.w3.org/2000/09/xmldsig#sha1"/><ds:DigestValue>%%DIGEST%%</ds:DigestValue></ds:Reference></ds:SignedInfo><ds:SignatureValue>%%SIGNATURE%%</ds:SignatureValue></ds:Signature><saml2:Subject><saml2:NameID Format="urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified">#{username}</saml2:NameID><saml2:SubjectConfirmation Method="urn:oasis:names:tc:SAML:2.0:cm:bearer"/></saml2:Subject><saml2:Conditions NotBefore="#{before.utc.strftime(time_format)}" NotOnOrAfter="#{after.utc.strftime(time_format)}"><saml2:AudienceRestriction><saml2:Audience>#{issuer_id}</saml2:Audience></saml2:AudienceRestriction></saml2:Conditions><saml2:AuthnStatement AuthnInstant="#{instant.utc.strftime(time_format)}" SessionIndex="#{id}"><saml2:AuthnContext><saml2:AuthnContextClassRef>urn:oasis:names:tc:SAML:2.0:ac:classes:unspecified</saml2:AuthnContextClassRef></saml2:AuthnContext></saml2:AuthnStatement></saml2:Assertion>
EOF_XML
          digestible_xml = get_digestible_xml(saml_assertion_xml)
          digest = calc_digest(digestible_xml).strip
          signed_info_xml = get_signed_info_xml(id, digest)
          signature_value = get_signature_value(signed_info_xml, private_key_path, private_key_string, private_key_password)
          saml_assertion_xml.gsub!(/%%DIGEST%%/, digest)
          saml_assertion_xml.gsub!(/%%SIGNATURE%%/, signature_value)
          return saml_assertion_xml

        end

        def get_signature_value(signed_info_xml, private_key_path, private_key_string, private_key_password)
          if !private_key_path.nil?
            pkey = OpenSSL::PKey::RSA.new(File.read(private_key_path), private_key_password)
          else
            pkey = OpenSSL::PKey::RSA.new(private_key_string, private_key_password)
          end
          signed_info_xml_canon = Nokogiri::XML(signed_info_xml).canonicalize
          digest = OpenSSL::Digest::SHA1.new
          signature = Base64.encode64 pkey.sign(digest, signed_info_xml_canon)
          signature.gsub!(/\n/,'') #remove newline
          return signature
        end

        def get_signed_info_xml(id, digest)
          signed_info_xml = <<-EOF_XML
<ds:SignedInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#"><ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/><ds:SignatureMethod Algorithm="http://www.w3.org/2000/09/xmldsig#rsa-sha1"/><ds:Reference URI="##{id}"><ds:Transforms><ds:Transform Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature"/><ds:Transform Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/></ds:Transforms><ds:DigestMethod Algorithm="http://www.w3.org/2000/09/xmldsig#sha1"/><ds:DigestValue>#{digest.strip}</ds:DigestValue></ds:Reference></ds:SignedInfo>
EOF_XML
          signed_info_xml = signed_info_xml.strip
          return signed_info_xml
        end

        def calc_digest(digestible_xml)
          doc = Nokogiri::XML(digestible_xml)
          doc_canonicalized = doc.canonicalize(mode=Nokogiri::XML::XML_C14N_1_1)
          digest = OpenSSL::Digest::SHA1.new.digest(doc_canonicalized)
          digest_b64 = Base64.encode64(digest)
          return digest_b64
        end

        def get_digestible_xml(saml_assertion_xml)
          doc = Nokogiri::XML(saml_assertion_xml)
          doc.xpath('//ds:Signature', 'ds' => "http://www.w3.org/2000/09/xmldsig#" ).each do |node|
            node.remove
          end
          new_xml = doc.root.to_s
          doc = Nokogiri::XML(new_xml)
          doc.xpath('//text()[not(normalize-space())]').remove
          doc_canonical = doc.canonicalize(mode=Nokogiri::XML::XML_C14N_1_1)
          return doc_canonical.to_s.strip
        end

        def send_saml_assertion(saml_assertion_b64, oauth_consumer_key, oauth_consumer_secret)

          oauth_url="https://oauth.intuit.com/oauth/v1/get_access_token_by_saml"

          uri = URI.parse(oauth_url)
          if IntuitIdsAggcat.config.proxy.nil?
            http = Net::HTTP.new(uri.host, uri.port)
          else
            proxy_uri = URI.parse(IntuitIdsAggcat.config.proxy)
            http = Net::HTTP::Proxy(proxy_uri.host,proxy_uri.port).new(uri.host, uri.port)
          end
          request = Net::HTTP::Post.new(uri.request_uri)
          request["Content-Type"] = "application/x-www-form-urlencoded"
          request["Content-Language"] = "en-US"
          request["Content-Length"] = saml_assertion_b64.length
          request["Authorization"] = "OAuth oauth_consumer_key=\"#{oauth_consumer_key}\""
          request["Host"] = "financialdatafeed.platform.intuit.com"
          request.set_form_data({"saml_assertion"=>saml_assertion_b64})
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          #http.set_debug_output($stdout)
          response = http.request(request)
          params = CGI::parse(response.body)
          return {oauth_token_secret: params["oauth_token_secret"][0],
                  oauth_token: params["oauth_token"][0] }
          
        end
        def get_oauth_info issuer_id, username, oauth_consumer_key, oauth_consumer_secret, private_key_path, private_key_string, private_key_password
          instant = Time.now
          saml_assertion_xml = get_saml_assertion_xml issuer_id, username, private_key_path, private_key_string, private_key_password, instant
          saml_assertion_b64 = Base64.strict_encode64(saml_assertion_xml)
          oauth_token_info = send_saml_assertion saml_assertion_b64, oauth_consumer_key, oauth_consumer_secret
          oauth_token_info[:token_expiry] = instant + @token_timeout
          oauth_token_info
        end

        def get_tokens username, issuer_id = IntuitIdsAggcat.config.issuer_id, oauth_consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, oauth_consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret, certificate_path = IntuitIdsAggcat.config.certificate_path, certificate_string = IntuitIdsAggcat.config.certificate_string, certificate_password = IntuitIdsAggcat.config.certificate_password
            oauth_token_info = get_oauth_info issuer_id, username, oauth_consumer_key, oauth_consumer_secret, certificate_path, certificate_string, certificate_password
        end

      end
    end
  end
end