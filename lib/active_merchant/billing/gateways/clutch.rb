require 'active_support/core_ext/hash/slice'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ClutchGateway < Gateway

      self.test_url = 'https://api-test.profitpointinc.com:9002/merchant/'
      self.live_url = 'https://api.clutch.com/merchant/'

      # ==== Options
      #
      # * <tt>:login</tt> -- The Clutch API Login ID (REQUIRED)
      # * <tt>:password</tt> -- The Clutch Transaction Key. (REQUIRED)
      # * <tt>:test</tt> -- +true+ or +false+. If true, perform transactions against the test server.

      def initialize(options = {})
        requires!(options, :login, :password, :brand_id, :location, :terminal)
        @api_key      = options[:login]
        @api_secret   = options[:password]
        @brand_id     = options[:brand_id]
        @location     = options[:location]
        @terminal     = options[:terminal]
        @require_pin  = options[:require_pin]
        super
      end

      def authorize(identification, amount, options = {})
        post = {}
        add_single_card(post, identification)
        add_action(post, :hold)
        add_currency_balance(post, amount, options)
        add_pin_validation(post, options[:pin]) if options[:require_pin]
        add_return_balances(post)
        commit(:post, "updateBalance", post)
      end

      def capture(identification, amount, authorization, options = {})
        post = {}
        add_single_card(post, identification)
        add_action(post, :redeem)
        add_currency_balance(post, amount, options)
        add_redeem_transaction_id(post, authorization)
        add_release_hold_remainder(post)
        add_return_balances(post)
        commit(:post, "updateBalance", post)
      end

      def void(identification, authorization, options = {})
        post = {}
        add_single_card(post, identification)
        add_action(post, :redeem)
        add_currency_balance(post, 0, options)
        add_redeem_transaction_id(post, authorization)
        add_release_hold_remainder(post)
        add_return_balances(post)
        commit(:post, "updateBalance", post)
      end

      def refund(identification, amount, options = {})
        post = {}
        add_single_card(post, identification)
        add_action(post, :issue)
        add_return_related(post)
        add_currency_balance(post, amount, options)
        add_return_balances(post)
        commit(:post, "updateBalance", post)
      end

      def add_return_related(post)
        post["isReturnRelated"] = true
      end

      def add_pin_validation(post, pin)
        post["forcePinValidation"] = true
        post["pin"] = pin.try(:to_s)
      end
      
      def add_redeem_transaction_id(post, authorization)
        post["redeemFromHoldTransactionId"] = authorization.try(:to_s)
      end

      def add_release_hold_remainder(post)
        post["releaseHoldRemainder"] =  true
      end

      def allocate_from_set(set, options = {})
        post = {}
        add_card_set(post, set)
        commit(:post, "allocate", post)
      end

      def allocate_from_id(identification, options = {})
        post = {}
        add_single_card(post, identification)
        commit(:post, "allocate", post)
      end

      def add_card_set(post, set)
        post["cardSetId"] = set
      end

      def update_balance(identification, amount, action = :issue, options = {})
        post = {}
        add_single_card(post, identification)
        add_action(post, action)
        add_currency_balance(post, amount, options)
        add_return_balances(post)
        add_max_overdraw(post)
        commit(:post, "updateBalance", post)
      end

      def get_card(identification, options = {})
        post = {}
        add_single_card_search(post, identification)
        add_pin_validation(post, options[:pin]) if options[:require_pin]
        commit(:post, "search", post)
      end

      def test_credentials(options = {})
        post = {"filters" => {}}
        commit(:post, "search", post)
      end

      def add_single_card(post, identification)
        post["cardNumber"] = identification.try(:to_s)
      end

      def add_action(post, action)
        post["action"] = action.try(:to_s)
      end

      def add_currency_balance(post, amount, options = {})
        post["amount"] = {
          "balanceType"   => "Currency",
          "balanceCode"   => options[:currency] || "USD",
          "amount"        => amount.try(:to_f)
        }
      end

      def add_return_balances(post)
        post["returnBalances"] = true
      end

      def add_max_overdraw(post)
        post["redeemMaxOnOverdraw"] = true
      end

      def add_single_card_search(post, identification)
        post["filters"] = {
          "cardNumber" => identification
        }
        post["returnFields"] = {
          "balances"          => true,
          "customer"          => true,
          "alternateCustomer" => true,
          "giverCustomer"     => true,
          "isEnrolled"        => true,
          "customData"        => true,
          "customCardNumber"  => true
        }
      end

      def headers(options = {})
        brand     = options[:brand_id] || @brand_id
        {
          "Content-Type"    => "application/json",
          "Authorization"   => "Basic #{basic_auth(options)}",
          "Brand"           => brand,
          "Location"        => @location,
          "Terminal"        => @terminal
        }
      end

      def basic_auth(options = {})
        key       = options[:api_key] || @api_key
        secret    = options[:api_secret] || @api_secret
        Base64.strict_encode64("#{key}:#{secret}").strip
      end

      def commit(method, url, parameters=nil, options = {})
        raw_response = response = nil
        success = false

        begin
          endpoint_url    = test? ? self.test_url : self.live_url
          request_body    = parameters.to_json
          request_headers = headers(options)

          ap parameters
          ap request_headers

          raw_response  = ssl_request(method, endpoint_url + url, request_body, request_headers)
          response      = parse(raw_response)
          success       = response['success']
        rescue ResponseError => e
          raw_response  = e.response.body
          response      = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end

        ap response

        Response.new(success,
          response,
          :test => test?,
          :authorization => response["id"]
        )
      end

      # FIX ME: move below methods to module (copied from Stripe)

      def response_error(raw_response)
        begin
          parse(raw_response)
        rescue JSON::ParserError
          json_error(raw_response)
        end
      end

      def json_error(raw_response)
        msg = 'Invalid response received from Clutch.'
        msg += "  (The raw response returned by the API was #{raw_response.inspect})"
        {
          "error" => {
            "message" => msg
          }
        }
      end

      def parse(body)
        JSON.parse(body)
      end

    end
  end
end
