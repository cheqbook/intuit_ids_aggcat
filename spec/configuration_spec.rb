require 'spec_helper'

describe IntuitIdsAggcat::Core::Configuration do
  it 'should configure issuer id' do
    IntuitIdsAggcat.config(:issuer_id => "test_issuer")
    IntuitIdsAggcat.config.issuer_id.should == "test_issuer"
  end

  it 'should configure oauth consumer key' do
    IntuitIdsAggcat.config(:oauth_consumer_key => "consumer_key")
    IntuitIdsAggcat.config.oauth_consumer_key.should == "consumer_key"
  end

  it 'should configure oauth consumer secret' do
    IntuitIdsAggcat.config(:oauth_consumer_secret => "secret")
    IntuitIdsAggcat.config.oauth_consumer_secret.should == "secret"
  end

  it 'should configure certificate path' do
    IntuitIdsAggcat.config(:certificate_path => "cert")
    IntuitIdsAggcat.config.certificate_path.should == "cert"
  end
end