intuit_ids_aggcat - A wrapper for Intuit's Aggregation & Categorization Data Services
==================================================================
**Important Note: This gem is still under active development for its first release. Features are missing or imcomplete. It is released under the Apache 2.0 license "as-is" without warranty.**  

Configuration
-----------------
While the first release of this gem is being developed, it will not be included in gem directories. Installation of the gem can be accomplished by cloning the code from Github and installing manually:  
`git clone https://github.com/rewardsummit/intuit_ids_aggcat.git`  
`gem build intuit_ids_aggcat.gemspec && gem install intuit_ids_aggcat-0.0.1.gem`  
  
... or in a Rails environment using bundler by adding this to your Gemfile:  
`gem 'quicken_parser', :git => 'https://github.com/rewardsummit/intuit_ids_aggcat.git'`
  
Once installed, you can manually configure the gem at runtime (e.g. in a pure Ruby environment) by doing:  
`require "intuit_ids_aggcat"`  
`IntuitIdsAggcat.config(:issuer_id => "intuit_issuer_id")`  
`IntuitIdsAggcat.config(:oauth_consumer_key => "intuit_consumer_key")`  
`IntuitIdsAggcat.config(:oauth_consumer_secret => "intuit_consumer_secret")`  
`IntuitIdsAggcat.config(:certificate_path => "path_to_private_key.key")`  
  
Or in a Rails environment by creating a file *config/intuit_ids_aggcat.yml* with the following format:  
`development:`  
&nbsp;&nbsp;`certificate_path: config/path_to_key.key`  
&nbsp;&nbsp;`issuer_id: intuit_issuer_id`  
&nbsp;&nbsp;`oauth_consumer_key: consumer_key`  
&nbsp;&nbsp;`oauth_consumer_secret: consumer_secret`  
  
In addition to providing a certificate path, you can also pass a certificate string using the the certificate_string key in YAML or the symbol :certificate_string in the hash when calling IntuitIdsAggCat.config. You may optionally pass a certificate password as certificate_password if your private certificate is passphrase protected. Finally, you can also provide a proxy configuration parameter in the format "http://host:port". Username/password authentication with proxies is not currently supported.  
  
Important Note On Intuit Tokens
------------------------------------------
**Before attempting to use this gem, you must read the Aggregation & Categorization API documentation on the Intuit Partner Platform web site. Understanding how the API works is critical to a successful implementation. If you do not understand the API, you may make mistakes that have serious unintended consequences for your users.**

Intuit's platform makes use of OAuth tokens to authenticate your use of the system as well as to provide information about the customer for whom you are making the request. For example, assuming you are writing an application named "MyFinancialService" and you are aggregating accounts for "steve", the OAuth token you use to interact with Intuit identify both the application *MyFinancialService* _and_ connect the functions you perform on user *steve*'s behalf to an identity on Intuit's systems.  When you make a call to discover and add accounts, your OAuth token identifies your request to Intuit as coming from *MyFinancialService* and that the request is being done for user *steve*. Subsequent requests for that user need to keep this context (for example, so you can add or remove accounts for the user). Similarly, if you make another request for user *joe*, you cannot reuse the OAuth tokens you used when you used for *steve*, otherwise you will inadvertently take action using *joe*'s account but it will affect *steve*. 
  
 For example, if you want to discover and add accounts for steve, you could call:  
   
 `IntuitIdsAggcat::Client::Services.discover_and_add_accounts_with_credentials 14007, "steve", { "onlineID" => "steve_bank", "passcode" => "mysecret" }`  
   
 In this example, *14007* is the institution ID (Bank of America, in this case), and *steve* is the username you are identifying to link the accounts to. If, after some period of time, you need to delete the accounts connected to *steve*, you could call: 
  
`IntuitIdsAggcat::Client::Services.delete_customer "steve"`
  
What is happening behind the scenes with each of these requests is an OAuth token for your application and user steve is being created. If you have a number of requests that you will make, one after the other, for the same user in a short period of time, this may not be ideal. You can explicitly request an OAuth token for user steve by calling:  
  
`tokens = IntuitIdsAggcat::Client::Saml.get_tokens "steve"`  

This returns a hash with the keys oauth_token_secret and oauth_token that are used to identify the application and user to the server and a key token_expiry that contains the time at which the token will stop working. You can pass an explicit token to the service methods like this:  
  
`IntuitIdsAggcat::Client::Services.discover_and_add_accounts_with_credentials 14007, "steve", { "onlineID" => "steve_bank", "passcode" => "mysecret" }, tokens`  
`IntuitIdsAggcat::Client::Services.delete_customer "steve", tokens`  
  
What is important to undestand about this is that while username is always required as a parameter, providing tokens explicitly ALWAYS overrides whatever username you provide. This can have a potential unintended side-effect:
  
`tokens = IntuitIdsAggcat::Client::Saml.get_tokens "steve" # tokens are related to user steve` 
`IntuitIdsAggcat::Client::Services.discover_and_add_accounts_with_credentials 14007, "steve", { "onlineID" => "steve_bank", "passcode" => "mysecret" }, tokens # adds accounts from Bank of America, logging in with steve_bank/mysecret, to a user you have named steve`  
`IntuitIdsAggcat::Client::Services.discover_and_add_accounts_with_credentials 14007, "cathy", { "onlineID" => "cathy", "passcode" => "money" }, tokens # WRONG! adds Bank of America accounts for online ID cathy to steve's aggregation profile because the token is still tied to steve's identity!` 
  
