require 'spec_helper'

describe IntuitIdsAggcat::Client::Saml do
  it 'should generate a SAML assertion' do
    SecureRandom.stub(:uuid).and_return("6bf05546-89ee-4ec1-8cf7-e90c438cb147")
    IntuitIdsAggcat::Client::Saml.get_saml_assertion_xml("rails_test_id", "test", "spec/config/test.key", nil, nil, Time.new(2008,6,21, 13,30,0, "+09:00")).should == 
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?><saml2:Assertion xmlns:saml2=\"urn:oasis:names:tc:SAML:2.0:assertion\" ID=\"_6bf0554689ee4ec18cf7e90c438cb147\" IssueInstant=\"2008-06-21T04:30:00.000Z\" Version=\"2.0\"><saml2:Issuer>rails_test_id</saml2:Issuer><ds:Signature xmlns:ds=\"http://www.w3.org/2000/09/xmldsig#\"><ds:SignedInfo><ds:CanonicalizationMethod Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"/><ds:SignatureMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#rsa-sha1\"/><ds:Reference URI=\"#_6bf0554689ee4ec18cf7e90c438cb147\"><ds:Transforms><ds:Transform Algorithm=\"http://www.w3.org/2000/09/xmldsig#enveloped-signature\"/><ds:Transform Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"/></ds:Transforms><ds:DigestMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#sha1\"/><ds:DigestValue>nzk4auzjFeqgAeWIKFAvtjxHKqc=</ds:DigestValue></ds:Reference></ds:SignedInfo><ds:SignatureValue>Yv5BHxMttOlN+N+LQnEYXDvzCpTTpqWegDJQTnJtqyohH5WEllszOrDad0ZugO4NToa179aJkb0bhSHRlUZ83BAR2WqZjTG8a9tSEd/PGAbUkGmzNiGF8kYTuXAq//PmED6HYAO/PAXzaK9kubMLO+ZlOnyD0eW7+t913A0W0VY=</ds:SignatureValue></ds:Signature><saml2:Subject><saml2:NameID Format=\"urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified\">test</saml2:NameID><saml2:SubjectConfirmation Method=\"urn:oasis:names:tc:SAML:2.0:cm:bearer\"/></saml2:Subject><saml2:Conditions NotBefore=\"2008-06-21T04:25:00.000Z\" NotOnOrAfter=\"2008-06-21T04:40:00.000Z\"><saml2:AudienceRestriction><saml2:Audience>rails_test_id</saml2:Audience></saml2:AudienceRestriction></saml2:Conditions><saml2:AuthnStatement AuthnInstant=\"2008-06-21T04:30:00.000Z\" SessionIndex=\"_6bf0554689ee4ec18cf7e90c438cb147\"><saml2:AuthnContext><saml2:AuthnContextClassRef>urn:oasis:names:tc:SAML:2.0:ac:classes:unspecified</saml2:AuthnContextClassRef></saml2:AuthnContext></saml2:AuthnStatement></saml2:Assertion>\n"
  end

  it "should return signed XML" do
    IntuitIdsAggcat::Client::Saml.get_signed_info_xml("123", "test").should == 
      "<ds:SignedInfo xmlns:ds=\"http://www.w3.org/2000/09/xmldsig#\"><ds:CanonicalizationMethod Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"/><ds:SignatureMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#rsa-sha1\"/><ds:Reference URI=\"#123\"><ds:Transforms><ds:Transform Algorithm=\"http://www.w3.org/2000/09/xmldsig#enveloped-signature\"/><ds:Transform Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"/></ds:Transforms><ds:DigestMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#sha1\"/><ds:DigestValue>test</ds:DigestValue></ds:Reference></ds:SignedInfo>"
  end

  it "should return tokens" do
    path = Pathname.new("spec/config/real_config.yml")
    config = YAML::load(ERB.new(File.read(path)).result)
    IntuitIdsAggcat.config(config)
    tokens = IntuitIdsAggcat::Client::Saml.get_tokens "test"
    tokens[:oauth_token_secret].should_not be_nil
    tokens[:oauth_token].should_not be_nil
    tokens[:token_expiry].should_not be_nil
  end

  it "should return different tokens for different usernames" do 
    path = Pathname.new("spec/config/real_config.yml")  
    config = YAML::load(ERB.new(File.read(path)).result)  
    IntuitIdsAggcat.config(config)   
    tokens = IntuitIdsAggcat::Client::Saml.get_tokens "test" 
    tokens[:oauth_token_secret].should_not be_nil
    tokens[:oauth_token].should_not be_nil  
    tokens[:token_expiry].should_not be_nil  
    tokens2 = IntuitIdsAggcat::Client::Saml.get_tokens "test2"  
    tokens2[:oauth_token_secret].should_not be_nil    
    tokens2[:oauth_token].should_not be_nil     
    tokens2[:token_expiry].should_not be_nil    
    tokens[:oauth_token_secret].should_not eql(tokens2[:oauth_token_secret])   
    tokens[:oauth_token].should_not eql(tokens2[:oauth_token])      
  end

end

