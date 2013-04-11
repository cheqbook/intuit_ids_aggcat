require 'spec_helper'

describe IntuitIdsAggcat::Rails do
  it 'should load configuration from a YAML file' do
    Rails = Object.new
    ::Rails.stub(:root).and_return("#{Dir.pwd}/spec")
    ::Rails.stub(:env).and_return("development")
    IntuitIdsAggcat::Rails.load_yaml_config
    IntuitIdsAggcat.config.issuer_id.should == "rails_test_id"
    IntuitIdsAggcat.config.certificate_path.should == "test.key"
    IntuitIdsAggcat.config.oauth_consumer_key.should == "rails_test_key"
    IntuitIdsAggcat.config.oauth_consumer_secret.should == "rails_test_secret"
    
  end
end
