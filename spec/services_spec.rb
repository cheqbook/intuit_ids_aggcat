require 'spec_helper'

describe IntuitIdsAggcat::Client::Services do
  before(:all) do
    path = Pathname.new("spec/config/real_config.yml")
    cfg = YAML::load(ERB.new(File.read(path)).result)
    IntuitIdsAggcat.config(cfg)
  end

  it 'should map datetimes to and from XML correctly using custom date_time node type' do
    al_xml = %q^<?xml version='1.0' encoding='UTF-8' standalone='yes'?> <AccountList><BankingAccount><accountId>400000013892</accountId><status>ACTIVE</status><accountNumber>5053</accountNumber><accountNickname>Interest Checking</accountNickname><displayPosition>3</displayPosition><institutionId>14007</institutionId><description>CHECKING</description><balanceAmount>3.22</balanceAmount><balanceDate>2012-10-23T13:04:03-07:00</balanceDate><lastTxnDate>2012-10-15T00:00:00-07:00</lastTxnDate><aggrSuccessDate>2012-10-23T13:04:03.948-07:00</aggrSuccessDate><aggrAttemptDate>2012-10-23T13:04:03.948-07:00</aggrAttemptDate><aggrStatusCode>0</aggrStatusCode><currencyCode>USD</currencyCode><institutionLoginId>5200187</institutionLoginId><bankingAccountType>CHECKING</bankingAccountType><availableBalanceAmount>3.22</availableBalanceAmount></BankingAccount></AccountList>^
    al_rexml = REXML::Document.new al_xml
    al_obj = IntuitIdsAggcat::AccountList.load_from_xml(al_rexml.root)
    # 2012-10-23T13:04:03.948-07:00
    al_obj.banking_accounts[0].aggregation_success_date.year.should == 2012
    al_obj.banking_accounts[0].aggregation_success_date.month.should == 10
    al_obj.banking_accounts[0].aggregation_success_date.day.should == 23
    al_obj.banking_accounts[0].aggregation_success_date.hour.should == 13
    al_obj.banking_accounts[0].aggregation_success_date.minute.should == 4
    al_obj.banking_accounts[0].aggregation_success_date.second.should == 3
    al_obj.banking_accounts[0].aggregation_success_date.zone.should == "-07:00"

    # 2012-10-15T00:00:00-07:00
    al_obj.banking_accounts[0].last_transaction_date.year.should == 2012
    al_obj.banking_accounts[0].last_transaction_date.month.should == 10
    al_obj.banking_accounts[0].last_transaction_date.day.should == 15
    al_obj.banking_accounts[0].last_transaction_date.hour.should == 0
    al_obj.banking_accounts[0].last_transaction_date.minute.should == 0
    al_obj.banking_accounts[0].last_transaction_date.second.should == 0
    al_obj.banking_accounts[0].last_transaction_date.zone.should == "-07:00"

    dt = DateTime.new(2012, 10, 20, 21, 15, 15, '+5')
    b = IntuitIdsAggcat::BankingAccount.new
    b.last_transaction_date = dt
    output_time = b.save_to_xml.each_element("//lastTxnDate"){ |x| x}[0].text
    output_time.should == "2012-10-20T21:15:15+05:00"
    

  end

  it 'should get financial institutions' do
    institutions = IntuitIdsAggcat::Client::Services.get_institutions
    institutions.should_not be_nil
    institutions[0].name.should_not be_nil
  end

  it 'should get financial institution detail' do
    i = IntuitIdsAggcat::Client::Services.get_institution_detail 14007
    i.name.should == "Bank of America"
    i.special_text.should == "Please enter your Bank of America Online ID and Passcode required for login."
  end

  it 'should setup aggregation with username/password, get accounts, get transactions, then delete the customer' do
    # delete customer to ensure we are starting from scratch
    IntuitIdsAggcat::Client::Services.delete_customer "9cj2hbjfgh47cna72"

    # discover accounts
    x = IntuitIdsAggcat::Client::Services.discover_and_add_accounts_with_credentials 100000, "9cj2hbjfgh47cna72", { "Banking Userid" => "direct", "Banking Password" => "anyvalue" } 
    x[:discover_response][:response_code].should == "201"
    x[:accounts].should_not be_nil
    x[:accounts].banking_accounts.count.should be > 2
    x = IntuitIdsAggcat::Client::Services.get_customer_accounts "9cj2hbjfgh47cna72"
    x.should_not be_nil
    x.banking_accounts.count.should be > 2

    # get transactions from 90 days ago until current
    start = Time.now - (90 * 24 * 60 * 60)
    y = IntuitIdsAggcat::Client::Services.get_account_transactions "9cj2hbjfgh47cna72", x.banking_accounts[0].account_id, start
    y.should_not be_nil
    y.banking_transactions[0].id.should_not be_nil
    y.banking_transactions[0].amount.should_not be_nil
    
    # delete customer
    x = IntuitIdsAggcat::Client::Services.delete_customer "9cj2hbjfgh47cna72"
    x[:response_code].should == "200"

  end

  it 'should setup aggregation with text challenge then delete the customer' do
    IntuitIdsAggcat::Client::Services.delete_customer "9cj2hbjfgh47cna72"
    x = IntuitIdsAggcat::Client::Services.discover_and_add_accounts_with_credentials 100000, "9cj2hbjfgh47cna72", { "Banking Userid" => "tfa_text", "Banking Password" => "anyvalue" } 
    x[:discover_response][:response_code].should == "401"
    x[:discover_response][:challenge_node_id].should_not be_nil
    x[:discover_response][:challenge_session_id].should_not be_nil
    x[:challenge_type].should == "text"
    x[:challenge].challenge[0].text.should == "Enter your first pet's name:"
    x = IntuitIdsAggcat::Client::Services.challenge_response 100000, "9cj2hbjfgh47cna72", "test", x[:discover_response][:challenge_session_id], x[:discover_response][:challenge_node_id]
    x[:accounts].should_not be_nil
    x[:accounts].banking_accounts.count.should be > 2
    x = IntuitIdsAggcat::Client::Services.delete_customer "9cj2hbjfgh47cna72"
    x[:response_code].should == "200"
  end

  it 'should setup aggregation with choice challenge then delete the customer' do
    IntuitIdsAggcat::Client::Services.delete_customer "9cj2hbjfgh47cna72"
    x = IntuitIdsAggcat::Client::Services.discover_and_add_accounts_with_credentials 100000, "9cj2hbjfgh47cna72", { "Banking Userid" => "tfa_choice", "Banking Password" => "anyvalue" } 
    x[:discover_response][:response_code].should == "401"
    x[:discover_response][:challenge_node_id].should_not be_nil
    x[:discover_response][:challenge_session_id].should_not be_nil
    x[:challenge_type].should == "choice"
    x[:challenge].challenge[0].text.should == "Which high school did you attend?"
    x = IntuitIdsAggcat::Client::Services.challenge_response 100000, "9cj2hbjfgh47cna72", "test", x[:discover_response][:challenge_session_id], x[:discover_response][:challenge_node_id]
    x[:accounts].should_not be_nil
    x[:accounts].banking_accounts.count.should be > 2
    x = IntuitIdsAggcat::Client::Services.delete_customer "9cj2hbjfgh47cna72"
    x[:response_code].should == "200"
  end

end