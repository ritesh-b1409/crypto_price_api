require "faraday"
require "faraday/retry"

class CoingeckoClient
  class Error < StandardError; end

  BASE_URL = "https://api.coingecko.com/api/v3"

  def initialize(api_key: ENV["COINGECKO_API_KEY"], connection: nil)
    @api_key = api_key
    @connection = connection || build_connection
  end

  def fetch_price(coin_id, vs_currency: "usd")
    response = @connection.get("simple/price") do |req|
      req.params["ids"] = coin_id
      req.params["vs_currencies"] = vs_currency
    end

    raise Error, "Unexpected status #{response.status}" unless response.success?

    price = response.body.dig(coin_id, vs_currency)
    raise Error, "No price data returned for #{coin_id}/#{vs_currency}" if price.nil?

    Float(price)
  rescue Faraday::Error => e
    raise Error, "Network error contacting CoinGecko: #{e.message}"
  rescue JSON::ParserError => e
    raise Error, "Malformed response from CoinGecko: #{e.message}"
  end

  private

  def build_connection
    Faraday.new(url: BASE_URL) do |f|
      f.request :retry, max: 2, interval: 0.5, backoff_factor: 2,
                         exceptions: [ Faraday::TimeoutError, Faraday::ConnectionFailed ]
      f.headers["x-cg-demo-api-key"] = @api_key if @api_key.present?
      f.response :json
      f.options.timeout = 5
      f.options.open_timeout = 3
      f.adapter Faraday.default_adapter
    end
  end
end