**It is critically important that if you do this, YOU MANAGE THE RELATIONSHIP BETWEEN THE TOKEN AND THE USER.** If you pass your own OAuth tokens, the gem will use whatever you pass **with no validation**. This means that if you provide a username of "joe", but OAuth tokens for username "steve", the activity you perform will be done in the context of *steve*. Managing your own tokens may provide some performance benefits, but you must take extra care to ensure that the token you pass is connected with the user you intend.   
  
Usage
-----
The gem currently provides the following helper class methods from IntuitIdsAggcat::Client::Services:  

- get_institutions(oauth_token_info, consumer_key, consumer_secret): all arguments optional, a "default" user context will be used for the request and consumer_key and consumer_secret will be pulled from the gem configuration if not specified. Returns an XML document with institution data.  
- get_institution_detail(id, oauth_token_info, consumer_key, consumer_secret): id is required and is the institution ID for which the detail is retrieved, all other arguments optional, a "default" user context will be used for the request and consumer_key and consumer_secret will be pulled from the gem configuration if not specified. Returns institution detail XML document.  
- discover_and_add_accounts_with_credentials institution_id, username, creds_hash, oauth_token_info, consumer_key, consumer_secret, timeout): Discovers and adds accounts from institution in the context of username or using the auth_tokens provided using the key/value pairs in creds_hash to populate the credentials/credential elements of the login request message. If no oauth_token_info is provided, new tokens will be provisioned using username. consumer_key, consumer_secret are optional and will be pulled from the gem configuration. timeout is optional, default is 30 seconds. **Currently only supports FIs that do NOT use MFA. Still under development!**  
- delete_customer(username, oauth_token_info, consumer_key, consumer_secret): Deletes a customer from aggregation in the context of username or using the oauth_tokens provided.  
  
Return values from all methods except get_institutions and get_institution_detail are a hash with a response_code key with the HTTP response code value and a response_xml key containing a REXML::Document object.
  
### Examples
  
	institutions = IntuitIdsAggcat::Client::Services.get_institutions # get a list of all institutions
	i = IntuitIdsAggcat::Client::Services.get_institution_detail 14007 # get details for institution id 14007
	x = IntuitIdsAggcat::Client::Services.discover_and_add_accounts_with_credentials 100000, 1, { "Banking Userid" => "direct", "Banking Password" => "anyvalue" } # sets up aggregation for an Intuit test ID as user 1
	x = IntuitIdsAggcat::Client::Services.delete_customer 1 # stops aggregation for user 1
	x = IntuitIdsAggcat::Client::Services.discover_and_add_accounts_with_credentials 100000, 1, { "Banking Userid" => "tfa_text", "Banking Password" => "anyvalue" } # sets up aggregation for an Intuit test ID as user 1but results in a multi-factor auth text-based challenge
	y = IntuitIdsAggcat::Client::Services.challenge_response 100000, 1, "challenge_response", x[:challenge_session_id], x[:challenge_node_id] #responds to challenge question above with "challenge_response"
	x = IntuitIdsAggcat::Client::Services.delete_customer 1 # stops aggregation for user 1
	x = IntuitIdsAggcat::Client::Services.discover_and_add_accounts_with_credentials 100000, 1, { "Banking Userid" => "tfa_text", "Banking Password" => "anyvalue" } # sets up aggregation for an Intuit test ID as user 1but results in a multi-factor auth text-based challenge
	y = IntuitIdsAggcat::Client::Services.challenge_response 100000, 1, "challenge_response", x[:challenge_session_id], x[:challenge_node_id] #responds to challenge question above with "challenge_response"
	x = IntuitIdsAggcat::Client::Services.delete_customer 1 # stops aggregation for user 1
	x = IntuitIdsAggcat::Client::Services.discover_and_add_accounts_with_credentials 100000, 1, { "Banking Userid" => "tfa_choicet", "Banking Password" => "anyvalue" } # sets up aggregation for an Intuit test ID as user 1but results in a multi-factor auth text-based challenge
	y = IntuitIdsAggcat::Client::Services.challenge_response 100000, 1, "Madison", x[:challenge_session_id], x[:challenge_node_id] #responds to challenge question above with Madison choice value response
	x = IntuitIdsAggcat::Client::Services.delete_customer 1 # stops aggregation for user 1
  
Testing
----------
In order to thoroughly test the Intuit integration, many of the RSpec tests included with this gem make live calls to the Intuit services and use Intuit's test financial institutions/customers/accounts. In order for this to work, real OAuth tokens and the corresponding private  key and issuer ID need to be used. To configure these the tests assume there is a YAML configuration in spec/config/real_config.yml in the following format:  
  
`certificate_path: key_file`  
`issuer_id: issuer_id`  
`oauth_consumer_key: consumer_key`  
`oauth_consumer_secret: consumer_secret`  
  
Note that the tests do create a test user to validate the integration and this will count towards your Intuit usage. In general the tests always delete the user provided the tests are not stopped in the middle of execution or experience an exception that interrupt the test, so there should be a net effect of one additional user per month that you execute the tests.  The test user ID is "9cj2hbjfgh47cna72" - this random string should prevent collision with a real user in your system.
  
The .gitignore file contains spec/config/real_config.yml and spec/config/real_cert.key to prevent sensitive information from being checked in. Note that if you change the names, or .gitignore is modified, this may not hold true. Exercise caution when commiting code to public repos.  
  
Contributing
-----------------
Feel free to fork this repo, make changes and submit a pull request. 
